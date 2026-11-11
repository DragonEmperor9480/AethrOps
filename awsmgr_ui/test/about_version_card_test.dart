import 'package:aethr_ops/screens/about_screen.dart';
import 'package:aethr_ops/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/real_fonts.dart';

// Widths the card gets: 320 in phone portrait (360 minus padding), ~313 in
// the two-column layout of an 800-wide window, 480.6 (reported overflow),
// ~531 at 1280, and wider.
const widths = [280.0, 313.0, 320.0, 480.6, 531.0, 600.0, 700.0];

// A release build, and a dev build without the version ldflags.
const versions = [
  ('1.1.0', 'CachyOS'),
  ('placeholder for version', 'Ubuntu 24.04.1 LTS'),
];

Future<void> pumpCard(
  WidgetTester tester,
  double width,
  String version,
  String osName, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
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
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: AboutVersionCard(
                  version: version,
                  osName: osName,
                  onCheckUpdates: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    final quantify = FontLoader('Quantify')
      ..addFont(rootBundle.load('assets/fonts/Quantify.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Quantify Bold.ttf'));
    await quantify.load();
  });

  for (final (version, osName) in versions) {
    for (final width in widths) {
      testWidgets('version card "$version" fits $width px', (tester) async {
        await pumpCard(tester, width, version, osName);
        expect(tester.takeException(), isNull);
      });
    }
    for (final scale in [1.5, 2.0]) {
      testWidgets('version card "$version" fits 320 px at text scale $scale', (
        tester,
      ) async {
        await pumpCard(tester, 320, version, osName, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('version card stays on one row when there is room', (
    tester,
  ) async {
    await pumpCard(tester, 700, '1.1.0', 'CachyOS');
    expect(
      tester.getCenter(find.text('Check Updates')).dy,
      tester.getCenter(find.text('CachyOS')).dy,
    );
  });
}
