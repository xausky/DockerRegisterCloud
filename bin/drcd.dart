import 'dart:io';

import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:angel_static/angel_static.dart';
import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/helper/DrcHttpClient.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:file/local.dart';

main() async {
  BasePlatform platform = BasePlatform();
  var app = Angel();
  var fs = LocalFileSystem();
  var http = AngelHttp(app);
  var virtualDirectory =
      CachingVirtualDirectory(app, fs, source: fs.directory("./build/web"));
  app.get("/api/items", (req, res) async {
    String repository = req.queryParameters['repository'];
    GlobalConfig config = GlobalConfig();
    config.currentRepository = repository;
    AuthManager auth = AuthManager(platform, config);
    DrcHttpClient client = DrcHttpClient(auth, config);
    List<FileItem> items = await Repository(auth, config, client).list();
    res.json(items);
    res.headers["Content-Type"] = "application/json; charset=utf-8";
  });
  app.get("/api/link", (req, res) async {
    String repository = req.queryParameters['repository'];
    String digest = req.queryParameters['digest'];
    GlobalConfig config = GlobalConfig();
    config.currentRepository = repository;
    AuthManager auth = AuthManager(platform, config);
    DrcHttpClient client = DrcHttpClient(auth, config);
    String link = await Repository(auth, config, client).link(digest);
    res.json({"link": link});
    res.headers["Content-Type"] = "application/json; charset=utf-8";
  });
  app.get("/api/download", (req, res) async {
    String repository = req.queryParameters['repository'];
    String digest = req.queryParameters['digest'];
    GlobalConfig config = GlobalConfig();
    config.currentRepository = repository;
    AuthManager auth = AuthManager(platform, config);
    DrcHttpClient client = DrcHttpClient(auth, config);
    String link = await Repository(auth, config, client).link(digest);
    res.redirect(link);
  });
  app.get('/d/:path(.*)', (req, res) async {
    String path = req.params['path'];
    print(path);
    int colonIndex = path.indexOf(':');
    String repo, name;
    if (colonIndex != -1) {
      repo = path.substring(0, colonIndex);
      name = path.substring(colonIndex + 1);
    } else {
      res.statusCode = 400;
      res.write('request path must is /d/{repository}:{name|digest}');
      return;
    }
    GlobalConfig config = GlobalConfig();
    config.currentRepository = repo;
    AuthManager auth = AuthManager(platform, config);
    DrcHttpClient client = DrcHttpClient(auth, config);
    Repository repository = Repository(auth, config, client);
    if (!name.startsWith("sha256:")) {
      List<FileItem> items = await repository.list();
      FileItem file;
      for (var item in items) {
        if (item.name == name) {
          file = item;
        }
      }
      if (file == null) {
        res.statusCode = 404;
        res.write('file not found in repository');
        return;
      }
      name = file.digest;
    }
    String link = await repository.link(name);
    res.redirect(link);
  });
  app.fallback(virtualDirectory.handleRequest);
  var port = 3000;
  if (Platform.environment["PORT"] != null) {
    port = int.parse(Platform.environment["PORT"]);
  }
  await http.startServer('0.0.0.0', port);
}
