import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DrcRepositoryList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return DrcRepositoryListState();
  }
}

class DrcRepositoryListState extends State<DrcRepositoryList> {

  onOpen(String path){
    Provider.of<UIPlatform>(context, listen: false).open(path);
  }

  @override
  Widget build(BuildContext context) {
    var items = context.watch<UIPlatform>().config.repositoryCretificates;
    List<Widget> list = List();
    if (items.isEmpty) {
      list.add(Text("目前没有存储的仓库，请先到浏览页面输入仓库地址！"));
    } else {
      items.forEach((k, v) {
        list.add(InkWell(
          onTap: () {
            context.read<UIPlatform>().setCurrentRepository(k);
            context.read<UIPlatform>().setCurrentSelectIndex(0);
          },
          child: RepositoryItemView(
            repository: k,
            cretificate: v,
          ),
        ));
      });
    }
    return Container(
      child: ListView(
        children: list,
      ),
    );
  }
}

class RepositoryItemView extends StatefulWidget {
  final String repository;
  final String cretificate;

  const RepositoryItemView({Key key, this.repository, this.cretificate}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return RepositoryItemViewState();
  }
}

class RepositoryItemViewState extends State<RepositoryItemView> {
  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.lock_open;
    if(widget.cretificate != null){
      icon = Icons.lock;
    }
    return Card(
      margin: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 42,
            color: Theme.of(context).primaryColor,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(
                    widget.repository,
                    textAlign: TextAlign.left,
                  ),
                )
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
            ),
          ),
          IconButton(
                  color: Theme.of(context).primaryColor,
                  icon: Icon(Icons.delete),
                  onPressed: () async {
                    context.read<UIPlatform>().removeRepository(widget.repository);
                  },
                  tooltip: "删除仓库",
                ),
        ],
      ),
    );
  }
}
