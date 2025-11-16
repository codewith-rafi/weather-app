import 'package:flutter/material.dart'; // Flutter UI toolkit
import 'package:intl/intl.dart'; // For date and time formatting
import 'package:weather_app/services/weather_service.dart'; // Weather API service
import 'package:weather_app/info/information.dart'; // Widget for additional info display
import 'package:weather_app/forecast/hourly_forecast.dart'; // Widget for hourly forecast cards
import 'package:weather_app/forecast/weekly_forecast.dart'; // Widget for weekly forecast cards
import 'package:weather_app/screen/event_list.dart';
import 'package:weather_app/services/notification_service.dart';
import 'package:weather_app/models/event.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Main screen for weather app
class WeatherScreen extends StatefulWidget {
  final VoidCallback toggleTheme; // Callback to toggle dark/light theme

  const WeatherScreen({super.key, required this.toggleTheme});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService =
      WeatherService(); // Instance of weather service
  late Future<Map<String, dynamic>>
  _weatherFuture; // Future for async weather data

  @override
  void initState() {
    super.initState();
    _weatherFuture = _weatherService
        .fetchForecastByLocation(); // Fetch forecast on init
    // Initialize notifications and listen for taps (payload is event id)
    NotificationService().init();
    NotificationService().onNotification.listen((payload) async {
      if (payload == null) return;
      try {
        final id = int.parse(payload);
        final box = Hive.box<Event>('events');
        final event = box.get(id);
        Map<String, dynamic> weatherJson;
        if (event != null &&
            event.latitude != null &&
            event.longitude != null) {
          weatherJson = await _weatherService.fetchCurrentWeather(
            event.latitude!,
            event.longitude!,
          );
        } else {
          weatherJson = await _weatherService.fetchCurrentWeatherByLocation();
        }
        final advice = _weatherService.mapWeatherToAdvice(weatherJson);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Weather advice'),
            content: Text(advice),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        // ignore errors
      }
    });
  }

  // Refresh weather manually
  void _refreshWeather() {
    setState(() {
      _weatherFuture = _weatherService.fetchForecastByLocation();
    });
  }

  // Map weather conditions to icons
  IconData getWeatherIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'snow':
        return Icons.ac_unit;
      case 'thunderstorm':
        return Icons.flash_on;
      default:
        return Icons.wb_sunny;
    }
  }

  // Format hour from date string
  String formatHour(String dtTxt) {
    final dt = DateTime.parse(dtTxt);
    return '${DateFormat.H().format(dt)}:00';
  }

  // Format day from date string
  String formatDay(String dtTxt) {
    final dt = DateTime.parse(dtTxt);
    return DateFormat.E().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark; // Check current theme
    final cardColor = isDarkMode
        ? Colors.white12
        : Colors.white; // Card background color
    final textColor = isDarkMode
        ? Colors.white
        : Colors.black; // Primary text color
    final subTextColor = isDarkMode
        ? Colors.white70
        : Colors.grey[700]; // Subtext color
    final iconColor = isDarkMode ? Colors.white : Colors.black; // Icon color

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: Text(
          'Weather App',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: widget.toggleTheme, // Toggle dark/light theme
            icon: Icon(Icons.brightness_6, color: iconColor),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventListScreen()),
              );
            },
            icon: Icon(Icons.event, color: iconColor),
          ),
          IconButton(
            onPressed: _refreshWeather, // Refresh weather manually
            icon: Icon(Icons.refresh, color: iconColor),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _weatherFuture, // Async weather data
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            ); // Loading indicator
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            ); // Display error
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No weather data available'),
            ); // No data message
          }

          final weatherData = snapshot.data!;
          final forecastList = weatherData['list'] as List; // Forecast entries
          final city = weatherData['city'] ?? {};
          final cityName = city['name'] ?? 'Unknown Location';

          // Approximate "current weather" from first forecast
          final currentForecast = forecastList.first;
          final currentMain = currentForecast['main'];
          final currentWeather = currentForecast['weather'][0];

          // Hourly (3-hour interval) forecast for next 24 hours (8 intervals)
          final hourlyData = forecastList.take(8).toList();

          // Weekly forecast approximation: pick one forecast per day (every 8 items ~24h)
          final weeklyData = <Map<String, dynamic>>[];
          for (int i = 0; i < forecastList.length; i += 8) {
            weeklyData.add(forecastList[i]);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Weather Card
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            cityName,
                            style: TextStyle(
                              fontSize: 20,
                              color: subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            DateFormat('EEE, MMM d').format(DateTime.now()),
                            style: TextStyle(fontSize: 16, color: subTextColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${currentMain['temp'].round()}°C",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            getWeatherIcon(currentWeather['main']),
                            size: 54,
                            color: iconColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentWeather['main'],
                            style: TextStyle(fontSize: 22, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Hourly Forecast Section
                Text(
                  "Hourly Forecast",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: hourlyData.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final data = hourlyData[index];
                      return HourlyForecast(
                        time: formatHour(data['dt_txt']), // Display hour
                        temp:
                            "${data['main']['temp'].round()}°C", // Temperature
                        icon: getWeatherIcon(
                          data['weather'][0]['main'],
                        ), // Weather icon
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // Weekly Forecast Section
                Text(
                  "Weekly Forecast",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: weeklyData.length,
                  itemBuilder: (context, index) {
                    final data = weeklyData[index];
                    return WeeklyForecast(
                      day: formatDay(data['dt_txt']), // Display day
                      temp: "${data['main']['temp'].round()}°C", // Temperature
                      icon: getWeatherIcon(
                        data['weather'][0]['main'],
                      ), // Weather icon
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Additional Information Section
                Text(
                  "Additional Information",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Information(
                      icon: Icons.water_drop,
                      title: "Humidity",
                      percentage: "${currentMain['humidity']}%", // Humidity %
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                    Information(
                      icon: Icons.air,
                      title: "Wind Speed",
                      percentage:
                          "${currentForecast['wind']['speed']} m/s", // Wind speed
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                    Information(
                      icon: Icons.thermostat,
                      title: "Pressure",
                      percentage: "${currentMain['pressure']} hPa", // Pressure
                      iconColor: iconColor,
                      textColor: textColor,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
