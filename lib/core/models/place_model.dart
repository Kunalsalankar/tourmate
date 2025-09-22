import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model class for a place from Google Places API
class PlaceModel {
  final String placeId;
  final String name;
  final String address;
  final LatLng location;
  final List<String>? types;
  final double? rating;
  final String? photoReference;
  final String? icon;

  PlaceModel({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
    this.types,
    this.rating,
    this.photoReference,
    this.icon,
  });

  /// Create a PlaceModel from a map
  factory PlaceModel.fromMap(Map<String, dynamic> map) {
    return PlaceModel(
      placeId: map['place_id'],
      name: map['name'],
      address: map['vicinity'] ?? map['formatted_address'] ?? '',
      location: LatLng(
        map['geometry']['location']['lat'],
        map['geometry']['location']['lng'],
      ),
      types: map['types'] != null ? List<String>.from(map['types']) : null,
      rating: map['rating']?.toDouble(),
      photoReference: map['photos'] != null && map['photos'].isNotEmpty
          ? map['photos'][0]['photo_reference']
          : null,
      icon: map['icon'],
    );
  }

  /// Convert PlaceModel to a map
  Map<String, dynamic> toMap() {
    return {
      'place_id': placeId,
      'name': name,
      'address': address,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'types': types,
      'rating': rating,
      'photo_reference': photoReference,
      'icon': icon,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceModel &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;
}