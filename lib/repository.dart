import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/app.dart';

class Repository {
  AuthManager auth;
  GlobalConfig config;
  Repository(GlobalConfig config, AuthManager auth) {
    this.auth = auth;
    this.config = config;
  }

  Future<Translation> begin() async {
    Translation translation = new Translation();
    translation.config.fileItems = await list();
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    translation.server = artifact.server;
    translation.name = artifact.name;
    return translation;
  }

  Future<String> beginUpload(Translation translation) async {
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.postUrl(Uri.parse(
        "https://${translation.server}/v2/${translation.name}/blobs/uploads/"));
    request.headers.set("User-Agent", config.userAgent);
    if (translation.token != null) {
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(
          config.currentRepository, response.headers.value("Www-Authenticate"));
      translation.token = token;
      request = await httpClient.postUrl(Uri.parse(
          "https://${translation.server}/v2/${translation.name}/blobs/uploads/"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      response = await request.close();
    }
    if (response.statusCode == 401){
      throw PermissionDeniedException(config.currentRepository);
    }
    if (response.statusCode >= 300 || response.statusCode < 200) {
      print(request.method);
      print(request.uri);
      print(request.headers);
      throw "Repository start upload status code ${response.statusCode} ${await response.transform(utf8.decoder).join()}";
    }

    return response.headers.value("Location");
  }

  Future<void> commit(Translation translation) async {
    HttpClient httpClient = HttpClient();
    List<int> configContent = utf8.encode(jsonEncode(translation.config));
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
    HttpClientRequest request = await httpClient.putUrl(Uri.parse(
        "https://${translation.server}/v2/${translation.name}/manifests/latest"));
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set(
        "Content-Type", "application/vnd.docker.distribution.manifest.v2+json");
    if (translation.token != null) {
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    String requestBody = jsonEncode(manifest);
    request.write(requestBody);
    HttpClientResponse response = await request.close();
    if (response.statusCode >= 300 || response.statusCode < 200) {
      print(request.method);
      print(request.uri);
      print(request.headers);
      throw "Repository start upload status code ${response.statusCode} ${await response.transform(utf8.decoder).join()}";
    }
  }

  Future<void> remove(Translation translation, String name) async {
    FileItem target;
    for(FileItem item in translation.config.fileItems){
      if(item.name == name){
        target = item;
      }
    }
    if(target == null){
      throw "File item not found $name";
    }
    translation.config.fileItems.remove(target);
  }

  Future<void> pullWithName(Translation translation, String name, String path, TransportProgressListener listener) async {
    FileItem target;
    for(FileItem item in translation.config.fileItems){
      if(item.name == name){
        target = item;
      }
    }
    if(target == null){
      throw "File item not found $name";
    }
    await pull(target.digest, path, listener);
  }

  Future<String> linkWithName(Translation translation, String name) async {
        FileItem target;
    for(FileItem item in translation.config.fileItems){
      if(item.name == name){
        target = item;
      }
    }
    if(target == null){
      throw "File item not found $name";
    }
    return await link(target.digest);
  }

  Future<void> upload(Translation translation, String name, String path, TransportProgressListener listener) async {
    String url = await beginUpload(translation);
    String hash =
        (await sha256.bind(File(path).openRead()).firstWhere((d) => true))
            .toString();
    Uri uploadUri = Uri.parse("$url&digest=sha256:$hash");
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.putUrl(uploadUri);
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Content-Type", "application/octet-stream");
    if (translation.token != null) {
      request.headers.set("Authorization", "Bearer ${translation.token}");
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
    Uri uploadUri = Uri.parse("$url&digest=sha256:$hash");
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.putUrl(uploadUri);
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Content-Type", "application/octet-stream");
    if (translation.token != null) {
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    request.contentLength = content.length;
    await request.addStream(Stream.fromFuture(Future.value(content)));
    HttpClientResponse response = await request.close();
    if (response.statusCode >= 300 || response.statusCode < 200) {
      String body = await response.transform(utf8.decoder).join();
      throw "Repository upload status code ${response.statusCode} $body";
    }
    return "sha256:$hash";
  }

  Future<List<FileItem>> list() async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse(
        "https://${artifact.server}/v2/${artifact.name}/manifests/latest"));
    request.headers.set("User-Agent", config.userAgent);
    request.headers
        .set("Accept", "application/vnd.docker.distribution.manifest.v2+json");
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(
          config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse(
          "https://${artifact.server}/v2/${artifact.name}/manifests/latest"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      request.headers.set(
          "Accept", "application/vnd.docker.distribution.manifest.v2+json");
      response = await request.close();
    }
    if (response.statusCode == 404) {
      return List();
    }
    if (response.statusCode >= 300 || response.statusCode < 200) {
      String body = await response.transform(utf8.decoder).join();
      throw "Repository list status code ${response.statusCode} $body";
    }
    String body = await response.transform(utf8.decoder).join();
    String configContent =
        await pullConfig(jsonDecode(body)["config"]["digest"]);
    ManifestConfig manifestConfig =
        ManifestConfig.fromJson(jsonDecode(configContent));
    return manifestConfig.fileItems;
  }

  Future<String> pullConfig(String digest) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse(
        "https://${artifact.server}/v2/${artifact.name}/blobs/$digest"));
    request.headers.set("User-Agent", config.userAgent);
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(
          config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse(
          "https://${artifact.server}/v2/${artifact.name}/blobs/$digest"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      response = await request.close();
    }
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository list status code ${response.statusCode}";
    }
    return response.transform(utf8.decoder).join();
  }

  Future<String> link(String hash) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse(
        "https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
    request.headers.set("User-Agent", config.userAgent);
    request.followRedirects = false;
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(
          config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse(
          "https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      request.followRedirects = false;
      response = await request.close();
    }
    response.drain();
    if (response.statusCode >= 400 || response.statusCode < 300) {
      print("https://${artifact.server}/v2/${artifact.name}/blobs/$hash");
      throw "Repository pull status code ${response.statusCode} ${request.headers}";
    }
    return response.headers.value("Location");
  }

  Future<void> pull(String hash, String path, TransportProgressListener listener) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse(
        "https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
    request.headers.set("User-Agent", config.userAgent);
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(
          config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse(
          "https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      response = await request.close();
    }
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "Repository pull status code ${response.statusCode}";
    }
    var length = response.contentLength;
    var received = 0;
    var timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      listener.onProgess(received, length);
    });
    await response.map((s) {
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
