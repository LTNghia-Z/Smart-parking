import 'package:flutter/foundation.dart';

import '../models/message_model.dart';

class ParkingSlot {
  final int slot;
  final bool occupied;

  const ParkingSlot({required this.slot, required this.occupied});
}

class ParkingProvider extends ChangeNotifier {
  final Map<int, bool> _slotStates = <int, bool>{1: false, 2: false, 3: false};

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ParkingSlot> get slots {
    final values = _slotStates.entries
        .map((entry) => ParkingSlot(slot: entry.key, occupied: entry.value))
        .toList();
    values.sort((a, b) => a.slot.compareTo(b.slot));
    return values;
  }

  int get totalSlots => _slotStates.length;
  int get occupiedSlots => _slotStates.values.where((value) => value).length;
  int get availableSlots => totalSlots - occupiedSlots;

  void processParkingMessage(Message message) {
    final Object? payload = message.data;

    bool hasValidUpdate = false;

    void applyUpdate(dynamic item) {
      if (item is! Map) return;

      final slot = _parseSlot(item["slot"]);
      final occupied = _parseOccupied(item["occupied"]);

      if (slot == null || occupied == null) return;

      _slotStates[slot] = occupied;
      hasValidUpdate = true;
    }

    if (payload is Map) {
      applyUpdate(payload);
    } else if (payload is List) {
      for (final item in payload) {
        applyUpdate(item);
      }
    } else {
      _errorMessage = "Dữ liệu parking phải là một object hoặc một danh sách object.";
      notifyListeners();
      return;
    }

    if (!hasValidUpdate) {
      _errorMessage = "Không có trạng thái chỗ đỗ hợp lệ trong message.";
    } else {
      _errorMessage = null;
    }

    notifyListeners();
  }

  int? _parseSlot(Object? value) {
    final slot = switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text),
      _ => null,
    };

    if (slot == null || slot <= 0) {
      return null;
    }

    return slot;
  }

  bool? _parseOccupied(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        "true" || "1" => true,
        "false" || "0" => false,
        _ => null,
      };
    }

    return null;
  }
}
