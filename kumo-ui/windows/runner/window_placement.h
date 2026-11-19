#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

// Where Kumo's window opens and how small it gets, like MainFlutterWindow.swift
// on macOS: a roomy default centered on the primary screen, never smaller
// than what the sidebar + terminal + side panel need, and reopened where
// the user left it (HKCU\Software\Kumo\WindowPlacement).

// The smallest client area, in logical pixels (macOS: contentMinSize).
constexpr int kMinWindowWidth = 980;
constexpr int kMinWindowHeight = 640;

// The first launch's size, in logical pixels, clamped to the work area.
constexpr int kDefaultWindowWidth = 1440;
constexpr int kDefaultWindowHeight = 920;

// The default frame in logical pixels (what Win32Window::Create takes):
// kDefaultWindowWidth x kDefaultWindowHeight, or less on a small
// screen, centered on the primary monitor's work area.
void DefaultWindowFrame(int* x, int* y, int* width, int* height);

// Moves the (hidden) |window| to where it was when it last closed. Returns
// the show command for it (maximized or normal); SW_SHOWNORMAL when nothing
// was saved or the saved frame is on no monitor anymore.
int RestoreWindowPlacement(HWND window);

// Saves where |window| is, for RestoreWindowPlacement.
void SaveWindowPlacement(HWND window);

// Fills |info|'s minimum tracking size from kMinWindow* at |window|'s DPI,
// no larger than the work area of the monitor |window| is on.
void ApplyMinWindowSize(HWND window, MINMAXINFO* info);

#endif  // RUNNER_WINDOW_PLACEMENT_H_
