import 'package:flutter/material.dart';

// Widget to display additional weather information (e.g., Humidity, Wind, Pressure)
class Information extends StatelessWidget {
  final IconData icon; // Icon to represent the info type
  final String title; // Title (e.g., "Humidity")
  final String percentage; // Value (e.g., "60%")
  final Color? iconColor; // Optional: custom color for icon
  final Color? textColor; // Optional: custom color for text

  const Information({
    super.key,
    required this.icon,
    required this.title,
    required this.percentage,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Display icon
        Icon(
          icon,
          size: 40,
          color: iconColor ?? Theme.of(context).iconTheme.color,
        ),
        const SizedBox(height: 8),
        // Display title
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor ?? Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        // Display value (percentage or measurement)
        Text(
          percentage,
          style: TextStyle(
            fontSize: 18,
            color: textColor ?? Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}
