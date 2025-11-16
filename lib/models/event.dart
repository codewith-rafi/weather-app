import 'package:hive/hive.dart';

/// Simple Event model stored in Hive. Manual TypeAdapter below avoids build_runner.
class Event extends HiveObject {
  int id; // local id
  String title;
  String? notes;
  DateTime startDateTime;
  DateTime? endDateTime;
  int reminderMinutesBefore; // minutes before start
  String repeat; // none/daily/weekly/monthly
  double? latitude;
  double? longitude;
  int? notificationId;

  Event({
    required this.id,
    required this.title,
    this.notes,
    required this.startDateTime,
    this.endDateTime,
    this.reminderMinutesBefore = 10,
    this.repeat = 'none',
    this.latitude,
    this.longitude,
    this.notificationId,
  });
}

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return Event(
      id: fields[0] as int,
      title: fields[1] as String,
      notes: fields[2] as String?,
      startDateTime: fields[3] as DateTime,
      endDateTime: fields[4] as DateTime?,
      reminderMinutesBefore: fields[5] as int,
      repeat: fields[6] as String,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      notificationId: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.startDateTime)
      ..writeByte(4)
      ..write(obj.endDateTime)
      ..writeByte(5)
      ..write(obj.reminderMinutesBefore)
      ..writeByte(6)
      ..write(obj.repeat)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude)
      ..writeByte(9)
      ..write(obj.notificationId);
  }
}
