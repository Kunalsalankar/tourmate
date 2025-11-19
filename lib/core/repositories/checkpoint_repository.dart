import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checkpoint_model.dart';
import '../../services/analytics_service.dart';

class CheckpointRepository {
  final FirebaseFirestore _firestore;
  final String collectionName = 'checkpoints';
  final AnalyticsService _analytics;

  CheckpointRepository({FirebaseFirestore? firestore, AnalyticsService? analytics}) 
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _analytics = analytics ?? AnalyticsService();

  // Add a new checkpoint to Firestore
  Future<void> addCheckpoint(CheckpointModel checkpoint) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(checkpoint.id)
          .set(checkpoint.toMap());
      await _analytics.logCheckpoint(checkpoint);
    } catch (e) {
      throw Exception('Failed to add checkpoint: $e');
    }
  }

  // Get a stream of all checkpoints, ordered by timestamp (newest first)
  Stream<List<CheckpointModel>> getAllCheckpoints() {
    return _firestore
        .collection(collectionName)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckpointModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get checkpoints for a specific user
  Stream<List<CheckpointModel>> getUserCheckpoints(String userId) {
    return _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckpointModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get checkpoints for a specific user and trip (client-side ordered by time)
  Stream<List<CheckpointModel>> getTripCheckpointsForUser(
      String userId, String tripId) {
    return _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('tripId', isEqualTo: tripId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CheckpointModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        });
  }

  // Get a single checkpoint by ID
  Future<CheckpointModel?> getCheckpointById(String id) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(id).get();
      if (doc.exists) {
        return CheckpointModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get checkpoint: $e');
    }
  }

  // Delete a checkpoint
  Future<void> deleteCheckpoint(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete checkpoint: $e');
    }
  }

  // Get checkpoints within a date range
  Stream<List<CheckpointModel>> getCheckpointsByDateRange(
      DateTime start, DateTime end) {
    return _firestore
        .collection(collectionName)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckpointModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchCheckpointsPage({
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collectionName)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }
}
