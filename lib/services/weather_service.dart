import 'dart:convert'; // For JSON encoding/decoding
import 'dart:async';

import 'package:geolocator/geolocator.dart'; // For getting device location
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:logger/logger.dart'; // For logging info, errors, etc.

// Service class to fetch weather data
class WeatherService {
  // NOTE: For local development it's OK to keep the free API key here.
  // For production consider moving this to secure storage or build-time config.
  final String apiKey = '848efbeab951e650f1342b370588d3f9'; // Free plan API key

  // OpenWeatherMap 2.5 endpoints (free tier)
  final String _forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';
  final String _currentUrl = 'https://api.openweathermap.org/data/2.5/weather';

  final Logger _logger = Logger(); // Logger instance

  // Simple in-memory cache to avoid hitting rate limits during short periods.
  // Keyed by '<lat>,<lon>,<type>' where type is 'current' or 'forecast'.
  final Map<String, _CachedWeather> _cache = {};
  final Duration cacheTtl = const Duration(minutes: 10);

  /// Fetch forecast (3-hourly) data using the 2.5 `/forecast` endpoint.
  Future<Map<String, dynamic>> fetchForecastByLocation() async {
    try {
      final position = await _determinePosition(); // Get current position
      return await fetchForecast(position.latitude, position.longitude);
    } catch (e, stackTrace) {
      _logger.e(
        'Error in fetchForecastByLocation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Fetch current weather using the 2.5 `/weather` endpoint.
  Future<Map<String, dynamic>> fetchCurrentWeatherByLocation() async {
    try {
      final position = await _determinePosition();
      return await fetchCurrentWeather(position.latitude, position.longitude);
    } catch (e, stackTrace) {
      _logger.e(
        'Error in fetchCurrentWeatherByLocation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Fetch forecast for given coordinates. Uses caching.
  Future<Map<String, dynamic>> fetchForecast(double lat, double lon) async {
    final key = '\$lat,\$lon,forecast';
    final now = DateTime.now();
    if (_cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (now.difference(cached.timestamp) <= cacheTtl) {
        _logger.i('Returning cached forecast for $lat,$lon');
        return cached.data;
      }
    }

    final url = Uri.parse(
      '$_forecastUrl?lat=$lat&lon=$lon&units=metric&appid=$apiKey',
    );
    _logger.i('Fetching forecast from URL: $url');

    final response = await http.get(url).timeout(const Duration(seconds: 15));
    _logger.i('Forecast response status: \\${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) throw Exception('Forecast data is empty');
      _cache[key] = _CachedWeather(data, now);
      return data;
    } else if (response.statusCode == 401) {
      throw Exception('Invalid API key or unauthorized request');
    } else {
      throw Exception('Weather API error: \\${response.statusCode}');
    }
  }

  /// Fetch current weather for given coordinates. Uses caching.
  Future<Map<String, dynamic>> fetchCurrentWeather(
    double lat,
    double lon,
  ) async {
    final key = '\$lat,\$lon,current';
    final now = DateTime.now();
    if (_cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (now.difference(cached.timestamp) <= cacheTtl) {
        _logger.i('Returning cached current weather for $lat,$lon');
        return cached.data;
      }
    }

    final url = Uri.parse(
      '$_currentUrl?lat=$lat&lon=$lon&units=metric&appid=$apiKey',
    );
    _logger.i('Fetching current weather from URL: $url');

    final response = await http.get(url).timeout(const Duration(seconds: 15));
    _logger.i('Current weather response status: \\${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) throw Exception('Current weather data is empty');
      _cache[key] = _CachedWeather(data, now);
      return data;
    } else if (response.statusCode == 401) {
      throw Exception('Invalid API key or unauthorized request');
    } else {
      throw Exception('Weather API error: \\${response.statusCode}');
    }
  }

  /// Map weather data (current or forecast item) to a short advice message.
  /// Accepts the JSON structure returned by the 2.5 endpoints.
  String mapWeatherToAdvice(Map<String, dynamic> weatherJson) {
    try {
      double? tempC;
      double windSpeed = 0.0;
      int clouds = 0;
      bool precipitation = false;

      // Current weather structure: main.temp, wind.speed, clouds.all, weather[0].main
      if (weatherJson.containsKey('main')) {
        final main = weatherJson['main'] as Map<String, dynamic>;
        tempC = (main['temp'] as num?)?.toDouble();
      }
      if (weatherJson.containsKey('wind')) {
        final wind = weatherJson['wind'] as Map<String, dynamic>;
        windSpeed = (wind['speed'] as num?)?.toDouble() ?? 0.0;
      }
      if (weatherJson.containsKey('clouds')) {
        final c = weatherJson['clouds'] as Map<String, dynamic>;
        clouds = (c['all'] as num?)?.toInt() ?? 0;
      }

      // Check for precipitation fields (current may include 'rain' or 'snow')
      if (weatherJson.containsKey('rain') || weatherJson.containsKey('snow')) {
        precipitation = true;
      }

      // Some forecast items include 'pop' (probability of precipitation)
      if (weatherJson.containsKey('pop')) {
        final pop = (weatherJson['pop'] as num?)?.toDouble() ?? 0.0;
        if (pop >= 0.25) precipitation = true;
      }

      // Also check weather[0].main for keywords
      String? mainCondition;
      if (weatherJson.containsKey('weather')) {
        final w = weatherJson['weather'] as List<dynamic>;
        if (w.isNotEmpty)
          mainCondition = (w[0] as Map<String, dynamic>)['main'] as String?;
      }

      // Build advice
      final adviceParts = <String>[];
      if (precipitation ||
          (mainCondition != null &&
              (mainCondition.toLowerCase().contains('rain') ||
                  mainCondition.toLowerCase().contains('snow')))) {
        adviceParts.add('Rain expected — don\'t forget your umbrella!');
      }

      if (tempC != null) {
        if (tempC <= 5) {
          adviceParts.add('It\'s very cold — wear a heavy jacket!');
        } else if (tempC <= 15) {
          adviceParts.add('It\'s chilly — take a jacket.');
        } else if (tempC >= 30) {
          adviceParts.add('Hot today — drink water and stay cool!');
        }
      }

      if (windSpeed > 10) {
        adviceParts.add('Windy conditions — secure loose items.');
      }

      if (adviceParts.isEmpty) {
        if (clouds >= 60) return 'Cloudy — you might want a light layer.';
        return 'Looks good — have a nice day!';
      }

      // Join up to 2 pieces to keep notification concise
      return adviceParts.take(2).join(' ');
    } catch (e, st) {
      _logger.e('Error in mapWeatherToAdvice', error: e, stackTrace: st);
      return 'Check the weather for details.';
    }
  }

  // Determine device's current position with permissions
  Future<Position> _determinePosition() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled(); // Check if location service is enabled
    if (!serviceEnabled)
      throw Exception(
        'Location services are disabled.',
      ); // Throw if not enabled

    LocationPermission permission =
        await Geolocator.checkPermission(); // Check current permission
    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission(); // Request permission if denied
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permissions are denied.',
        ); // Throw if still denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied.',
      ); // Throw if permanently denied
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

// Simple container for cached weather data
class _CachedWeather {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  _CachedWeather(this.data, this.timestamp);
}
