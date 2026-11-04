import 'dart:ui' show Brightness;

import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

import 'os/host_os.dart';

/// Native window translucency. The decision (design canvas + kumo.md):
/// the *window* gets real OS translucency; panels inside are light-weight
/// semi-transparent fills with no BackdropFilter, so a terminal repainting
/// at 60 fps never forces a re-blur. Only transient overlays blur.
///
/// What each OS does is in its [HostOs] (`os/macos.dart`, `os/windows.dart`).
class WindowEffects {
  WindowEffects._();

  /// True when the OS draws a translucent backdrop behind Flutter.
  static bool nativeBackdrop = false;

  static bool get _supported => !kIsWeb && hostOs.supportsNativeBackdrop;

  static Future<void> init() async {
    if (!_supported) return;
    try {
      await Window.initialize();
      await hostOs.prepareWindow();
      nativeBackdrop = true;
    } catch (e) {
      debugPrint('WindowEffects.init failed, falling back to painted backdrop: $e');
      nativeBackdrop = false;
    }
  }

  static Brightness? _applied;

  static Future<void> apply(Brightness brightness) async {
    if (!nativeBackdrop || _applied == brightness) return;
    _applied = brightness;
    final dark = brightness == Brightness.dark;
    try {
      await hostOs.applyBackdrop(dark: dark);
    } catch (e) {
      debugPrint('WindowEffects.apply failed: $e');
    }
  }

  /// Height reserved at the top of the sidebar for the native traffic lights.
  static double get trafficLightsInset => (!kIsWeb && hostOs.windowButtonsInContent && nativeBackdrop) ? 40 : 6;
}
