import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';

/// Hive adapter for LatLng
class LatLngAdapter extends TypeAdapter<LatLng> {
  @override
  final int typeId = 4;

  @override
  LatLng read(BinaryReader reader) {
    final latitude = reader.readDouble();
    final longitude = reader.readDouble();
    return LatLng(latitude, longitude);
  }

  @override
  void write(BinaryWriter writer, LatLng obj) {
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLngAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
