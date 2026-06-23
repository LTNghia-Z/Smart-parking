import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PlateRecognitionResult {
  final bool success;
  final String? plateNumber;
  final String? displayPlate;
  final String? rawText;
  final double? confidence;
  final String? message;
  final Map<String, dynamic>? rawApi;

  PlateRecognitionResult({
    required this.success,
    this.plateNumber,
    this.displayPlate,
    this.rawText,
    this.confidence,
    this.message,
    this.rawApi,
  });

  factory PlateRecognitionResult.fromJson(Map<String, dynamic> json) {
    return PlateRecognitionResult(
      success: json['success'] == true,
      plateNumber: json['plateNumber'],
      displayPlate: json['displayPlate'],
      rawText: json['rawText'],
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      message: json['message'],
      rawApi: json,
    );
  }
}

class PlateRecognitionService {
  static const String baseUrl = 'http://localhost:8000';

  Future<PlateRecognitionResult> recognizePlate(Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/recognize-plate');

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'plate.jpg',
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

    if (streamedResponse.statusCode != 200) {
      throw Exception('AI server lỗi: $responseBody');
    }

    return PlateRecognitionResult.fromJson(jsonData);
  }
}