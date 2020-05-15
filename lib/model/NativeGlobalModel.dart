import 'dart:io';

import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:clippy/server.dart' as clipy;
import 'package:downloads_path_provider/downloads_path_provider.dart';  
import 'package:open_file/open_file.dart';

class NativeUIPlatform extends UIPlatform {
  @override
  Future<String> link(String repository, String digest) async {
    return Repository(config, auth).link(digest);
  }

  @override
  Future<List<FileItem>> items(String repository) async {
    print(repository);
    return Repository(config, auth).list();
  }

  @override
  Future<void> download(
      String repository, digest, name, TransportModel transport) async {
    var target = (Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            ".") +
        "/Downloads";
    if (Platform.isAndroid || Platform.isIOS) {
      target = (await DownloadsPathProvider.downloadsDirectory).path;
      if(target.startsWith("files://")){
        target = target.substring("files://".length);
      }
      if(target.endsWith("/")){
        target = target.substring(0, target.length - 1);
      }
    }
    var targetPath = "$target/$repository/$name";
    print(targetPath);
    if (!await File(targetPath).parent.exists()) {
      File(targetPath).parent.create(recursive: true);
    }
    Repository(config, auth).pull(
        digest,
        targetPath,
        ModelDownloadTransportProgressListener(
            "$repository:$name", transport, targetPath));
  }

  @override
  Future<void> upload(
      String repository, name, path, TransportModel transport) async {
    Repository repo = Repository(config, auth);
    Translation translation = await repo.begin();
    await repo.upload(
        translation,
        name,
        path,
        ModelUploadTransportProgressListener(
            "$repository:$name", path, transport));
    await repo.commit(translation);
  }

  @override
  Future<void> login(
      String repository, String username, String password) async {
    await auth.login(repository, username, password);
  }

  @override
  void writeClipy(String content) async {
    clipy.write(content);
  }

  @override
  Future<void> open(String path) {
    String parent = path.substring(0, path.lastIndexOf("/"));
    if(Platform.isLinux){
      Process.run('xdg-open', [parent]);
    } else if(Platform.isWindows){
      Process.run('start', [parent]);
    } else if(Platform.isMacOS){
      Process.run('open', [parent]);
    } else {
      OpenFile.open(path);
    } 
  }
}

UIPlatform instanceOfGlobalModel() => NativeUIPlatform();

class ModelDownloadTransportProgressListener extends TransportProgressListener {
  final String name;
  final TransportModel transportModel;
  int start;

  ModelDownloadTransportProgressListener(
      this.name, this.transportModel, String path) {
    this.start = DateTime.now().millisecondsSinceEpoch;
    transportModel.createItem(name, path, TransportItemType.DOWNLOAD);
  }

  @override
  void onProgess(int current, int total) {
    transportModel.updateItem(
        name, current, total, TransportStateType.TRANSPORTING);
  }

  @override
  void onSuccess(int total) {
    transportModel.updateItem(name, total, total, TransportStateType.COMPLETED);
  }
}

class ModelUploadTransportProgressListener extends TransportProgressListener {
  final String name;
  final TransportModel transportModel;
  int start;

  ModelUploadTransportProgressListener(
      this.name, String path, this.transportModel) {
    this.start = DateTime.now().millisecondsSinceEpoch;
    transportModel.createItem(name, path, TransportItemType.UPLOAD);
  }

  @override
  void onProgess(int current, int total) {
    transportModel.updateItem(
        name, current, total, TransportStateType.TRANSPORTING);
  }

  @override
  void onSuccess(int total) {
    transportModel.updateItem(name, total, total, TransportStateType.COMPLETED);
  }
}
