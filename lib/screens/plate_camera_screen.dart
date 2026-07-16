import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/plate_recognition_service.dart';

class PlateCameraScreen extends StatefulWidget {
  const PlateCameraScreen({super.key});

  @override
  State<PlateCameraScreen> createState() => _PlateCameraScreenState();
}

class _PlateCameraScreenState extends State<PlateCameraScreen> {
  final PlateRecognitionService _plateService = PlateRecognitionService();

  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  CameraController? _controller;

  Uint8List? _capturedImageBytes;
  PlateRecognitionResult? _result;

  bool _isLoadingCamera = true;
  bool _isCapturing = false;
  bool _isRecognizing = false;

  // DroidCam hay bị ngược trái-phải.
  // Nếu ảnh sau khi chụp vẫn bị ngược thì để true.
  // Nếu bị lật ngược lại sai thì đổi thành false trên UI.
  bool _flipHorizontal = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _isLoadingCamera = false;
          _error =
              'Không tìm thấy camera. Kiểm tra DroidCam và quyền camera trong Chrome.';
        });
        return;
      }

      for (final camera in cameras) {
        debugPrint('Camera found: ${camera.name}');
      }

      final droidCam = cameras.where((camera) {
        final name = camera.name.toLowerCase();
        return name.contains('droid') ||
            name.contains('virtual') ||
            name.contains('usb');
      }).toList();

      final selected = droidCam.isNotEmpty ? droidCam.first : cameras.first;

      setState(() {
        _cameras = cameras;
        _selectedCamera = selected;
      });

      await _startCamera(selected);
    } catch (e) {
      setState(() {
        _isLoadingCamera = false;
        _error = 'Lỗi khởi tạo camera: $e';
      });
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    try {
      setState(() {
        _isLoadingCamera = true;
        _error = null;
      });

      await _controller?.dispose();

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _selectedCamera = camera;
        _isLoadingCamera = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingCamera = false;
        _error = 'Không mở được camera: $e';
      });
    }
  }

  Uint8List _flipImageHorizontally(Uint8List imageBytes) {
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return imageBytes;
    }

    final flippedImage = img.flipHorizontal(decodedImage);

    return Uint8List.fromList(
      img.encodeJpg(flippedImage, quality: 95),
    );
  }

  Uint8List _fixCapturedImage(Uint8List originalBytes) {
    if (!_flipHorizontal) {
      return originalBytes;
    }

    return _flipImageHorizontally(originalBytes);
  }

  Future<void> _captureAndRecognize() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _error = 'Camera chưa sẵn sàng';
      });
      return;
    }

    if (_isCapturing || _isRecognizing) return;

    try {
      setState(() {
        _isCapturing = true;
        _isRecognizing = false;
        _error = null;
        _result = null;
      });

      final XFile imageFile = await controller.takePicture();
      final Uint8List originalBytes = await imageFile.readAsBytes();

      // Ảnh này là ảnh đã xử lý lật ngang nếu DroidCam bị ngược.
      final Uint8List fixedImageBytes = _fixCapturedImage(originalBytes);

      if (!mounted) return;

      setState(() {
        _capturedImageBytes = fixedImageBytes;
        _isCapturing = false;
        _isRecognizing = true;
      });

      final result = await _plateService.recognizePlate(fixedImageBytes);

      if (!mounted) return;

      setState(() {
        _result = result;
        _isRecognizing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _isRecognizing = false;
        _error = 'Lỗi chụp/đọc biển số: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    final controller = _controller;

    if (_isLoadingCamera) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: Text('Camera chưa được khởi tạo')),
      );
    }

    Widget preview = CameraPreview(controller);

    // Lật preview cho khớp với ảnh gửi AI.
    if (_flipHorizontal) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: preview,
      );
    }

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: preview,
    );
  }

  Widget _buildCameraSelector() {
    if (_cameras.isEmpty) {
      return const SizedBox.shrink();
    }

    final isBusy = _isCapturing || _isRecognizing;

    return DropdownButtonFormField<CameraDescription>(
      initialValue: _selectedCamera,
      decoration: const InputDecoration(
        labelText: 'Chọn camera',
        border: OutlineInputBorder(),
      ),
      items: _cameras.map((camera) {
        return DropdownMenuItem(
          value: camera,
          child: Text(camera.name),
        );
      }).toList(),
      onChanged: isBusy
          ? null
          : (camera) {
              if (camera != null) {
                _startCamera(camera);
              }
            },
    );
  }

  Widget _buildFlipSwitch() {
    final isBusy = _isCapturing || _isRecognizing;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Lật ngang ảnh DroidCam'),
      subtitle: const Text(
        'Bật nếu ảnh/biển số bị ngược trái-phải',
      ),
      value: _flipHorizontal,
      onChanged: isBusy
          ? null
          : (value) {
              setState(() {
                _flipHorizontal = value;
                _capturedImageBytes = null;
                _result = null;
              });
            },
    );
  }

  Widget _buildActionButton() {
    final isBusy = _isCapturing || _isRecognizing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isBusy ? null : _captureAndRecognize,
        icon: const Icon(Icons.camera_alt),
        label: Text(
          _isCapturing
              ? 'Đang chụp...'
              : _isRecognizing
                  ? 'Đang đọc biển số...'
                  : 'Chụp ảnh & đọc biển số',
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result;

    if (_isRecognizing) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Đang đọc biển số...'),
          ],
        ),
      );
    }

    if (result == null) {
      return const SizedBox.shrink();
    }

    if (!result.success) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          result.message ?? 'Không đọc được biển số',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final displayPlate = result.displayPlate ?? result.plateNumber ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết quả nhận diện:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            displayPlate,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('Dạng lưu DB: ${result.plateNumber ?? ''}'),
          if (result.rawText != null) Text('Raw text: ${result.rawText}'),
          if (result.confidence != null)
            Text(
              'Độ tin cậy: ${(result.confidence! * 100).toStringAsFixed(1)}%',
            ),
        ],
      ),
    );
  }

  Widget _buildCapturedImage() {
    if (_capturedImageBytes == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Ảnh vừa chụp đã gửi AI:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            _capturedImageBytes!,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    if (_error == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhận diện biển số'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCameraSelector(),
            const SizedBox(height: 12),
            _buildFlipSwitch(),
            const SizedBox(height: 12),
            _buildCameraPreview(),
            const SizedBox(height: 16),
            _buildActionButton(),
            _buildError(),
            _buildResult(),
            _buildCapturedImage(),
          ],
        ),
      ),
    );
  }
}