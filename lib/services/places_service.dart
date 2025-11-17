import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String name;
  final double lat;
  final double lng;

  PlaceResult({
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class PlacesService {
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PlaceResult>> searchNearby({
    required Position position,
    required String keyword,
    int limit = 5,
  }) async {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      // Placeholder: user must configure API key in .env
      return [];
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=3000'
      '&keyword=${Uri.encodeComponent(keyword)}'
      '&key=$apiKey',
    );

    final res = await _client.get(url);
    if (res.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];

    return results.take(limit).map((raw) {
      final geo = raw['geometry'] as Map<String, dynamic>?;
      final loc = geo != null ? geo['location'] as Map<String, dynamic>? : null;
      return PlaceResult(
        name: raw['name'] as String? ?? 'Unknown place',
        lat: (loc?['lat'] as num?)?.toDouble() ?? position.latitude,
        lng: (loc?['lng'] as num?)?.toDouble() ?? position.longitude,
      );
    }).toList();
  }
}
