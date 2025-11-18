import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Service responsible for exporting recent analytics data
/// from Firestore to CSV / JSON files on device storage.
class ExportService {
  ExportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Export all log collections to a single CSV file.
  /// If [forceStreaming] is true or total rows exceed [streamingThreshold],
  /// rows are written incrementally to reduce memory usage.
  Future<File> exportLogsToCsv({bool forceStreaming = false}) async {
    const streamingThreshold = 10000;

    // First, estimate total rows quickly using document count.
    final counts = await Future.wait<int>([
      _countCollection('searchLogs'),
      _countCollection('navigationLogs'),
      _countCollection('notificationLogs'),
      _countCollection('appPerformance'),
    ]);
    final totalRows = counts.fold<int>(0, (p, c) => p + c);
    final useStreaming = forceStreaming || totalRows > streamingThreshold;

    final file = await _createExportFile(extension: 'csv');
    final sink = file.openWrite(encoding: utf8);

    // Fixed CSV columns for all collections
    const headers = <String>[
      'collection',
      'id',
      'userId',
      'placeName',
      'userLocation',
      'used200mFeature',
      'destination',
      'openedGoogleMaps',
      'distanceTravelled',
      'notificationType',
      'loadTime',
      'responseTime',
      'featureUsed',
      'timestamp',
    ];

    sink.writeln(headers.map(_csvEscape).join(','));

    Future<void> writeCollection(String name) async {
      await for (final doc in _collectionStream(name)) {
        final data = doc.data();
        final row = <String, String>{
          'collection': name,
          'id': doc.id,
          'userId': _string(data['userId']),
          'placeName': _string(data['placeName']),
          'userLocation': _geoPointString(data['userLocation']),
          'used200mFeature': _boolString(data['used200mFeature']),
          'destination': _string(data['destination']),
          'openedGoogleMaps': _boolString(data['openedGoogleMaps']),
          'distanceTravelled': _numString(data['distanceTravelled']),
          'notificationType': _string(data['notificationType']),
          'loadTime': _numString(data['loadTime']),
          'responseTime': _numString(data['responseTime']),
          'featureUsed': _string(data['featureUsed']),
          'timestamp': _timestampString(data['timestamp']),
        };

        final line = headers.map((h) => _csvEscape(row[h])).join(',');
        sink.writeln(line);
      }
    }

    // For non-streaming mode we still iterate as a stream, but we already
    // decided memory strategy above. Keeping one implementation here.
    await writeCollection('searchLogs');
    await writeCollection('navigationLogs');
    await writeCollection('notificationLogs');
    await writeCollection('appPerformance');

    await sink.flush();
    await sink.close();
    return file;
  }

  /// Export all log collections to a single pretty-formatted JSON file.
  Future<File> exportLogsToJson() async {
    final result = <String, List<Map<String, dynamic>>>{
      'searchLogs': <Map<String, dynamic>>[],
      'navigationLogs': <Map<String, dynamic>>[],
      'notificationLogs': <Map<String, dynamic>>[],
      'appPerformance': <Map<String, dynamic>>[],
    };

    Future<void> collect(String name) async {
      await for (final doc in _collectionStream(name)) {
        final map = doc.data();
        map['id'] = doc.id;
        result[name]!.add(_normalizeForJson(map));
      }
    }

    await collect('searchLogs');
    await collect('navigationLogs');
    await collect('notificationLogs');
    await collect('appPerformance');

    final encoder = const JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(result);

    final file = await _createExportFile(extension: 'json');
    await file.writeAsString(jsonString, encoding: utf8);
    return file;
  }

  /// Returns a stream of documents for the given collection, paginated
  /// by timestamp to support large datasets.
  Stream<QueryDocumentSnapshot<Map<String, dynamic>>> _collectionStream(
    String collection,
  ) async* {
    const pageSize = 2000;
    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .orderBy('timestamp', descending: false)
        .limit(pageSize);

    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        yield doc;
      }

      lastDoc = snap.docs.last;
      query = _firestore
          .collection(collection)
          .orderBy('timestamp', descending: false)
          .startAfterDocument(lastDoc)
          .limit(pageSize);
    }
  }

  Future<int> _countCollection(String collection) async {
    try {
      final agg = await _firestore.collection(collection).count().get();
      return agg.count ?? 0;
    } catch (_) {
      // Fallback: approximate by reading first page
      final snap = await _firestore.collection(collection).limit(1000).get();
      return snap.size;
    }
  }

  Future<File> _createExportFile({required String extension}) async {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmm');
    final fileName = 'export_${formatter.format(now)}.$extension';

    Directory dir;
    if (Platform.isAndroid) {
      dir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File('${dir.path}/$fileName');
  }

  static String _csvEscape(String? value) {
    final v = value ?? '';
    final escaped = v.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static String _numString(Object? value) {
    if (value is num) return value.toString();
    return '';
  }

  static String _boolString(Object? value) {
    if (value is bool) return value ? 'true' : 'false';
    return '';
  }

  static String _timestampString(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    return '';
  }

  static String _geoPointString(Object? value) {
    if (value is GeoPoint) {
      return '${value.latitude},${value.longitude}';
    }
    return '';
  }

  static Map<String, dynamic> _normalizeForJson(Map<String, dynamic> map) {
    final normalized = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Timestamp) {
        normalized[key] = value.toDate().toIso8601String();
      } else if (value is GeoPoint) {
        normalized[key] = {
          'lat': value.latitude,
          'lng': value.longitude,
        };
      } else {
        normalized[key] = value;
      }
    });
    return normalized;
  }
}
