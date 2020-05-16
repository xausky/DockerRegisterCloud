import 'dart:io';
import 'dart:convert';

import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/repository.dart';

class AuthManager {
  final BasePlatform platform;
  final GlobalConfig config;
  AuthManager(this.platform, this.config);

  Future<void> use(String repository) async {
    config.currentRepository = repository;
    await platform.save('config', config);
  }

  Future<void> remove(String repository) async {
    config.repositoryCretificates.remove(repository);
    if(config.currentRepository == repository){
      config.currentRepository = null;
    }
    await platform.save('config', config);
  }

  Future<void> list() async {
    for(String key in config.repositoryCretificates.keys){
      bool logined = config.repositoryCretificates.containsKey(key);
      print("${logined?'Logined':'NoLogin'} $key");
    }
    print("Current Use: ${config.currentRepository}");
  }

  Future<String> login(String repository, String username, String password) async {
    RepositoryArtifact artifact = Repository.sovleRepository(repository);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.postUrl(Uri.parse("https://${artifact.server}/v2/${artifact.name}/blobs/uploads/"));
    request.headers.set("User-Agent", config.userAgent);
    HttpClientResponse response = await request.close();
    if (response.statusCode == 401) {
      config.repositoryCretificates[repository] = Base64Encoder().convert(utf8.encode("$username:$password"));
      String token = await challenge(repository, response.headers.value("Www-Authenticate"));
      if (token == null){
        config.repositoryCretificates.remove(repository);
      } else {
        config.currentRepository = repository;
        await platform.save('config', config);
        return token;
      }
    }
    return null;
  }

  Future<String> challenge(String repository, String challenge) async {
    String auth = config.repositoryCretificates[repository];
    RegExpMatch challengeMatch = RegExp('^Bearer realm="(?<server>.*?)",service="(?<service>.*?)"(,scope="(?<scope>.*?)"|)\$').firstMatch(challenge);
    if (challengeMatch == null){
      return null;
    }
    String challengeServer = challengeMatch.namedGroup("server");
    String challengeService = challengeMatch.namedGroup("service");
    String challengeScope = challengeMatch.namedGroup("scope");
    HttpClient httpClient = HttpClient();
    String challengeUrl;
    if (challengeScope == null){
      challengeUrl = "$challengeServer?service=$challengeService";
    } else {
      challengeUrl = "$challengeServer?service=$challengeService&scope=$challengeScope";
    }
    HttpClientRequest request = await httpClient.getUrl(Uri.parse(challengeUrl));
    request.headers.add("User-Agent", config.userAgent);
    if(auth != null){
      request.headers.add("Authorization", "Basic $auth");
    }
    HttpClientResponse response = await request.close();
    if (response.statusCode == 401){
      throw PermissionDeniedException(config.currentRepository);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      String body = await response.transform(utf8.decoder).join();
      Map<String, dynamic> resposeBody = jsonDecode(body);
      if (resposeBody.containsKey("token")){
        return resposeBody["token"];
      }
    } else {
      throw response.statusCode;
    }
    return null;
  }
}

class AuthCretificate {
  String auth;
  String token;
  int expiresIn;
}
