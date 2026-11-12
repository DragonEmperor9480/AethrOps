/// A fixed-width font for logs and JSON.
///
/// `monospace` is a generic name that Linux (fontconfig) and Android resolve
/// to their monospace font, but Windows and macOS have no font by that name.
/// Without a fallback, Windows drew logs in a proportional font and JSON
/// indentation did not line up. The fallbacks are tried in order: the
/// Windows fonts first, then macOS, then common Linux fonts.
const String monoFontFamily = 'monospace';

const List<String> monoFontFallback = [
  'Cascadia Mono',
  'Consolas',
  'Menlo',
  'DejaVu Sans Mono',
  'Liberation Mono',
  'Courier New',
];
