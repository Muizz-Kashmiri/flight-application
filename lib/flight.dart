import 'package:hive/hive.dart';

part 'flight.g.dart'; // Generated part file

@HiveType(typeId: 0)
class Flight extends HiveObject {
  @HiveField(0)
  String origin;

  @HiveField(1)
  String destination;

  @HiveField(2)
  String airline;

  @HiveField(3)
  double availableSeats;

  @HiveField(4)
  int connections;

  @HiveField(5)
  double ticketPrice;

  Flight({
    required this.origin,
    required this.destination,
    required this.airline,
    required this.availableSeats,
    required this.connections,
    required this.ticketPrice,
  });
}
