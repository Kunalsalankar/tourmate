import 'package:cloud_firestore/cloud_firestore.dart';

class TripLocation {
  final String tripId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String driverId;

  const TripLocation({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.driverId,
  });

  Map<String, dynamic> toMap() => {
        'tripId': tripId,
        'lat': latitude,
        'lng': longitude,
        'recordedAt': recordedAt,
        'driverId': driverId,
      };

  factory TripLocation.fromMap(Map<String, dynamic> data) {
    final rec = data['recordedAt'];
    final dt = rec is Timestamp ? rec.toDate() : rec as DateTime;
    return TripLocation(
      tripId: data['tripId'] as String,
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['lng'] as num).toDouble(),
      recordedAt: dt,
      driverId: data['driverId'] as String,
    );
  }
}
