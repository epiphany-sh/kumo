#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  app_icon_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "kumo/app_icon",
          &flutter::StandardMethodCodec::GetInstance());
  app_icon_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "set") {
          result->NotImplemented();
          return;
        }
        const auto* name = std::get_if<std::string>(call.arguments());
        result->Success(
            flutter::EncodableValue(name != nullptr && SetAppIcon(*name)));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  app_icon_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  if (big_icon_) {
    DestroyIcon(big_icon_);
    big_icon_ = nullptr;
  }
  if (small_icon_) {
    DestroyIcon(small_icon_);
    small_icon_ = nullptr;
  }

  Win32Window::OnDestroy();
}

bool FlutterWindow::SetAppIcon(const std::string& name) {
  // The icons in Runner.rc, by the names the Flutter side uses: one that
  // ships with Kumo goes there and here.
  int id = 0;
  if (name == "kumo") {
    id = IDI_APP_ICON;
  } else {
    return false;
  }
  HINSTANCE instance = GetModuleHandle(nullptr);
  HICON big_icon = static_cast<HICON>(
      LoadImage(instance, MAKEINTRESOURCE(id), IMAGE_ICON,
                GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), 0));
  HICON small_icon = static_cast<HICON>(LoadImage(
      instance, MAKEINTRESOURCE(id), IMAGE_ICON,
      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0));
  if (!big_icon || !small_icon) {
    if (big_icon) DestroyIcon(big_icon);
    if (small_icon) DestroyIcon(small_icon);
    return false;
  }
  HWND window = GetHandle();
  SendMessage(window, WM_SETICON, ICON_BIG,
              reinterpret_cast<LPARAM>(big_icon));
  SendMessage(window, WM_SETICON, ICON_SMALL,
              reinterpret_cast<LPARAM>(small_icon));
  if (big_icon_) DestroyIcon(big_icon_);
  if (small_icon_) DestroyIcon(small_icon_);
  big_icon_ = big_icon;
  small_icon_ = small_icon;
  return true;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
