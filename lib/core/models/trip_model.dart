import 'package:cloud_firestore/cloud_firestore.dart';

/// Trip model class representing travel information
/// This model captures all the required trip details as specified in the requirements
class TripModel {
  final String? id;
  final String tripNumber;
  final String origin;
  final DateTime time;
  final String mode;
  final String destination;
  final List<String> activities;
  final List<TravellerInfo> accompanyingTravellers;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripModel({
    this.id,
    required this.tripNumber,
    required this.origin,
    required this.time,
    required this.mode,
    required this.destination,
    required this.activities,
    required this.accompanyingTravellers,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert TripModel to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'tripNumber': tripNumber,
      'origin': origin,
      'time': Timestamp.fromDate(time),
      'mode': mode,
      'destination': destination,
      'activities': activities,
      'accompanyingTravellers': accompanyingTravellers
          .map((t) => t.toMap())
          .toList(),
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create TripModel from Firestore document
  factory TripModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TripModel(
      id: documentId,
      tripNumber: map['tripNumber'] ?? '',
      origin: map['origin'] ?? '',
      time: (map['time'] as Timestamp).toDate(),
      mode: map['mode'] ?? '',
      destination: map['destination'] ?? '',
      activities: List<String>.from(map['activities'] ?? []),
      accompanyingTravellers:
          (map['accompanyingTravellers'] as List<dynamic>?)
              ?.map((t) => TravellerInfo.fromMap(t))
              .toList() ??
          [],
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Create a copy of TripModel with updated fields
  TripModel copyWith({
    String? id,
    String? tripNumber,
    String? origin,
    DateTime? time,
    String? mode,
    String? destination,
    List<String>? activities,
    List<TravellerInfo>? accompanyingTravellers,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripModel(
      id: id ?? this.id,
      tripNumber: tripNumber ?? this.tripNumber,
      origin: origin ?? this.origin,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      destination: destination ?? this.destination,
      activities: activities ?? this.activities,
      accompanyingTravellers:
          accompanyingTravellers ?? this.accompanyingTravellers,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TripModel(id: $id, tripNumber: $tripNumber, origin: $origin, time: $time, mode: $mode, destination: $destination, activities: $activities, accompanyingTravellers: $accompanyingTravellers, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripModel &&
        other.id == id &&
        other.tripNumber == tripNumber &&
        other.origin == origin &&
        other.time == time &&
        other.mode == mode &&
        other.destination == destination &&
        other.activities == activities &&
        other.accompanyingTravellers == accompanyingTravellers &&
        other.userId == userId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        tripNumber.hashCode ^
        origin.hashCode ^
        time.hashCode ^
        mode.hashCode ^
        destination.hashCode ^
        activities.hashCode ^
        accompanyingTravellers.hashCode ^
        userId.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

/// TravellerInfo model for accompanying travellers
class TravellerInfo {
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? relationship;
  final int age;

  TravellerInfo({
    required this.name,
    this.phoneNumber,
    this.email,
    this.relationship,
    required this.age,
  });

  /// Convert TravellerInfo to Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
      'age': age,
    };
  }

  /// Create TravellerInfo from Map
  factory TravellerInfo.fromMap(Map<String, dynamic> map) {
    return TravellerInfo(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      relationship: map['relationship'],
      age: map['age'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'TravellerInfo(name: $name, phoneNumber: $phoneNumber, email: $email, relationship: $relationship, age: $age)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TravellerInfo &&
        other.name == name &&
        other.phoneNumber == phoneNumber &&
        other.email == email &&
        other.relationship == relationship &&
        other.age == age;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        phoneNumber.hashCode ^
        email.hashCode ^
        relationship.hashCode ^
        age.hashCode;
  }
}
