/// Width breakpoints (logical pixels) shared by the screens, so the layout
/// numbers live in one place. Layout decisions use width only: height and
/// orientation do not choose between layouts.
abstract final class Breakpoints {
  /// Below this the window is phone-sized: one column, full-width buttons.
  static const double compact = 600;

  /// Features shows two columns from here.
  static const double medium = 750;

  /// Settings and About switch to their two-column layout from here. This is
  /// the desktop window's minimum width, so every desktop window gets it.
  static const double twoColumn = 800;

  /// Home shows four service cards per row above this.
  static const double expanded = 900;

  /// Features shows three columns from here.
  static const double large = 1100;

  static bool isCompact(double width) => width < compact;

  static bool isTwoColumn(double width) => width >= twoColumn;
}
