import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String userId;
  final String tripId;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tripId': tripId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
    };
  }

  factory Comment.fromMap(String id, Map<String, dynamic> map) {
    return Comment(
      id: id,
      userId: map['userId'] as String,
      tripId: map['tripId'] as String,
      text: map['text'] as String,
      imageUrl: map['imageUrl'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
