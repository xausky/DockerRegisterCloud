import 'dart:html';
import 'dart:convert';

import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:docker_register_cloud/repository.dart';

class WebUIPlatform extends UIPlatform {
  String getOrigin() {
    String origin = document
        .querySelector('meta[name="drcd-origin"]')
        .getAttribute('content');
    if (origin == 'DRCD_ORIGIN') {
      origin = window.location.origin;
    }
    return origin;
  }

  @override
  Future<String> link(String repository, String digest, String path) async {
    if (digest != null) {
      return "${getOrigin()}/d/$repository:$digest";
    } else {
      return "${getOrigin()}/d/$repository:$path";
    }
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
    String url = await link(repository, digest, null);
    AnchorElement anchorElement = AnchorElement(href: url);
    anchorElement.setAttribute("download", name);
    anchorElement.click();
  }

  @override
  void writeClipy(String content) async {
    Clipboard.setData(ClipboardData(text: content));
  }

  @override
  Future<void> upload(
      String repository, name, path, TransportModel transport) {}
  @override
  Future<void> login(String repository, String username, String password) {}

  @override
  Future<void> open(String path) {}

  @override
  Future<void> remove(String name) {}
}

UIPlatform instanceOfGlobalModel() => WebUIPlatform();
