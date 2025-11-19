import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/controllers/research_analytics_controller.dart';
import '../core/services/research_analytics_service.dart';

class ResearchAnalyticsScreen extends StatefulWidget {
  const ResearchAnalyticsScreen({super.key});

  @override
  State<ResearchAnalyticsScreen> createState() => _ResearchAnalyticsScreenState();
}

class _ResearchAnalyticsScreenState extends State<ResearchAnalyticsScreen> {
  late final ResearchAnalyticsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ResearchAnalyticsController(ResearchAnalyticsService());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Research Analytics'),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarText,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilters(context),
                const SizedBox(height: 12),
                Expanded(child: _buildBody()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Filters', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _presetChip('Today', ResearchPreset.today),
                _presetChip('This Week', ResearchPreset.thisWeek),
                _presetChip('This Month', ResearchPreset.thisMonth),
                _presetChip('This Year', ResearchPreset.thisYear),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _dateButton('From', _controller.from, () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _controller.from,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) _controller.setFrom(picked);
                })),
                const SizedBox(width: 12),
                Expanded(child: _dateButton('To', _controller.to, () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _controller.to,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) _controller.setTo(picked);
                })),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.traffic, size: 18, color: AppColors.iconPrimary),
              const SizedBox(width: 8),
              Text('Mode', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: _controller.mode,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'car', child: Text('Car')),
                      DropdownMenuItem(value: 'bike', child: Text('Bike')),
                      DropdownMenuItem(value: 'bus', child: Text('Bus')),
                      DropdownMenuItem(value: 'walk', child: Text('Walk')),
                      DropdownMenuItem(value: 'train', child: Text('Train')),
                      DropdownMenuItem(value: 'flight', child: Text('Flight')),
                    ],
                    onChanged: (val) { if (val != null) _controller.setMode(val); },
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, ResearchPreset preset) {
    final selected = _controller.preset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _controller.applyPreset(preset),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) {
    final text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          Text(text, style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.data.totalTrips == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(height: 8),
            Text('Failed to load', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            if (_controller.error != null)
              Text(_controller.error!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryCards(),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _modeShareCard()),
              const SizedBox(width: 12),
              Expanded(child: _dailyTrendCard()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _odMatrixCard()),
      ],
    );
  }

  Widget _summaryCards() {
    final d = _controller.data;
    return Row(
      children: [
        _summaryCard(Icons.analytics, 'Total Trips', d.totalTrips.toString()),
        const SizedBox(width: 12),
        _summaryCard(Icons.people, 'Total Users', d.totalUsers.toString()),
        const SizedBox(width: 12),
        _summaryCard(Icons.timer, 'Avg Duration', '${d.avgTripDurationMinutes.toStringAsFixed(1)} min'),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String label, String value) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeShareCard() {
    final mc = _controller.data.modeCounts;
    final max = mc.values.fold<int>(0, (a, b) => a > b ? a : b);
    final modes = mc.keys.toList()..sort();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.stacked_bar_chart, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Mode Share', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 8),
            if (mc.isEmpty)
              Expanded(child: Center(child: Text('No data', style: TextStyle(color: AppColors.textSecondary))))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: modes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final m = modes[i];
                    final v = mc[m] ?? 0;
                    final frac = max > 0 ? (v / max) : 0.0;
                    return Row(
                      children: [
                        SizedBox(width: 60, child: Text(m.toUpperCase(), style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(height: 16, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border))),
                              FractionallySizedBox(
                                widthFactor: frac,
                                child: Container(height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(v.toString(), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dailyTrendCard() {
    final trend = _controller.data.dailyTrend;
    final max = trend.fold<int>(0, (a, b) => a > (b['count'] as int) ? a : (b['count'] as int));
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.timeline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Daily Trips', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 8),
            if (trend.isEmpty)
              Expanded(child: Center(child: Text('No data', style: TextStyle(color: AppColors.textSecondary))))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: trend.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final day = trend[i];
                    final v = day['count'] as int;
                    final frac = max > 0 ? (v / max) : 0.0;
                    return Row(
                      children: [
                        SizedBox(width: 74, child: Text(day['date'] as String, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        Expanded(
                          child: Stack(children: [
                            Container(height: 12, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border))),
                            FractionallySizedBox(widthFactor: frac, child: Container(height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)))),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text(v.toString(), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _odMatrixCard() {
    final pairs = _controller.data.odPairs;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.public, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Top OD Pairs', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: pairs.isEmpty
                  ? Center(child: Text('No data', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      itemCount: pairs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = pairs[i];
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${p['origin'] ?? ''} → ${p['destination'] ?? ''}',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                              child: Text('${p['count']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
