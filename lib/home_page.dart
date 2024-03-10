// homepage.dart
import 'dart:convert';

import 'package:flight_app/constants.dart';
import 'package:flight_app/flight_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'flight.dart';
import 'package:http/http.dart' as http;

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> cities = [];
  String? _selectedSourceCity;
  String? _selectedDestinationCity;
  List<Flight> _flights = [];
  String _selectedCurrency = 'usd';
  String accessToken = '';
  Map<String, double> conversionRates = {};
  double? destinationLat = 0.0;
  double? destinationLng = 0.0;

  // Define the currency map
  final Map<String, String> currencyMap = {
    "usd": "US Dollar",
    "eur": "Euro",
    "gbp": "British Pound",
    "inr": "Indian Rupee",
    // Add more currencies as needed
  };

  String _directions = '';
  bool _isLoadingDirections = false; // Flag to track if directions are loading

  @override
  void initState() {
    super.initState();
    _initHive();
    _initializeAccessToken(); // Call a new method to initialize access token
    _fetchConversionRates();
  }

  Future<void> _initializeAccessToken() async {
    try {
      accessToken = await _generateAccessToken(); // Await for the access token
    } catch (e) {
      print('Error initializing access token: $e');
    }
  }

  Future<void> getDirections(double sourceLat, double sourceLng,
      double destinationLat, double destinationLng) async {
    try {
      accessToken = await _generateAccessToken(); // Update accessToken

      var aPIKey = Constants.mapQuestAPI;
      var url =
          "https://www.mapquestapi.com/directions/v2/optimizedroute?key=$aPIKey&json={\"locations\":[\"${sourceLat},${sourceLng}\",\"${destinationLat},${destinationLng}\"]}";

      var uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('route') && data['route'].containsKey('legs')) {
          var route = data["route"];
          var legs = route["legs"];
          var zero = legs[0];
          var maneuvers = zero["maneuvers"] as List;

          // Create a string to store directions
          String directions = '';

          for (var element in maneuvers) {
            var narrative = element["narrative"];
            directions += '$narrative\n';
          }

          // Update the directions state variable
          setState(() {
            _directions = directions;
          });
        } else {
          throw Exception('Invalid response format: ${response.body}');
        }
      } else {
        throw Exception('Failed to load directions: ${response.statusCode}');
      }
    } catch (e) {
      print("Exception thrown: $e");
      throw e;
    } finally {
      setState(() {
        _isLoadingDirections =
            false; // Set loading flag to false regardless of success or failure
      });
    }
  }

  Future<void> _fetchConversionRates() async {
    try {
      final response = await http.get(Uri.parse(
          'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@2024-03-02/v1/currencies/usd.min.json'));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        Map<String, double> newConversionRates = {};
        // print(data['usd']);
        data['usd'].forEach((key, value) {
          // Check if the currency exists in the currencyMap and if the value is a double
          if (currencyMap.containsKey(key) && value is double) {
            newConversionRates[key] = value;
          }
        });

        // Assign the new conversion rates to the conversionRates map
        setState(() {
          conversionRates = newConversionRates;
        });

        print(conversionRates); // Print the updated conversion rates
      } else {
        throw Exception('Failed to fetch conversion rates');
      }
    } catch (e) {
      print('Error fetching conversion rates: $e');
    }
  }

  double convertPrice(double price, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return price;
    print(fromCurrency);
    // Check if conversion rates are available for both currencies
    if (!conversionRates.containsKey(toCurrency) ||
        !conversionRates.containsKey(fromCurrency)) {
      // Handle the case where conversion rates are not available
      // For example, throw an exception or log an error message
      // Throwing an exception:
      throw Exception(
          'Conversion rates not available for $fromCurrency to $toCurrency');

      // Or, logging an error message and returning the original price:
      // print('Error: Conversion rates not available for $fromCurrency to $toCurrency');
      // return price;
    }

    double rate = conversionRates[toCurrency]! / conversionRates[fromCurrency]!;
    return price * rate;
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    Hive.registerAdapter(FlightAdapter());
    var box = await Hive.openBox<Flight>('flights');
    if (box.isEmpty) {
      await _loadFlightData();
    } else {
      _loadFlightsFromHive(box);
    }
  }

  Future<void> _loadFlightData() async {
    final String jsonString =
        await rootBundle.loadString('assets/flight_data.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    var box = await Hive.openBox<Flight>('flights');
    for (var jsonFlight in jsonList) {
      Flight flight = Flight(
        origin: jsonFlight['origin'],
        destination: jsonFlight['destination'],
        airline: jsonFlight['airline'],
        availableSeats: jsonFlight['available_seats'],
        connections: jsonFlight['connections'],
        ticketPrice: jsonFlight['ticket_price'].toDouble(),
      );
      await box.add(flight);
    }
    _loadFlightsFromHive(box);
  }

  void _loadFlightsFromHive(Box<Flight> box) {
    _flights = box.values.toList();
    for (var flight in _flights) {
      cities.add(flight.origin);
      cities.add(flight.destination);
    }
    cities = cities.toSet().toList();
    cities.sort();
    setState(() {});
  }

  List<String> getDestinationCities() {
    if (_selectedSourceCity == null) return [];
    return _flights
        .where((flight) => flight.origin == _selectedSourceCity)
        .map((flight) => flight.destination)
        .toList();
  }

  Future<String> _generateAccessToken() async {
    try {
      String clientId = Constants.apiKey;
      String clientSecret = Constants.apiSecret;

      final response = await http.post(
        Uri.parse("https://test.api.amadeus.com/v1/security/oauth2/token"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body:
            "grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret",
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        return data['access_token'];
      } else {
        throw Exception('Failed to generate access token');
      }
    } catch (e) {
      print('Error generating access token: $e');
      throw e;
    }
  }

  void bookFlight(Flight flight) async {
    try {
      if (accessToken.isNotEmpty) {
        setState(() {
          flight.availableSeats -= 1;
        });

        await flight.save(); // Save updated flight data

        // Update flight data in the Hive database
        var flightBox = await Hive.openBox<Flight>('flights');
        int index = flightBox.values
            .toList()
            .indexWhere((element) => element == flight);
        if (index != -1) {
          await flightBox.putAt(index, flight);
        }

        // Show snack bar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Flight booked from ${flight.origin} to ${flight.destination}'),
          ),
        );

        // Delay the navigation to allow time for the snack bar to be dismissed
        await Future.delayed(const Duration(seconds: 1));

        // Get the coordinates for the selected destination city
        var destinationCoordinates = await getCoordinates(flight.destination);
        double? destinationLat = destinationCoordinates['lat'];
        double? destinationLng = destinationCoordinates['lng'];
        print("Destination Coordinates: $destinationLat, $destinationLng");
        // Navigate to the flight details page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlightDetails(
              origin: flight.origin,
              destination: flight.destination,
              ticketPrice: flight.ticketPrice,
              accessToken: accessToken,
              currency: _selectedCurrency,
              destinationLat: destinationLat,
              destinationLng: destinationLng,
            ),
          ),
        );
      } else {
        throw Exception('Access token not available');
      }
    } catch (e) {
      print('Error booking flight: $e');
    }
  }

  Future<Map<String, double>> getCoordinates(String location) async {
    try {
      String accessToken =
          await _generateAccessToken(); // Get fresh access token
      var response = await http.get(Uri.parse(
          'https://api.opencagedata.com/geocode/v1/json?q=${location}&key=${Constants.geoCodeApi}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final lat = data['results'][0]['geometry']['lat'] as double;
          final lng = data['results'][0]['geometry']['lng'] as double;
          return {'lat': lat, 'lng': lng};
        } else {
          throw Exception('No results found for the destination');
        }
      } else {
        throw Exception('Failed to load coordinates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching coordinates: $e');
      throw e;
    }
  }

  List<Widget> _buildDirectionCards() {
    List<Widget> directionCards = [];
    List<String> directionsList = _directions.split('\n');

    for (int i = 0; i < directionsList.length; i++) {
      String direction = directionsList[i].trim();
      if (direction.isNotEmpty) {
        directionCards.add(
          Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '$i. $direction',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }
    }

    return directionCards;
  }

  @override
  Widget build(BuildContext context) {
    List<String> destinationCities = getDestinationCities();

    List<Flight> filteredFlights = _flights.where((flight) {
      if (_selectedSourceCity != null && _selectedDestinationCity != null) {
        return flight.origin == _selectedSourceCity &&
            flight.destination == _selectedDestinationCity;
      }
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Booking App'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: _selectedCurrency,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCurrency = newValue!;
                });
              },
              items: currencyMap.keys
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value:
                      value, // This value should match the keys in currencyMap exactly
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        currencyMap[value]!, // Use the full name from the map
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _selectedSourceCity,
                items: cities.map((String city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSourceCity = newValue;
                    _selectedDestinationCity = null;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Source City',
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedDestinationCity,
                items: destinationCities.map((String city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDestinationCity = newValue;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Destination City',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_selectedSourceCity != null &&
                      _selectedDestinationCity != null) {
                    try {
                      // Generate access token
                      await _generateAccessToken();

                      if (accessToken.isNotEmpty) {
                        // Get the coordinates for the selected source city
                        var sourceCoordinates =
                            await getCoordinates(_selectedSourceCity!);
                        double? sourceLat = sourceCoordinates['lat'];
                        double? sourceLng = sourceCoordinates['lng'];

                        // Get the coordinates for the selected destination city
                        var destinationCoordinates =
                            await getCoordinates(_selectedDestinationCity!);
                        destinationLat = destinationCoordinates['lat'];
                        destinationLng = destinationCoordinates['lng'];

                        setState(() {
                          _isLoadingDirections =
                              true; // Set loading flag to true
                        });

                        // Call the method to fetch directions
                        await getDirections(sourceLat!, sourceLng!,
                            destinationLat!, destinationLng!);
                      } else {
                        print('Access token not available');
                      }
                    } catch (error) {
                      print('Error: $error');
                    }
                  }
                },
                child: Text(_isLoadingDirections
                    ? 'Fetching Directions...'
                    : 'Get Directions'),
              ),

              // Display the directions or the loading indicator
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: _isLoadingDirections
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          children: _directions.isNotEmpty
                              ? _buildDirectionCards()
                              : [
                                  const SizedBox(height: 20),
                                  const Text(
                                      'Directions will be displayed here'),
                                ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (filteredFlights.isNotEmpty)
                    Column(
                      children: filteredFlights.map((flight) {
                        double convertedPrice = convertPrice(
                            flight.ticketPrice, 'usd', _selectedCurrency);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Airline: ${flight.airline}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('Available Seats: ${flight.availableSeats}'),
                            Text('Connections: ${flight.connections}'),
                            Text(
                              'Ticket Price: $_selectedCurrency ${convertedPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                bookFlight(flight);
                              },
                              child: const Text('Book Flight'),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }).toList(),
                    ),
                  if (filteredFlights.isEmpty &&
                      _selectedSourceCity != null &&
                      _selectedDestinationCity != null)
                    const Text('No flights available for the selected route'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
