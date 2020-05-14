import 'dart:io';

import 'package:docker_register_cloud/component/DrcDialogs.dart';
import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DrcFileList extends StatefulWidget {
  final String repository;
  DrcFileList(this.repository);
  @override
  State<StatefulWidget> createState() {
    return DrcFileListState();
  }
}

class DrcFileListState extends State<DrcFileList>
    with TickerProviderStateMixin {
  String path = "/";
  List<FileItem> items;
  String repository = "";

  final myController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the
    // widget tree.
    myController.dispose();
    super.dispose();
  }

  @override
  didChangeDependencies() async {
    super.didChangeDependencies();
    updateRepositoryEditing();
  }

  updateRepositoryEditing() {
    myController.text = "${widget.repository}:${this.path}";
  }

  onRepositorySubmitted(String value) async {
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    platform.setCurrentRepository(value.split(":")[0]);
  }

  onDownloadClick(FileItem item, String name, GlobalKey itemkey) async {
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    TransportModel transport =
        Provider.of<TransportModel>(context, listen: false);
    if (transport.items.containsKey("${widget.repository}:${item.name}")) {
      if (transport.items["${widget.repository}:${item.name}"].state !=
          TransportStateType.COMPLETED) {
        Scaffold.of(context).showSnackBar(SnackBar(
          content: Text("该文件已经在下载列表不可重复下载。"),
        ));
        return;
      } else {
        if (await DrcDialogs.showConfirm(
                "确认覆盖", "该文件已经在下载列表，是否覆盖下载？", context) !=
            true) {
          return;
        }
      }
    }
    try {
      await platform.download(
          widget.repository, item.digest, item.name, transport);
    } catch (err) {
      Scaffold.of(context).showSnackBar(SnackBar(
        content: Text("获取下载链接失败，推荐用本地客户端试试"),
        action: SnackBarAction(
          label: "下载客户端",
          onPressed: () {
            launch("https://github.com/xausky/DockerRegisterCloud");
          },
        ),
      ));
    }
  }

  onRefreshClick() {
    UIPlatform global = Provider.of<UIPlatform>(context, listen: false);
    setState(() {
      items = null;
    });
    global
        .items(widget.repository)
        .then((value) => setState(() {
              items = value;
            }))
        .catchError((err) {
      setState(() {
        items = [];
      });
      Scaffold.of(context).showSnackBar(SnackBar(
        content: Text("获取文件列表失败，仓库不存在或者非公开。"),
      ));
      print(err);
    });
  }

  onUploadClick() async {
    File target = await FilePicker.getFile();
    print(target);
    if(target == null || ! await target.exists()){
      return;
    }
    UIPlatform platform = Provider.of<UIPlatform>(context, listen: false);
    TransportModel transport =
        Provider.of<TransportModel>(context, listen: false);
    String name = this.path + target.path.split("/").last;
    while (true) {
      try {
        await platform.upload(widget.repository, name, target.path, transport);
        break;
      } on PermissionDeniedException catch (_) {
        List<String> results =
            await DrcDialogs.showAuthority(repository, context);
        if (results == null) {
          transport.removeItem("${widget.repository}:$name");
          break;
        }
        await platform.login(repository, results[0], results[1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository != this.repository && widget.repository != null) {
      this.repository = widget.repository;
      onRefreshClick();
    }
    if (widget.repository == null) {
      items = [];
    }
    myController.text = "${this.repository}:${this.path}";
    List<Widget> list = List();
    List<Widget> headers = List();
    List<Widget> toolbar = List();
    toolbar.add(Container(
      child: IconButton(
        iconSize: 32,
        color: Theme.of(context).primaryColor,
        icon: Icon(Icons.home),
        onPressed: () {
          setState(() {
            this.path = "/";
            updateRepositoryEditing();
          });
        },
      ),
    ));
    toolbar.add(Container(
      child: IconButton(
        iconSize: 32,
        color: Theme.of(context).primaryColor,
        icon: Icon(Icons.keyboard_arrow_up),
        onPressed: () {
          setState(() {
            int index = this.path.lastIndexOf("/", this.path.length - 2);
            if (index == -1) {
              this.path = "/";
            } else {
              this.path = this.path.substring(0, index + 1);
            }
          });
          updateRepositoryEditing();
        },
      ),
    ));
    if (!kIsWeb) {
      toolbar.add(Container(
        child: IconButton(
          iconSize: 32,
          color: Theme.of(context).primaryColor,
          icon: Icon(Icons.file_upload),
          onPressed: () {
            onUploadClick();
          },
        ),
      ));
    }
    toolbar.add(Container(
      child: IconButton(
        iconSize: 32,
        color: Theme.of(context).primaryColor,
        icon: Icon(Icons.refresh),
        onPressed: () {
          onRefreshClick();
        },
      ),
    ));
    toolbar.add(Flexible(
        child: TextField(
      controller: myController,
      style: TextStyle(
        fontSize: 16,
      ),
      decoration: InputDecoration(
          isDense: true, border: OutlineInputBorder(), labelText: '仓库地址'),
      onSubmitted: (value) => onRepositorySubmitted(value),
    )));
    headers.add(
      Container(
          margin: EdgeInsets.all(8),
          height: 46,
          child: Row(
            children: toolbar,
          )),
    );
    if (items == null) {
      headers.add(SizedBox(
        child: LinearProgressIndicator(),
        height: 4,
      ));
    } else {
      Set<String> dirs = Set();
      items.forEach((element) {
        String name = element.name;
        if (!name.startsWith("/")) {
          name = "/$name";
        }
        if (name.startsWith(path)) {
          name = name.substring(path.length);
          if (name.indexOf("/") != -1) {
            name = name.substring(0, name.indexOf("/"));
            if (dirs.add(name)) {
              print(name);
              list.add(
                InkWell(
                    onTap: () {
                      setState(() {
                        this.path = "$path$name/";
                        myController.text = "${widget.repository}:${this.path}";
                      });
                    },
                    child: FileItemView(
                      name: name,
                      directory: true,
                    )),
              );
            }
          }
        }
      });
      items.forEach((element) {
        Key itemkey = GlobalKey();
        String name = element.name;
        if (!name.startsWith("/")) {
          name = "/$name";
        }
        if (name.startsWith(path)) {
          name = name.substring(path.length);
          if (name.indexOf("/") == -1) {
            list.add(
              InkWell(
                  onTap: () {
                    onDownloadClick(element, name, itemkey);
                  },
                  child: FileItemView(
                    key: itemkey,
                    name: name,
                    size: element.size,
                    digest: element.digest,
                    directory: false,
                  )),
            );
          }
        }
      });
    }

    headers.add(Expanded(
      child: ListView(
        children: list,
      ),
    ));
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: headers,
    );
  }
}

class FileItemView extends StatefulWidget {
  final bool directory;
  final String name;
  final String digest;
  final int size;

  const FileItemView(
      {Key key, this.directory, this.name, this.size, this.digest})
      : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return FileItemViewState();
  }
}

class FileItemViewState extends State<FileItemView> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(
            widget.directory ? Icons.folder : Icons.insert_drive_file,
            size: 48,
            color: widget.directory
                ? Theme.of(context).primaryColorLight
                : Theme.of(context).primaryColor,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(
                    widget.name,
                    textAlign: TextAlign.left,
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(widget.directory ? "-" : filesize(widget.size),
                      textAlign: TextAlign.left),
                )
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
            ),
          ),
          widget.directory
              ? Column()
              : IconButton(
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.content_copy),
                  onPressed: () async {
                    UIPlatform global =
                        Provider.of<UIPlatform>(context, listen: false);
                    global.writeClipy(widget.name);
                    Scaffold.of(context).showSnackBar(SnackBar(
                      content: Text("复制文件名成功"),
                    ));
                  },
                  tooltip: "复制文件名",
                ),
          widget.directory
              ? Column()
              : IconButton(
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.link),
                  onPressed: () async {
                    UIPlatform global =
                        Provider.of<UIPlatform>(context, listen: false);
                    global
                        .link(global.config.currentRepository, widget.digest)
                        .then((value) {
                      global.writeClipy(value);
                      Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text("复制下载链接成功"),
                      ));
                    }).catchError((err) {
                      Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text("获取下载链接失败，推荐用本地客户端试试"),
                        action: SnackBarAction(
                          label: "下载客户端",
                          onPressed: () {
                            launch(
                                "https://github.com/xausky/DockerRegisterCloud");
                          },
                        ),
                      ));
                    });
                  },
                  tooltip: "复制下载链接",
                ),
        ],
      ),
    );
  }
}
