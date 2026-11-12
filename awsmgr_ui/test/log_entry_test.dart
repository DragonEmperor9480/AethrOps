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
}
