import 'package:docker_register_cloud/component/file_list.dart';
import 'package:docker_register_cloud/model/global_model.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() => runApp(DrcApp());

class DrcApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GlobalModel>(
        create: (_) => GlobalModel.instance(),
        child: MaterialApp(
          title: 'Docker Register Cloud',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: HomePage(title: 'Docker Register Cloud'),
        ));
  }
}

class HomePage extends StatelessWidget {
  final String title;
  HomePage({Key key, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.title),
      ),
      body: DrcFileList(context.watch<GlobalModel>().config.currentRepository),
    );
  }
}
