import 'package:flutter/material.dart';
import 'package:weather_app/screen/weather_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:weather_app/models/event.dart';
import 'package:weather_app/services/notification_service.dart';
import 'package:weather_app/services/app_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive and register adapters
  await Hive.initFlutter();
  Hive.registerAdapter(EventAdapter());
  // Open events box early so repository/screens can use it
  await Hive.openBox<Event>('events');
  // Initialize local notifications
  await NotificationService().init();

  runApp(const MyApp()); // Entry point of the app
}

// Main app widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// State class for MyApp
class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true; // Default theme is dark

  // Function to toggle between dark and light themes
  void toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Disable debug banner
      navigatorKey: appNavigatorKey,
      // Light theme configuration
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.grey[100], // Background color
        cardTheme: const CardThemeData(
          color: Colors.white, // Card background color
          elevation: 6, // Shadow elevation
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(12),
            ), // Rounded corners
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar background
          foregroundColor: Colors.black, // AppBar text/icon color
          elevation: 0, // No shadow
          centerTitle: true, // Center the title
        ),
        iconTheme: const IconThemeData(
          color: Colors.black,
        ), // Default icon color
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black), // Default text color
        ),
      ),

      // Dark theme configuration
      darkTheme: ThemeData.dark(useMaterial3: true),

      // Apply theme based on _isDarkMode
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Home screen of the app, passing toggle function
      home: WeatherScreen(toggleTheme: toggleTheme),
    );
  }
}
