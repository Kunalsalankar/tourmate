import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/services/export_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecentDataScreen extends StatefulWidget {
  const RecentDataScreen({super.key});

  @override
  State<RecentDataScreen> createState() => _RecentDataScreenState();
}

class _RecentDataScreenState extends State<RecentDataScreen> {
  final ExportService _exportService = ExportService();

  bool _loading = true;
  String? _error;

  List<MapEntry<String, int>> _topSearchLocations = const [];
  int _used200mCount = 0;

  List<MapEntry<String, int>> _keywordFrequency = const [];
  List<MapEntry<int, int>> _activeTimeByHour = const [];

  int _totalNearestRequests = 0;
  int _openedGoogleMapsCount = 0;
  double _avgDistanceTravelled = 0;

  int _total200mAlerts = 0;
  int _popupTriggeredCount = 0;

  double _avgLoadTime = 0;
  double _avgResponseTime = 0;
  String _mostUsedFeature = '-';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      bool isAdmin = false;
      if (uid != null) {
        try {
          final u = await firestore.collection('users').doc(uid).get();
          final d = u.data();
          if (d != null && d['role'] == 'admin') {
            isAdmin = true;
          }
        } catch (_) {}
      }

      Query<Map<String, dynamic>> buildQuery(String collection) {
        Query<Map<String, dynamic>> q = firestore.collection(collection);
        if (!isAdmin && uid != null) {
          q = q.where('userId', isEqualTo: uid);
        }
        return q.orderBy('timestamp', descending: true).limit(500);
      }

      Future<QuerySnapshot<Map<String, dynamic>>> fetch(String collection) async {
        try {
          return await buildQuery(collection).get();
        } on FirebaseException catch (e) {
          if (e.code == 'failed-precondition') {
            Query<Map<String, dynamic>> q = firestore.collection(collection);
            if (!isAdmin && uid != null) {
              q = q.where('userId', isEqualTo: uid);
            }
            return q.limit(500).get();
          }
          rethrow;
        }
      }

      final futures = await Future.wait([
        fetch('searchLogs'),
        fetch('navigationLogs'),
        fetch('notificationLogs'),
        fetch('appPerformance'),
      ]);

      final searchSnap = futures[0] as QuerySnapshot<Map<String, dynamic>>;
      final navigationSnap = futures[1] as QuerySnapshot<Map<String, dynamic>>;
      final notificationSnap = futures[2] as QuerySnapshot<Map<String, dynamic>>;
      final performanceSnap = futures[3] as QuerySnapshot<Map<String, dynamic>>;

      _processSearchLogs(searchSnap.docs.map((d) => d.data()));
      _processNavigationLogs(navigationSnap.docs.map((d) => d.data()));
      _processNotificationLogs(notificationSnap.docs.map((d) => d.data()));
      _processPerformanceLogs(performanceSnap.docs.map((d) => d.data()));

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _processSearchLogs(Iterable<Map<String, dynamic>> logs) {
    final placeCounts = <String, int>{};
    final keywordCounts = <String, int>{};
    final hourCounts = <int, int>{};
    int used200m = 0;

    for (final log in logs) {
      final place = (log['placeName'] as String?)?.trim();
      if (place != null && place.isNotEmpty) {
        placeCounts[place] = (placeCounts[place] ?? 0) + 1;
        keywordCounts[place.toLowerCase()] = (keywordCounts[place.toLowerCase()] ?? 0) + 1;
      }

      final ts = log['timestamp'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final hour = dt.hour;
        hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
      }

      final used = log['used200mFeature'];
      if (used is bool && used) {
        used200m++;
      }
    }

    final topPlaces = placeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final keywords = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final hours = hourCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    _topSearchLocations = topPlaces.take(5).toList();
    _keywordFrequency = keywords.take(8).toList();
    _activeTimeByHour = hours;
    _used200mCount = used200m;
  }

  void _processNavigationLogs(Iterable<Map<String, dynamic>> logs) {
    int total = 0;
    int openedMaps = 0;
    double totalDistance = 0;

    for (final log in logs) {
      total++;

      final opened = log['openedGoogleMaps'];
      if (opened is bool && opened) {
        openedMaps++;
      }

      final distance = log['distanceTravelled'];
      if (distance is num) {
        totalDistance += distance.toDouble();
      }
    }

    _totalNearestRequests = total;
    _openedGoogleMapsCount = openedMaps;
    _avgDistanceTravelled = total > 0 ? totalDistance / total : 0;
  }

  void _processNotificationLogs(Iterable<Map<String, dynamic>> logs) {
    int totalAlerts = 0;
    int popupCount = 0;

    for (final log in logs) {
      final type = (log['notificationType'] as String?)?.toLowerCase();
      if (type == null) continue;

      if (type.contains('200m')) {
        totalAlerts++;
      }
      if (type.contains('popup')) {
        popupCount++;
      }
    }

    _total200mAlerts = totalAlerts;
    _popupTriggeredCount = popupCount;
  }

  void _processPerformanceLogs(Iterable<Map<String, dynamic>> logs) {
    double totalLoad = 0;
    double totalResponse = 0;
    int count = 0;
    final featureCounts = <String, int>{};

    for (final log in logs) {
      final load = log['loadTime'];
      final response = log['responseTime'];
      final feature = (log['featureUsed'] as String?)?.trim();

      if (load is num) {
        totalLoad += load.toDouble();
      }
      if (response is num) {
        totalResponse += response.toDouble();
      }
      if (feature != null && feature.isNotEmpty) {
        featureCounts[feature] = (featureCounts[feature] ?? 0) + 1;
      }
      count++;
    }

    _avgLoadTime = count > 0 ? totalLoad / count : 0;
    _avgResponseTime = count > 0 ? totalResponse / count : 0;

    if (featureCounts.isNotEmpty) {
      final sorted = featureCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _mostUsedFeature = sorted.first.key;
    } else {
      _mostUsedFeature = '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBackground,
        elevation: 0,
        title: const Text(
          'Recent Data Dashboard',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.appBarText),
            tooltip: 'Export Data',
            onPressed: _showExportOptions,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load recent data',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimary,
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: AppColors.textOnPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard(
                    title: 'User Location Analytics',
                    icon: Icons.location_on,
                    color: Colors.blue,
                    child: _buildUserLocationSection(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Search Pattern Analytics',
                    icon: Icons.search,
                    color: Colors.deepPurple,
                    child: _buildSearchPatternSection(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Navigation & Travel Analytics',
                    icon: Icons.directions,
                    color: Colors.teal,
                    child: _buildNavigationSection(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Notification Analytics',
                    icon: Icons.notifications_active,
                    color: Colors.orange,
                    child: _buildNotificationSection(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Performance Analytics',
                    icon: Icons.speed,
                    color: Colors.redAccent,
                    child: _buildPerformanceSection(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Export as CSV'),
                onTap: () {
                  Navigator.pop(context);
                  _exportCsv(forceStreaming: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Export as JSON'),
                onTap: () {
                  Navigator.pop(context);
                  _exportJson();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download),
                title: const Text('Export as CSV (Large Dataset)'),
                subtitle: const Text('Streaming mode for 10k+ rows'),
                onTap: () {
                  Navigator.pop(context);
                  _exportCsv(forceStreaming: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportCsv({required bool forceStreaming}) async {
    await _runExport(
      label: forceStreaming ? 'Exporting large CSV…' : 'Exporting CSV…',
      action: () => _exportService.exportLogsToCsv(forceStreaming: forceStreaming),
    );
  }

  Future<void> _exportJson() async {
    await _runExport(
      label: 'Exporting JSON…',
      action: _exportService.exportLogsToJson,
    );
  }

  Future<void> _runExport({
    required String label,
    required Future<File> Function() action,
  }) async {
    // Show progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );

    String message;
    Color bgColor;

    try {
      final file = await action();
      message = 'Export completed: ${file.path}';
      bgColor = AppColors.success;
    } catch (e) {
      message = 'Export failed: $e';
      bgColor = AppColors.error;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textOnPrimary),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildUserLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: 140,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top searched locations',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._topSearchLocations.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: TextStyle(color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e.value.toString(),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_topSearchLocations.isEmpty)
                        Text(
                          'No search data',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 140,
              width: 160,
              child: _buildBarChart(_topSearchLocations),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.radar, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '200m nearest-feature used: $_used200mCount times',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchPatternSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keyword frequency',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: _buildBarChart(_keywordFrequency),
        ),
        const SizedBox(height: 16),
        Text(
          'User active time by hour',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: _buildLineChart(_activeTimeByHour),
        ),
      ],
    );
  }

  Widget _buildNavigationSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricTile(
                label: 'Total nearest requests',
                value: _totalNearestRequests.toString(),
                icon: Icons.navigation,
              ),
              const SizedBox(height: 8),
              _buildMetricTile(
                label: 'Google Maps opened',
                value: _openedGoogleMapsCount.toString(),
                icon: Icons.map,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricTile(
            label: 'Avg distance travelled (km)',
            value: _avgDistanceTravelled.toStringAsFixed(2),
            icon: Icons.social_distance,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: '200m alerts sent',
            value: _total200mAlerts.toString(),
            icon: Icons.notification_important,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricTile(
            label: 'Popup triggered',
            value: _popupTriggeredCount.toString(),
            icon: Icons.open_in_new,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricTile(
                label: 'Avg load time (ms)',
                value: _avgLoadTime.toStringAsFixed(0),
                icon: Icons.hourglass_bottom,
              ),
              const SizedBox(height: 8),
              _buildMetricTile(
                label: 'Avg response time (ms)',
                value: _avgResponseTime.toStringAsFixed(0),
                icon: Icons.timeline,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricTile(
            label: 'Most used feature',
            value: _mostUsedFeature,
            icon: Icons.star,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<MapEntry<String, int>> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final maxY = data.map((e) => e.value).fold<int>(0, (p, c) => c > p ? c : p).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY == 0 ? 1 : maxY + 1,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                final label = data[index].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label.length > 6 ? '${label.substring(0, 6)}…' : label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].value.toDouble(),
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<MapEntry<int, int>> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final spots = data
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    final maxY = data.map((e) => e.value).fold<int>(0, (p, c) => c > p ? c : p).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                if (hour % 4 != 0) return const SizedBox.shrink();
                return Text('${hour}h', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        minX: 0,
        maxX: 23,
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY + 1,
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            spots: spots,
          ),
        ],
      ),
    );
  }
}
