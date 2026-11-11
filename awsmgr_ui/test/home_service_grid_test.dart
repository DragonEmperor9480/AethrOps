import 'package:aethr_ops/screens/home_screen.dart';
import 'package:aethr_ops/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/real_fonts.dart';

// Same titles and descriptions as the home screen.
final services = [
  for (final (title, description) in const [
    ('IAM', 'Control access to AWS resources'),
    ('S3', 'Scalable cloud storage'),
    ('EC2', 'Virtual servers in the cloud'),
    ('Live Tail', 'Real-time log streaming'),
  ])
    ServiceInfo(
      title: title,
      description: description,
      icon: Icons.cloud_outlined,
      color: AppTheme.primaryPurple,
      route: '/',
    ),
];

Future<void> pumpGrid(WidgetTester tester, Size size, double textScale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          // The home screen puts the grid in a 20 px padded scroll view.
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ServiceGrid(services: services, onOpen: (_) {}),
            ),
          ),
        ),
      ),
    ),
  );
  // Let the cards' entry animation finish.
  await tester.pump(const Duration(seconds: 2));
}

/// The description is Flexible, so a card that is too short squeezes it
/// and clips the text without raising an overflow error. Check every text in
/// the cards got the height it needs.
void expectNoClippedText(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(needed - 0.5),
      reason: '"${paragraph.text.toPlainText()}" is clipped',
    );
  }
}

void main() {
  setUpAll(loadRoboto);

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final size in const [
      Size(360, 640),
      Size(800, 360),
      Size(800, 600),
      Size(1280, 800),
    ]) {
      testWidgets(
        'service cards fit ${size.width}x${size.height} at text scale $scale',
        (tester) async {
          await pumpGrid(tester, size, scale);
          expect(tester.takeException(), isNull);
          expectNoClippedText(tester);
        },
      );
    }
  }

  testWidgets('cards keep their size at the normal text size', (tester) async {
    await pumpGrid(tester, const Size(1280, 800), 1);
    final card = tester.getSize(
      find.byType(TweenAnimationBuilder<double>).first,
    );
    // 1240 px wide grid, 4 columns, 16 px gaps, aspect ratio 1.2.
    expect(card.width, closeTo(298, 0.5));
    expect(card.height, closeTo(298 / 1.2, 0.5));
  });
}
