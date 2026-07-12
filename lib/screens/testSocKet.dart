import 'dart:async';

import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String data = "Chưa có dữ liệu";

  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = WebSocketService.instance.messages.listen((message) {
      print("ESP32: $message");

      if (!mounted) return;

      setState(() {
        data = message;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void openGate() {
    WebSocketService.instance.send(
      '''
      {
        "type":"gate",
        "command":"open"
      }
      ''',
    );
  }

  void closeGate() {
    WebSocketService.instance.send(
      '''
      {
        "type":"gate",
        "command":"close"
      }
      ''',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Parking"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Text(
              WebSocketService.instance.isConnected
                  ? "🟢 Đã kết nối"
                  : "🔴 Mất kết nối",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Dữ liệu từ ESP32",
              style: TextStyle(fontSize: 22),
            ),

            const SizedBox(height: 20),

            Text(
              data,
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: openGate,
              child: const Text("MỞ CỔNG"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: closeGate,
              child: const Text("ĐÓNG CỔNG"),
            ),
          ],
        ),
      ),
    );
  }
}