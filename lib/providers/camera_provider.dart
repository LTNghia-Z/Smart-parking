import 'package:flutter/material.dart';

import '../services/camera_service.dart';

class CameraProvider extends ChangeNotifier {
  final CameraService _cameraService = CameraService.instance;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  /// Controller để CameraPreview sử dụng
  get controller => _cameraService.controller;
  
  /// Khởi tạo camera
  Future<void> initializeCamera() async {
    _isInitializing = true;
    notifyListeners();

    _isConnected = await _cameraService.initialize();

    _isInitializing = false;
    notifyListeners();
  }


  /// Kiểm tra trạng thái

  Future<void> checkConnection() async {
    _isConnected = _cameraService.isInitialized;
    notifyListeners();
  }

  /// Đóng camera

  Future<void> disposeCamera() async {
    await _cameraService.dispose();

    _isConnected = false;

    notifyListeners();
  }
}
