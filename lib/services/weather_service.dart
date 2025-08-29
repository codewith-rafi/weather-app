import 'dart:convert'; // For JSON encoding/decoding

import 'package:geolocator/geolocator.dart'; // For getting device location
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:logger/logger.dart'; // For logging info, errors, etc.

// Service class to fetch weather data
class WeatherService {
  final String apiKey = '9325ebe140c7bae1674be5d8c5535b01'; // Free plan API key
  final String forecastUrl = 'https://api.openweathermap.org/data/2.5/forecast'; // OpenWeatherMap 2.5 API URL
  final Logger _logger = Logger(); // Logger instance

  // Fetch weather data based on current device location
  Future<Map<String, dynamic>> fetchWeatherByLocation() async {
    try {
      final position = await _determinePosition(); // Get current position

      // Build API request URL with coordinates and API key
      final url = Uri.parse(
        '$forecastUrl?lat=${position.latitude}&lon=${position.longitude}&units=metric&appid=$apiKey',
      );

      _logger.i('Fetching weather from URL: $url'); // Log request URL

      final response = await http.get(url).timeout(const Duration(seconds: 15)); // Send GET request with timeout
      _logger.i('Response status: ${response.statusCode}'); // Log status code

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>; // Decode JSON response
        if (data.isEmpty) throw Exception('Weather data is empty'); // Handle empty data
        return data; // Return weather data
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key or unauthorized request'); // Handle invalid API key
      } else {
        throw Exception('Weather API error: ${response.statusCode}'); // Handle other API errors
      }
    } catch (e, stackTrace) {
      _logger.e('Error in fetchWeatherByLocation', error: e, stackTrace: stackTrace); // Log errors
      rethrow; // Rethrow exception for caller
    }
  }

  // Determine device's current position with permissions
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled(); // Check if location service is enabled
    if (!serviceEnabled) throw Exception('Location services are disabled.'); // Throw if not enabled

    LocationPermission permission = await Geolocator.checkPermission(); // Check current permission
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission(); // Request permission if denied
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.'); // Throw if still denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.'); // Throw if permanently denied
    }

    // Get current position with high accuracy
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // High accuracy location
        distanceFilter: 0, // Get updates for any movement
      ),
    );
  }
}
