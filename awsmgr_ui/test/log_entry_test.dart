import 'package:aethr_ops/services/cloudwatch_service.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry entry(String message) =>
    LogEntry.fromJson({'message': message, 'timestamp': 0});

void main() {
  test('a JSON array log is parsed, not dropped', () {
    final log = entry('2026-11-12T10:00:00Z\tabc\tINFO\t[1, 2, {"a": 3}]');
    expect(log.parsedJson, [
      1,
      2,
      {'a': 3},
    ]);
    expect(log.jsonPrefix, '2026-11-12T10:00:00Z\tabc\tINFO\t');
  });

  test('a JSON object log keeps working', () {
    final log = entry('2026-11-12T10:00:00Z\tabc\tINFO\t{"user": "alice"}');
    expect(log.parsedJson, {'user': 'alice'});
  });

  test('a Python line finds the JSON after the [INFO] tag', () {
    final log = entry(
      '[INFO]\t2026-11-12T10:00:00Z\tabc\t{"order": {"id": 7}, "ok": true}',
    );
    expect(log.parsedJson, {
      'order': {'id': 7},
      'ok': true,
    });
    expect(log.jsonPrefix, '[INFO]\t2026-11-12T10:00:00Z\tabc\t');
  });

  test('a Python line with an array after the tag', () {
    final log = entry('[WARNING]\tabc\t[{"a": 1}]');
    expect(log.parsedJson, [
      {'a': 1},
    ]);
    expect(log.jsonPrefix, '[WARNING]\tabc\t');
  });

  test('plain text with braces is not shown as JSON', () {
    expect(entry('user {id} not found').parsedJson, isNull);
    expect(entry('{Name:alice Age:3}').parsedJson, isNull);
    expect(entry('[INFO] started').parsedJson, isNull);
    expect(entry('payload {"a": 1} received').parsedJson, isNull);
  });

  test('broken JSON is not shown as JSON', () {
    expect(entry('START {"a": 1').parsedJson, isNull);
    expect(entry('').parsedJson, isNull);
  });
}
