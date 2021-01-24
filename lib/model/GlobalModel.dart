import 'dart:convert';
import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/helper/DrcHttpClient.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docker_register_cloud/model/GlobalModel.dart'
    if (dart.library.io) 'package:docker_register_cloud/model/NativeGlobalModel.dart'
    if (dart.library.html) 'package:docker_register_cloud/model/WebGlobalModel.dart'
    as gm;

abstract class UIPlatform extends ChangeNotifier with BasePlatform {
  static UIPlatform _instance;
  GlobalConfig config;
  AuthManager auth;
  DrcHttpClient client;
  Repository repo;
  int selectedIndex = 0;

  UIPlatform() {
    config = GlobalConfig();
    auth = AuthManager(this, config);
    client = DrcHttpClient(auth, config);
    repo = Repository(auth, config, client);
    load('config').then((value) {
      if (value != null) {
        config = GlobalConfig.fromJson(value);
      }
      auth = AuthManager(this, config);
      client = DrcHttpClient(auth, config);
      repo = Repository(auth, config, client);
      notifyListeners();
    });
  }

  setCurrentSelectIndex(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  setCurrentRepository(String repository) {
    this.config.currentRepository = repository;
    this.config.repositoryCretificates.putIfAbsent(repository, () => null);
    save('config', config);
    this.notifyListeners();
  }

  removeRepository(String repository) {
    if (this.config.currentRepository == repository) {
      this.config.currentRepository = null;
    }
    this.config.repositoryCretificates.remove(repository);
    save('config', config);
    this.notifyListeners();
  }

  Future<String> link(String repository, String digest, String path);
  Future<List<FileItem>> items(String repository);
  Future<void> login(String repository, String username, String password);
  Future<void> download(
      String repository, digest, name, TransportModel transport);
  Future<void> upload(String repository, name, path, TransportModel transport);
  Future<void> remove(String name);
  Future<void> open(String path);

  void writeClipy(String content);

  Future<dynamic> load(String key) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey(key)) {
      String content = preferences.getString(key);
      return json.decode(content);
    }
  }

  Future<void> save(String key, Object object) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(object));
  }

  static UIPlatform instance() {
    if (_instance == null) {
      _instance = gm.instanceOfGlobalModel();
    }
    return _instance;
  }
}

UIPlatform instanceOfGlobalModel() {
  throw "Unsupported";
}
