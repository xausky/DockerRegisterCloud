import 'dart:html';
import 'dart:convert';

import 'package:docker_register_cloud/model/global_model.dart';
import 'package:http/http.dart' as http;
import 'package:clippy/browser.dart' as clipy;
import 'package:docker_register_cloud/repository.dart';

class WebGlobalModel extends GlobalModel {
  UIGlobalConfig config = UIGlobalConfig();
  Future<String> link(String repository, String digest) async {
    var response =
        await http.get("/api/link?repository=$repository&digest=$digest");
    if (response.statusCode >= 300 || response.statusCode < 200) {
      throw "/items Invoke Error ${response.statusCode}";
    }
    return jsonDecode(response.body)["link"];
  }

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

  void download(String url, String name) async {
    AnchorElement anchorElement = AnchorElement(href: url);
    anchorElement.setAttribute("download", name);
    anchorElement.click();
  }

  void writeClipy(String content) async {
    clipy.write(content);
  }
}

GlobalModel instanceOfGlobalModel() => WebGlobalModel();
