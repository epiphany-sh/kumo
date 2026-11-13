import Cocoa
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate {
  let updates = Updates()
  let appIcon = AppIcon()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    AppIcon.restore()
    updates.start()
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// The icon chosen in Settings › Appearance (`lib/platform/app_icon.dart`):
/// Kumo's own or one made from an image of the user's, in the Dock and the
/// app switcher while Kumo runs. A closed app shows the bundle's: changing
/// that would break the bundle's signature.
///
/// The choice is also kept in the user defaults, so the next launch shows
/// it before the Flutter side starts.
final class AppIcon {
  private static let key = "KumoAppIcon"

  /// Icons that ship in Assets.xcassets (image sets), by the names the
  /// Flutter side uses. "kumo", the bundle's own, needs none.
  private static let images: [String: String] = [:]

  private var channel: FlutterMethodChannel?

  static func restore() {
    guard let saved = UserDefaults.standard.string(forKey: key) else { return }
    if saved.hasPrefix("file:") {
      _ = applyFile(String(saved.dropFirst("file:".count)))
    } else {
      _ = apply(saved)
    }
  }

  /// False when there is no icon by that name.
  static func apply(_ name: String) -> Bool {
    if name == "kumo" {
      NSApp.applicationIconImage = nil
    } else if let asset = images[name], let image = NSImage(named: asset) {
      NSApp.applicationIconImage = image
    } else {
      return false
    }
    UserDefaults.standard.set(name, forKey: key)
    return true
  }

  /// An icon made by `IconImage.make`; false when it's gone.
  static func applyFile(_ path: String) -> Bool {
    guard let image = NSImage(contentsOfFile: path) else { return false }
    NSApp.applicationIconImage = image
    UserDefaults.standard.set("file:" + path, forKey: key)
    return true
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "kumo/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "set":
        result(AppIcon.apply(call.arguments as? String ?? ""))
      case "setFile":
        result(AppIcon.applyFile(call.arguments as? String ?? ""))
      case "make":
        let args = call.arguments as? [String: Any]
        let source = args?["source"] as? String ?? ""
        let target = args?["target"] as? String ?? ""
        // A big photo takes a moment to decode and scale: off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
          let made = IconImage.make(from: source, to: target)
          DispatchQueue.main.async { result(made) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }
}

// MARK: IconImage

/// An app icon from an image of the user's.
enum IconImage {
  static let size = 1024

  /// Writes to `target` a PNG icon from the image at `source`: anything
  /// macOS reads (PNG, JPEG, HEIC, ICNS…). One with see-through corners is
  /// an icon already and stays as it is; any other is cropped square into
  /// the tile Kumo's own icon has, rounded, with the room around it Mac
  /// icons leave. False when `source` isn't an image.
  static func make(from source: String, to target: String) -> Bool {
    guard let image = NSImage(contentsOfFile: source) else { return false }
    var proposed = NSRect(x: 0, y: 0, width: size, height: size)
    guard let art = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
      art.width > 0, art.height > 0,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return false }
    ctx.interpolationQuality = .high
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    if shaped(art) {
      ctx.draw(art, in: place(art, in: canvas, fill: false))
    } else {
      tile(art, in: ctx)
    }
    guard let icon = ctx.makeImage(),
      let png = NSBitmapImageRep(cgImage: icon).representation(using: .png, properties: [:])
    else { return false }
    do {
      try png.write(to: URL(fileURLWithPath: target), options: .atomic)
    } catch {
      NSLog("Kumo: saving the app icon failed: %@", error.localizedDescription)
      return false
    }
    return true
  }

  /// Whether all four corners are see-through: the image has its own shape.
  static func shaped(_ art: CGImage) -> Bool {
    let n = 32
    guard
      let ctx = CGContext(
        data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let data = ctx.data
    else { return false }
    ctx.draw(art, in: CGRect(x: 0, y: 0, width: n, height: n))
    let px = data.assumingMemoryBound(to: UInt8.self)
    return [(0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)].allSatisfy { x, y in
      px[(y * n + x) * 4 + 3] < 26
    }
  }

  /// `art` over `box` keeping its proportions: covering it (cropped), or
  /// inside it.
  static func place(_ art: CGImage, in box: CGRect, fill: Bool) -> CGRect {
    let w = CGFloat(art.width), h = CGFloat(art.height)
    let scale = fill ? max(box.width / w, box.height / h) : min(box.width / w, box.height / h)
    return CGRect(
      x: box.midX - w * scale / 2, y: box.midY - h * scale / 2, width: w * scale, height: h * scale)
  }

  /// Kumo's tile (as `assets/brand/app_icon.svg` draws it) filled with `art`:
  /// 824 points of 1024, rounded, with a shadow under it and a light rim.
  static func tile(_ art: CGImage, in ctx: CGContext) {
    let box = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: box, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.draw(art, in: place(art, in: box, fill: true))
    ctx.restoreGState()

    // The rim, brightest on top (y goes up here).
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: box.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
    ctx.setLineWidth(4)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let colors = [CGColor(gray: 1, alpha: 0.24), CGColor(gray: 1, alpha: 0.08), CGColor(gray: 1, alpha: 0.05)]
    if let rim = CGGradient(
      colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 0.12, 1])
    {
      ctx.drawLinearGradient(rim, start: CGPoint(x: 0, y: box.maxY), end: CGPoint(x: 0, y: box.minY), options: [])
    }
    ctx.restoreGState()
  }
}

// MARK: -

/// New versions through Sparkle. Only release builds carry a feed
/// (`SUFeedURL`, added by `make release`): a local build never replaces
/// itself with the published one.
///
/// Sparkle checks at launch and every hour, and downloads in the background;
/// once an update waits to be installed the UI hears of it ("ready") and
/// offers a restart ("install"). Without that click it installs when Kumo
/// quits. Kumo › Check for Updates… checks now, with Sparkle's own window.
final class Updates: NSObject, SPUUpdaterDelegate {
  private var controller: SPUStandardUpdaterController?
  private var channel: FlutterMethodChannel?
  private var installNow: (() -> Void)?
  private var readyVersion: String?

  func start() {
    let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    guard !feed.isEmpty else { return }
    let controller = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    self.controller = controller
    // On its own Sparkle waits out the interval since the last check, even
    // across launches: opening Kumo is when a new version should show.
    controller.updater.checkForUpdatesInBackground()
    addMenuItem(controller)
  }

  /// "Check for Updates…" under "About Kumo", as Mac apps have it.
  private func addMenuItem(_ controller: SPUStandardUpdaterController) {
    guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
    let item = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
      keyEquivalent: "")
    item.target = controller  // it disables the item while a check runs
    appMenu.insertItem(item, at: min(1, appMenu.items.count))
  }

  /// The Flutter side, once its engine runs.
  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "kumo/updates", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "install":
        // The Flutter side stopped kumod already: with no update waiting,
        // still come back rather than stay without a daemon.
        if let install = self?.installNow { install() } else { Updates.relaunch() }
        result(nil)
      case "relaunch":
        Updates.relaunch()
        result(nil)
      case "check":
        self?.controller?.checkForUpdates(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    if let version = readyVersion {
      channel.invokeMethod("ready", arguments: version)
    }
  }

  /// Quits and opens this bundle again once this process is gone (two copies
  /// of Kumo never run at once).
  static func relaunch() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = [
      "-c", "while kill -0 \"$0\" 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$1\"",
      String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
    ]
    do {
      try task.run()
    } catch {
      NSLog("Kumo: relaunch failed: %@", error.localizedDescription)
      return
    }
    NSApp.terminate(nil)
  }

  func updater(
    _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    NSLog("Kumo: update %@ downloaded, installs on quit", item.displayVersionString)
    installNow = immediateInstallHandler
    readyVersion = item.displayVersionString
    channel?.invokeMethod("ready", arguments: item.displayVersionString)
    return true  // the UI shows it, not Sparkle
  }
}
