import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/app.dart';
import 'package:filesize/filesize.dart';

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
    HttpClientRequest request = await httpClient.postUrl(Uri.parse("https://${translation.server}/v2/${translation.name}/blobs/uploads/"));
    request.headers.set("User-Agent", config.userAgent);
    if(translation.token != null){
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(config.currentRepository, response.headers.value("Www-Authenticate"));
      translation.token = token;
      request = await httpClient.postUrl(Uri.parse("https://${translation.server}/v2/${translation.name}/blobs/uploads/"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      response = await request.close();
    }
    if (response.statusCode >= 300 || response.statusCode < 200){
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
    manifest["mediaType"] = "application/vnd.docker.distribution.manifest.v2+json";
    Map<String, dynamic> manifestConfig = Map();
    manifestConfig["mediaType"] = "application/vnd.docker.container.image.v1+json";
    manifestConfig["size"] = configContent.length;
    manifestConfig["digest"] = configDigest;
    List<Map<String, dynamic>> layers = List();
    for(FileItem item in translation.config.fileItems){
      Map<String, dynamic> layer = new Map();
      layer["mediaType"] = "application/vnd.docker.image.rootfs.diff.tar.gzip";
      layer["digest"] = item.digest;
      layer["size"] = item.size;
      layers.add(layer);
    }
    manifest["config"] = manifestConfig;
    manifest["layers"] = layers;
    HttpClientRequest request = await httpClient.putUrl(Uri.parse("https://${translation.server}/v2/${translation.name}/manifests/latest"));
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Content-Type", "application/vnd.docker.distribution.manifest.v2+json");
    if (translation.token != null){
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    String requestBody = jsonEncode(manifest);
    print(requestBody);
    request.write(requestBody);
    HttpClientResponse response = await request.close();
    String body = await response.transform(utf8.decoder).join();
    print(body);
  }

  Future<void> upload(Translation translation,String name, String path) async {
    String url = await beginUpload(translation);
    String hash = (await sha256.bind(File(path).openRead()).firstWhere((d) => true)).toString();
    Uri uploadUri = Uri.parse("$url&digest=sha256:$hash");
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.putUrl(uploadUri);
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Content-Type", "application/octet-stream");
    if (translation.token != null){
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    request.contentLength = await File(path).length();
    var length = await File(path).length();
    var sink = File(path).openRead();
    var start = DateTime.now().millisecondsSinceEpoch;
    var received = 0;
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      var current = DateTime.now().millisecondsSinceEpoch;
      var speed = (received / (current - start) * 1000).round();
      print("Uploading $name received ${filesize(received)} total ${filesize(length)} speed ${filesize(speed)}/s");
    });
    await request.addStream(sink.map((s) {
      received += s.length;
      return s;
      }));
    HttpClientResponse response = await request.close();
    if (response.statusCode >= 300 || response.statusCode < 200){
      String body = await response.transform(utf8.decoder).join();
      throw "Repository upload status code ${response.statusCode} ${response.headers} $body";
    }
    FileItem fileItem = FileItem();
    fileItem.name = name;
    fileItem.size = request.contentLength;
    fileItem.digest = "sha256:$hash";
    translation.config.fileItems.add(fileItem);
  }

  Future<String> uploadConfig(Translation translation,List<int> content) async {
    String url = await beginUpload(translation);
    String hash = sha256.convert(content).toString();
    Uri uploadUri = Uri.parse("$url&digest=sha256:$hash");
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.putUrl(uploadUri);
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Content-Type", "application/octet-stream");
    if (translation.token != null){
      request.headers.set("Authorization", "Bearer ${translation.token}");
    }
    request.contentLength = content.length;
    await request.addStream(Stream.fromFuture(Future.value(content)));
    HttpClientResponse response = await request.close();
    if (response.statusCode >= 300 || response.statusCode < 200){
      String body = await response.transform(utf8.decoder).join();
      throw "Repository upload status code ${response.statusCode} $body";
    }
    return "sha256:$hash";
  }

  Future<List<FileItem>> list() async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/manifests/latest"));
    request.headers.set("User-Agent", config.userAgent);
    request.headers.set("Accept", "application/vnd.docker.distribution.manifest.v2+json");
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/manifests/latest"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      request.headers.set("Accept", "application/vnd.docker.distribution.manifest.v2+json");
      response = await request.close();
    }
    if(response.statusCode == 404){
      return List();
    }
    if (response.statusCode >= 300 || response.statusCode < 200){
      String body = await response.transform(utf8.decoder).join();
      throw "Repository list status code ${response.statusCode} $body";
    }
    String body = await response.transform(utf8.decoder).join();
    String configContent = await pullConfig(jsonDecode(body)["config"]["digest"]);
    ManifestConfig manifestConfig = ManifestConfig.fromJson(jsonDecode(configContent));
    return manifestConfig.fileItems;
  }

  Future<String> pullConfig(String digest) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/$digest"));
    request.headers.set("User-Agent", config.userAgent);
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/$digest"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      response = await request.close();
    }
    if (response.statusCode >= 300 || response.statusCode < 200){
      throw "Repository list status code ${response.statusCode}";
    }
    return response.transform(utf8.decoder).join();
  }

  Future<String> link(String hash) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
    request.headers.set("User-Agent", config.userAgent);
    request.followRedirects = false;
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      request.followRedirects = false;
      response = await request.close();
    }
    if (response.statusCode >= 400 || response.statusCode < 300){
      throw "Repository pull status code ${response.statusCode}";
    }
    return response.headers.value("Location");
  }

  Future<void> pull(String hash, String path) async {
    RepositoryArtifact artifact = sovleRepository(config.currentRepository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
    request.headers.set("User-Agent", config.userAgent);
    HttpClientResponse response = await request.close();
    String token;
    if (response.statusCode == 401) {
      token = await auth.challenge(config.currentRepository, response.headers.value("Www-Authenticate"));
      request = await httpClient.getUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/$hash"));
      request.headers.set("User-Agent", config.userAgent);
      request.headers.set("Authorization", "Bearer $token");
      response = await request.close();
    }
    if (response.statusCode >= 300 || response.statusCode < 200){
      throw "Repository pull status code ${response.statusCode}";
    }
    var length = response.contentLength;
    var start = DateTime.now().millisecondsSinceEpoch;
    var received = 0;
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      var current = DateTime.now().millisecondsSinceEpoch;
      var speed = (received / (current - start) * 1000).round();
      print("Downloading $path received ${filesize(received)} total ${filesize(length)} speed ${filesize(speed)}/s");
    });
    await response.map((s) {
      received += s.length;
      return s;
      }).pipe(File(path).openWrite());
  }

  static RepositoryArtifact sovleRepository(String repository){
    List<String> artifacts = repository.split("/");
    String name, server;
    switch(artifacts.length){
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
    if(server != null){
      result.server = server;
    }
    result.name = name;
    return result;
  }
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

  FileItem();

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