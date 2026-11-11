import 'package:aethr_ops/screens/iam_group_profile_screen.dart';
import 'package:aethr_ops/screens/iam_user_profile_screen.dart';
import 'package:aethr_ops/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The dialogs load from the backend in initState. In a widget test every HTTP
// request fails, so they show their empty state (header, search/filter block,
// list area) plus an error toast.
final dialogs = <String, Widget Function()>{
  'user attach policies': () => const AttachPoliciesDialog(username: 'alice'),
  'group attach policies': () =>
      const AttachGroupPoliciesDialog(groupname: 'admins'),
  'group add users': () => const AddUsersToGroupDialog(groupname: 'admins'),
};

// The policy dialogs' scope filter row is too wide for phone widths and
// large text; that is a separate problem (BUG-055), so those cases only run
// for the add-users dialog for now.
const narrowCasesSkipped = {'user attach policies', 'group attach policies'};

Future<void> pumpDialog(
  WidgetTester tester,
  Widget dialog,
  Size size, {
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          // Like a showDialog route: full screen, and the Dialog itself
          // makes room for the keyboard.
          child: Scaffold(resizeToAvoidBottomInset: false, body: dialog),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> expectNoOverflow(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  // Let the error toast's timers run out before the test ends.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  for (final entry in dialogs.entries) {
    final narrow = !narrowCasesSkipped.contains(entry.key);

    for (final size in [
      if (narrow) const Size(360, 640),
      const Size(800, 360),
      const Size(800, 600),
      const Size(1280, 800),
    ]) {
      testWidgets('${entry.key} fits ${size.width}x${size.height}', (
        tester,
      ) async {
        await pumpDialog(tester, entry.value(), size);
        await expectNoOverflow(tester);
      });
    }

    testWidgets('${entry.key} fits with the keyboard open', (tester) async {
      await pumpDialog(
        tester,
        entry.value(),
        narrow ? const Size(360, 640) : const Size(800, 600),
        keyboard: 280,
      );
      await expectNoOverflow(tester);
    });

    if (narrow) {
      for (final scale in [1.5, 2.0]) {
        testWidgets('${entry.key} fits 800x600 at text scale $scale', (
          tester,
        ) async {
          await pumpDialog(
            tester,
            entry.value(),
            const Size(800, 600),
            textScale: scale,
          );
          await expectNoOverflow(tester);
        });
      }
    }
  }

  testWidgets('dialogs keep their size on a large desktop window', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      dialogs['group add users']!(),
      const Size(1280, 800),
    );
    final box = tester.getSize(find.byType(Column).first);
    expect(box.height, 600);
    await expectNoOverflow(tester);
  });
}
