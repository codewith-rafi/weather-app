import 'package:flutter/material.dart';

// Widget to display weekly weather forecast (day, temperature, and icon)
class WeeklyForecast extends StatelessWidget {
  final String day; // Day of the week (e.g., Mon, Tue)
  final String temp; // Temperature (e.g., "25°C")
  final IconData icon; // Weather icon representing condition (e.g., sunny, rain)

  const WeeklyForecast({
    super.key,
    required this.day,
    required this.temp,
    required this.icon, // Required for displaying weather condition
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // Space between cards
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Rounded corners
        ),
        elevation: 2, // Slight shadow for card
        child: ListTile(
          leading: Icon(icon, size: 32), // Weather icon on the left
          title: Text(day), // Day text in the middle
          trailing: Text(temp), // Temperature on the right
        ),
      ),
    );
  }
}
