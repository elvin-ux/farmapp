import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/camera_model.dart';

class CameraService {
  static const String baseUrl = "${ApiConfig.baseUrl}/api/cameras";

  /// 🔥 ADD THIS (stream base URL — CHANGE when tunnel changes)
  static const String streamBaseUrl =
      "https://contributions-ste-harper-dvds.trycloudflare.com/device001/whep";

  /// Fetch all cameras for a device
  static Future<List<CameraDevice>> getCameras(String deviceId) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/$deviceId"))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => CameraDevice.fromJson(e)).toList();
      }

      throw Exception("Failed to load cameras");
    } catch (e) {
      print("CameraService Error: $e");
      throw Exception("Error fetching cameras");
    }
  }

  /// 🔥 ADD THIS METHOD (IMPORTANT)
  static String getStreamUrl(String deviceId) {
    return streamBaseUrl;
  }
}