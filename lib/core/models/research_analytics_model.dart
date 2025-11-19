class ResearchAnalytics {
  final int totalTrips;
  final int totalUsers;
  final double avgTripDurationMinutes;
  final Map<String, int> modeCounts; // mode -> trips
  final List<Map<String, dynamic>> odPairs; // [{origin, destination, count}]
  final List<Map<String, dynamic>> dailyTrend; // [{date, count}]

  const ResearchAnalytics({
    required this.totalTrips,
    required this.totalUsers,
    required this.avgTripDurationMinutes,
    required this.modeCounts,
    required this.odPairs,
    required this.dailyTrend,
  });

  factory ResearchAnalytics.empty() => const ResearchAnalytics(
        totalTrips: 0,
        totalUsers: 0,
        avgTripDurationMinutes: 0,
        modeCounts: const {},
        odPairs: const [],
        dailyTrend: const [],
      );
}
