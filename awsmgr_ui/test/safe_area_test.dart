import 'package:aethr_ops/screens/about_screen.dart';
import 'package:aethr_ops/screens/features_screen.dart';
import 'package:aethr_ops/screens/settings_screen.dart';
import 'package:aethr_ops/screens/splash_screen.dart';
import 'package:aethr_ops/theme/app_theme.dart';
import 'package:aethr_ops/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/real_fonts.dart';

// A phone with a 24 px status bar and a 48 px gesture bar.
const topInset = 24.0;
const bottomInset = 48.0;

Future<void> pumpWithInsets(
  WidgetTester tester,
  Size size,
  Widget home, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: topInset,
    bottom: bottomInset,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// Scrolls the screen's scroll view to its end and checks that its last
/// card (Container) stops above the gesture bar.
Future<void> expectEndClearsGestureBar(WidgetTester tester, Size size) async {
  final scrollable = find.byType(Scrollable).first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();

  final viewport = tester.renderObject<RenderBox>(scrollable);
  final contentBottom = tester
      .renderObjectList<RenderBox>(
        find.descendant(of: scrollable, matching: find.byType(Container)),
      )
      .map((box) => box.localToGlobal(Offset(0, box.size.height)).dy)
      .reduce((a, b) => a > b ? a : b);
  final viewportBottom =
      viewport.localToGlobal(Offset.zero).dy + viewport.size.height;
  expect(viewportBottom, size.height);
  expect(contentBottom, lessThanOrEqualTo(size.height - bottomInset));
}

void main() {
  setUpAll(loadRoboto);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [Size(360, 640), Size(800, 600)]) {
    testWidgets('settings scrolls clear of the gesture bar at $size', (
      tester,
    ) async {
      await pumpWithInsets(tester, size, const SettingsScreen());
      await expectEndClearsGestureBar(tester, size);
    });

    testWidgets('about scrolls clear of the gesture bar at $size', (
      tester,
    ) async {
      await pumpWithInsets(tester, size, const AboutScreen());
      await expectEndClearsGestureBar(tester, size);
    });

    testWidgets('features scrolls clear of the gesture bar at $size', (
      tester,
    ) async {
      await pumpWithInsets(tester, size, const FeaturesScreen());
      await expectEndClearsGestureBar(tester, size);
    });
  }

  testWidgets('splash keeps its title below the status bar', (tester) async {
    // Large text makes the error state taller than the screen, so it
    // scrolls and starts at the very top.
    await pumpWithInsets(
      tester,
      const Size(360, 640),
      Scaffold(
        body: SplashContent(
          status: 'Oops! Something went wrong',
          hasError: true,
          onRetry: () {},
        ),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('AethrOps')).dy,
      greaterThanOrEqualTo(topInset),
    );
  });
}
