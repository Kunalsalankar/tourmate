import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/colors.dart';
import '../core/services/data_export_service.dart';

/// Advanced analytics screen for transportation planners
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DataExportService _exportService = DataExportService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _exportService.exportTripStatistics();
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load statistics: $e');
    }
  }

  Future<void> _exportData(String type) async {
    try {
      _showLoadingDialog('Generating export...');

      String csvData;
      String fileName;

      switch (type) {
        case 'all_trips':
          csvData = await _exportService.exportAllTripsToCSV();
          fileName = 'all_trips_${DateTime.now().millisecondsSinceEpoch}.csv';
          break;
        case 'od_matrix':
          csvData = await _exportService.exportODMatrix();
          fileName = 'od_matrix_${DateTime.now().millisecondsSinceEpoch}.csv';
          break;
        case 'mode_share':
          csvData = await _exportService.exportModeShareAnalysis();
          fileName = 'mode_share_${DateTime.now().millisecondsSinceEpoch}.csv';
          break;
        case 'purpose':
          csvData = await _exportService.exportTripPurposeAnalysis();
          fileName = 'trip_purpose_${DateTime.now().millisecondsSinceEpoch}.csv';
          break;
        case 'hourly':
          csvData = await _exportService.exportHourlyDistribution();
          fileName = 'hourly_distribution_${DateTime.now().millisecondsSinceEpoch}.csv';
          break;
        default:
          throw Exception('Unknown export type');
      }

      Navigator.pop(context); // Close loading dialog

      // Save file
      await _saveFile(csvData, fileName);

      _showSuccess('Data exported successfully to $fileName');
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showError('Export failed: $e');
    }
  }

  Future<void> _saveFile(String content, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      
      // Copy to clipboard as well
      await Clipboard.setData(ClipboardData(text: content));
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Transportation Analytics',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appBarBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.appBarText),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatisticsOverview(),
                  const SizedBox(height: 20),
                  _buildModeDistribution(),
                  const SizedBox(height: 20),
                  _buildExportSection(),
                  const SizedBox(height: 20),
                  _buildAnalysisTools(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsOverview() {
    if (_statistics == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Overall Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Trips',
                    _statistics!['totalTrips'].toString(),
                    Icons.trip_origin,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Users',
                    _statistics!['totalUsers'].toString(),
                    Icons.people,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Auto Trips',
                    _statistics!['totalAutoTrips'].toString(),
                    Icons.gps_fixed,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Manual Trips',
                    _statistics!['totalManualTrips'].toString(),
                    Icons.edit,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Distance',
                    '${_statistics!['totalDistance'].toStringAsFixed(1)} km',
                    Icons.straighten,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Distance',
                    '${_statistics!['avgDistance'].toStringAsFixed(1)} km',
                    Icons.timeline,
                    Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              'Avg Duration',
              '${_statistics!['avgDuration'].toStringAsFixed(0)} minutes',
              Icons.timer,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModeDistribution() {
    if (_statistics == null) return const SizedBox.shrink();

    final modeDistribution = _statistics!['modeDistribution'] as Map<String, int>;
    final total = modeDistribution.values.fold(0, (sum, count) => sum + count);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Mode Distribution',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...modeDistribution.entries.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              return _buildModeItem(entry.key, entry.value, percentage);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModeItem(String mode, int count, String percentage) {
    final color = _getModeColor(mode);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mode,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count trips ($percentage%)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: double.parse(percentage) / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return Colors.green;
      case 'cycling':
      case 'e-bike':
        return Colors.blue;
      case 'motorcycle':
        return Colors.orange;
      case 'car':
        return Colors.red;
      case 'bus':
        return Colors.purple;
      case 'train':
      case 'train/fast transit':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Widget _buildExportSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.download, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Data Export',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Export trip data for external analysis',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const Divider(height: 20),
            _buildExportButton(
              'All Trips (CSV)',
              'Complete trip dataset with all fields',
              Icons.table_chart,
              () => _exportData('all_trips'),
            ),
            _buildExportButton(
              'Origin-Destination Matrix',
              'OD pairs with trip counts',
              Icons.grid_on,
              () => _exportData('od_matrix'),
            ),
            _buildExportButton(
              'Mode Share Analysis',
              'Trip distribution by transport mode',
              Icons.directions_transit,
              () => _exportData('mode_share'),
            ),
            _buildExportButton(
              'Trip Purpose Analysis',
              'Trip distribution by purpose',
              Icons.work,
              () => _exportData('purpose'),
            ),
            _buildExportButton(
              'Hourly Distribution',
              'Trip counts by hour of day',
              Icons.access_time,
              () => _exportData('hourly'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(
    String title,
    String description,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTools() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Analysis Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Advanced analysis capabilities',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const Divider(height: 20),
            _buildAnalysisItem(
              'Peak Hour Analysis',
              'Identify traffic congestion periods',
              Icons.trending_up,
            ),
            _buildAnalysisItem(
              'Route Optimization',
              'Analyze common routes and alternatives',
              Icons.route,
            ),
            _buildAnalysisItem(
              'Travel Time Reliability',
              'Compare actual vs expected travel times',
              Icons.schedule,
            ),
            _buildAnalysisItem(
              'Accessibility Analysis',
              'Identify underserved areas',
              Icons.location_city,
            ),
            _buildAnalysisItem(
              'Carbon Footprint',
              'Calculate environmental impact',
              Icons.eco,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
