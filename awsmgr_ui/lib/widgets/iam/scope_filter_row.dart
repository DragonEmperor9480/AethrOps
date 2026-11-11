import 'package:flutter/material.dart';

/// The "Scope: [All | AWS | Custom]   N selected" row of the attach-policies
/// dialogs. On one line when there is room (as before); otherwise the label
/// and count share a line and the scope selector goes below it, scaled down
/// if it is still too wide.
class ScopeFilterRow extends StatelessWidget {
  /// Width needed for the one-line layout at the normal text size.
  static const double oneLineMinWidth = 600;

  final Widget label;
  final Widget scopeSelector;
  final Widget selectedCount;

  const ScopeFilterRow({
    super.key,
    required this.label,
    required this.scopeSelector,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneLine =
            constraints.maxWidth >=
            MediaQuery.textScalerOf(context).scale(oneLineMinWidth);

        if (oneLine) {
          return Row(
            children: [
              label,
              const SizedBox(width: 8),
              scopeSelector,
              const Spacer(),
              selectedCount,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: label),
                const SizedBox(width: 8),
                Flexible(child: selectedCount),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(fit: BoxFit.scaleDown, child: scopeSelector),
          ],
        );
      },
    );
  }
}
