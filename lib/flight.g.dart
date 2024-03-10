// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlightAdapter extends TypeAdapter<Flight> {
  @override
  final int typeId = 0;

  @override
  Flight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Flight(
      origin: fields[0] as String,
      destination: fields[1] as String,
      airline: fields[2] as String,
      availableSeats: fields[3] as double,
      connections: fields[4] as int,
      ticketPrice: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Flight obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.origin)
      ..writeByte(1)
      ..write(obj.destination)
      ..writeByte(2)
      ..write(obj.airline)
      ..writeByte(3)
      ..write(obj.availableSeats)
      ..writeByte(4)
      ..write(obj.connections)
      ..writeByte(5)
      ..write(obj.ticketPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
