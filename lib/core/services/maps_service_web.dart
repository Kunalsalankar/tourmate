// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_model.dart';

/// Web-specific implementation using Google Maps JavaScript API
/// This avoids CORS issues by using the JavaScript SDK instead of REST API
class MapsServiceWeb {
  static final MapsServiceWeb _instance = MapsServiceWeb._internal();
  factory MapsServiceWeb() => _instance;
  MapsServiceWeb._internal();

  /// Search for places using JavaScript API (no CORS issues)
  Future<List<PlaceModel>> searchPlaces(String query) async {
    try {
      if (kDebugMode) {
        print('[WEB] Searching places with query: $query');
      }
      
      final completer = Completer<List<PlaceModel>>();
      
      // Create a temporary div for PlacesService
      final div = html.DivElement();
      final service = js.JsObject(
        js.context['google']['maps']['places']['PlacesService'],
        [div],
      );
      
      final request = js.JsObject.jsify({
        'query': query,
        'fields': ['place_id', 'name', 'formatted_address', 'geometry'],
      });
      
      // Callback function - Google API passes 3 args: results, status, pagination
      void callback(dynamic results, dynamic status, [dynamic pagination]) {
        try {
          final statusStr = status.toString();
          if (statusStr == 'OK' && results != null) {
            final List<PlaceModel> places = [];
            final jsResults = results as js.JsArray;
            final int length = jsResults.length;
            
            for (int i = 0; i < length; i++) {
              try {
                final result = jsResults[i] as js.JsObject;
                final geometry = result['geometry'] as js.JsObject;
                final location = geometry['location'] as js.JsObject;
                  
                places.add(PlaceModel(
                  placeId: result['place_id'] as String,
                  name: result['name'] as String,
                  address: result['formatted_address'] as String? ?? '',
                  location: LatLng(
                    location.callMethod('lat') as double,
                    location.callMethod('lng') as double,
                  ),
                ));
              } catch (e) {
                if (kDebugMode) {
                  print('[WEB] Error parsing place result: $e');
                }
              }
            }
            
            if (kDebugMode) {
              print('[WEB] Found ${places.length} places');
            }
            completer.complete(places);
          } else {
            if (kDebugMode) {
              print('[WEB] Places search failed with status: $statusStr');
            }
            completer.complete([]);
          }
        } catch (e) {
          if (kDebugMode) {
            print('[WEB] Error in callback: $e');
          }
          completer.completeError(e);
        }
      }
      
      // Call textSearch
      service.callMethod('textSearch', [
        request,
        js.allowInterop(callback),
      ]);
      
      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        print('[WEB] Error searching places: $e');
      }
      return [];
    }
  }

  /// Get autocomplete suggestions
  Future<List<PlaceModel>> searchPlacesAutocomplete(String query) async {
    try {
      if (kDebugMode) {
        print('[WEB] Autocomplete search with query: $query');
      }
      
      final completer = Completer<List<PlaceModel>>();
      
      // Create AutocompleteService
      final service = js.JsObject(
        js.context['google']['maps']['places']['AutocompleteService'],
      );
      
      final request = js.JsObject.jsify({
        'input': query,
      });
      
      // Callback for predictions - Google API passes 2 args for autocomplete
      void predictionsCallback(dynamic predictions, dynamic status) {
        try {
          final statusStr = status.toString();
          if (statusStr == 'OK' && predictions != null) {
            final jsPredictions = predictions as js.JsArray;
            // Get details for each prediction
            final div = html.DivElement();
            final placesService = js.JsObject(
              js.context['google']['maps']['places']['PlacesService'],
              [div],
            );
            
            final List<PlaceModel> places = [];
            final int length = jsPredictions.length;
            int completed = 0;
            
            if (length == 0) {
              completer.complete([]);
              return;
            }
            
            for (int i = 0; i < length && i < 5; i++) {
              try {
                final prediction = jsPredictions[i] as js.JsObject;
                final placeId = prediction['place_id'] as String;
                
                final detailRequest = js.JsObject.jsify({
                  'placeId': placeId,
                  'fields': ['place_id', 'name', 'formatted_address', 'geometry'],
                });
                
                // Get place details - Google API passes 2 args for details
                void detailCallback(dynamic place, dynamic detailStatus) {
                  try {
                    final detailStatusStr = detailStatus.toString();
                    if (detailStatusStr == 'OK' && place != null) {
                      final jsPlace = place as js.JsObject;
                      final geometry = jsPlace['geometry'] as js.JsObject;
                      final location = geometry['location'] as js.JsObject;
                      
                      places.add(PlaceModel(
                        placeId: jsPlace['place_id'] as String,
                        name: jsPlace['name'] as String,
                        address: jsPlace['formatted_address'] as String? ?? '',
                        location: LatLng(
                          location.callMethod('lat') as double,
                          location.callMethod('lng') as double,
                        ),
                      ));
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('[WEB] Error parsing place detail: $e');
                    }
                  } finally {
                    completed++;
                    if (completed >= length || completed >= 5) {
                      if (kDebugMode) {
                        print('[WEB] Autocomplete found ${places.length} places');
                      }
                      completer.complete(places);
                    }
                  }
                }
                
                placesService.callMethod('getDetails', [
                  detailRequest,
                  js.allowInterop(detailCallback),
                ]);
              } catch (e) {
                if (kDebugMode) {
                  print('[WEB] Error processing prediction: $e');
                }
                completed++;
                if (completed >= length || completed >= 5) {
                  completer.complete(places);
                }
              }
            }
          } else {
            if (kDebugMode) {
              print('[WEB] Autocomplete failed with status: $statusStr');
            }
            completer.complete([]);
          }
        } catch (e) {
          if (kDebugMode) {
            print('[WEB] Error in predictions callback: $e');
          }
          completer.completeError(e);
        }
      }
      
      // Call getPlacePredictions
      service.callMethod('getPlacePredictions', [
        request,
        js.allowInterop(predictionsCallback),
      ]);
      
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            print('[WEB] Autocomplete timeout');
          }
          return [];
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('[WEB] Error in autocomplete: $e');
      }
      return [];
    }
  }

  /// Get directions using JavaScript API (no CORS issues)
  Future<Map<String, dynamic>> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      if (kDebugMode) {
        print('[WEB] Getting directions from $origin to $destination');
      }
      
      final completer = Completer<Map<String, dynamic>>();
      
      // Create DirectionsService
      final service = js.JsObject(
        js.context['google']['maps']['DirectionsService'],
      );
      
      final request = js.JsObject.jsify({
        'origin': {
          'lat': origin.latitude,
          'lng': origin.longitude,
        },
        'destination': {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
        'travelMode': 'DRIVING',
      });
      
      // Callback function - Google API passes 2 args: result, status
      void callback(dynamic result, dynamic status) {
        try {
          final statusStr = status.toString();
          if (statusStr == 'OK' && result != null) {
            final jsResult = result as js.JsObject;
            final routes = jsResult['routes'] as js.JsArray;
            
            if (routes.length > 0) {
              final route = routes[0] as js.JsObject;
              final overviewPath = route['overview_path'] as js.JsArray;
              final legs = route['legs'] as js.JsArray;
              final leg = legs[0] as js.JsObject;
              
              // Convert overview_path to List<LatLng>
              final List<LatLng> polylineCoordinates = [];
              for (int i = 0; i < overviewPath.length; i++) {
                final point = overviewPath[i] as js.JsObject;
                polylineCoordinates.add(LatLng(
                  point.callMethod('lat') as double,
                  point.callMethod('lng') as double,
                ));
              }
              
              // Get distance and duration
              final distance = (leg['distance'] as js.JsObject)['text'] as String;
              final duration = (leg['duration'] as js.JsObject)['text'] as String;
              
              if (kDebugMode) {
                print('[WEB] Directions found: $distance, $duration, ${polylineCoordinates.length} points');
              }
              
              completer.complete({
                'polylineCoordinates': polylineCoordinates,
                'distance': distance,
                'duration': duration,
              });
            } else {
              if (kDebugMode) {
                print('[WEB] No routes found');
              }
              completer.complete({});
            }
          } else {
            if (kDebugMode) {
              print('[WEB] Directions failed with status: $statusStr');
            }
            completer.complete({});
          }
        } catch (e) {
          if (kDebugMode) {
            print('[WEB] Error in directions callback: $e');
          }
          completer.completeError(e);
        }
      }
      
      // Call route
      service.callMethod('route', [
        request,
        js.allowInterop(callback),
      ]);
      
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (kDebugMode) {
            print('[WEB] Directions timeout');
          }
          return {};
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('[WEB] Error getting directions: $e');
      }
      return {};
    }
  }
}
