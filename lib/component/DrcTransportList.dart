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
  onOpen(String path) {
    Provider.of<UIPlatform>(context, listen: false).open(path);
  }

  @override
  Widget build(BuildContext context) {
    var items =
        List.from(context.watch<TransportModel>().items.values).reversed;
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
    List<Widget> toolbar = List();
    toolbar.add(Container(
      padding: EdgeInsets.all(4),
      child: FlatButton(
        color: Theme.of(context).secondaryHeaderColor,
        child: Text("清空已完成任务"),
        onPressed: () {
          context.read<TransportModel>().removeCompleted();
        },
      ),
    ));
    toolbar.add(Container(
      padding: EdgeInsets.all(4),
      child: FlatButton(
        color: Theme.of(context).secondaryHeaderColor,
        child: Text("清空所有任务"),
        onPressed: () {
          context.read<TransportModel>().clear();
        },
      ),
    ));
    List<Widget> headers = List();
    headers.add(
      Container(
          margin: EdgeInsets.all(8),
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: toolbar,
          )),
    );
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

class TransportItemView extends StatefulWidget {
  final TransportItem item;

  const TransportItemView({Key key, this.item}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return TransportItemViewState();
  }
}

class TransportItemViewState extends State<TransportItemView> {
  int latestReviced = 0;
  int latestUpdateTime = 0;

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
    print(widget.item.end + 1 - latestUpdateTime);
    int speed = 0;
    if (widget.item.end - latestUpdateTime > 0) {
      speed = ((widget.item.current - latestReviced) /
              (widget.item.end - latestUpdateTime) *
              1000)
          .round();
    }
    int averageSpeed = 0;
    if (widget.item.end - widget.item.start > 0) {
      averageSpeed = (widget.item.current /
              (widget.item.end + 1 - widget.item.start) *
              1000)
          .round();
    }
    latestReviced = widget.item.current;
    latestUpdateTime = widget.item.end;
    return Card(
        margin: EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            Row(
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
                          widget.item.name,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.all(4),
                        child: Text(
                            widget.item.state == TransportStateType.TRANSPORTING
                                ? "已传输：${filesize(widget.item.current)} 总大小：${filesize(widget.item.total)} 实时速度：${filesize(speed)}/s"
                                : "总大小：${filesize(widget.item.total)} 平均速度：${filesize(averageSpeed)}/s",
                            textAlign: TextAlign.left),
                      )
                    ],
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
              ],
            ),
            widget.item.state == TransportStateType.TRANSPORTING
                ? LinearProgressIndicator(
                    value: widget.item.current / widget.item.total,
                  )
                : Column()
          ],
        ));
  }
}
