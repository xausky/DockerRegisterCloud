import 'package:docker_register_cloud/model/GlobalModel.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'TransportModel.g.dart';

class TransportModel extends ChangeNotifier {
  Map<String, TransportItem> items = new Map();

  TransportModel() {
    UIPlatform platform = UIPlatform.instance();
    platform.load('transports').then((value) {
      if (value != null) {
        (value as Map<String, dynamic>).forEach((key, value) {
          items.putIfAbsent(key, () => TransportItem.fromJson(value));
        });
        notifyListeners();
      }
    });
  }

  void createItem(String name, path, TransportItemType type) {
    items[name] = TransportItem(name, type, path);
    notifyListeners();
  }

  void updateItem(String name, int current, total, TransportStateType state) {
    TransportItem item = items[name];
    if (item != null) {
      item.current = current;
      item.total = total;
      item.state = state;
      item.end = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
      if (state != TransportStateType.TRANSPORTING) {
        UIPlatform platform = UIPlatform.instance();
        platform.save('transports', items);
      }
    }
  }

  void removeItem(String name) {
    if (items.containsKey(name)) {
      items.remove(name);
      notifyListeners();
      UIPlatform platform = UIPlatform.instance();
      platform.save('transports', items);
    }
  }

  void removeCompleted() {
    items.removeWhere(
        (key, value) => value.state == TransportStateType.COMPLETED);
    notifyListeners();
    UIPlatform platform = UIPlatform.instance();
    platform.save('transports', items);
  }

  void clear() {
    items.clear();
    notifyListeners();
    UIPlatform platform = UIPlatform.instance();
    platform.save('transports', items);
  }

}



enum TransportItemType { UPLOAD, DOWNLOAD }

enum TransportStateType { CREATED, TRANSPORTING, COMPLETED }

@JsonSerializable()
class TransportItem {
  final String name;
  final String path;
  final TransportItemType type;
  TransportStateType state;
  int current;
  int total;
  int start;
  int end;

  TransportItem(this.name, this.type, this.path) {
    start = DateTime.now().millisecondsSinceEpoch;
    end = start + 1;
    state = TransportStateType.CREATED;
    total = 0;
    current = 0;
  }

  factory TransportItem.fromJson(Map<String, dynamic> json) =>
      _$TransportItemFromJson(json);
  Map<String, dynamic> toJson() => _$TransportItemToJson(this);
}
