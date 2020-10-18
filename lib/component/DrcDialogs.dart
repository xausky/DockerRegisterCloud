import 'package:docker_register_cloud/component/DrcPreview.dart';
import 'package:flutter/material.dart';

class DrcDialogs {
  static Future<List<String>> showAuthority(
      String repository, BuildContext context) async {
    String username;
    String password;
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("仓库 [$repository] 需要登录"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: EdgeInsets.all(4),
              child: TextField(
                style: TextStyle(
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: '用户名'),
                onChanged: (value) => username = value,
              ),
            ),
            Container(
              margin: EdgeInsets.all(4),
              child: TextField(
                obscureText: true,
                style: TextStyle(
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: '密码'),
                onChanged: (value) => password = value,
              ),
            )
          ]),
          actions: <Widget>[
            FlatButton(
              child: Text("取消"),
              onPressed: () => Navigator.of(context).pop(), // 关闭对话框
            ),
            FlatButton(
              child: Text("登录"),
              onPressed: () {
                Navigator.of(context).pop([username, password]);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<String> showInput(
      String title, BuildContext context) async {
    String input;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Container(
            margin: EdgeInsets.all(4),
            child: TextField(
              style: TextStyle(
                fontSize: 16,
              ),
              decoration:
                  InputDecoration(isDense: true, border: OutlineInputBorder()),
              onChanged: (value) => input = value,
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text("取消"),
              onPressed: () => Navigator.of(context).pop(), // 关闭对话框
            ),
            FlatButton(
              child: Text("确定"),
              onPressed: () {
                Navigator.of(context).pop(input);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<bool> showConfirm(
      String title, String content, BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            FlatButton(
              child: Text("取消"),
              onPressed: () => Navigator.of(context).pop(false), // 关闭对话框
            ),
            FlatButton(
              child: Text("确定"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  static void showPreview(BuildContext context, String name, String url) async {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DrcPreview(name: name, url: url), fullscreenDialog: true));
  }
}
