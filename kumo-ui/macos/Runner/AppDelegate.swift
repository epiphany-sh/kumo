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
/// Sparkle checks and downloads in the background; once an update waits to
/// be installed the UI hears of it ("ready") and offers a restart
/// ("install"). Without that click it installs when Kumo quits.
final class Updates: NSObject, SPUUpdaterDelegate {
  private var controller: SPUStandardUpdaterController?
  private var channel: FlutterMethodChannel?
  private var installNow: (() -> Void)?
  private var readyVersion: String?

  func start() {
    let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    guard !feed.isEmpty else { return }
    controller = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
  }

  /// The Flutter side, once its engine runs.
  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "kumo/updates", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "install":
        self?.installNow?()
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
