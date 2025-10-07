import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'place_model.dart';

/// Hive adapter for PlaceModel
class PlaceModelAdapter extends TypeAdapter<PlaceModel> {
  @override
  final int typeId = 3;

  @override
  PlaceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return PlaceModel(
      placeId: fields[0] as String,
      name: fields[1] as String,
      address: fields[2] as String,
      location: fields[3] as LatLng,
      types: fields[4] != null ? (fields[4] as List).cast<String>() : null,
      rating: fields[5] as double?,
      photoReference: fields[6] as String?,
      icon: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlaceModel obj) {
    writer
      ..writeByte(8) // Number of fields
      ..writeByte(0)
      ..write(obj.placeId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.types)
      ..writeByte(5)
      ..write(obj.rating)
      ..writeByte(6)
      ..write(obj.photoReference)
      ..writeByte(7)
      ..write(obj.icon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
