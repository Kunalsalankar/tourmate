import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/trip_location_service.dart';

class TripLocationHistoryScreen extends StatelessWidget {
  final String tripId;
  const TripLocationHistoryScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final svc = TripLocationService(FirebaseFirestore.instance);
    final stream = svc.streamTripHistory(tripId);

    return Scaffold(
      appBar: AppBar(title: Text('Trip $tripId - Location History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No history yet'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final lat = (d['lat'] as num?)?.toDouble();
              final lng = (d['lng'] as num?)?.toDouble();
              final ts = d['recordedAt'];
              final dt = ts is Timestamp ? ts.toDate() : null;
              return ListTile(
                leading: const Icon(Icons.place),
                title: Text('($lat, $lng)'),
                subtitle: Text(dt?.toLocal().toString().substring(0, 19) ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
