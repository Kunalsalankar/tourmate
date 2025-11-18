class AdminAnalytics {
  final int totalTrips;
  final int carTrips;
  final int bikeTrips;
  final int busTrips;
  final int walkTrips;
  final double totalDistance;
  final int totalUsers;
  final double avgTripDuration;

  const AdminAnalytics({
    required this.totalTrips,
    required this.carTrips,
    required this.bikeTrips,
    required this.busTrips,
    required this.walkTrips,
    required this.totalDistance,
    required this.totalUsers,
    required this.avgTripDuration,
  });

  factory AdminAnalytics.empty() {
    return const AdminAnalytics(
      totalTrips: 0,
      carTrips: 0,
      bikeTrips: 0,
      busTrips: 0,
      walkTrips: 0,
      totalDistance: 0,
      totalUsers: 0,
      avgTripDuration: 0,
    );
  }

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    num _n(String key) => json[key] is num ? json[key] as num : 0;

    return AdminAnalytics(
      totalTrips: _n('totalTrips').toInt(),
      carTrips: _n('carTrips').toInt(),
      bikeTrips: _n('bikeTrips').toInt(),
      busTrips: _n('busTrips').toInt(),
      walkTrips: _n('walkTrips').toInt(),
      totalDistance: _n('totalDistance').toDouble(),
      totalUsers: _n('totalUsers').toInt(),
      avgTripDuration: _n('avgTripDuration').toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTrips': totalTrips,
      'carTrips': carTrips,
      'bikeTrips': bikeTrips,
      'busTrips': busTrips,
      'walkTrips': walkTrips,
      'totalDistance': totalDistance,
      'totalUsers': totalUsers,
      'avgTripDuration': avgTripDuration,
    };
  }

  /// Convenience list for charts/tables.
  List<_ModeStat> get modeStats => [
        _ModeStat('Car', carTrips),
        _ModeStat('Bike', bikeTrips),
        _ModeStat('Bus', busTrips),
        _ModeStat('Walk', walkTrips),
      ];
}

class _ModeStat {
  final String mode;
  final int trips;

  const _ModeStat(this.mode, this.trips);
}

