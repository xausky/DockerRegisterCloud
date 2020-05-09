import 'package:docker_register_cloud/model/global_model.dart';
import 'package:docker_register_cloud/repository.dart';
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

class DrcFileListState extends State<DrcFileList> {
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
    GlobalModel global = Provider.of<GlobalModel>(context, listen: false);
    global.setCurrentRepository(value.split(":")[0]);
  }

  onDownloadClick(FileItem item, String name) async {
    GlobalModel global = Provider.of<GlobalModel>(context, listen: false);
    global.link(widget.repository, item.digest).then((value) {
      global.download(value, name);
    }).catchError((err) {
      Scaffold.of(context).showSnackBar(SnackBar(
        content: Text("获取下载链接失败，推荐用本地客户端试试"),
        action: SnackBarAction(
          label: "下载客户端",
          onPressed: () {
            launch("https://github.com/xausky/DockerRegisterCloud");
          },
        ),
      ));
    });
  }

  onRefreshClick() {
    GlobalModel global = Provider.of<GlobalModel>(context, listen: false);
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
    });
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
    list.add(
      Container(
          margin: EdgeInsets.all(8),
          height: 46,
          child: Row(
            children: [
              Container(
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
              ),
              Container(
                child: IconButton(
                  iconSize: 32,
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.keyboard_arrow_up),
                  onPressed: () {
                    setState(() {
                      int index =
                          this.path.lastIndexOf("/", this.path.length - 2);
                      if (index == -1) {
                        this.path = "/";
                      } else {
                        this.path = this.path.substring(0, index + 1);
                      }
                    });
                    updateRepositoryEditing();
                  },
                ),
              ),
              Container(
                child: IconButton(
                  iconSize: 32,
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    onRefreshClick();
                  },
                ),
              ),
              Flexible(
                  child: TextField(
                controller: myController,
                style: TextStyle(
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                    border: OutlineInputBorder(), labelText: '仓库地址'),
                onSubmitted: (value) => onRepositorySubmitted(value),
              ))
            ],
          )),
    );
    if (items == null) {
      list.add(SizedBox(
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
                    onDownloadClick(element, name);
                  },
                  child: FileItemView(
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
    return Container(
      child: ListView(
        children: list,
      ),
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
                    GlobalModel global =
                        Provider.of<GlobalModel>(context, listen: false);
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
                    GlobalModel global =
                        Provider.of<GlobalModel>(context, listen: false);
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
