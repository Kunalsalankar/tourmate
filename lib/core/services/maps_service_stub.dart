import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_model.dart';

/// Stub implementation for non-web platforms
/// This file is used when the platform is not web
class MapsServiceWeb {
  static final MapsServiceWeb _instance = MapsServiceWeb._internal();
  factory MapsServiceWeb() => _instance;
  MapsServiceWeb._internal();

  Future<List<PlaceModel>> searchPlaces(String query) async {
    throw UnsupportedError('Web-specific implementation not available on this platform');
  }

  Future<List<PlaceModel>> searchPlacesAutocomplete(String query) async {
    throw UnsupportedError('Web-specific implementation not available on this platform');
  }

  Future<Map<String, dynamic>> getDirections(LatLng origin, LatLng destination) async {
    throw UnsupportedError('Web-specific implementation not available on this platform');
  }
}
