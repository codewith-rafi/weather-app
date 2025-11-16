import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:weather_app/models/event.dart';
import 'package:weather_app/screen/event_edit.dart';
import 'package:weather_app/services/notification_service.dart';

class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Event>('events');
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Event> box, _) {
          final events = box.values.toList()
            ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          if (events.isEmpty) return const Center(child: Text('No events yet'));
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final e = events[index];
              return ListTile(
                title: Text(e.title),
                subtitle: Text('${e.startDateTime}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    // Cancel scheduled notification if present
                    if (e.notificationId != null) {
                      final notificationService = NotificationService();
                      await notificationService.cancel(e.notificationId!);
                    }
                    await box.delete(e.id);
                  },
                ),
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventEditScreen(event: e),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventEditScreen()),
          );
        },
      ),
    );
  }
}
