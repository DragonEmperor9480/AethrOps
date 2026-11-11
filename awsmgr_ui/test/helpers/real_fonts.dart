import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto (the app's default font on Android) from the Flutter SDK, so
/// text in a widget test is as wide as on a phone. Without it, tests use the
/// Ahem test font, whose glyphs are all 1 em wide, about twice as wide as
/// Roboto, which wraps text far sooner than a real device does.
Future<void> loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set; run with `flutter test`.');
  }
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final name in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('$dir/Roboto-$name.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
