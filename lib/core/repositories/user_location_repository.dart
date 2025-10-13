import 'package:cloud_firestore/cloud_firestore.dart';

/// Repository to read/write a user's last known location for admin visibility
class UserLocationRepository {
  static const String _collection = 'user_locations';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get last known location for a given user
  /// Expects document at `user_locations/{userId}` with fields:
  /// - latitude: double
  /// - longitude: double
  /// - updatedAt: Timestamp
  Future<({double latitude, double longitude, DateTime? updatedAt})?>
  getUserLocation(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final ts = data['updatedAt'];
      DateTime? updatedAt;
      if (ts is Timestamp) {
        updatedAt = ts.toDate();
      }
      return (latitude: lat, longitude: lng, updatedAt: updatedAt);
    } catch (e) {
      return null;
    }
  }
}
