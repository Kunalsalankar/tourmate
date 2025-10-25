import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String driverId;
  final String status; // 'active' | 'inactive'
  final DateTime? startedAt;

  const Trip({
    required this.id,
    required this.driverId,
    required this.status,
    this.startedAt,
  });

  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    final started = data['startedAt'];
    DateTime? startedAt;
    if (started is Timestamp) startedAt = started.toDate();
    if (started is DateTime) startedAt = started;

    return Trip(
      id: id,
      driverId: data['driverId'] as String,
      status: data['status'] as String,
      startedAt: startedAt,
    );
  }

  bool get isActive => status == 'active';
}
