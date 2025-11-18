import 'dart:async';

import 'package:flutter/material.dart';
import 'package:weather_app/services/app_navigator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

// Top-level callback dispatcher for Workmanager. This runs in a background
// isolate and shows a platform notification using its own instance of
// FlutterLocalNotificationsPlugin.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final fln = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosInit = DarwinInitializationSettings();
      final settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await fln.initialize(settings);

      final payload = inputData?['payload'] as String?;
      final title = inputData?['title'] as String? ?? 'Reminder';
      final body =
          inputData?['body'] as String? ?? 'Tap to view weather advice';
      final nid = (inputData?['id'] is int)
          ? inputData!['id'] as int
          : task.hashCode;

      const androidDetails = AndroidNotificationDetails(
        'weather_reminder_channel',
        'Weather Reminders',
        channelDescription: 'Reminders for weather-aware events',
        importance: Importance.max,
        priority: Priority.high,
      );
      const platform = NotificationDetails(android: androidDetails);
      await fln.show(nid, title, body, platform, payload: payload);
    } catch (e) {
      debugPrint('Background workmanager task failed: $e');
    }
    return Future.value(true);
  });
}

/// Lightweight in-app "notification" service that uses Timers.
/// This is a fallback for environments where the native plugin cannot be compiled.
/// It schedules callbacks while the app is running and emits payloads on a stream.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final StreamController<String?> _selectNotificationStream =
      StreamController<String?>.broadcast();
  Stream<String?> get onNotification => _selectNotificationStream.stream;

  final Map<int, Timer> _timers = {};
  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  bool _pluginInitialized = false;

  Future<void> init() async {
    // Initialize Workmanager so background tasks can run when the app
    // is terminated (Android). If this fails, we'll still use the
    // in-app timer fallback.
    try {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    } catch (e) {
      debugPrint('Workmanager init failed: $e');
    }

    // Try to initialize the native notification plugin. If it fails,
    // we'll continue using the timer-based in-app fallback.
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);
      await _fln.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          _selectNotificationStream.add(response.payload);
        },
      );
      _pluginInitialized = true;
    } catch (e, s) {
      debugPrint('Local notifications init failed: $e\n$s');
      _pluginInitialized = false;
    }
  }

  Future<void> showImmediate(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    // Deliver payload immediately to listeners and attempt to show a system
    // notification (if the plugin initialized). Also show an in-app banner
    // so users running the app still get feedback.
    _selectNotificationStream.add(payload);
    if (_pluginInitialized) {
      try {
        const androidDetails = AndroidNotificationDetails(
          'weather_reminder_channel',
          'Weather Reminders',
          channelDescription: 'Reminders for weather-aware events',
          importance: Importance.max,
          priority: Priority.high,
        );
        const platform = NotificationDetails(android: androidDetails);
        await _fln.show(id, title, body, platform, payload: payload);
      } catch (e) {
        debugPrint('Failed to show platform notification: $e');
      }
    }
    _showInAppBanner(title, body);
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String? payload,
  }) async {
    // Cancel any existing timer for this id
    await cancel(id);

    final now = DateTime.now();
    final diff = scheduledDate.difference(now);
    if (diff <= Duration.zero) {
      // Past -> immediate
      await showImmediate(id, title, body, payload: payload);
      return;
    }

    // Try scheduling an OS-level Workmanager one-off task so the notification
    // will be delivered even if the app is terminated (Android). If that
    // fails for any reason we'll fall back to the in-app Timer.
    try {
      final inputData = {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
      };
      await Workmanager().registerOneOffTask(
        'notify_$id',
        'showNotification',
        inputData: inputData,
        initialDelay: diff,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      // Keep a local timer so that while the app is running the in-app banner
      // and stream events are still emitted at the scheduled time.
      final timer = Timer(diff, () {
        _selectNotificationStream.add(payload);
        _showInAppBanner(title, body);
        _timers.remove(id);
      });
      _timers[id] = timer;
      return;
    } catch (e) {
      debugPrint('Workmanager scheduling failed, falling back to timer: $e');
    }

    // Fallback: schedule using a local Timer while the app runs.
    final timer = Timer(diff, () {
      // When timer fires, try to show a native notification (if available)
      // and also emit the payload for in-app listeners.
      if (_pluginInitialized) {
        try {
          const androidDetails = AndroidNotificationDetails(
            'weather_reminder_channel',
            'Weather Reminders',
            channelDescription: 'Reminders for weather-aware events',
            importance: Importance.max,
            priority: Priority.high,
          );
          const platform = NotificationDetails(android: androidDetails);
          _fln.show(id, title, body, platform, payload: payload);
        } catch (e) {
          debugPrint('Failed to show scheduled platform notification: $e');
        }
      }
      _selectNotificationStream.add(payload);
      _showInAppBanner(title, body);
      _timers.remove(id);
    });

    _timers[id] = timer;
  }

  Future<void> cancel(int id) async {
    final t = _timers.remove(id);
    if (t != null && t.isActive) t.cancel();
    try {
      await Workmanager().cancelByUniqueName('notify_$id');
    } catch (e) {
      debugPrint('Failed to cancel workmanager task: $e');
    }
  }

  void _showInAppBanner(String title, String body) {
    final ctx = appNavigatorKey.currentState?.overlay?.context;
    if (ctx != null) {
      final messenger = ScaffoldMessenger.of(ctx);
      messenger.showSnackBar(
        SnackBar(
          content: Text('$title — $body'),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      debugPrint('Notification: $title - $body');
    }
  }

  void dispose() {
    for (final t in _timers.values) {
      if (t.isActive) t.cancel();
    }
    _timers.clear();
    _selectNotificationStream.close();
  }
}
