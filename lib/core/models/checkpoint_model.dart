import 'package:cloud_firestore/cloud_firestore.dart';

class CheckpointModel {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final DateTime createdAt;

  CheckpointModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert CheckpointModel to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create CheckpointModel from Firestore document
  factory CheckpointModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CheckpointModel(
      id: documentId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown User',
      title: map['title'] ?? 'Checkpoint',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Create a copy of the CheckpointModel with updated fields
  CheckpointModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return CheckpointModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'CheckpointModel(id: $id, userId: $userId, title: $title, latitude: $latitude, longitude: $longitude, timestamp: $timestamp)';
  }
}
