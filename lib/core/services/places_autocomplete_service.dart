import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A service that handles Google Places Autocomplete API
class PlacesAutocompleteService {
  // Singleton instance
  static final PlacesAutocompleteService _instance = PlacesAutocompleteService._internal();
  factory PlacesAutocompleteService() => _instance;
  PlacesAutocompleteService._internal();

  // API key from .env file
  String? _apiKey;

  /// Initialize the service
  Future<void> initialize() async {
    if (_apiKey != null) {
      return;
    }
    
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (_apiKey?.isEmpty ?? true) {
      throw Exception('Google Maps API key not found in .env file');
    }
  }

  /// Get autocomplete suggestions for a query
  Future<List<PlaceAutocompletePrediction>> getAutocompleteSuggestions(
    String input, {
    String? sessionToken,
  }) async {
    if (input.isEmpty || input.length < 2) {
      return [];
    }

    try {
      // Ensure service is initialized
      if (_apiKey == null || _apiKey!.isEmpty) {
        await initialize();
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=${Uri.encodeComponent(input)}'
        '&key=$_apiKey'
        '${sessionToken != null ? '&sessiontoken=$sessionToken' : ''}'
        '&components=country:in', // Restrict to India, remove if needed
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((prediction) => PlaceAutocompletePrediction(
                    placeId: prediction['place_id'],
                    description: prediction['description'],
                    mainText: prediction['structured_formatting']['main_text'],
                    secondaryText: prediction['structured_formatting']['secondary_text'] ?? '',
                  ))
              .toList();
          
          return predictions;
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          if (kDebugMode) {
            print('Places Autocomplete API error: ${data['status']} - ${data['error_message']}');
          }
          return [];
        }
      } else {
        if (kDebugMode) {
          print('HTTP error: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting autocomplete suggestions: $e');
      }
      return [];
    }
  }

  /// Get place details from place ID
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      // Ensure service is initialized
      if (_apiKey == null || _apiKey!.isEmpty) {
        await initialize();
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId'
        '&fields=name,formatted_address,geometry'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = data['result'];
          return PlaceDetails(
            placeId: placeId,
            name: result['name'],
            formattedAddress: result['formatted_address'],
            latitude: result['geometry']['location']['lat'],
            longitude: result['geometry']['location']['lng'],
          );
        } else {
          if (kDebugMode) {
            print('Place Details API error: ${data['status']}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('HTTP error: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting place details: $e');
      }
      return null;
    }
  }
}

/// Model for autocomplete prediction
class PlaceAutocompletePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceAutocompletePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  @override
  String toString() => description;
}

/// Model for place details
class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });
}
