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
  app.fallback(virtualDirectory.handleRequest);
  await http.startServer('0.0.0.0', 3000);
}
