import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/location_comment_model.dart';

/// Repository for managing location comments in Firestore
class LocationCommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'location_comments';

  /// Add a new location comment
  Future<String?> addComment(LocationCommentModel comment) async {
    try {
      final docRef = await _firestore
          .collection(_collectionName)
          .add(comment.toMap());
      
      if (kDebugMode) {
        print('[LocationCommentRepo] Comment added: ${docRef.id}');
      }
      
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('[LocationCommentRepo] Error adding comment: $e');
      }
      return null;
    }
  }

  /// Update an existing comment
  Future<bool> updateComment(String commentId, LocationCommentModel comment) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(commentId)
          .update(comment.toMap());
      
      if (kDebugMode) {
        print('[LocationCommentRepo] Comment updated: $commentId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[LocationCommentRepo] Error updating comment: $e');
      }
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(commentId)
          .delete();
      
      if (kDebugMode) {
        print('[LocationCommentRepo] Comment deleted: $commentId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[LocationCommentRepo] Error deleting comment: $e');
      }
      return false;
    }
  }

  /// Get all comments for a specific trip
  Stream<List<LocationCommentModel>> getTripComments(String tripId) {
    return _firestore
        .collection(_collectionName)
        .where('tripId', isEqualTo: tripId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationCommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get all comments by a specific user
  Stream<List<LocationCommentModel>> getUserComments(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationCommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get comments near a specific location (within radius in km)
  Future<List<LocationCommentModel>> getCommentsNearLocation(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      // Calculate approximate bounds (simple box, not perfect circle)
      final latDelta = radiusKm / 111.0; // 1 degree lat ≈ 111 km

      final snapshot = await _firestore
          .collection(_collectionName)
          .where('lat', isGreaterThanOrEqualTo: lat - latDelta)
          .where('lat', isLessThanOrEqualTo: lat + latDelta)
          .get();

      // Filter by longitude and exact distance
      final comments = snapshot.docs
          .map((doc) => LocationCommentModel.fromMap(doc.data(), doc.id))
          .where((comment) {
            final distance = _calculateDistance(lat, lng, comment.lat, comment.lng);
            return distance <= radiusKm;
          })
          .toList();

      return comments;
    } catch (e) {
      if (kDebugMode) {
        print('[LocationCommentRepo] Error getting nearby comments: $e');
      }
      return [];
    }
  }

  /// Get all public comments (for map view)
  Stream<List<LocationCommentModel>> getAllComments({int limit = 100}) {
    return _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationCommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get comments with specific tags
  Stream<List<LocationCommentModel>> getCommentsByTag(String tag) {
    return _firestore
        .collection(_collectionName)
        .where('tags', arrayContains: tag)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LocationCommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
