import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/checkpoint_model.dart';

class CheckpointRepository {
  final FirebaseFirestore _firestore;
  final String collectionName = 'checkpoints';

  CheckpointRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Add a new checkpoint to Firestore
  Future<void> addCheckpoint(CheckpointModel checkpoint) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(checkpoint.id)
          .set(checkpoint.toMap());
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
}
