import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  final StreamController<String?> _selectNotificationStream =
      StreamController.broadcast();

  Stream<String?> get onNotification => _selectNotificationStream.stream;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    final settings = InitializationSettings(android: android, iOS: ios);

    await _fln.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        _selectNotificationStream.add(resp.payload);
      },
    );
  }

  Future<void> showImmediate(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      'weather_channel',
      'Weather Reminders',
      channelDescription: 'Reminder notifications with weather advice',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);
    await _fln.show(id, title, body, details, payload: payload);
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      'weather_channel',
      'Weather Reminders',
      channelDescription: 'Reminder notifications with weather advice',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);

    if (scheduledDate.isBefore(DateTime.now())) {
      // If time already passed, show immediately
      await showImmediate(id, title, body, payload: payload);
      return;
    }

    await _fln.schedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      payload: payload,
      androidAllowWhileIdle: true,
    );
  }

  Future<void> cancel(int id) async {
    await _fln.cancel(id);
  }

  void dispose() {
    _selectNotificationStream.close();
  }
}
