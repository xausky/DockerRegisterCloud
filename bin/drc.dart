import 'dart:io';
import 'package:args/args.dart';

import 'package:docker_register_cloud/app.dart';
import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/helper/DrcHttpClient.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:filesize/filesize.dart';

main(List<String> args) async {
  BasePlatform platform = BasePlatform();
  GlobalConfig config = GlobalConfig();
  dynamic configContent = await platform.load('config');
  if (configContent != null) {
    config = GlobalConfig.fromJson(configContent);
  }
  AuthManager auth = AuthManager(platform, config);
  DrcHttpClient client = DrcHttpClient(auth, config);
  Repository repository = Repository(auth, config, client);
  ArgParser parser = ArgParser();
  parser.addFlag('help',
      abbr: 'h', negatable: false, help: "Displays this help information.");
  parser.addCommand("login")
    ..addSeparator("Log in to a Docker registry.\ndrc login <repository>")
    ..addOption("username", abbr: "u", help: "Specify username.")
    ..addOption("password",
        abbr: "p",
        help: "Specify a password, only recommended for batch processing.");
  parser.addCommand("push").addSeparator(
      "Upload a file to the current repository.\ndrc push <path> <name>");
  parser.addCommand("pull").addSeparator(
      "Download a file from the current repository.\ndrc pull <name> <path>");
  parser
      .addCommand("ls")
      .addSeparator("List the current repository file list.\ndrc list");
  parser
      .addCommand("mv")
      .addSeparator("rename a file from the current repository.\ndrc mv <originName> <targetName>");
  parser.addCommand("use").addSeparator(
      "Switch current repository.\ndrc use <repository>\teg. drc use registry-1.docker.io/xausky/public");
  parser.addCommand("repos").addSeparator("List repository list.\ndrc repos");
  parser.addCommand("rmr").addSeparator(
      "Remove repository from repository list.\ndrc rmr <repository>");
  parser
      .addCommand("link")
      .addSeparator("Direct download address of file.\ndrc link <name>");
  parser.addCommand("rm").addSeparator(
      "Remove a file from the current repository.\ndrc rm <name>");
  parser.addSeparator(
      'Use "drc [command] --help" for more information about a command.');
  var result = parser.parse(args);
  if (result['help'] || result.command == null) {
    if (result.command == null) {
      print("drc -- Network disk client based on docker register protocol.\n");
      print("Commands:");
      parser.commands.forEach((key, cmd) {
        print("  $key");
      });
      print("");
      print(parser.usage);
    } else {
      print(parser.commands[result.command.name].usage);
    }
    exit(1);
  }
  switch (result.command.name) {
    case "login":
      String username = result.command["username"];
      String password = result.command["password"];
      if (username == null) {
        stdout.write("Username: ");
        username = stdin.readLineSync();
      }
      if (password == null) {
        stdout.write("Password: ");
        stdin.echoMode = false;
        password = stdin.readLineSync();
        stdin.echoMode = true;
      }
      await auth.login(result.command.arguments[0], username, password);
      break;
    case "push":
      Translation translation = await repository.begin();
      await repository.upload(
          translation,
          result.command.arguments[1],
          result.command.arguments[0],
          PrintUploadTransportProgressListener(result.command.arguments[1]));
      await repository.commit(translation);
      break;
    case "ls":
      List<FileItem> items = await repository.list();
      for (FileItem item in items) {
        String fileSizeText = filesize(item.size);
        fileSizeText = " " * (10 - fileSizeText.length) + fileSizeText;
        print("${item.digest}  $fileSizeText  ${item.name}");
      }
      break;
    case "mv":
      Translation translation = await repository.begin();
      await repository.rename(translation, result.command.arguments[0], result.command.arguments[1]);
      await repository.commit(translation);
      break;
    case "pull":
      int start = DateTime.now().millisecondsSinceEpoch;
      Translation translation = await repository.begin();
      await repository.pullWithName(
          translation,
          result.command.arguments[0],
          result.command.arguments[1],
          PrintDownloadTransportProgressListener(result.command.arguments[0]));
      int end = DateTime.now().millisecondsSinceEpoch;
      int size = await File(result.command.arguments[1]).length();
      num time = (end - start) / 1000;
      int speed = (size / time).round();
      print("Downloaded ${filesize(size)} in ${time}s on ${filesize(speed)}/s");
      break;
    case "use":
      await auth.use(result.command.arguments[0]);
      print("Current Use: ${auth.config.currentRepository}");
      break;
    case "repos":
      await auth.list();
      break;
    case "rmr":
      String repository = result.command.arguments[0];
      await auth.remove(repository);
      break;
    case "link":
      Translation translation = await repository.begin();
      String link = await repository.linkWithName(
          translation, result.command.arguments[0]);
      print(link);
      break;
    case "rm":
      Translation translation = await repository.begin();
      await repository.remove(translation, result.command.arguments[0]);
      await repository.commit(translation);
      break;
  }
  exit(0);
}

class PrintDownloadTransportProgressListener extends TransportProgressListener {
  final String name;
  int start;

  PrintDownloadTransportProgressListener(this.name) {
    this.start = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void onProgess(int current, int total) {
    var end = DateTime.now().millisecondsSinceEpoch;
    var speed = (current / (end - start) * 1000).round();
    print(
        "Downloading $name received ${filesize(current)} total ${filesize(total)} speed ${filesize(speed)}/s");
  }

  @override
  void onSuccess(int total) {
    var end = DateTime.now().millisecondsSinceEpoch;
    var speed = (total / (end - start) * 1000).round();
    print(
        "Downloaded $name total ${filesize(total)} speed ${filesize(speed)}/s");
  }
}

class PrintUploadTransportProgressListener extends TransportProgressListener {
  final String name;
  int start;

  PrintUploadTransportProgressListener(this.name) {
    this.start = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void onProgess(int current, int total) {
    var end = DateTime.now().millisecondsSinceEpoch;
    var speed = (current / (end - start) * 1000).round();
    print(
        "Uploading $name uploaded ${filesize(current)} total ${filesize(total)} speed ${filesize(speed)}/s");
  }

  @override
  void onSuccess(int total) {
    var end = DateTime.now().millisecondsSinceEpoch;
    var speed = (total / (end - start) * 1000).round();
    print("Uploaded $name total ${filesize(total)} speed ${filesize(speed)}/s");
  }
}
