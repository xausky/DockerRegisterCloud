import 'dart:io';
import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'app.g.dart';

class BasePlatform {
  Future<dynamic> load(String key) async {
    String userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (!await Directory("$userHome/.drc").exists()) {
      await Directory("$userHome/.drc").create();
    }
    if (await File("$userHome/.drc/$key.json").exists()) {
      String content = await File("$userHome/.drc/$key.json").readAsString();
      return json.decode(content);
    }
  }

  Future<void> save(String key, Object object) async {
    String userHome =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    await File("$userHome/.drc/$key.json").writeAsString(jsonEncode(object));
  }
}

@JsonSerializable()
class GlobalConfig {
  String userAgent = "Docker-Client/19.03.8-ce (linux)";
  String currentRepository;
  Map<String, String> repositoryCretificates = Map();

  GlobalConfig();

  factory GlobalConfig.fromJson(Map<String, dynamic> json) =>
      _$GlobalConfigFromJson(json);
  Map<String, dynamic> toJson() => _$GlobalConfigToJson(this);
}
