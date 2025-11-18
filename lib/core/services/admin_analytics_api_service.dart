import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/admin_analytics_model.dart';

class AdminAnalyticsApiService {
  final String baseUrl;
  final http.Client _client;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  AdminAnalyticsApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<AdminAnalytics> fetchAnalytics({
    required DateTime start,
    required DateTime end,
    required String mode,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/admin/analytics',
      queryParameters: {
        'start': _dateFormat.format(start),
        'end': _dateFormat.format(end),
        'mode': mode,
      },
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load analytics: ${response.statusCode}');
    }

    final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
    return AdminAnalytics.fromJson(data);
  }
}

