import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GateImageSaveResult {
  final bool success;
  final String? fileName;
  final String? relativePath;
  final String? url;
  final String? message;

  const GateImageSaveResult({
    required this.success,
    this.fileName,
    this.relativePath,
    this.url,
    this.message,
  });

  factory GateImageSaveResult.fromJson(Map<String, dynamic> json) {
    return GateImageSaveResult(
      success: json["success"] == true,
      fileName: json["fileName"]?.toString(),
      relativePath: json["relativePath"]?.toString(),
      url: json["url"]?.toString(),
      message: json["message"]?.toString(),
    );
  }
}

class GateImageService {
  static const String baseUrl = 'http://localhost:8000';

  Future<Uint8List?> loadGateImage({
    required String cid,
    required String time,
  }) async {
    if (cid.trim().isEmpty || time.trim().isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      '$baseUrl/gate-image',
    ).replace(queryParameters: {"cid": cid, "time": time});
    
    final response = await http.get(uri);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception('AI server lỗi: ${response.body}');
    }

    return response.bodyBytes;
  }

  Future<GateImageSaveResult> saveGateImage({
    required Uint8List imageBytes,
    required String cid,
    required String time,
  }) async {
    final uri = Uri.parse('$baseUrl/save-gate-image');
    final request = http.MultipartRequest('POST', uri);

    request.fields["cid"] = cid;
    request.fields["time"] = time;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'gate_image.jpg',
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();
    final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

    if (streamedResponse.statusCode != 200) {
      throw Exception('AI server lỗi: $responseBody');
    }

    return GateImageSaveResult.fromJson(jsonData);
  }
}
