import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/helper/DrcHttpClient.dart';
import 'package:http/http.dart';
import 'package:synchronized/synchronized.dart';

class Repository {
  final AuthManager auth;
  final GlobalConfig config;
  final DrcHttpClient client;
  final cachedFilesLock = new Lock();
  Map<String, List<FileItem>> cachedFiles = Map();

  Repository(this.auth, this.config, this.client);

  Future<Translation> begin() async {
    Translation translation = new Translation();
    await cachedFilesLock.synchronized(() async {
      if (cachedFiles.containsKey(config.currentRepository)) {
        translation.config.fileItems = cachedFiles[config.currentRepository];
      } else {
        translation.config.fileItems = await list();
        cachedFiles[config.currentRepository] = translation.config.fileItems;
      }
    });
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    translation.server = artifact.server;
    translation.name = artifact.name;
    translation.repository = config.currentRepository;
    return translation;
  }

  Future<String> beginUpload(Translation translation) async {
    Response response = await client.post(
        "https://${translation.server}/v2/${translation.name}/blobs/uploads/",
        headers: {"repository": translation.repository});
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository start upload status code ${response.statusCode} ${response.body}";
    }
    return response.headers["location"];
  }

  Future<void> commit(Translation translation) async {
    List<int> configContent = utf8.encode(json.encode(translation.config));
    String configDigest = await uploadConfig(translation, configContent);
    Map<String, dynamic> manifest = Map();
    manifest["schemaVersion"] = 2;
    manifest["mediaType"] =
        "application/vnd.docker.distribution.manifest.v2+json";
    Map<String, dynamic> manifestConfig = Map();
    manifestConfig["mediaType"] =
        "application/vnd.docker.container.image.v1+json";
    manifestConfig["size"] = configContent.length;
    manifestConfig["digest"] = configDigest;
    List<Map<String, dynamic>> layers = List();
    for (FileItem item in translation.config.fileItems) {
      Map<String, dynamic> layer = new Map();
      layer["mediaType"] = "application/vnd.docker.image.rootfs.diff.tar.gzip";
      layer["digest"] = item.digest;
      layer["size"] = item.size;
      layers.add(layer);
    }
    manifest["config"] = manifestConfig;
    manifest["layers"] = layers;
    Response response = await client.put(
        "https://${translation.server}/v2/${translation.name}/manifests/latest",
        headers: {
          "repository": translation.repository,
          "Content-Type": "application/vnd.docker.distribution.manifest.v2+json"
        },
        body: json.encode(manifest));
    cachedFiles.remove(translation.repository);
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository put manifests status code ${response.statusCode} ${response.body}";
    }
  }

  Future<void> rename(Translation translation, String originName, String targetName) async {
    if (!targetName.startsWith("/") || targetName.contains("*") || targetName.contains("//")) {
      throw "targetName [$targetName] must not contains * or // and start with /";
    }
    if(translation.config.fileItems.firstWhere((element) => element.name == targetName, orElse: () => null) != null){
      throw "targetName [$targetName] already exists in repository";
    }
    FileItem item = translation.config.fileItems.firstWhere((element) => element.name == originName, orElse: () => null);
    if(item == null){
      throw "originName [$originName] not found in repository";
    }
    item.name = targetName;
  }
  

  Future<void> remove(Translation translation, String name) async {
    Set<String> originHashs =
        await Stream.fromIterable(translation.config.fileItems)
            .map((event) => event.digest)
            .toSet();
    int originSize = translation.config.fileItems.length;
    translation.config.fileItems.removeWhere((item) =>
        item.name == name ||
        (item.name.startsWith(name) && name.endsWith("/")) ||
        name == '*');
    Set<String> currentHashs =
        await Stream.fromIterable(translation.config.fileItems)
            .map((event) => event.digest)
            .toSet();
    int currentSize = translation.config.fileItems.length;
    if (originSize == currentSize) {
      throw "No file match $name";
    }
    // originHashs -> removedHashs
    originHashs.removeAll(currentHashs);
    originHashs.forEach((element) async {
      Response response = await client.delete(
          "https://${translation.server}/v2/${translation.name}/blobs/${element}",
          headers: {"repository": translation.repository});
      if (response.statusCode >= 300 || response.statusCode < 200) {
        print(
            "Repository delete status code ${response.statusCode} ${response.body}");
      }
    });
  }

  Future<void> pullWithName(Translation translation, String name, String path,
      TransportProgressListener listener) async {
    FileItem target;
    for (FileItem item in translation.config.fileItems) {
      if (item.name == name) {
        target = item;
      }
    }
    if (target == null) {
      throw "File item not found $name";
    }
    await pull(target.digest, path, listener);
  }

  Future<String> linkWithName(Translation translation, String name) async {
    FileItem target;
    for (FileItem item in translation.config.fileItems) {
      if (item.name == name) {
        target = item;
      }
    }
    if (target == null) {
      throw "File item not found $name";
    }
    return await link(target.digest);
  }

  Future<void> upload(Translation translation, String name, String path,
      TransportProgressListener listener) async {
    if (!name.startsWith("/") || name.contains("*") || name.contains("//")) {
      throw "name [$name] must not contains * or // and start with /";
    }
    String url = await beginUpload(translation);
    Future<Digest> hashFuture = sha256.bind(File(path).openRead()).first;
    Uri uploadUri = Uri.parse("$url");
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.patchUrl(uploadUri);
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Content-Type", "application/octet-stream");
    if (client.cachedTokens.containsKey(translation.repository)) {
      request.headers.set("Authorization",
          "Bearer ${client.cachedTokens[translation.repository]}");
    }
    request.contentLength = await File(path).length();
    var length = await File(path).length();
    var sink = File(path).openRead();
    var received = 0;
    var timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      listener.onProgess(received, length);
    });
    await request.addStream(sink.map((s) {
      received += s.length;
      return s;
    }));
    HttpClientResponse response = await request.close();
    if (response.statusCode >= 300 || response.statusCode < 200) {
      String body = await response.transform(utf8.decoder).join();
      throw "Repository upload status code ${response.statusCode} ${response.headers} $body";
    }
    url = response.headers.value("location");
    String hash = (await hashFuture).toString();
    Response completeResponse = await client.put("$url&digest=sha256:$hash",
        headers: {"repository": translation.repository});
    if (completeResponse.statusCode >= 300 ||
        completeResponse.statusCode < 200) {
      throw "Repository start upload status code ${completeResponse.statusCode} ${completeResponse.body}";
    }
    timer.cancel();
    listener.onSuccess(length);
    FileItem fileItem = FileItem();
    fileItem.name = name;
    fileItem.size = request.contentLength;
    fileItem.digest = "sha256:$hash";
    translation.config.fileItems.add(fileItem);
  }

  Future<String> uploadConfig(
      Translation translation, List<int> content) async {
    String url = await beginUpload(translation);
    String hash = sha256.convert(content).toString();
    Response response = await client.put("$url&digest=sha256:$hash",
        headers: {
          "Content-Type": "application/octet-stream",
          "repository": translation.repository
        },
        body: content);
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository upload status code ${response.statusCode} ${response.body}";
    }
    return "sha256:$hash";
  }

  Future<List<FileItem>> list() async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    Response response = await client.get(
        "https://${artifact.server}/v2/${artifact.name}/manifests/latest",
        headers: {
          "Accept": "application/vnd.docker.distribution.manifest.v2+json",
          "repository": "${config.currentRepository}"
        });
    if (response.statusCode == 404) {
      return List();
    }
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository list status code ${response.statusCode} ${response.body}";
    }
    String configContent =
        await pullConfig(json.decode(response.body)["config"]["digest"]);
    ManifestConfig manifestConfig =
        ManifestConfig.fromJson(json.decode(configContent));
    return manifestConfig.fileItems;
  }

  Future<String> pullConfig(String digest) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    Response response = await client.get(
        "https://${artifact.server}/v2/${artifact.name}/blobs/$digest",
        headers: {"repository": "${config.currentRepository}"});
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository list status code ${response.statusCode}";
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<String> link(String hash) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    Request request = Request(
        "get",
        Uri.parse(
            "https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
    request.headers["repository"] = config.currentRepository;
    request.followRedirects = false;
    StreamedResponse response = await client.send(request);
    response.stream.drain();
    if (response.statusCode >= 400 || response.statusCode < 300) {
      throw "Repository pull status code ${response.statusCode} ${response.headers}";
    }
    return response.headers["location"];
  }

  Future<void> pull(
      String hash, String path, TransportProgressListener listener) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    Request request = Request(
        "get",
        Uri.parse(
            "https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
    request.headers["repository"] = config.currentRepository;
    StreamedResponse response = await client.send(request);
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository pull status code ${response.statusCode}";
    }
    var length = response.contentLength;
    var received = 0;
    var timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      listener.onProgess(received, length);
    });
    await response.stream.map((s) {
      received += s.length;
      return s;
    }).pipe(File(path).openWrite());
    timer.cancel();
    listener.onSuccess(length);
  }

  static RepositoryArtifact sovleRepository(String repository) {
    List<String> artifacts = repository.split("/");
    String name, server;
    switch (artifacts.length) {
      case 1:
        name = "library/${artifacts[0]}";
        break;
      case 2:
        name = "${artifacts[0]}/${artifacts[1]}";
        break;
      case 3:
        server = artifacts[0];
        name = "${artifacts[1]}/${artifacts[2]}";
        break;
      default:
        throw "Unsupport repository $repository";
        break;
    }
    RepositoryArtifact result = RepositoryArtifact();
    if (server != null) {
      result.server = server;
    }
    result.name = name;
    return result;
  }
}

class PermissionDeniedException {
  final String repository;

  PermissionDeniedException(this.repository);
}

abstract class TransportProgressListener {
  void onSuccess(int total);
  void onProgess(int currnt, int total);
}

class RepositoryArtifact {
  String server = "registry-1.docker.io";
  String name;
}

class Translation {
  String name;
  String token;
  String server;
  String repository;
  ManifestConfig config = ManifestConfig();

  Translation();

  Translation.fromJson(Map<String, dynamic> json) {
    this.name = json["name"];
    this.token = json["token"];
    this.server = json["server"];
    this.config = ManifestConfig.fromJson(json["config"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['token'] = this.token;
    data['server'] = this.server;
    data['config'] = this.config;
    return data;
  }
}

class ManifestConfig {
  List<FileItem> fileItems = List();

  ManifestConfig();

  ManifestConfig.fromJson(Map<String, dynamic> json) {
    var list = json["fileItems"] as List;
    this.fileItems = list.map((i) => FileItem.fromJson(i)).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['fileItems'] = this.fileItems;
    return data;
  }
}

class FileItem {
  int size;
  String name;
  String digest;

  FileItem({this.name, this.size, this.digest});

  FileItem.fromJson(Map<String, dynamic> json) {
    this.name = json["name"];
    this.size = json["size"];
    this.digest = json["digest"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['size'] = this.size;
    data['digest'] = this.digest;
    return data;
  }
}
