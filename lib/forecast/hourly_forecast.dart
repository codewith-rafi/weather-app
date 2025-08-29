import 'package:flutter/material.dart';

// Widget to display hourly weather forecast (time, temperature, and icon)
class HourlyForecast extends StatelessWidget {
  final String time; // Time of the forecast (e.g., "14:00")
  final String temp; // Temperature at that time (e.g., "26°C")
  final IconData icon; // Weather icon representing condition (e.g., sunny, rain)

  const HourlyForecast({
    super.key,
    required this.time,
    required this.temp,
    required this.icon, // Required to show weather condition
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2, // Slight shadow for card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded corners
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Inner padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time, // Display forecast time
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8), // Spacing between elements
            Icon(icon, size: 32), // Weather icon in the center
            const SizedBox(height: 8),
            Text(
              temp, // Display temperature
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
