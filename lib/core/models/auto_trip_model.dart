import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a location point with timestamp during trip tracking
class LocationPoint {
  final LatLng coordinates;
  final DateTime timestamp;
  final double speed; // in m/s
  final double accuracy; // in meters

  LocationPoint({
    required this.coordinates,
    required this.timestamp,
    required this.speed,
    required this.accuracy,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'speed': speed,
      'accuracy': accuracy,
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      coordinates: LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      speed: map['speed'] as double,
      accuracy: map['accuracy'] as double,
    );
  }
}

/// Status of an automatically detected trip
enum AutoTripStatus {
  detecting, // Trip is being detected in real-time
  detected, // Trip has been detected and ended
  confirmed, // User has confirmed the trip details
  rejected, // User rejected the detected trip
}

/// Model for automatically detected trips
class AutoTripModel {
  final String? id;
  final String userId;
  
  // Trip detection data
  final LocationPoint origin;
  final LocationPoint? destination;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceCovered; // in meters
  final double averageSpeed; // in m/s
  final double maxSpeed; // in m/s
  final List<LocationPoint> routePoints;
  // Human-readable addresses
  final String? originAddress;
  final String? destinationAddress;
  
  // Trip status
  final AutoTripStatus status;
  
  // User-provided data (filled after confirmation)
  final String? purpose;
  final String? detectedMode; // Auto-detected mode based on speed
  final String? confirmedMode; // User-confirmed mode
  final List<String>? companions;
  final double? cost;
  final String? notes;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  AutoTripModel({
    this.id,
    required this.userId,
    required this.origin,
    this.destination,
    required this.startTime,
    this.endTime,
    required this.distanceCovered,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.routePoints,
    required this.status,
    this.purpose,
    this.detectedMode,
    this.confirmedMode,
    this.companions,
    this.cost,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.originAddress,
    this.destinationAddress,
  });

  /// Calculate trip duration in minutes
  int get durationMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  /// Get distance in kilometers
  double get distanceKm => distanceCovered / 1000;

  /// Get average speed in km/h
  double get averageSpeedKmh => averageSpeed * 3.6;

  /// Get max speed in km/h
  double get maxSpeedKmh => maxSpeed * 3.6;

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'origin': origin.toMap(),
      'destination': destination?.toMap(),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'distanceCovered': distanceCovered,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'routePoints': routePoints.map((p) => p.toMap()).toList(),
      'status': status.toString().split('.').last,
      'purpose': purpose,
      'detectedMode': detectedMode,
      'confirmedMode': confirmedMode,
      'companions': companions,
      'cost': cost,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'originAddress': originAddress,
      'destinationAddress': destinationAddress,
    };
  }

  /// Create from Firestore document
  factory AutoTripModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AutoTripModel(
      id: documentId,
      userId: map['userId'] as String,
      origin: LocationPoint.fromMap(map['origin'] as Map<String, dynamic>),
      destination: map['destination'] != null
          ? LocationPoint.fromMap(map['destination'] as Map<String, dynamic>)
          : null,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      distanceCovered: (map['distanceCovered'] as num).toDouble(),
      averageSpeed: (map['averageSpeed'] as num).toDouble(),
      maxSpeed: (map['maxSpeed'] as num).toDouble(),
      routePoints: (map['routePoints'] as List<dynamic>)
          .map((p) => LocationPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      status: AutoTripStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => AutoTripStatus.detecting,
      ),
      purpose: map['purpose'] as String?,
      detectedMode: map['detectedMode'] as String?,
      confirmedMode: map['confirmedMode'] as String?,
      companions: map['companions'] != null
          ? List<String>.from(map['companions'] as List)
          : null,
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      originAddress: map['originAddress'] as String?,
      destinationAddress: map['destinationAddress'] as String?,
    );
  }

  /// Create a copy with updated fields
  AutoTripModel copyWith({
    String? id,
    String? userId,
    LocationPoint? origin,
    LocationPoint? destination,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceCovered,
    double? averageSpeed,
    double? maxSpeed,
    List<LocationPoint>? routePoints,
    AutoTripStatus? status,
    String? purpose,
    String? detectedMode,
    String? confirmedMode,
    List<String>? companions,
    double? cost,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? originAddress,
    String? destinationAddress,
  }) {
    return AutoTripModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceCovered: distanceCovered ?? this.distanceCovered,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      routePoints: routePoints ?? this.routePoints,
      status: status ?? this.status,
      purpose: purpose ?? this.purpose,
      detectedMode: detectedMode ?? this.detectedMode,
      confirmedMode: confirmedMode ?? this.confirmedMode,
      companions: companions ?? this.companions,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
    );
  }

  @override
  String toString() {
    return 'AutoTripModel(id: $id, userId: $userId, startTime: $startTime, endTime: $endTime, distance: ${distanceKm.toStringAsFixed(2)}km, status: $status)';
  }
}
