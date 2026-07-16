import 'dart:async';
import 'package:baidoxe_app/models/message_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'realtime_dispatcher.dart';

class FirebaseRealtimeService {
  FirebaseRealtimeService._();

  static final FirebaseRealtimeService instance = FirebaseRealtimeService._();

  final DatabaseReference _eventRef = FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>? _valueSubscription;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  RealtimeDispatcher? _dispatcher;
  bool _shouldListen = false;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void initialize(RealtimeDispatcher dispatcher) {
    _dispatcher = dispatcher;
  }

  Future<void> connect() async {
    _shouldListen = true;

    if (_valueSubscription != null) {
      if (_valueSubscription!.isPaused) {
        _valueSubscription!.resume();
      }
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _connectionSubscription ??= FirebaseDatabase.instance
        .ref(".info/connected")
        .onValue
        .listen((event) {
          _isConnected = event.snapshot.value == true;
          debugPrint("Firebase connected: $_isConnected");
        });

    _valueSubscription = _eventRef.onValue.listen(
      (event) async {
        await _dispatchSnapshotValue(event.snapshot.value);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint("Firebase value listener error: $error");
        debugPrintStack(stackTrace: stackTrace);
      },
      onDone: _handleListenerDone,
      cancelOnError: false,
    );

    debugPrint("Listening Firebase root...");
  }

  Future<void> send(Message message) async {
    await sendCommand(type: message.type, data: message.data);
  }

  Future<void> sendCommand({required String type, Object? data}) async {
    final payload = <String, Object?>{"type": type, "data": data};

    try {
      await ensureListening();
      await _eventRef.set(payload);
      debugPrint('Firebase write OK: $payload');
    } catch (e, stackTrace) {
      debugPrint('Firebase write failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void dispose() {
    _shouldListen = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _valueSubscription?.cancel();
    _connectionSubscription?.cancel();

    _valueSubscription = null;
    _connectionSubscription = null;
    _isConnected = false;
  }

  Future<void> ensureListening() async {
    final subscription = _valueSubscription;

    if (subscription == null) {
      await connect();
      return;
    }

    if (subscription.isPaused) {
      subscription.resume();
    }
  }

  void _handleListenerDone() {
    _valueSubscription = null;
    debugPrint("Firebase value listener stopped.");

    if (!_shouldListen) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      if (_shouldListen && _valueSubscription == null) {
        unawaited(connect());
      }
    });
  }

  Future<void> _dispatchSnapshotValue(Object? value) async {
    final message = _tryCreateMessage(value);

    if (message == null) {
      debugPrint("Firebase ignored invalid root value: $value");
      return;
    }

    await _dispatchMessage(message);
  }

  Future<void> _dispatchMessage(Message message) async {
    final dispatcher = _dispatcher;

    if (dispatcher == null) {
      debugPrint("Firebase dispatcher is not initialized.");
      return;
    }

    debugPrint("Firebase message: ${message.toJson()}");

    await dispatcher.dispatch(message);
  }

  Message? _tryCreateMessage(Object? value) {
    final normalized = _normalizeJson(value);

    if (normalized is! Map<String, dynamic>) {
      return null;
    }

    if (!normalized.containsKey("type")) {
      return null;
    }

    return Message.fromJson(normalized);
  }

  Object? _normalizeJson(Object? value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, childValue) =>
            MapEntry(key.toString(), _normalizeJson(childValue)),
      );
    }

    if (value is List) {
      return value.map(_normalizeJson).toList();
    }

    return value;
  }
}
