#include "window_placement.h"

#include <flutter_windows.h>

#include <algorithm>

namespace {

constexpr wchar_t kKey[] = L"Software\\Kumo";
constexpr wchar_t kValue[] = L"WindowPlacement";

double ScaleOf(HMONITOR monitor) {
  return FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
}

}  // namespace

void DefaultWindowFrame(int* x, int* y, int* width, int* height) {
  const POINT origin = {0, 0};
  HMONITOR primary = MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info = {sizeof(info)};
  const double scale = ScaleOf(primary);
  if (!GetMonitorInfo(primary, &info)) {
    *x = 10;
    *y = 10;
    *width = kDefaultWindowWidth;
    *height = kDefaultWindowHeight;
    return;
  }
  // The work area is in physical pixels; Win32Window::Create scales back.
  const RECT& work = info.rcWork;
  const int work_width = static_cast<int>((work.right - work.left) / scale);
  const int work_height = static_cast<int>((work.bottom - work.top) / scale);
  *width = std::min(kDefaultWindowWidth, work_width);
  *height = std::min(kDefaultWindowHeight, work_height);
  *x = static_cast<int>(work.left / scale) + (work_width - *width) / 2;
  *y = static_cast<int>(work.top / scale) + (work_height - *height) / 2;
}

int RestoreWindowPlacement(HWND window) {
  WINDOWPLACEMENT placement = {};
  DWORD size = sizeof(placement);
  if (RegGetValueW(HKEY_CURRENT_USER, kKey, kValue, RRF_RT_REG_BINARY,
                   nullptr, &placement, &size) != ERROR_SUCCESS ||
      size != sizeof(placement) || placement.length != sizeof(placement)) {
    return SW_SHOWNORMAL;
  }
  RECT& frame = placement.rcNormalPosition;
  if (frame.right - frame.left <= 0 || frame.bottom - frame.top <= 0 ||
      MonitorFromRect(&frame, MONITOR_DEFAULTTONULL) == nullptr) {
    // A monitor that was unplugged: the default frame stays.
    return SW_SHOWNORMAL;
  }
  const bool maximized = placement.showCmd == SW_SHOWMAXIMIZED;
  // Still hidden: the first Flutter frame shows it.
  placement.showCmd = SW_HIDE;
  placement.flags = 0;
  if (!SetWindowPlacement(window, &placement)) {
    return SW_SHOWNORMAL;
  }
  return maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
}

void SaveWindowPlacement(HWND window) {
  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window, &placement)) {
    return;
  }
  // Minimized when closed (from the taskbar): reopen as it was before.
  if (placement.showCmd == SW_SHOWMINIMIZED || placement.showCmd == SW_MINIMIZE) {
    placement.showCmd = (placement.flags & WPF_RESTORETOMAXIMIZED)
                            ? SW_SHOWMAXIMIZED
                            : SW_SHOWNORMAL;
  }
  RegSetKeyValueW(HKEY_CURRENT_USER, kKey, kValue, REG_BINARY, &placement,
                  sizeof(placement));
}

void ApplyMinWindowSize(HWND window, MINMAXINFO* info) {
  HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  const double scale = ScaleOf(monitor);
  // The client area's minimum plus the frame around it.
  RECT frame = {0, 0, static_cast<LONG>(kMinWindowWidth * scale),
                static_cast<LONG>(kMinWindowHeight * scale)};
  AdjustWindowRectEx(&frame, static_cast<DWORD>(GetWindowLongPtr(window, GWL_STYLE)),
                     FALSE, static_cast<DWORD>(GetWindowLongPtr(window, GWL_EXSTYLE)));
  LONG width = frame.right - frame.left;
  LONG height = frame.bottom - frame.top;
  // Never more than the monitor's work area (both in physical pixels at its
  // DPI): on a small screen (1366x768 at 125%) the minimum would otherwise
  // push the window past the taskbar or off the screen.
  MONITORINFO monitor_info = {sizeof(monitor_info)};
  if (GetMonitorInfo(monitor, &monitor_info)) {
    const RECT& work = monitor_info.rcWork;
    width = std::min(width, work.right - work.left);
    height = std::min(height, work.bottom - work.top);
  }
  info->ptMinTrackSize.x = width;
  info->ptMinTrackSize.y = height;
}
