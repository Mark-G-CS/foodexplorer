import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// This screen takes the [cuisine] (e.g., "Burgers") from the slot machine,
/// determines the user’s location (or prompts for a zip code if location services
/// are unavailable), then searches Google Places for a nearby restaurant that matches
/// the cuisine. It finally displays the restaurant details and 3 action buttons.
class ResultScreen extends StatefulWidget {
  final String cuisine;
  const ResultScreen({super.key, required this.cuisine});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

/// Tracks the current search/loading state.
enum SearchState { loading, needZip, loaded, error }

/// Model to hold restaurant details.
class Restaurant {
  final String name;
  final double lat;
  final double lng;
  final String? photoReference;
  final double rating;
  final String placeId;
  final String address;

  Restaurant({
    required this.name,
    required this.lat,
    required this.lng,
    this.photoReference,
    required this.rating,
    required this.placeId,
    required this.address,
  });
}

class _ResultScreenState extends State<ResultScreen> {
  // Replace with your own Google API key.
  static const String googleApiKey = '';

  SearchState _state = SearchState.loading;
  Restaurant? _restaurant;
  Position? _userPosition;
  String? _errorMessage;
  final TextEditingController _zipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _determineLocationAndSearch();
  }

  /// Determines the user’s location either via location services or by using a zip code.
  Future<void> _determineLocationAndSearch({String? zipCode}) async {
    setState(() {
      _state = SearchState.loading;
    });
    try {
      Position position;
      if (zipCode == null) {
        // Try to get the current position.
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled.');
        }
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied.');
          }
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are permanently denied.');
        }
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } else {
        // If a zip code was entered, convert it to latitude/longitude using Google Geocoding.
        final geocodeUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?address=$zipCode&key=$googleApiKey');
        final geocodeResponse = await http.get(geocodeUrl);
        final geocodeJson = json.decode(geocodeResponse.body);
        if (geocodeJson['status'] != 'OK' || geocodeJson['results'].isEmpty) {
          throw Exception('Could not find location for the provided zip code.');
        }
        final location = geocodeJson['results'][0]['geometry']['location'];
        position = Position(
          latitude: location['lat'],
          longitude: location['lng'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
      _userPosition = position;
      // Now search for a restaurant near the user.
      await _searchRestaurant(position);
    } catch (e) {
      // If a location error occurs, prompt for a zip code.
      if (e.toString().contains('Location')) {
        setState(() {
          _state = SearchState.needZip;
          _errorMessage = e.toString();
        });
      } else {
        setState(() {
          _state = SearchState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }
  Widget _styledButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }


  /// Searches Google Places for restaurants matching [widget.cuisine] near [position].
  Future<void> _searchRestaurant(Position position) async {
    final lat = position.latitude;
    final lng = position.longitude;
    // 5 miles in meters (approx).
    final radius = 8047;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radius&type=restaurant&keyword=${Uri.encodeComponent(widget.cuisine)}&key=$googleApiKey');

    final response = await http.get(url);
    final data = json.decode(response.body);
    if (data['status'] != 'OK' || data['results'].isEmpty) {
      throw Exception('No results found for ${widget.cuisine} near you.');
    }

    // Sort the results by rating (top reviews first).
    List results = data['results'];
    results.sort((a, b) {
      double ratingA = a['rating'] != null ? a['rating'].toDouble() : 0.0;
      double ratingB = b['rating'] != null ? b['rating'].toDouble() : 0.0;
      return ratingB.compareTo(ratingA);
    });
    // From the top 10 results (or fewer if less are available), select one at random.
    final topResults = results.take(10).toList();
    final randomIndex = Random().nextInt(topResults.length);
    final chosen = topResults[randomIndex];

    final restaurant = Restaurant(
      name: chosen['name'] ?? 'Unknown',
      lat: chosen['geometry']['location']['lat'],
      lng: chosen['geometry']['location']['lng'],
      photoReference: (chosen['photos'] != null && chosen['photos'].isNotEmpty)
          ? chosen['photos'][0]['photo_reference']
          : null,
      rating: chosen['rating'] != null ? chosen['rating'].toDouble() : 0.0,
      placeId: chosen['place_id'] ?? '',
      address: chosen['vicinity'] ?? '',


    );

    setState(() {
      _restaurant = restaurant;
      _state = SearchState.loaded;
    });
  }
  Future<void> _recordResult(String result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'history': FieldValue.arrayUnion([result]),

      });
      print("RECORDING RESULT!");
    }


  }

  /// Constructs the URL to fetch a photo from the Google Places Photo API.
  String _getPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$googleApiKey';
  }

  /// Computes the distance in miles between the user and the restaurant.
  double _calculateDistance(double lat, double lng) {
    if (_userPosition == null) return 0.0;
    double distanceInMeters = Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude, lat, lng);
    return distanceInMeters / 1609.34;
  }

  /// Launches a URL using the url_launcher package.
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (_state) {
      case SearchState.loading:
        content = Center(child: CircularProgressIndicator());
        break;
      case SearchState.needZip:
        content = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Location not available. Please enter your zip code:'),
              SizedBox(height: 16),
              TextField(
                controller: _zipController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Zip Code',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  String zip = _zipController.text.trim();
                  if (zip.isNotEmpty) {
                    _determineLocationAndSearch(zipCode: zip);
                  }
                },
                child: Text('Submit'),
              )
            ],
          ),
        );
        break;
      case SearchState.error:
        content = Center(child: Text(_errorMessage ?? 'An error occurred.'));
        break;
      case SearchState.loaded:
        if (_restaurant == null) {
          content = Center(child: Text('No restaurant found.'));
        } else {
          final distance = _calculateDistance(_restaurant!.lat, _restaurant!.lng);
          final photoUrl = (_restaurant!.photoReference != null)
              ? _getPhotoUrl(_restaurant!.photoReference!)
              : null;

          content = SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),

              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _restaurant!.name,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _restaurant!.address,
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Approximately ${distance.toStringAsFixed(1)} miles away',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 16),
                        if (photoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(photoUrl),
                          )
                        else
                          Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: Center(child: Text('No photo available')),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _styledButton("Spin Again", () => Navigator.pop(context)),
                      _styledButton("Reviews", () {
                        final url = 'https://search.google.com/local/reviews?placeid=${_restaurant!.placeId}';
                        _launchUrl(url);
                      }),
                      _styledButton("Navigate", () {
                        final url = 'https://www.google.com/maps/dir/?api=1&destination=${_restaurant!.address}';
                        _launchUrl(url);
                      }),
                    ],
                  ),
                ],
              )

            ),
          );
        }
        _recordResult(_restaurant!.name);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.cuisine} Near Me',
          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: Colors.deepPurple),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(child: content),
      ),
    );

  }
}
