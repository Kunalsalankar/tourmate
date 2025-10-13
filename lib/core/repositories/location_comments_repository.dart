import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository to create and read user comments pinned to map locations
class LocationCommentsRepository {
  static const String _collection = 'location_comments';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Add a comment for a given coordinate. Each document stores metadata and geo.
  Future<String> addComment({
    required double latitude,
    required double longitude,
    required String userName,
    required String comment,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final doc = await _firestore.collection(_collection).add({
      'uid': uid,
      'userName': userName,
      'comment': comment,
      'lat': latitude,
      'lng': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Stream comments around a bounding box (current visible region)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCommentsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    // Firestore doesn't support compound range on two fields in single query without indexes.
    // We fetch by lat bounds first and filter lng client-side.
    final query = _firestore
        .collection(_collection)
        .where('lat', isGreaterThanOrEqualTo: minLat)
        .where('lat', isLessThanOrEqualTo: maxLat);

    return query.snapshots();
  }

  /// Stream all comments (simple implementation without geo filtering)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllComments() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
