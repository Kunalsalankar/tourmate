import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/research_analytics_model.dart';

class ResearchAnalyticsService {
  final FirebaseFirestore _db;
  ResearchAnalyticsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<ResearchAnalytics> fetch({
    required DateTime from,
    required DateTime to,
    String mode = 'all',
    int topOdPairs = 50,
  }) async {
    final startKey = _dateKey(from);
    final endKey = _dateKey(to);

    final auth = FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    bool isAdmin = false;
    if (uid != null) {
      try {
        final userDoc = await _db.collection('users').doc(uid).get();
        final ud = userDoc.data();
        if (ud != null) {
          final role = ud['role'];
          if (role is String && role == 'admin') {
            isAdmin = true;
          }
        }
      } catch (_) {}
    }

    Query<Map<String, dynamic>> q = _db
        .collection('od_flat')
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThanOrEqualTo: endKey);
    if (!isAdmin && uid != null) {
      q = q.where('userId', isEqualTo: uid);
    }
    final snap = await q.get();

    final modeLC = mode.toLowerCase();

    int totalTrips = 0;
    final users = <String>{};
    double totalDurationMin = 0;
    final modeCounts = <String, int>{};
    final odMap = <String, int>{};
    final trend = <String, int>{};

    for (final d in snap.docs) {
      final data = d.data();
      final m = (data['mode'] as String? ?? '').toLowerCase();
      if (modeLC != 'all' && m != modeLC) continue;

      totalTrips += 1;
      final uid = data['userId'] as String?;
      if (uid != null) users.add(uid);

      final tsStart = data['startTime'];
      final tsEnd = data['endTime'];
      if (tsStart is Timestamp && tsEnd is Timestamp) {
        final mins = tsEnd.toDate().difference(tsStart.toDate()).inMinutes;
        totalDurationMin += mins;
      }

      modeCounts[m.isEmpty ? 'unknown' : m] = (modeCounts[m.isEmpty ? 'unknown' : m] ?? 0) + 1;

      final o = (data['origin'] as String? ?? '').trim();
      final ddd = (data['destination'] as String? ?? '').trim();
      final key = '$o||$ddd';
      odMap[key] = (odMap[key] ?? 0) + 1;

      final dk = data['dateKey'] as String?;
      if (dk != null) trend[dk] = (trend[dk] ?? 0) + 1;
    }

    final avg = totalTrips > 0 ? (totalDurationMin / totalTrips) : 0.0;

    final odPairs = odMap.entries
        .map((e) {
          final parts = e.key.split('||');
          return {
            'origin': parts[0],
            'destination': parts.length > 1 ? parts[1] : '',
            'count': e.value,
          };
        })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final topPairs = odPairs.take(topOdPairs).toList();

    final dailyTrend = trend.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return ResearchAnalytics(
      totalTrips: totalTrips,
      totalUsers: users.length,
      avgTripDurationMinutes: avg,
      modeCounts: modeCounts,
      odPairs: topPairs,
      dailyTrend: dailyTrend,
    );
  }
}
