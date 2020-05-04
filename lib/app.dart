import 'dart:io';
import 'dart:convert';

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