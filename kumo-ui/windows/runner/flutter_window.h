#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The icon chosen in Settings > Appearance (lib/platform/app_icon.dart),
  // on the window and its taskbar button. "kumo" is the exe's own; false
  // when there is no icon by that name.
  bool SetAppIcon(const std::string& name);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      app_icon_channel_;

  // The icons set with SetAppIcon, destroyed once replaced.
  HICON big_icon_ = nullptr;
  HICON small_icon_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
