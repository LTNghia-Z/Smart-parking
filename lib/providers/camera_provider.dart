import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/camera_service.dart';

class CameraProvider extends ChangeNotifier {
  final CameraService _cameraService = CameraService.instance;
  bool _isDisposed = false;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  /// Controller để CameraPreview sử dụng
  get controller => _cameraService.controller;

  void _safeNotifyListeners() {
    if (_isDisposed || !hasListeners) return;

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && hasListeners) {
          notifyListeners();
        }
      });
      return;
    }

    notifyListeners();
  }

  /// Khởi tạo camera
  Future<void> initializeCamera() async {
    _isInitializing = true;
    _safeNotifyListeners();

    _isConnected = await _cameraService.initialize();

    _isInitializing = false;
    _safeNotifyListeners();
  }

  /// Kiểm tra trạng thái
  Future<void> checkConnection() async {
    _isConnected = _cameraService.isInitialized;
    _safeNotifyListeners();
  }

  /// Đóng camera
  Future<void> disposeCamera() async {
    await _cameraService.dispose();

    _isConnected = false;
    _isInitializing = false;

    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
