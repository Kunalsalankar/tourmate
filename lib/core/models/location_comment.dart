import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationComment {
  final String id;
  final String uid;
  final String userName;
  final String comment;
  final double lat;
  final double lng;
  final DateTime? createdAt;

  const LocationComment({
    required this.id,
    required this.uid,
    required this.userName,
    required this.comment,
    required this.lat,
    required this.lng,
    this.createdAt,
  });

  LatLng get position => LatLng(lat, lng);

  factory LocationComment.fromMap(Map<String, dynamic> data, String id) {
    return LocationComment(
      id: id,
      uid: (data['uid'] ?? '') as String,
      userName: (data['userName'] ?? '') as String,
      comment: (data['comment'] ?? '') as String,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : null,
    );
  }
}
