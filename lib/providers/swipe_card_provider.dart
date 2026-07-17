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

  int _state = 0;
  int get state => _state;

  // ---- Cơ chế chặn re-trigger sau khi đóng cổng ----
  String? _ignoredCid;
  DateTime? _ignoredAt;
  static const Duration _ignoreWindow = Duration(seconds: 8);

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

  /// Có đang trong thời gian "vừa đóng cổng cho cid này" hay không.
  bool _isIgnoredCid(String cid) {
    if (_ignoredCid == null || _ignoredAt == null) return false;
    if (cid.isEmpty || cid != _ignoredCid) return false;
    final expired = DateTime.now().difference(_ignoredAt!) > _ignoreWindow;
    if (expired) {
      // hết hạn -> dọn cờ, không chặn nữa
      _ignoredCid = null;
      _ignoredAt = null;
      return false;
    }
    return true;
  }

  Future<void> processEntry(Message message) async {
    final cid = _extractCid(message);

    if (_isIgnoredCid(cid)) {
      debugPrint(
        "Bỏ qua processEntry cho cid=$cid vì vừa đóng cổng (chống echo).",
      );
      return;
    }

    _requestVersion++;
    final currentRequestVersion = _requestVersion;
    _isLoading = true;
    _resetData();
    notifyListeners();

    try {
      if (cid.isEmpty) {
        _setStateZeroError("Lệnh quẹt vào không có CID thẻ.");
        return;
      }

      final latestLog = await _firestoreService.findLatestParkingLogByCid(cid);

      if (_requestVersion != currentRequestVersion) {
        return;
      }

      if (!SwipeCardProvider.shouldAllowEntryForLatestLog(latestLog)) {
        if (latestLog != null && latestLog.state == 1) {
          _setStateZeroError("Thẻ $cid đã được sử dụng rồi.");
        } else {
          _setStateZeroError(
            "Trạng thái gần nhất của thẻ $cid không hợp lệ: ${latestLog?.state ?? 0}.",
          );
        }
        return;
      }

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

      message.data["cid"] = cid;

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
    final cid = _extractCid(message);

    if (_isIgnoredCid(cid)) {
      debugPrint(
        "Bỏ qua processExit cho cid=$cid vì vừa đóng cổng (chống echo).",
      );
      return;
    }

    _requestVersion++;
    final currentRequestVersion = _requestVersion;
    _isLoading = true;
    _resetData();
    notifyListeners();

    try {
      if (cid.isEmpty) {
        _setStateZeroError("Lệnh quẹt ra không có CID thẻ.");
        return;
      }

      final latestLog = await _firestoreService.findLatestParkingLogByCid(cid);

      if (_requestVersion != currentRequestVersion) {
        return;
      }

      if (latestLog == null) {
        _setStateZeroError("Không tìm thấy lịch sử ra vào của thẻ $cid.");
        return;
      }

      if (latestLog.state == 0) {
        _setStateZeroError("Thẻ $cid đã được ghi nhận đi ra ở lượt gần nhất.");
        return;
      }

      if (latestLog.state != 1) {
        _setStateZeroError(
          "Trạng thái gần nhất của thẻ $cid không hợp lệ: ${latestLog.state}.",
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
          "cid": latestLog.cid,
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
          cid: latestLog.cid,
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

  void showStatusMessage(String message) {
    _requestVersion++;
    _resetData();
    _errorMessage = message;
    notifyListeners();
  }

  /// Dùng khi bấm "Đóng cổng": reset UI VÀ chặn mọi sự kiện quẹt-thẻ
  /// echo lại cho đúng cid này trong [_ignoreWindow] tiếp theo.
  void closeAndIgnore(String? cid) {
    if (cid != null && cid.trim().isNotEmpty) {
      _ignoredCid = cid.trim();
      _ignoredAt = DateTime.now();
    }
    _requestVersion++;
    _resetData();
    notifyListeners();
  }

  static bool shouldAllowEntryForLatestLog(ParkingLogRecord? latestLog) {
    if (latestLog == null) {
      return true;
    }
    return latestLog.state == 0;
  }

  String _extractCid(Message message) {
    return message.data["cid"]?.toString().trim() ?? "";
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