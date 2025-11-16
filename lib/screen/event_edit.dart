import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:weather_app/models/event.dart';
import 'package:weather_app/services/notification_service.dart';

class EventEditScreen extends StatefulWidget {
  final Event? event;
  const EventEditScreen({super.key, this.event});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  String? _notes;
  late DateTime _start;
  DateTime? _end;
  int _reminder = 10;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _title = widget.event!.title;
      _notes = widget.event!.notes;
      _start = widget.event!.startDateTime;
      _end = widget.event!.endDateTime;
      _reminder = widget.event!.reminderMinutesBefore;
    } else {
      _title = '';
      _start = DateTime.now().add(const Duration(hours: 1));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final box = Hive.box<Event>('events');
    if (widget.event != null) {
      final e = widget.event!;
      final oldNid = e.notificationId;
      e.title = _title;
      e.notes = _notes;
      e.startDateTime = _start;
      e.endDateTime = _end;
      e.reminderMinutesBefore = _reminder;
      final nid = (e.id & 0x7fffffff);
      e.notificationId = nid;
      await e.save();
      // Reschedule notification
      final notificationService = NotificationService();
      if (oldNid != null && oldNid != nid)
        await notificationService.cancel(oldNid);
      final notifyTime = e.startDateTime.subtract(
        Duration(minutes: e.reminderMinutesBefore),
      );
      await notificationService.scheduleNotification(
        nid,
        'Reminder: ${e.title}',
        'Tap to view weather advice',
        notifyTime,
        payload: e.id.toString(),
      );
    } else {
      final id = DateTime.now().millisecondsSinceEpoch;
      final e = Event(
        id: id,
        title: _title,
        notes: _notes,
        startDateTime: _start,
        endDateTime: _end,
        reminderMinutesBefore: _reminder,
      );
      // Assign notification id and persist with it
      final nid = (e.id & 0x7fffffff);
      e.notificationId = nid;
      await box.put(e.id, e);
      // Schedule notification for new event
      final notificationService = NotificationService();
      final notifyTime = e.startDateTime.subtract(
        Duration(minutes: e.reminderMinutesBefore),
      );
      await notificationService.scheduleNotification(
        nid,
        'Reminder: ${e.title}',
        'Tap to view weather advice',
        notifyTime,
        payload: e.id.toString(),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _pickStart() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dt == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(dt.year, dt.month, dt.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? 'Edit Event' : 'Add Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                onSaved: (v) => _title = v ?? '',
              ),
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                onSaved: (v) => _notes = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Start: ${_start.toLocal()}')),
                  TextButton(onPressed: _pickStart, child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _reminder,
                items: const [5, 10, 15, 30, 60]
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text('$m minutes')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _reminder = v ?? 10),
                decoration: const InputDecoration(labelText: 'Reminder'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      // Quick test: fetch weather and show advice immediately
                      final tempEvent =
                          widget.event ??
                          Event(
                            id: 0,
                            title: _title,
                            startDateTime: _start,
                            reminderMinutesBefore: _reminder,
                          );
                      final notificationService = NotificationService();
                      // show immediate notification
                      await notificationService.showImmediate(
                        999999,
                        'Test Reminder: ${tempEvent.title}',
                        'Tap to view weather advice',
                        payload: tempEvent.id.toString(),
                      );
                    },
                    child: const Text('Test'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
