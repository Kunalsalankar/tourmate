import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

class TripService {
  TripService(this._db);
  final FirebaseFirestore _db;

  Future<List<Trip>> fetchActiveTripsForDriver(String driverId) async {
    final snap = await _db
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map((d) => Trip.fromMap(d.id, d.data())).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLatestTripLocationsRaw() {
    return _db.collection('latest_trip_locations').snapshots();
  }
}
