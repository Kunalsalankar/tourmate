import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model for location-based comments during trips
class LocationCommentModel {
  final String? id;
  final String uid;
  final String userName;
  final String comment;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String? tripId; // Optional: link to specific trip
  final String? photoUrl; // Optional: user can attach photo
  final List<String>? tags; // Optional: categorize comments (e.g., 'traffic', 'scenic', 'food')

  LocationCommentModel({
    this.id,
    required this.uid,
    required this.userName,
    required this.comment,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.tripId,
    this.photoUrl,
    this.tags,
  });

  /// Get location as LatLng
  LatLng get location => LatLng(lat, lng);

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'comment': comment,
      'lat': lat,
      'lng': lng,
      'timestamp': Timestamp.fromDate(timestamp),
      'tripId': tripId,
      'photoUrl': photoUrl,
      'tags': tags,
    };
  }

  /// Create from Firestore document
  factory LocationCommentModel.fromMap(Map<String, dynamic> map, String id) {
    return LocationCommentModel(
      id: id,
      uid: map['uid'] ?? '',
      userName: map['userName'] ?? '',
      comment: map['comment'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tripId: map['tripId'],
      photoUrl: map['photoUrl'],
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
    );
  }

  /// Create a copy with updated fields
  LocationCommentModel copyWith({
    String? id,
    String? uid,
    String? userName,
    String? comment,
    double? lat,
    double? lng,
    DateTime? timestamp,
    String? tripId,
    String? photoUrl,
    List<String>? tags,
  }) {
    return LocationCommentModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      userName: userName ?? this.userName,
      comment: comment ?? this.comment,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      tripId: tripId ?? this.tripId,
      photoUrl: photoUrl ?? this.photoUrl,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() {
    return 'LocationComment(id: $id, user: $userName, comment: $comment, location: ($lat, $lng))';
  }
}
