import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalModel extends ChangeNotifier {
  UIGlobalConfig config = UIGlobalConfig();

  GlobalModel() {
    config.load().then((value) => notifyListeners());
  }

  setCurrentRepository(String repository) {
    this.config.currentRepository = repository;
    this.config.save();
    this.notifyListeners();
  }

  Future<String> link(String repository, String digest) async {
    var response = await http.get("/api/link?repository=$repository&digest=$digest");
    if (response.statusCode >= 300 || response.statusCode < 200) {
        throw "/items Invoke Error ${response.statusCode}";
    }
    return jsonDecode(response.body)["link"];
  }

  Future<List<FileItem>> items(String repository) async {
    if (kIsWeb) {
      var response = await http.get("/api/items?repository=$repository");
      print(response.body);
      if (response.statusCode == 404) {
        return [];
      }
      if (response.statusCode >= 300 || response.statusCode < 200) {
        throw "/items Invoke Error ${response.statusCode}";
      }
      return List.from(jsonDecode(response.body)).map((e) => FileItem.fromJson(e)).toList();
    } else {
      return [];
    }
  }
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
