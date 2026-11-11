import 'package:aethr_ops/screens/settings_screen.dart';
import 'package:aethr_ops/theme/app_theme.dart';
import 'package:aethr_ops/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpSettings(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

bool isTwoColumn() => find.byType(ListView).evaluate().isEmpty;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Sizes where the layout was already right keep it.
  testWidgets('settings: one column on a phone in portrait', (tester) async {
    await pumpSettings(tester, const Size(360, 640));
    expect(isTwoColumn(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings: two columns on desktop windows', (tester) async {
    for (final size in const [Size(800, 600), Size(1280, 800)]) {
      await pumpSettings(tester, size);
      expect(isTwoColumn(), isTrue, reason: '$size');
      expect(tester.takeException(), isNull);
    }
  });

  // The layout is chosen by width, not by orientation.
  testWidgets('settings: a narrow landscape window stays one column', (
    tester,
  ) async {
    await pumpSettings(tester, const Size(700, 360));
    expect(isTwoColumn(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
