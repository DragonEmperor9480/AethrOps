import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The box inside a list dialog (a header and a search/filter block above an
/// `Expanded` list). It is at most [maxWidth] wide (the dialog narrows it
/// further on small screens) and at most [maxHeight] high or
/// [heightFraction] of the screen height, whichever is smaller.
///
/// When the dialog ends up shorter than that height (the keyboard is open)
/// or than [minContentHeight] scaled with the text size (a short screen), the
/// whole content scrolls at the larger of the two instead of squeezing the
/// list to nothing.
class ScreenSizedDialogBox extends StatelessWidget {
  static const double heightFraction = 0.85;

  final double maxWidth;
  final double maxHeight;
  final double minContentHeight;
  final Widget child;

  const ScreenSizedDialogBox({
    super.key,
    required this.maxWidth,
    required this.maxHeight,
    this.minContentHeight = 440,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final height = math.min(maxHeight, screenHeight * heightFraction);
    // The keyboard can make the dialog shorter than [height]; the content
    // then keeps [height] and scrolls.
    final minContent = math.max(
      height,
      MediaQuery.textScalerOf(context).scale(minContentHeight),
    );

    return SizedBox(
      width: maxWidth,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight >= minContent) return child;
          return SingleChildScrollView(
            child: SizedBox(height: minContent, child: child),
          );
        },
      ),
    );
  }
}
