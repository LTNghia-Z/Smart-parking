import 'package:baidoxe_app/models/message_model.dart';
import 'package:baidoxe_app/providers/parking_provider.dart';
import 'package:baidoxe_app/screens/pages/parking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpParkingPage(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final provider = ParkingProvider();
    provider.processParkingMessage(
      Message.fromJson({
        "type": "parking",
        "data": [
          {"slot": 1, "occupied": true},
          {"slot": 2, "occupied": false},
          {"slot": 3, "occupied": true},
        ],
      }),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: ParkingPage())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("parking page renders without exceptions on desktop", (
    tester,
  ) async {
    await pumpParkingPage(tester, size: const Size(1280, 720));
    expect(tester.takeException(), isNull);
  });

  testWidgets("parking page renders without exceptions on a narrow screen", (
    tester,
  ) async {
    await pumpParkingPage(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });
}
