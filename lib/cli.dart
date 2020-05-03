import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';

import 'package:docker_register_cloud/auth.dart';
import 'package:docker_register_cloud/repository.dart';
import 'package:filesize/filesize.dart';

void main(List<String> args) async {
  GlobalConfig config = GlobalConfig();
  await config.load();
  AuthManager auth = AuthManager(config);
  Repository repository = Repository(config, auth);
  ArgParser parser = ArgParser();
  parser.addFlag('help', abbr: 'h', negatable: false, help: "Displays this help information.");
  parser.addCommand("login")
  ..addSeparator("Log in to a Docker registry.\nbrc login <repository>")
  ..addOption("username", abbr: "u", help: "Specify username.")
  ..addOption("password", abbr: "p", help: "Specify a password, only recommended for batch processing.");
  parser.addCommand("push").addSeparator("Upload a file to the current repository.\nbrc push <localFile> <name>");
  parser.addCommand("pull").addSeparator("Download a file from the current repository.\nbrc pull <digest> <localFileName>");
  parser.addCommand("ls").addSeparator("List the current repository file list.\nbrc list");
  parser.addCommand("use").addSeparator("Switch current repository.\nbrc use <repository>\teg. brc use registry-1.docker.io/xausky/public");
  parser.addCommand("repos").addSeparator("List repository list.\nbrc repos");
  parser.addCommand("rmr").addSeparator("Remove repository from repository list.\nbrc rmr <repository>");
  parser.addSeparator('Use "brc [command] --help" for more information about a command.');
  var result = parser.parse(args);
  if(result['help'] || result.command == null){
    if(result.command == null){
      print("brc -- Network disk client based on docker register protocol.\n");
      print("Commands:");
      parser.commands.forEach((key, cmd){
        print("  $key");
      });
      print("");
      print(parser.usage);
    } else {
      print(parser.commands[result.command.name].usage);
    }
    exit(1);
  }
  switch(result.command.name){
    case "login":
    String username = result.command["username"];
    String password = result.command["password"];
    if(username == null){
      stdout.write("Username: ");
      username  = stdin.readLineSync();
    }
    if(password == null){
      stdout.write("Password: ");
      stdin.echoMode = false;
      password  = stdin.readLineSync();
      stdin.echoMode = true;
    }
    await auth.login(result.command.arguments[0], username, password);
    break;
    case "push":
    Translation translation = await repository.begin();
    await repository.upload(translation, result.command.arguments[1], result.command.arguments[0]);
    await repository.commit(translation);
    break;
    case "ls":
    List<FileItem> items = await repository.list();
    for(FileItem item in items){
      print("${item.digest}\t${filesize(item.size)}\t${item.name}");
    }
    break;
    case "pull":
    int start = DateTime.now().millisecondsSinceEpoch;
    await repository.pull(result.command.arguments[0], result.command.arguments[1]);
    int end = DateTime.now().millisecondsSinceEpoch;
    int size = await File(result.command.arguments[1]).length();
    num time =  (end - start) / 1000;
    int speed = (size/time).round();
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
  }
  exit(0);
}

class GlobalConfig {
  String userAgent;
  String currentRepository;
  Map<String, String> repositoryCretificates = Map();

  GlobalConfig();

  Future<void> load() async {
    String userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if(! await Directory("$userHome/.drc").exists()){
      await Directory("$userHome/.drc").create();
    }
    if(await File("$userHome/.drc/config.json").exists()){
      String content = await File("$userHome/.drc/config.json").readAsString();
      fromJson(jsonDecode(content));
    } else {
      this.userAgent = "Docker-Client/19.03.8-ce (linux)";
      await save();
    }
  }

  Future<void> save() async {
    String userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    await File("$userHome/.drc/config.json").writeAsString(jsonEncode(this));
  }

  fromJson(Map<String, dynamic> json) {
    this.userAgent = json["userAgent"];
    this.currentRepository = json["currentRepository"];
    this.repositoryCretificates = Map.from(json["repositoryCretificates"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['userAgent'] = this.userAgent;
    data['currentRepository'] = this.currentRepository;
    data['repositoryCretificates'] = this.repositoryCretificates;
    return data;
  }
}