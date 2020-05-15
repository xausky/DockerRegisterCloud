import 'package:docker_register_cloud/component/DrcFileList.dart';
import 'package:docker_register_cloud/component/DrcRepositoryList.dart';
import 'package:docker_register_cloud/component/DrcTransportList.dart';
import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:docker_register_cloud/model/TransportModel.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() => runApp(DrcApp());

class DrcApp extends StatelessWidget {
  bool requestPermission = false;

  @override
  Widget build(BuildContext context) {
    if (!requestPermission) {
      requestPermission = true;
      Permission.storage.request().then((value) {
        if (PermissionStatus.granted != value) {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      });
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UIPlatform>(
          create: (_) => UIPlatform.instance(),
        ),
        ChangeNotifierProvider<TransportModel>(
          create: (_) => TransportModel(),
        )
      ],
      child: MaterialApp(
        title: 'Docker Register Cloud',
        theme: ThemeData(
          fontFamily: 'WenQuanYi Micro Hei',
          primarySwatch: Colors.blue,
          primaryColorLight: Colors.blueGrey
        ),
        home: HomePage(title: 'Docker Register Cloud'),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String title;

  const HomePage({Key key, this.title}) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return HomePageState();
  }
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    int activeTransportCount = 0;
    context.watch<TransportModel>().items.forEach((key, value) {
      if (value.state != TransportStateType.COMPLETED) {
        activeTransportCount++;
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: IndexedStack(
        children: <Widget>[
          DrcFileList(context.watch<UIPlatform>().config.currentRepository),
          DrcRepositoryList(),
          DrcTransportList(),
        ],
        index: context.watch<UIPlatform>().selectedIndex,
      ),
      bottomNavigationBar: kIsWeb
          ? null
          : BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  title: Text('浏览'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business),
                  title: Text('仓库'),
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    overflow: Overflow.visible,
                    children: <Widget>[
                      Icon(Icons.cloud_download),
                      activeTransportCount == 0
                          ? Column()
                          : Positioned(
                              top: -1.0,
                              right: -6.0,
                              child: new Container(
                                decoration: new BoxDecoration(
                                    borderRadius:
                                        new BorderRadius.circular(4.0),
                                    color: Colors.red),
                                width: 16.0,
                                child: new Text(
                                  "$activeTransportCount",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ))
                    ],
                  ),
                  title: Text('下载'),
                ),
              ],
              currentIndex: context.watch<UIPlatform>().selectedIndex,
              selectedItemColor: Theme.of(context).primaryColor,
              onTap: (index) => context.read<UIPlatform>().setCurrentSelectIndex(index),
            ),
    );
  }
}
