import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class DroidCamCaptureWidget extends StatefulWidget {
  const DroidCamCaptureWidget({
    super.key,
    required this.onImageCaptured,
  });

  final void Function(Uint8List imageBytes) onImageCaptured;

  @override
  State<DroidCamCaptureWidget> createState() => DroidCamCaptureWidgetState();
}

class DroidCamCaptureWidgetState extends State<DroidCamCaptureWidget> {
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  CameraController? _controller;

  Uint8List? _capturedImageBytes;
  bool _isLoading = true;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Không tìm thấy camera. Kiểm tra DroidCam và quyền camera trong Chrome.';
        });
        return;
      }

      // Ưu tiên camera có tên chứa DroidCam nếu tìm thấy.
      final droidCam = _cameras.where((camera) {
        return camera.name.toLowerCase().contains('droid');
      }).toList();

      _selectedCamera = droidCam.isNotEmpty ? droidCam.first : _cameras.first;

      await _startCamera(_selectedCamera!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Lỗi khởi tạo camera: $e';
      });
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    try {
      await _controller?.dispose();

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      setState(() {
        _controller = controller;
        _selectedCamera = camera;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Không mở được camera: $e';
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> captureImage() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _error = 'Camera chưa sẵn sàng';
      });
      return null;
    }

    if (_isCapturing) return null;

    try {
      setState(() {
        _isCapturing = true;
        _error = null;
      });

      final XFile imageFile = await controller.takePicture();

      // Với Flutter Web, đọc ảnh dạng bytes để hiển thị/gửi AI/upload Firebase.
      final Uint8List imageBytes = await imageFile.readAsBytes();

      setState(() {
        _capturedImageBytes = imageBytes;
        _isCapturing = false;
      });

      widget.onImageCaptured(imageBytes);

      return imageBytes;
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _error = 'Chụp ảnh thất bại: $e';
      });
      return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        if (_cameras.isNotEmpty)
          DropdownButton<CameraDescription>(
            value: _selectedCamera,
            items: _cameras.map((camera) {
              return DropdownMenuItem(
                value: camera,
                child: Text(camera.name),
              );
            }).toList(),
            onChanged: (camera) {
              if (camera != null) {
                _startCamera(camera);
              }
            },
          ),

        const SizedBox(height: 8),

        if (controller != null && controller.value.isInitialized)
          SizedBox(
            height: 320,
            width: double.infinity,
            child: CameraPreview(controller),
          )
        else
          const Text('Camera chưa được khởi tạo'),

        const SizedBox(height: 12),

        ElevatedButton(
          onPressed: _isCapturing ? null : captureImage,
          child: Text(_isCapturing ? 'Đang chụp...' : 'Chụp ảnh'),
        ),

        const SizedBox(height: 12),

        if (_capturedImageBytes != null) ...[
          const Text('Ảnh vừa chụp:'),
          const SizedBox(height: 8),
          Image.memory(
            _capturedImageBytes!,
            height: 240,
            fit: BoxFit.cover,
          ),
        ],
      ],
    );
  }
}