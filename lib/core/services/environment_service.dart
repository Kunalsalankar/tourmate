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
        if (aqi == null || aqiCat == null) {
          final fallback = await _fetchAqiFromOpenAQ(latitude, longitude);
          if (fallback != null) {
            aqi = fallback.$1;
            aqiCat = fallback.$2;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[EnvironmentService] AQI fetch error: $e');
      if (aqi == null || aqiCat == null) {
        final fallback = await _fetchAqiFromOpenAQ(latitude, longitude);
        if (fallback != null) {
          aqi = fallback.$1;
          aqiCat = fallback.$2;
        }
      }
    }

    return EnvironmentInfo(
      temperatureC: tempC,
      weatherDescription: weatherDesc,
      weatherIconUri: iconUri,
      aqi: aqi,
      aqiCategory: aqiCat,
    );
  }

  Future<(int, String)?> _fetchAqiFromOpenAQ(double latitude, double longitude) async {
    try {
      final uri = Uri.parse('https://api.openaq.org/v2/latest?coordinates=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}&limit=1');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) return null;
      final measurements = (results.first['measurements'] as List?) ?? const [];
      double? pm25;
      for (final m in measurements) {
        final mm = m as Map<String, dynamic>;
        final p = (mm['parameter'] ?? mm['parameterCode'] ?? '').toString().toLowerCase();
        if (p == 'pm25' || p.contains('pm2.5')) {
          pm25 = (mm['value'] as num?)?.toDouble();
          break;
        }
      }
      if (pm25 == null) return null;
      final aqiVal = _aqiFromPm25(pm25);
      final cat = _aqiCategoryFromValue(aqiVal);
      return (aqiVal, cat);
    } catch (_) {
      return null;
    }
  }

  int _aqiFromPm25(double pm) {
    final List<List<double>> bp = [
      [0.0, 12.0, 0, 50],
      [12.1, 35.4, 51, 100],
      [35.5, 55.4, 101, 150],
      [55.5, 150.4, 151, 200],
      [150.5, 250.4, 201, 300],
      [250.5, 350.4, 301, 400],
      [350.5, 500.4, 401, 500],
    ];
    for (final b in bp) {
      final cLo = b[0];
      final cHi = b[1];
      final iLo = b[2];
      final iHi = b[3];
      if (pm >= cLo && pm <= cHi) {
        final aqi = ((iHi - iLo) / (cHi - cLo)) * (pm - cLo) + iLo;
        return aqi.round();
      }
    }
    return 500;
  }

  String _aqiCategoryFromValue(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }
}
