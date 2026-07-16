import 'package:baidoxe_app/models/message_model.dart';
import 'package:baidoxe_app/providers/parking_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("parking message updates slot colors and summary counts", () {
    final provider = ParkingProvider();
    final firstMessage = Message.fromJson({
      "type": "parking",
      "data": [
        {"slot": 2, "occupied": true},
      ],
    });

    provider.processParkingMessage(firstMessage);

    expect(provider.totalSlots, 3);
    expect(provider.occupiedSlots, 1);
    expect(provider.availableSlots, 2);
    expect(provider.slots.singleWhere((slot) => slot.slot == 2).occupied, true);

    final secondMessage = Message.fromJson({
      "type": "parking",
      "data": [
        {"slot": 2, "occupied": false},
        {"slot": 4, "occupied": true},
      ],
    });

    provider.processParkingMessage(secondMessage);

    expect(provider.totalSlots, 4);
    expect(provider.occupiedSlots, 1);
    expect(provider.availableSlots, 3);
    expect(
      provider.slots.singleWhere((slot) => slot.slot == 2).occupied,
      false,
    );
    expect(provider.slots.singleWhere((slot) => slot.slot == 4).occupied, true);
  });
}
