import 'dart:io' show Platform;
import 'dart:ui' show Brightness;

import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// Native window translucency. The decision (design canvas + kumo.md):
/// the *window* gets real OS translucency; panels inside are light-weight
/// semi-transparent fills with no BackdropFilter, so a terminal repainting
/// at 60 fps never forces a re-blur. Only transient overlays blur.
///
/// macOS: NSVisualEffectView via flutter_acrylic/macos_window_utils, full-size
/// content view with a transparent unified toolbar so the traffic lights sit
/// inside our sidebar. Note: this is NSVisualEffectView vibrancy, not the
/// macOS 26 NSGlassEffectView "Liquid Glass" material — the plugin doesn't
/// expose that yet.
/// Windows 11: Mica. Windows 10: Acrylic (known drag lag on Win10).
class WindowEffects {
  WindowEffects._();

  /// True when the OS draws a translucent backdrop behind Flutter.
  static bool nativeBackdrop = false;

  static bool get _supported => !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  static Future<void> init() async {
    if (!_supported) return;
    try {
      await Window.initialize();
      if (Platform.isMacOS) {
        await Window.makeTitlebarTransparent();
        await Window.enableFullSizeContentView();
        await Window.hideTitle();
        await Window.addToolbar();
        await Window.setToolbarStyle(toolbarStyle: MacOSToolbarStyle.unified);
      }
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
      if (Platform.isMacOS) {
        await Window.overrideMacOSBrightness(dark: dark);
        await Window.setEffect(effect: WindowEffect.sidebar, dark: dark);
      } else if (Platform.isWindows) {
        await Window.setEffect(effect: WindowEffect.mica, dark: dark);
      }
    } catch (e) {
      debugPrint('WindowEffects.apply failed: $e');
    }
  }

  /// Height reserved at the top of the sidebar for the native traffic lights.
  static double get trafficLightsInset => (!kIsWeb && Platform.isMacOS && nativeBackdrop) ? 40 : 6;
}
