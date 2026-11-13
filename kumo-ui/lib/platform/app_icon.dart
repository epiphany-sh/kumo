import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app/preferences.dart';
import 'os/host_os.dart';
import 'pasteboard.dart';

/// The icons Kumo can show itself with (Settings › Appearance).
///
/// One that ships with Kumo has a [preview] here and lives in the runners
/// as well: an image set in `macos/Runner/Assets.xcassets` (`AppIcon.images`
/// in `AppDelegate.swift`) and an icon in `windows/runner/Runner.rc`
/// (`SetAppIcon` in `flutter_window.cpp`).
enum AppIcon {
  kumo('Kumo', preview: 'assets/app_icons/kumo.png'),

  /// One made from an image of the user's ([AppIcons.make]).
  own('Yours');

  const AppIcon(this.label, {this.preview});

  final String label;

  /// A picture of it for Settings; [own]'s is its file.
  final String? preview;
}

/// The icon Kumo shows itself with, as saved in the settings, and the
/// runner that shows it (`AppDelegate.swift`, `flutter_window.cpp`).
class AppIcons {
  AppIcons._();

  static const key = 'appearance.appIcon';

  /// The icon made from the user's image, kept while another one is chosen
  /// so going back to it needs no new pick.
  static const fileKey = 'appearance.appIconFile';

  /// Images the file dialog offers for one of your own.
  static const imageTypes = ['png', 'jpg', 'jpeg', 'heic', 'tiff', 'tif', 'gif', 'webp', 'icns', 'svg'];

  /// Whether Kumo can change its icon here (see [HostOs.appIconPlaces]).
  static bool get supported => !kIsWeb && hostOs.appIconPlaces != null;

  /// Whether you can make one from an image: the runner opens a file
  /// dialog and makes it (macOS).
  static bool get canMakeOwn => supported && Pasteboard.canChoose;

  /// Whether Settings has a choice to offer.
  static bool get choosable => canMakeOwn || (supported && AppIcon.values.where((i) => i.preview != null).length > 1);

  static String? ownFile(Preferences p) {
    final f = p.get<String>(fileKey, '');
    return f.isEmpty ? null : f;
  }

  /// The one chosen: yours only while there is one, and [AppIcon.kumo]
  /// for none, or one this version lacks.
  static AppIcon chosen(Preferences p) {
    final name = p.get<String>(key, AppIcon.kumo.name);
    final icon = AppIcon.values.firstWhere((i) => i.name == name, orElse: () => AppIcon.kumo);
    return icon == AppIcon.own && ownFile(p) == null ? AppIcon.kumo : icon;
  }

  static const _channel = MethodChannel('kumo/app_icon');

  /// Shows the one chosen in [p] where [HostOs.appIconPlaces] says; Kumo's
  /// own when your file is gone.
  static Future<void> apply(Preferences p) async {
    if (!supported) return;
    final icon = chosen(p);
    if (icon == AppIcon.own && await _call('setFile', ownFile(p))) return;
    await _call('set', icon == AppIcon.own ? AppIcon.kumo.name : icon.name);
  }

  /// An icon from the image at [source], saved in [dir] (next to the
  /// settings): its path, or null when that isn't an image the runner reads.
  static Future<String?> make(String source, Directory dir) async {
    // A new name each time: Flutter caches a picture by its path.
    final target = '${dir.path}${Platform.pathSeparator}app-icon-${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      dir.createSync(recursive: true);
    } on FileSystemException {
      return null;
    }
    return await _call('make', {'source': source, 'target': target}) ? target : null;
  }

  /// Removes an icon [make] saved, once another replaced it.
  static void discard(String file) {
    try {
      File(file).deleteSync();
    } on FileSystemException {
      // Already gone.
    }
  }

  static Future<bool> _call(String method, Object? arguments) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on MissingPluginException {
      // A runner without the channel: the icon stays the app's own.
      return false;
    } on PlatformException catch (e) {
      debugPrint('AppIcons.$method failed: $e');
      return false;
    }
  }
}
