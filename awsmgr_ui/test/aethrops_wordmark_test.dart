import 'package:aethr_ops/widgets/aethrops_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wordmark draws the lowercase in a bundled font', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AethrOpsWordmark(fontSize: 42, letterSpacing: 3)),
      ),
    );
    final root = tester.widget<RichText>(find.byType(RichText)).text;
    final spans = <String, TextStyle>{};
    root.visitChildren((span) {
      if (span is TextSpan && span.text != null)
        spans[span.text!] = span.style!;
      return true;
    });

    expect(spans.keys.join(), 'AethrOps');
    // Anurati has only capitals: the lowercase must not use it, or the
    // platform's fallback font draws it.
    expect(spans['A']!.fontFamily, 'Anurati');
    expect(spans['O']!.fontFamily, 'Anurati');
    expect(spans['ethr']!.fontFamily, 'Quantify');
    expect(spans['ps']!.fontFamily, 'Quantify');
    // Anurati's O has 0.164 em of empty space on its right; its letter
    // spacing takes that back so the gap before "ps" is not wider.
    expect(spans['O']!.letterSpacing, closeTo(3 - 42 * 0.164, 0.001));
    expect(spans['A']!.letterSpacing, 3);
  });
}
