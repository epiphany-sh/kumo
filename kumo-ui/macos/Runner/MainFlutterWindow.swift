import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Key under which macOS remembers the window's last size and position.
  private static let frameName = "KumoMainWindow"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Never smaller than what the sidebar + terminal + side panel need.
    self.contentMinSize = NSSize(width: 980, height: 640)

    // Reopen where the user left it; the first launch gets a roomy default.
    if !self.setFrameUsingName(MainFlutterWindow.frameName) {
      self.setFrame(MainFlutterWindow.defaultFrame(for: self.screen ?? NSScreen.main), display: true)
    }
    self.setFrameAutosaveName(MainFlutterWindow.frameName)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// 1440×920 (the size the UI is designed at), shrunk to 92% of the
  /// visible screen on smaller displays, centered.
  private static func defaultFrame(for screen: NSScreen?) -> NSRect {
    let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let width = min(1440, visible.width * 0.92)
    let height = min(920, visible.height * 0.92)
    return NSRect(
      x: visible.midX - width / 2,
      y: visible.midY - height / 2,
      width: width,
      height: height
    )
  }
}
