import 'dart:convert';
import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docker_register_cloud/model/GlobalModel.dart'
    if (dart.library.io) 'package:docker_register_cloud/model/NativeGlobalModel.dart'
    if (dart.library.html) 'package:docker_register_cloud/model/WebGlobalModel.dart' as gm;
    
abstract class GlobalModel extends ChangeNotifier {
  UIGlobalConfig config;
  AuthManager auth;

  GlobalModel() {
    config  = UIGlobalConfig();
    auth = AuthManager(config);
    config.load().then((value) => notifyListeners());
  }

  setCurrentRepository(String repository) {
    this.config.currentRepository = repository;
    this.config.save();
    this.notifyListeners();
  }

  Future<String> link(String repository, String digest);
  Future<List<FileItem>> items(String repository);
  Future<void> login(String repository, String username, String password);
  Future<void> download(String repository, digest, name, TransportModel transport);
  Future<void> upload(String repository, name, path, TransportModel transport);
  Future<void> open(String path);
  void writeClipy(String content);
  static GlobalModel instance(){
    return gm.instanceOfGlobalModel();
  }
}

GlobalModel instanceOfGlobalModel(){
  throw "Unsupported";
}

class UIGlobalConfig extends GlobalConfig {
  String userAgent;
  String currentRepository;
  Map<String, String> repositoryCretificates = Map();

  UIGlobalConfig();

  Future<void> load() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey("config")) {
      String content = preferences.getString("config");
      print(content);
      fromJson(jsonDecode(content));
    } else {
      this.userAgent = "Docker-Client/19.03.8-ce (linux)";
      await save();
    }
  }

  Future<void> save() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString("config", jsonEncode(this));
  }
}
