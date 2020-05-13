import 'package:flutter/material.dart';

class TransportModel extends ChangeNotifier {
  Map<String, TransportItem> items = new Map();

  void createItem(String name, path, TransportItemType type){
    items[name] = TransportItem(name, type, path);
    notifyListeners();
  }

  void updateItem(String name, int current, total, TransportStateType state){
    TransportItem item = items[name];
    if(item != null){
      item.current = current;
      item.total = total;
      item.state = state;
      item.end = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    }
  }

  void removeItem(String name){
    if(items.containsKey(name)){
      items.remove(name);
      notifyListeners();
    }
  }

}

enum TransportItemType { UPLOAD, DOWNLOAD }

enum TransportStateType { CREATED, TRANSPORTING, COMPLETED }


class TransportItem {
  final String name;
  final String path;
  final TransportItemType type;
  TransportStateType state;
  int current;
  int total;
  int start;
  int end;

  TransportItem(this.name, this.type, this.path){
    start = DateTime.now().millisecondsSinceEpoch;
    end = start + 1;
    state = TransportStateType.CREATED;
    total = 0;
    current = 0;
  }
  
}