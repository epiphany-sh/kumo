import Cocoa
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate {
  let updates = Updates()

  override func applicationDidFinishLaunching(_ notification: Notification) {
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
