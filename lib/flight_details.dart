// flight_details.dart
import 'dart:convert';
import 'package:flight_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FlightDetails extends StatefulWidget {
  final String origin;
  final String destination;
  final double ticketPrice;
  final String accessToken;
  final String currency;
  final double? destinationLat;
  final double? destinationLng;

  const FlightDetails({
    Key? key,
    required this.origin,
    required this.destination,
    required this.ticketPrice,
    required this.accessToken,
    required this.currency,
    required this.destinationLat,
    required this.destinationLng,
  }) : super(key: key);

  @override
  State<FlightDetails> createState() => _FlightDetailsState();
}

class _FlightDetailsState extends State<FlightDetails> {
  List<String> attractions = [];
  bool isLoading = true;
  int availableSeats = 10;
  late String myAccessToken; // Changed to non-nullable

  @override
  void initState() {
    super.initState();
    _generateAccessToken().then((token) {
      myAccessToken = token;
      getAttractions(
          widget.destinationLat, widget.destinationLng, myAccessToken);
    }).catchError((error) {
      print('Error initializing flight details: $error');
    });
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

  Future<void> getAttractions(
      double? lat, double? lng, String accessToken) async {
    try {
      // Adjust the radius parameter to 5 kilometers
      String apiUrl =
          'https://test.api.amadeus.com/v1/reference-data/locations/pois?latitude=${lat}&longitude=${lng}&radius=5&page%5Blimit%5D=10&page%5Boffset%5D=0';

      print('Request URL: $apiUrl'); // Debugging line
      print('Access Token: $accessToken'); // Debugging line

      final response = await http.get(Uri.parse(apiUrl), headers: {
        'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          attractions = List<String>.from(data['data'].map((attraction) {
            return attraction['name'];
          }));

          isLoading = false;
        });
      } else {
        print('Failed to load attractions: Status Code ${response.statusCode}');
        print(
            'Response Body: ${response.body}'); // This can provide more details about the error
        throw Exception('Failed to load attractions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading attractions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Attractions in ${widget.destination}'),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : attractions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Fetching attractions...'),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Origin: ${widget.origin}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Destination: ${widget.destination}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Ticket Price: ${widget.currency} ${widget.ticketPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Available Seats: $availableSeats',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: attractions.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 10),
                              child: ListTile(
                                title: Text(attractions[index]),
                                leading: const Icon(Icons.place),
                              ),
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
