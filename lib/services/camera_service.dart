import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import 'plate_recognition_service.dart';

class CameraService {
  CameraService._();

  static final CameraService instance = CameraService._();

  CameraController? _controller;
  CameraDescription? _camera;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  CameraController? get controller => _controller;
  PlateRecognitionService _plateRecognitionService = PlateRecognitionService();
  XFile? _lastImage;
  Uint8List? _lastImageBytes;
  bool _flipHorizontal = true;

  XFile? get lastImage => _lastImage;
  Uint8List? get lastImageBytes => _lastImageBytes;
  bool get flipHorizontal => _flipHorizontal;

  set flipHorizontal(bool v) => _flipHorizontal = v;

  /// Khởi tạo camera
  Future<bool> initialize() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        print("Không tìm thấy camera.");
        return false;
      }

      // Ưu tiên DroidCam
      _camera = cameras.firstWhere(
        (camera) => camera.name.toLowerCase().contains("droid"),
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _camera!,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      _isInitialized = true;

      print("Đã kết nối camera: ${_camera!.name}");

      return true;
    } catch (e) {
      print("Lỗi khởi tạo camera: $e");

      _isInitialized = false;

      return false;
    }
  }

  /// Chụp ảnh
  Future<PlateRecognitionResult?> captureImage() async {
    if (!_isInitialized) {
      print("Camera chưa khởi tạo.");

      return null;
    }

    try {
      final image = await _controller!.takePicture();

      _lastImage = image;

      // Read bytes once and keep a copy for UI (Image.memory) which works on web.
      final bytes = await image.readAsBytes();

      // Optionally flip horizontally if DroidCam produces mirrored images.
      final fixed = _fixCapturedImage(bytes);

      _lastImageBytes = fixed;

      return await _plateRecognitionService.recognizePlate(fixed);
    } catch (e) {
      print("Lỗi chụp ảnh: $e");

      return null;
    }
  }

  ///==========================
  /// Đóng camera
  ///==========================
  Future<void> dispose() async {
    await _controller?.dispose();

    _controller = null;

    _camera = null;

    _isInitialized = false;
  }

  Uint8List _fixCapturedImage(Uint8List imageBytes) {
    if (!_flipHorizontal) return imageBytes;

    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return imageBytes;

      final flipped = img.flipHorizontal(decoded);
      return Uint8List.fromList(img.encodeJpg(flipped, quality: 95));
    } catch (e) {
      // If image processing fails, return original bytes.
      print('Lỗi xử lý ảnh: $e');
      return imageBytes;
    }
  }
}
