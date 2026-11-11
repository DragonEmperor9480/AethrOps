import 'package:flutter/material.dart';

/// The "AethrOps" logo text: the capitals A and O in Anurati, the lowercase
/// in Quantify.
///
/// Anurati has no lowercase letters, so a plain Text in Anurati drew "ethr"
/// and "ps" in whatever fallback font the platform had, and the logo looked
/// different on Linux, Windows and Android. The lowercase now comes from a
/// bundled font.
///
/// Anurati's O also has no space on its left but 0.164 em on its right,
/// which left a visible gap before "ps". The O's letter spacing takes that
/// back so the gap after it matches the one before it.
class AethrOpsWordmark extends StatelessWidget {
  /// Empty space on the right of Anurati's O, as a fraction of the font size
  /// (164 of 1000 font units).
  static const double _oRightGap = 0.164;

  final double fontSize;
  final double letterSpacing;
  final Color color;

  const AethrOpsWordmark({
    super.key,
    required this.fontSize,
    required this.letterSpacing,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final capitals = TextStyle(
      fontFamily: 'Anurati',
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
    );
    final lowercase = TextStyle(
      fontFamily: 'Quantify',
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'A', style: capitals),
          TextSpan(text: 'ethr', style: lowercase),
          TextSpan(
            text: 'O',
            style: capitals.copyWith(
              letterSpacing: letterSpacing - fontSize * _oRightGap,
            ),
          ),
          TextSpan(text: 'ps', style: lowercase),
        ],
      ),
      semanticsLabel: 'AethrOps',
    );
  }
}
