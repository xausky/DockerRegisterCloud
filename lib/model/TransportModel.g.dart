// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'TransportModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransportItem _$TransportItemFromJson(Map<String, dynamic> json) {
  return TransportItem(
      json['name'] as String,
      _$enumDecodeNullable(_$TransportItemTypeEnumMap, json['type']),
      json['path'] as String)
    ..state = _$enumDecodeNullable(_$TransportStateTypeEnumMap, json['state'])
    ..current = json['current'] as int
    ..total = json['total'] as int
    ..start = json['start'] as int
    ..end = json['end'] as int;
}

Map<String, dynamic> _$TransportItemToJson(TransportItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'type': _$TransportItemTypeEnumMap[instance.type],
      'state': _$TransportStateTypeEnumMap[instance.state],
      'current': instance.current,
      'total': instance.total,
      'start': instance.start,
      'end': instance.end
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$TransportItemTypeEnumMap = <TransportItemType, dynamic>{
  TransportItemType.UPLOAD: 'UPLOAD',
  TransportItemType.DOWNLOAD: 'DOWNLOAD'
};

const _$TransportStateTypeEnumMap = <TransportStateType, dynamic>{
  TransportStateType.CREATED: 'CREATED',
  TransportStateType.TRANSPORTING: 'TRANSPORTING',
  TransportStateType.COMPLETED: 'COMPLETED'
};
