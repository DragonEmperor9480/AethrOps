import 'package:aethr_ops/utils/orientation_lock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const portrait = [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

void main() {
  test('phones are locked to portrait in either orientation', () {
    expect(preferredOrientationsFor(const Size(360, 640)), portrait);
    expect(preferredOrientationsFor(const Size(800, 360)), portrait);
    expect(preferredOrientationsFor(const Size(412, 915)), portrait);
  });

  test('tablets and desktop windows are not restricted', () {
    expect(preferredOrientationsFor(const Size(800, 600)), isNull);
    expect(preferredOrientationsFor(const Size(1280, 800)), isNull);
    expect(preferredOrientationsFor(const Size(1024, 768)), isNull);
  });
}
