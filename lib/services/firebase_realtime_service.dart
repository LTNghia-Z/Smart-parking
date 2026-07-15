import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';

import 'realtime_dispatcher.dart';

class FirebaseRealtimeService {
  FirebaseRealtimeService._();

  static final FirebaseRealtimeService instance =
      FirebaseRealtimeService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  late final DatabaseReference _eventRef;
  late final DatabaseReference _commandRef;

  StreamSubscription<DatabaseEvent>? _subscription;

  late RealtimeDispatcher _dispatcher;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void initialize(RealtimeDispatcher dispatcher) {
    _dispatcher = dispatcher;
  }

  Future<void> connect() async {
    _eventRef = _database.ref();
    _commandRef = _database.ref("commands");

    FirebaseDatabase.instance.ref(".info/connected").onValue.listen((event) {
      _isConnected = event.snapshot.value == true;
      print("Firebase connected: $_isConnected");
    });

    _subscription = _eventRef.onValue.listen((event) async {
      final value = event.snapshot.value;

      if (value == null) return;

      final rawMessage = jsonEncode(value);

      print("Firebase:");
      print(rawMessage);

      await _dispatcher.dispatch(rawMessage);
    });

    print("Listening Firebase...");
  }

  Future<void> send(Map<String, dynamic> json) async {
    await _commandRef.push().set(json);
  }

  void dispose() {
    _subscription?.cancel();
  }
}