import 'package:aethr_ops/services/cloudwatch_service.dart';
import 'package:aethr_ops/widgets/log_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry entry(String message) =>
    LogEntry.fromJson({'message': message, 'timestamp': 0});

Future<void> pumpLine(
  WidgetTester tester,
  LogEntry log, {
  String query = '',
  bool isCurrentMatch = false,
}) {
  final isMatch =
      query.isNotEmpty &&
      log.message.toLowerCase().contains(query.toLowerCase());
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LogLineContent(
          log: log,
          searchQuery: query,
          isMatch: isMatch,
          isCurrentMatch: isCurrentMatch,
        ),
      ),
    ),
  );
}

/// Every text span drawn by the line, in order.
List<TextSpan> spansOf(WidgetTester tester) {
  final spans = <TextSpan>[];
  for (final text in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    final root = text.textSpan ?? TextSpan(text: text.data, style: text.style);
    root.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
  }
  return spans;
}

/// The colour that [text] is drawn in, inheriting from parent spans.
Color? colorOf(WidgetTester tester, String text) {
  for (final span in spansOf(tester)) {
    if (span.text!.trim() == text) return span.style?.color;
  }
  throw StateError('no span "$text" in ${spansOf(tester).map((s) => s.text)}');
}

void main() {
  testWidgets('a plain line is drawn as text', (tester) async {
    await pumpLine(tester, entry('START RequestId: abc'));
    expect(find.text('START RequestId: abc'), findsOneWidget);
  });

  testWidgets('a JSON line shows its prefix and values', (tester) async {
    await pumpLine(tester, entry('2026-11-12\tabc\tINFO\t{"user": "alice"}'));
    final text = spansOf(tester).map((s) => s.text).join();
    expect(text, contains('2026-11-12\tabc\tINFO\t'));
    expect(text, contains('"alice"'));
  });
}
