import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EnvironmentInfo {
  final double? temperatureC;
  final String? weatherDescription;
  final String? weatherIconUri;
  final int? aqi;
  final String? aqiCategory;

  const EnvironmentInfo({
    this.temperatureC,
    this.weatherDescription,
    this.weatherIconUri,
    this.aqi,
    this.aqiCategory,
  });
}

class EnvironmentService {
  static final EnvironmentService _instance = EnvironmentService._internal();
  factory EnvironmentService() => _instance;
  EnvironmentService._internal();

  String? _apiKey() {
    final k = dotenv.env['WEATHER_API_KEY'] ??
        dotenv.env['GOOGLE_API_KEY'] ??
        dotenv.env['GOOGLE_MAPS_API_KEY'] ??
        dotenv.env['AIR_QUALITY_API_KEY'];
    return (k != null && k.isNotEmpty) ? k : null;
  }

  Future<EnvironmentInfo?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final key = _apiKey();
    if (key == null) {
      if (kDebugMode) {
        debugPrint('[EnvironmentService] Missing GOOGLE/WEATHER API key in .env');
      }
      return null;
    }

    double? tempC;
    String? weatherDesc;
    String? iconUri;
    int? aqi;
    String? aqiCat;

    try {
      // Weather: Current conditions
      final weatherUri = Uri.parse(
          'https://weather.googleapis.com/v1/currentConditions:lookup'
          '?key=$key'
          '&location.latitude=${latitude.toStringAsFixed(6)}'
          '&location.longitude=${longitude.toStringAsFixed(6)}'
          '&languageCode=en');

      final weatherResp = await http
          .get(weatherUri)
          .timeout(const Duration(seconds: 5));
      if (weatherResp.statusCode == 200) {
        final data = json.decode(weatherResp.body) as Map<String, dynamic>;
        final cc = (data['currentConditions'] ?? data) as Map<String, dynamic>;

        // temperature may be a number or an object {value, unitCode}
        if (cc['temperature'] is Map) {
          final t = cc['temperature'] as Map<String, dynamic>;
          tempC = (t['value'] as num?)?.toDouble();
        } else if (cc['temperature'] is num) {
          tempC = (cc['temperature'] as num).toDouble();
        }

        // description/icon
        if (cc['weatherCondition'] is Map) {
          final wc = cc['weatherCondition'] as Map<String, dynamic>;
          weatherDesc = (wc['description'] ?? wc['iconDescriptor'])?.toString();
          iconUri = wc['iconBaseUri']?.toString();
        } else if (cc['summary'] != null) {
          weatherDesc = cc['summary']?.toString();
        }
      } else {
        if (kDebugMode) {
          debugPrint('[EnvironmentService] Weather API ${weatherResp.statusCode}: ${weatherResp.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[EnvironmentService] Weather fetch error: $e');
    }

    try {
      // Air Quality: Current conditions (POST)
      final aqiUri = Uri.parse(
          'https://airquality.googleapis.com/v1/currentConditions:lookup?key=$key');
      final body = json.encode({
        'location': {
          'latitude': double.parse(latitude.toStringAsFixed(6)),
          'longitude': double.parse(longitude.toStringAsFixed(6)),
        },
        'universalAqi': true,
        'languageCode': 'en',
      });
      final aqiResp = await http
          .post(
            aqiUri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      if (aqiResp.statusCode == 200) {
        final data = json.decode(aqiResp.body) as Map<String, dynamic>;
        final indexes = (data['indexes'] as List?)?.cast<dynamic>() ?? const [];
        Map<String, dynamic>? idx;

        // Prefer universal AQI/UAQI if present
        for (final it in indexes) {
          final m = it as Map<String, dynamic>;
          final name = (m['name'] ?? m['code'] ?? '').toString().toLowerCase();
          if (name.contains('uaqi') || name.contains('universal')) {
            idx = m;
            break;
          }
        }
        idx ??= indexes.isNotEmpty ? (indexes.first as Map<String, dynamic>) : null;

        if (idx != null) {
          // Some responses use 'aqi', others nest under 'aqi' -> value/category
          if (idx['aqi'] is Map) {
            final a = idx['aqi'] as Map<String, dynamic>;
            aqi = (a['value'] as num?)?.toInt();
            aqiCat = a['category']?.toString();
          } else {
            aqi = (idx['aqi'] as num?)?.toInt();
            aqiCat = (idx['category'] ?? idx['categoryDescription'])?.toString();
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('[EnvironmentService] AQI API ${aqiResp.statusCode}: ${aqiResp.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[EnvironmentService] AQI fetch error: $e');
    }

    return EnvironmentInfo(
      temperatureC: tempC,
      weatherDescription: weatherDesc,
      weatherIconUri: iconUri,
      aqi: aqi,
      aqiCategory: aqiCat,
    );
  }
}
