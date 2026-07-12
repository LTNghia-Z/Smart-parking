import 'dart:convert';

import '../models/message_model.dart';

class WebSocketDispatcher {

  void dispatch(String rawMessage) {

    final json = jsonDecode(rawMessage);

    final message = Message.fromJson(json);

    switch (message.type) {

      case "quet_vao":
        
        break;

      case "quet_ra":
        
        break;

      case "bai_do":
        
        break;
      case "loi":
        
        break;

      default:
        print("Unknown message: ${message.type}");
    }

  }

  Future<void> swipeCard() async
  {
    
  }
}