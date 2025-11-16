import 'dart:async';

import 'package:flutter/material.dart';
import 'package:weather_app/services/app_navigator.dart';

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

  Future<void> init() async {
    // Nothing to initialize for the timer-based fallback.
  }

  Future<void> showImmediate(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    // Deliver payload immediately to listeners and show a simple dialog/snackbar when possible.
    _selectNotificationStream.add(payload);
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

    final timer = Timer(diff, () {
      _selectNotificationStream.add(payload);
      _showInAppBanner(title, body);
      _timers.remove(id);
    });

    _timers[id] = timer;
  }

  Future<void> cancel(int id) async {
    final t = _timers.remove(id);
    if (t != null && t.isActive) t.cancel();
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
