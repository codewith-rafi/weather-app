import 'package:hive/hive.dart';
import 'package:weather_app/models/event.dart';

class EventRepository {
  static const String boxName = 'events';
  final Box<Event> _box;

  EventRepository._(this._box);

  static Future<EventRepository> open() async {
    final box = await Hive.openBox<Event>(boxName);
    return EventRepository._(box);
  }

  List<Event> getAll() {
    return _box.values.toList();
  }

  Future<void> add(Event event) async {
    await _box.put(event.id, event);
  }

  Future<void> update(Event event) async {
    await event.save();
  }

  Future<void> delete(int id) async {
    await _box.delete(id);
  }

  List<Event> eventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _box.values
        .where(
          (e) =>
              e.startDateTime.isAfter(
                start.subtract(const Duration(seconds: 1)),
              ) &&
              e.startDateTime.isBefore(end),
        )
        .toList();
  }
}
