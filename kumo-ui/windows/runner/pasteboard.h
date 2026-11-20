#ifndef RUNNER_PASTEBOARD_H_
#define RUNNER_PASTEBOARD_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>

// The clipboard and dropped files for the terminal
// (lib/platform/pasteboard.dart), as the macOS runner does them
// (MainFlutterWindow.swift).
//
// A terminal only takes text: files go in as their paths and an image (a
// screenshot) as a PNG saved for it, which is how Claude Code and the like
// attach them.
//
// "kumo/pasteboard":
//   "paths" -> [String] of copied files, or [the saved PNG] for an image with
//              no text; null when the clipboard's text is what goes in.
//   "drop" <- {"paths": [String], "x": double, "y": double}, files dropped on
//             the window at (x, y), logical pixels from its top left.
class Pasteboard {
 public:
  // Answers the channel and takes files dropped on |window|.
  Pasteboard(flutter::BinaryMessenger* messenger, HWND window);
  ~Pasteboard();

  Pasteboard(const Pasteboard&) = delete;
  Pasteboard& operator=(const Pasteboard&) = delete;

  // WM_DROPFILES on the window: the files go to Flutter.
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  void Drop(HDROP drop);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_PASTEBOARD_H_
