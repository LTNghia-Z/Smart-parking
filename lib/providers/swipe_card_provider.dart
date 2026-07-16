import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../services/camera_service.dart';
import '../services/firestore_service.dart';
import '../services/gate_image_service.dart';

class SwipeCardProvider extends ChangeNotifier {
  final CameraService _cameraService = CameraService.instance;
  final FirestoreService _firestoreService = FirestoreService.instance;
  final GateImageService _gateImageService = GateImageService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _requestVersion = 0;
  int get requestVersion => _requestVersion;

  /// 0 = Chưa có dữ liệu hoặc có lỗi, 1 = xe vào, 2 = xe ra.
  int _state = 0;
  int get state => _state;

  Message? _entryMessage;
  Message? get entryMessage => _entryMessage;

  XFile? _entryImage;
  XFile? get entryImage => _entryImage;

  Uint8List? _entryImageBytes;
  Uint8List? get entryImageBytes => _entryImageBytes;

  Message? _exitMessage;
  Message? get exitMessage => _exitMessage;

  XFile? _exitImage;
  XFile? get exitImage => _exitImage;

  Uint8List? _exitImageBytes;
  Uint8List? get exitImageBytes => _exitImageBytes;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool? _platesMatch;
  bool? get platesMatch => _platesMatch;

  String? _comparisonMessage;
  String? get comparisonMessage => _comparisonMessage;

  Future<void> processEntry(Message message) async {
    _requestVersion++;
    final currentRequestVersion = _requestVersion;
    _isLoading = true;
    _resetData();
    notifyListeners();

    try {
      final capture = await _cameraService.captureImageWithData();

      if (_requestVersion != currentRequestVersion) {
        return;
      }

      if (capture == null) {
        _setStateZeroError("Không chụp được ảnh xe vào từ camera.");
        return;
      }

      final result = capture.recognition;
      debugPrint("Kết quả nhận diện xe vào: ${result?.displayPlate}");

      if (result != null) {
        message.data["plate"] = result.displayPlate;
      }

      _entryMessage = message;
      _entryImage = capture.image;
      _entryImageBytes = capture.imageBytes;
      _state = 1;
    } catch (error, stackTrace) {
      debugPrint("processEntry: $error");
      debugPrintStack(stackTrace: stackTrace);
      if (_requestVersion == currentRequestVersion) {
        _setStateZeroError("Không thể xử lý lượt quẹt vào: $error");
      }
    } finally {
      if (_requestVersion == currentRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> processExit(Message message) async {
    _requestVersion++;
    final currentRequestVersion = _requestVersion;
    _isLoading = true;
    _resetData();
    notifyListeners();

    try {
      final uid = message.data["uid"]?.toString().trim() ?? "";

      if (uid.isEmpty) {
        _setStateZeroError("Lệnh quẹt ra không có UID thẻ.");
        return;
      }

      final latestLog = await _firestoreService.findLatestParkingLogByUid(uid);

      if (_requestVersion != currentRequestVersion) {
        return;
      }

      if (latestLog == null) {
        _setStateZeroError("Không tìm thấy lịch sử ra vào của thẻ $uid.");
        return;
      }

      if (latestLog.state == 0) {
        _setStateZeroError("Thẻ $uid đã được ghi nhận đi ra ở lượt gần nhất.");
        return;
      }

      if (latestLog.state != 1) {
        _setStateZeroError(
          "Trạng thái gần nhất của thẻ $uid không hợp lệ: ${latestLog.state}.",
        );
        return;
      }

      final capture = await _cameraService.captureImageWithData();

      if (_requestVersion != currentRequestVersion) {
        return;
      }

      if (capture == null) {
        _setStateZeroError("Không chụp được ảnh xe ra từ camera.");
        return;
      }

      final result = capture.recognition;
      debugPrint("Kết quả nhận diện xe ra: ${result?.displayPlate}");
      debugPrint("Ảnh xe ra đã chụp: ${capture.imageBytes.length} bytes");

      if (result != null) {
        message.data["plate"] = result.displayPlate;
      }

      final entryMessage = Message(
        type: "quet_vao",
        data: <String, dynamic>{
          "id": latestLog.id,
          "uid": latestLog.uid,
          "plate": latestLog.plate,
          "time": latestLog.displayTime,
          "fix": latestLog.fix,
          "state": latestLog.state,
        },
      );

      _entryMessage = entryMessage;
      _entryImage = null;
      _entryImageBytes = null;
      _exitMessage = message;
      _exitImage = capture.image;
      _exitImageBytes = capture.imageBytes;

      _comparePlates(
        entryPlate: latestLog.fix.trim().isNotEmpty
            ? latestLog.fix
            : latestLog.plate,
        exitPlate: message.data["plate"]?.toString() ?? "",
      );

      _state = 2;
      notifyListeners();

      Uint8List? entryImageBytes;

      try {
        entryImageBytes = await _gateImageService.loadGateImage(
          uid: latestLog.uid,
          time: latestLog.imageTimeKey,
        );
      } catch (error, stackTrace) {
        debugPrint("Không thể tải ảnh quẹt vào: $error");
        debugPrintStack(stackTrace: stackTrace);
      }

      if (_requestVersion != currentRequestVersion) {
        return;
      }

      _entryImageBytes = entryImageBytes;
    } catch (error, stackTrace) {
      debugPrint("processExit: $error");
      debugPrintStack(stackTrace: stackTrace);
      if (_requestVersion == currentRequestVersion) {
        _setStateZeroError("Không thể kiểm tra lượt quẹt ra: $error");
      }
    } finally {
      if (_requestVersion == currentRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool clearIfCurrentRequest(int expectedRequestVersion) {
    if (_requestVersion != expectedRequestVersion) {
      debugPrint(
        "Bỏ qua reset request cũ $expectedRequestVersion; "
        "request hiện tại là $_requestVersion.",
      );
      return false;
    }

    _requestVersion++;
    _resetData();
    notifyListeners();
    return true;
  }

  void clear() {
    _requestVersion++;
    _resetData();
    notifyListeners();
  }

  void _comparePlates({required String entryPlate, required String exitPlate}) {
    final normalizedEntryPlate = _normalizePlate(entryPlate);
    final normalizedExitPlate = _normalizePlate(exitPlate);

    if (normalizedEntryPlate.isEmpty || normalizedExitPlate.isEmpty) {
      _platesMatch = null;
      _comparisonMessage = "Không đủ dữ liệu biển số để đối chiếu.";
      return;
    }

    _platesMatch = normalizedEntryPlate == normalizedExitPlate;
    _comparisonMessage = _platesMatch == true
        ? "Đúng xe - biển số $entryPlate"
        : "Sai xe - lượt vào: $entryPlate, lượt ra: $exitPlate";
  }

  String _normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r"[^A-Z0-9]"), "");
  }

  void _setStateZeroError(String message) {
    _resetData();
    _errorMessage = message;
  }

  void _resetData() {
    _state = 0;
    _entryMessage = null;
    _exitMessage = null;
    _entryImage = null;
    _exitImage = null;
    _entryImageBytes = null;
    _exitImageBytes = null;
    _errorMessage = null;
    _platesMatch = null;
    _comparisonMessage = null;
  }
}
