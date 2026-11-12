import 'package:aethr_ops/services/cloudwatch_service.dart';
import 'package:aethr_ops/theme/mono_font.dart';
import 'package:aethr_ops/widgets/log_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? clipboard;
  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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

  const jsonLine = '2026-11-12\tabc\tINFO\t{"b": 1.50, "a": [1e3]}  ';

  testWidgets('Copy JSON copies the JSON exactly as it was logged', (
    tester,
  ) async {
    await pumpLine(tester, entry(jsonLine));
    await tester.tap(find.text('Copy JSON'));
    await tester.pump();
    expect(clipboard, '{"b": 1.50, "a": [1e3]}');
    await tester.pump(const Duration(seconds: 5)); // let the toast go
  });

  testWidgets('the line button copies the whole line, with a big target', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: LogCopyButton(content: jsonLine)),
        ),
      ),
    );
    expect(find.byTooltip('Copy line'), findsOneWidget);
    final button = find.byType(IconButton);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(32));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(32));
    await tester.tap(button);
    await tester.pump();
    expect(clipboard, jsonLine);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('JSON keys and string values get different colours', (
    tester,
  ) async {
    await pumpLine(tester, entry('{"user": "alice", "n": {"id": "x"}}'));
    final key = colorOf(tester, '"user"');
    final value = colorOf(tester, '"alice"');
    expect(key, isNot(value));
    expect(colorOf(tester, '"n"'), key);
    expect(colorOf(tester, '"id"'), key);
    expect(colorOf(tester, '"x"'), value);
  });

  testWidgets('the current match line keeps readable text around the match', (
    tester,
  ) async {
    await pumpLine(
      tester,
      entry('ERROR timeout calling orders'),
      query: 'timeout',
      isCurrentMatch: true,
    );
    expect(colorOf(tester, 'ERROR'), Colors.white);
    expect(colorOf(tester, 'calling orders'), Colors.white);
    expect(colorOf(tester, 'timeout'), Colors.black);
  });

  testWidgets('every span names fixed-width fallbacks for Windows', (
    tester,
  ) async {
    for (final line in ['plain text', 'INFO\t{"a": [1, true, null]}']) {
      await pumpLine(tester, entry(line), query: 'a');
      final styled = spansOf(
        tester,
      ).where((s) => s.style?.fontFamily != null).toList();
      expect(styled, isNotEmpty);
      for (final span in styled) {
        expect(span.style!.fontFamily, monoFontFamily);
        expect(span.style!.fontFamilyFallback, monoFontFallback);
      }
    }
  });
}
