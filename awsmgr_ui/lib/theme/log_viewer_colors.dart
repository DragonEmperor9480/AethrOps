import 'package:flutter/material.dart';

/// Colours of the live log viewer. Each colour has one meaning.
///
/// The viewer used to mix about eight accents, several with more than one
/// meaning (orange was paused, reconnecting, numbers and the current match;
/// green was live, download, the new-line bar and the rate). Now:
/// - green ([live]): the stream is live; the newest line
/// - orange ([warning]): reconnecting
/// - blue ([accent]): something switched on (search, auto-scroll, paused)
///   and the JSON buttons
/// - gold ([match]): search
/// - everything else is neutral grey; red is left for errors
///
/// JSON syntax uses muted pastels so it is not read as status.
class LogViewerColors {
  LogViewerColors._();

  // Surfaces and text (GitHub dark)
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color border = Color(0xFF30363D);
  static const Color text = Color(0xFFC9D1D9);
  static const Color textMuted = Color(0xFF8B949E);

  /// The text of a log line
  static const Color logText = Color(0xFFE6EDF3);

  // Status
  static const Color live = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color accent = Color(0xFF58A6FF);

  /// Paused is a state the user chose, not a problem
  static const Color paused = textMuted;

  // Search
  static const Color match = Color(0xFFE3B341);

  /// Text drawn on a solid [match] background (the current match)
  static const Color onMatch = Color(0xFF0D1117);

  /// Background of the other matches; their text stays [logText]
  static Color get matchBackground => match.withValues(alpha: 0.35);

  static Color get currentMatchRow => match.withValues(alpha: 0.16);
  static Color get matchRow => match.withValues(alpha: 0.07);

  // JSON syntax
  static const Color jsonKey = Color(0xFF9CDCFE);
  static const Color jsonString = Color(0xFFCE9178);
  static const Color jsonNumber = Color(0xFFB5CEA8);
  static const Color jsonLiteral = Color(0xFFC586C0);
  static const Color jsonPunctuation = textMuted;
}
