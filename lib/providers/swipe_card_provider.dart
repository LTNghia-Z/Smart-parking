import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../services/camera_service.dart';
import 'dart:typed_data';

class SwipeCardProvider extends ChangeNotifier {
  final CameraService _cameraService = CameraService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 0 = Chưa có dữ liệu
  /// 1 = Xe vào
  /// 2 = Xe ra
  int _state = 2;
  int get state => _state;

  /// Thông tin xe vào

  Message? _entryMessage;
  Message? get entryMessage => _entryMessage;

  XFile? _entryImage;
  XFile? get entryImage => _entryImage;
  Uint8List? _entryImageBytes;
  Uint8List? get entryImageBytes => _entryImageBytes;

  /// Thông tin xe ra
  Message? _exitMessage;
  Message? get exitMessage => _exitMessage;

  XFile? _exitImage;
  XFile? get exitImage => _exitImage;
  Uint8List? _exitImageBytes;
  Uint8List? get exitImageBytes => _exitImageBytes;

  /// Xe quẹt vào
  Future<void> processEntry(Message message) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _cameraService.captureImage();
      print("kết quả là: $result.displayPlate");
      message.data["plate"] = result?.displayPlate;

      _entryMessage = message;
      _entryImage = _cameraService.lastImage;
      _entryImageBytes = _cameraService.lastImageBytes;

      _state = 1;
    } catch (e) {
      debugPrint("processEntry: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Xe quẹt ra
  Future<void> processExit(Message message) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _cameraService.captureImage();

      if (result != null) {
        message.data["plate"] = result.displayPlate;
      }

      _exitMessage = message;
      _exitImage = _cameraService.lastImage;
      _exitImageBytes = _cameraService.lastImageBytes;

      _state = 2;
    } catch (e) {
      debugPrint("processExit: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset

  void clear() {
    _state = 0;
    _entryMessage = null;
    _exitMessage = null;

    _entryImage = null;
    _exitImage = null;


    notifyListeners();
  }
}