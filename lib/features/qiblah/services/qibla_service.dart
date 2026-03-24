import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/qibla_response.dart';

class QiblaService {
  static const _baseUrl = 'https://api.aladhan.com/v1/qibla';

  Future<QiblaResponse> getQiblaDirection(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/$lat/$lng');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return QiblaResponse.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to fetch Qibla direction (${response.statusCode})');
  }
}
