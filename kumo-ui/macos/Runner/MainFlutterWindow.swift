import Cocoa
import UniformTypeIdentifiers
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  /// Key under which macOS remembers the window's last size and position.
  private static let frameName = "KumoMainWindow"

  private let pasteboard = Pasteboard()

  // MARK: Dropping files

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return Pasteboard.files(sender.draggingPasteboard).isEmpty ? [] : .copy
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    return draggingEntered(sender)
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let files = Pasteboard.files(sender.draggingPasteboard)
    guard !files.isEmpty, let view = contentView else { return false }
    // Flutter's coordinates: points from the top left of its view.
    let p = view.convert(sender.draggingLocation, from: nil)
    let y = view.isFlipped ? p.y : view.bounds.height - p.y
    pasteboard.drop(files: files, x: Double(p.x), y: Double(y))
    return true
  }

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
    self.delegate = self

    RegisterGeneratedPlugins(registry: flutterViewController)
    (NSApp.delegate as? AppDelegate)?.updates.attach(
      messenger: flutterViewController.engine.binaryMessenger)
    pasteboard.attach(messenger: flutterViewController.engine.binaryMessenger)
    // Files dragged from Finder land on the terminal under the pointer.
    self.registerForDraggedTypes([.fileURL])

    super.awakeFromNib()
  }

  /// Full screen: the toolbar (where the traffic lights sit) hides with the
  /// menu bar. Kept, macOS draws it opaque over the top of our content.
  func window(
    _ window: NSWindow,
    willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []
  ) -> NSApplication.PresentationOptions {
    return proposedOptions.union([.fullScreen, .autoHideMenuBar, .autoHideToolbar])
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

/// The clipboard and dropped files for the terminal (`lib/platform/pasteboard.dart`).
///
/// A terminal only takes text: files go in as their paths and an image (a
/// screenshot) as a PNG saved for it, which is how Claude Code and the like
/// attach them.
final class Pasteboard {
  private var channel: FlutterMethodChannel?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "kumo/pasteboard", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "paths":
        result(Pasteboard.paths(NSPasteboard.general))
      case "chooseFile":
        // A file to read (an agent's .md to import): the system's open panel.
        let args = call.arguments as? [String: Any]
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = args?["message"] as? String ?? ""
        let exts = args?["extensions"] as? [String] ?? []
        if !exts.isEmpty {
          if #available(macOS 11.0, *) {
            panel.allowedContentTypes = exts.compactMap { UTType(filenameExtension: $0) }
          } else {
            panel.allowedFileTypes = exts
          }
        }
        result(panel.runModal() == .OK ? panel.url?.path : nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func drop(files: [String], x: Double, y: Double) {
    channel?.invokeMethod("drop", arguments: ["paths": files, "x": x, "y": y])
  }

  /// What ⌘V pastes as paths: copied files, or an image with no text. Nil
  /// when the clipboard's text is what goes in.
  static func paths(_ board: NSPasteboard) -> [String]? {
    let files = files(board)
    if !files.isEmpty { return files }
    if board.string(forType: .string) != nil { return nil }
    guard let image = NSImage(pasteboard: board), let path = save(image) else { return nil }
    return [path]
  }

  static func files(_ board: NSPasteboard) -> [String] {
    let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
    return (urls ?? []).map { $0.path }
  }

  /// The image as a PNG under the temporary folder; the ones from earlier
  /// days go.
  private static func save(_ image: NSImage) -> String? {
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else { return nil }
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("kumo-paste", isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let old = Date().addingTimeInterval(-24 * 3600)
    for file in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
      let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      if let date = date, date < old { try? fm.removeItem(at: file) }
    }
    let stamp = DateFormatter()
    stamp.dateFormat = "yyyyMMdd-HHmmss-SSS"
    let file = dir.appendingPathComponent("image-\(stamp.string(from: Date())).png")
    do {
      try png.write(to: file)
    } catch {
      NSLog("Kumo: saving the pasted image failed: %@", error.localizedDescription)
      return nil
    }
    return file.path
  }
}
