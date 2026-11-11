import 'package:aethr_ops/screens/splash_screen.dart';
import 'package:aethr_ops/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const sizes = [Size(360, 640), Size(800, 360), Size(800, 600), Size(1280, 800)];

Future<void> pumpSplash(
  WidgetTester tester,
  Size size, {
  required bool hasError,
  double textScale = 1,
}) async {
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
          child: Scaffold(
            body: SplashContent(
              status: hasError
                  ? 'Oops! Something went wrong'
                  : 'Starting local backend...',
              hasError: hasError,
              onRetry: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final hasError in [false, true]) {
    final state = hasError ? 'error' : 'loading';
    for (final size in sizes) {
      testWidgets('splash ($state) fits ${size.width}x${size.height}', (
        tester,
      ) async {
        await pumpSplash(tester, size, hasError: hasError);
        expect(tester.takeException(), isNull);
      });
    }
    for (final scale in [1.5, 2.0]) {
      testWidgets('splash ($state) fits 360x640 at text scale $scale', (
        tester,
      ) async {
        await pumpSplash(
          tester,
          const Size(360, 640),
          hasError: hasError,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
