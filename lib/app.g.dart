// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GlobalConfig _$GlobalConfigFromJson(Map<String, dynamic> json) {
  return GlobalConfig()
    ..userAgent = json['userAgent'] as String
    ..currentRepository = json['currentRepository'] as String
    ..repositoryCretificates =
        (json['repositoryCretificates'] as Map<String, dynamic>)?.map(
      (k, e) => MapEntry(k, e as String),
    );
}

Map<String, dynamic> _$GlobalConfigToJson(GlobalConfig instance) =>
    <String, dynamic>{
      'userAgent': instance.userAgent,
      'currentRepository': instance.currentRepository,
      'repositoryCretificates': instance.repositoryCretificates
    };
