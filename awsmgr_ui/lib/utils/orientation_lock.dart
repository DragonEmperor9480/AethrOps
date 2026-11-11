import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';

/// Displays whose shortest side is below this (in logical pixels) are phones.
/// The screens are laid out for phones in portrait, so phones stay upright;
/// tablets and desktop windows can use any orientation.
const double phoneShortestSideLimit = 600;

/// The orientations to allow on a display of [logicalSize]: portrait only for
/// phones, null (no restriction) for anything larger.
List<DeviceOrientation>? preferredOrientationsFor(Size logicalSize) {
  if (logicalSize.shortestSide < phoneShortestSideLimit) {
    return const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
  }
  return null;
}

/// Locks phones to portrait. Call once after the binding is initialized.
/// Uses the physical display, not the window, so split-screen does not
/// change the decision. Does nothing on desktop.
Future<void> lockPhonesToPortrait() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return;
  final display = views.first.display;
  if (display.devicePixelRatio <= 0) return;

  final orientations = preferredOrientationsFor(
    display.size / display.devicePixelRatio,
  );
  if (orientations != null) {
    await SystemChrome.setPreferredOrientations(orientations);
  }
}
