import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DrcTransportList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return DrcTransportListState();
  }
}

class DrcTransportListState extends State<DrcTransportList> {

  onOpen(String path){
    Provider.of<GlobalModel>(context, listen: false).open(path);
  }

  @override
  Widget build(BuildContext context) {
    var items = context.watch<TransportModel>().items.values;
    List<Widget> list = List();
    if (items.isEmpty) {
      list.add(Text("目前没有传输任务！"));
    } else {
      items.forEach((element) {
        list.add(InkWell(
          onTap: () => onOpen(element.path),
          child: TransportItemView(
            item: element,
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

class TransportItemView extends StatefulWidget {
  final TransportItem item;

  const TransportItemView({Key key, this.item}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return TransportItemViewState();
  }
}

class TransportItemViewState extends State<TransportItemView> {
  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.insert_drive_file;
    switch (widget.item.type) {
      case TransportItemType.DOWNLOAD:
        icon = Icons.file_download;
        break;
      case TransportItemType.UPLOAD:
        icon = Icons.file_upload;
        break;
    }
    int speed =
        (widget.item.current / (widget.item.end - widget.item.start) * 1000)
            .round();

    return Card(
      margin: EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 48,
            color: Theme.of(context).primaryColor,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(
                    widget.item.name,
                    textAlign: TextAlign.left,
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(4),
                  child: Text(
                      "${filesize(widget.item.current)} - ${filesize(widget.item.total)} - ${filesize(speed)}/s",
                      textAlign: TextAlign.left),
                )
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
            ),
          ),
        ],
      ),
    );
  }
}
