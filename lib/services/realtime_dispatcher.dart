import 'package:flutter/foundation.dart';

import '../models/message_model.dart';
import '../providers/parking_provider.dart';
import '../providers/swipe_card_provider.dart';

class RealtimeDispatcher {
  final SwipeCardProvider swipeCardProvider;
  final ParkingProvider parkingProvider;

  RealtimeDispatcher({
    required this.swipeCardProvider,
    required this.parkingProvider,
  });

  Future<void> dispatch(Message message) async {
    switch (message.type) {
      case "quet_vao":
        await swipeCardProvider.processEntry(message);
        break;

      case "quet_ra":
        await swipeCardProvider.processExit(message);
        break;

      case "parking":
        parkingProvider.processParkingMessage(message);
        break;
      case "loi":
        break;

      default:
        debugPrint("Unknown message: ${message.type}");
    }
  }
}
