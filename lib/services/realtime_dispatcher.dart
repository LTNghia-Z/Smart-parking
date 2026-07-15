import 'dart:convert';

import '../models/message_model.dart';
import '../providers/swipe_card_provider.dart';

class RealtimeDispatcher {
  final SwipeCardProvider swipeCardProvider;

  RealtimeDispatcher({required this.swipeCardProvider});

  Future<void> dispatch(String rawMessage) async {
    final json = jsonDecode(rawMessage);

    final message = Message.fromJson(json);

    switch (message.type) {
      case "quet_vao":
        await swipeCardProvider.processEntry(message);
        break;

      case "quet_ra":
        // await _swipeCardProvider.processExit(message);
        break;

      case "bai_do":
        break;
      case "loi":
        break;

      default:
        print("Unknown message: ${message.type}");
    }
  }
}
