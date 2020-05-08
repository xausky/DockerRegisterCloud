import 'package:docker_register_cloud/model/global_model.dart';
import 'package:docker_register_cloud/repository.dart';

class NativeGlobalModel extends GlobalModel {

  Future<String> link(String repository, String digest) async {
    return "";
  }

  Future<List<FileItem>> items(String repository) async {
    return [];
  }

  void download(String url, String name) async {}
  void writeClipy(String content) async {}
}

GlobalModel instanceOfGlobalModel() => NativeGlobalModel();