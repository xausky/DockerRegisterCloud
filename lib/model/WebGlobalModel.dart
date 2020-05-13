import 'dart:html';
import 'dart:convert';

import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:http/http.dart' as http;
import 'package:clippy/browser.dart' as clipy;
import 'package:docker_register_cloud/repository.dart';

class WebGlobalModel extends GlobalModel {
  UIGlobalConfig config = UIGlobalConfig();
  @override
  Future<String> link(String repository, String digest) async {
    var response =
        await http.get("/api/link?repository=$repository&digest=$digest");
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "/items Invoke Error ${response.statusCode}";
    }
    return jsonDecode(response.body)["link"];
  }

  @override
  Future<List<FileItem>> items(String repository) async {
    var response = await http.get("/api/items?repository=$repository");
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "/items Invoke Error ${response.statusCode}";
    }
    return List.from(jsonDecode(response.body))
        .map((e) => FileItem.fromJson(e))
        .toList();
  }

  @override
  Future<void> download(
      String repository, digest, name, TransportModel transportModel) async {
    String url = await link(repository, digest);
    AnchorElement anchorElement = AnchorElement(href: url);
    anchorElement.setAttribute("download", name);
    anchorElement.click();
  }

  @override
  void writeClipy(String content) async {
    clipy.write(content);
  }

  @override
  Future<void> upload(
      String repository, name, path, TransportModel transport) {}
  @override
  Future<void> login(String repository, String username, String password) {}

  @override
  Future<void> open(String path) {}
}

GlobalModel instanceOfGlobalModel() => WebGlobalModel();
