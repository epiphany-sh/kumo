#include "pasteboard.h"

#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <shellapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <chrono>
#include <cstdio>
#include <cwctype>
#include <filesystem>
#include <fstream>
#include <string>
#include <system_error>
#include <vector>

#include "utils.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;
namespace fs = std::filesystem;

// Whether [path] can be a file a drop or a copy names: absolute (`X:\` or
// `\\`), with no `"` or control character (C0, DEL, C1), and there. A
// forged list can hold anything, and what's left reaches the terminal.
bool IsRealPath(const std::wstring& path) {
  for (const wchar_t c : path) {
    if (c < 0x20 || (c >= 0x7F && c <= 0x9F) || c == L'"') return false;
  }
  const bool drive = path.size() >= 3 && iswalpha(path[0]) && path[1] == L':' &&
                     path[2] == L'\\';
  const bool unc = path.size() >= 2 && path[0] == L'\\' && path[1] == L'\\';
  if (!drive && !unc) return false;
  return GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES;
}

// The paths in a list of files (a drop, or files copied in Explorer), UTF-8;
// those no real file has are left out (IsRealPath).
std::vector<std::string> FilesIn(HDROP files) {
  std::vector<std::string> paths;
  const UINT count = DragQueryFileW(files, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < count; ++i) {
    const UINT length = DragQueryFileW(files, i, nullptr, 0);
    if (length == 0) continue;
    std::wstring path(length + 1, L'\0');
    DragQueryFileW(files, i, path.data(), length + 1);
    path.resize(length);
    if (!IsRealPath(path)) continue;
    std::string utf8 = Utf8FromUtf16(path.c_str());
    if (!utf8.empty()) paths.push_back(std::move(utf8));
  }
  return paths;
}

EncodableValue ListOf(const std::vector<std::string>& paths) {
  EncodableList list;
  for (const auto& path : paths) list.emplace_back(path);
  return EncodableValue(list);
}

// The clipboard, open for as long as this lives. Another app may hold it
// for a moment, so opening retries briefly.
class ClipboardLock {
 public:
  explicit ClipboardLock(HWND owner) {
    for (int attempt = 0; attempt < 5 && !open_; ++attempt) {
      open_ = OpenClipboard(owner) != 0;
      if (!open_) Sleep(10);
    }
  }
  ~ClipboardLock() {
    if (open_) CloseClipboard();
  }
  ClipboardLock(const ClipboardLock&) = delete;
  ClipboardLock& operator=(const ClipboardLock&) = delete;

  bool open() const { return open_; }

 private:
  bool open_ = false;
};

// %TEMP%\kumo-paste, as the macOS runner's temporary "kumo-paste" folder;
// the images from earlier days go.
fs::path PasteFolder() {
  wchar_t temp[MAX_PATH + 1];
  const DWORD length = GetTempPathW(MAX_PATH + 1, temp);
  if (length == 0 || length > MAX_PATH) return {};
  fs::path dir = fs::path(temp) / L"kumo-paste";
  std::error_code error;
  fs::create_directories(dir, error);
  const auto old = fs::file_time_type::clock::now() - std::chrono::hours(24);
  for (const auto& entry : fs::directory_iterator(dir, error)) {
    std::error_code ignored;
    if (entry.last_write_time(ignored) < old) fs::remove(entry.path(), ignored);
  }
  return dir;
}

// image-yyyyMMdd-HHmmss-SSS.png in local time, as on macOS.
fs::path NewImagePath(const fs::path& dir) {
  SYSTEMTIME now;
  GetLocalTime(&now);
  wchar_t name[64];
  swprintf_s(name, L"image-%04u%02u%02u-%02u%02u%02u-%03u.png", now.wYear,
             now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond,
             now.wMilliseconds);
  return dir / name;
}

bool WriteBytes(const fs::path& file, const void* data, size_t size) {
  std::ofstream out(file, std::ios::binary | std::ios::trunc);
  out.write(static_cast<const char*>(data), static_cast<std::streamsize>(size));
  return out.good();
}

// Clipboard data in the registered "PNG" format (browsers, Snipping Tool),
// as it is: it keeps transparency.
bool SavePngData(HANDLE data, const fs::path& file) {
  const SIZE_T size = GlobalSize(data);
  const void* bytes = GlobalLock(data);
  if (bytes == nullptr) return false;
  const bool saved = size > 0 && WriteBytes(file, bytes, size);
  GlobalUnlock(data);
  return saved;
}

// A bitmap (CF_BITMAP, which Windows also makes from CF_DIB / CF_DIBV5)
// encoded as a PNG with WIC.
bool SaveBitmap(HBITMAP bitmap, const fs::path& file) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) {
    return false;
  }
  ComPtr<IWICBitmap> source;
  if (FAILED(factory->CreateBitmapFromHBITMAP(bitmap, nullptr,
                                              WICBitmapIgnoreAlpha, &source))) {
    return false;
  }
  UINT width = 0, height = 0;
  ComPtr<IWICStream> stream;
  ComPtr<IWICBitmapEncoder> encoder;
  ComPtr<IWICBitmapFrameEncode> frame;
  ComPtr<IWICFormatConverter> converter;
  WICPixelFormatGUID format = GUID_WICPixelFormat24bppBGR;
  const bool saved =
      SUCCEEDED(source->GetSize(&width, &height)) &&
      SUCCEEDED(factory->CreateStream(&stream)) &&
      SUCCEEDED(stream->InitializeFromFilename(file.c_str(), GENERIC_WRITE)) &&
      SUCCEEDED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                       &encoder)) &&
      SUCCEEDED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)) &&
      SUCCEEDED(encoder->CreateNewFrame(&frame, nullptr)) &&
      SUCCEEDED(frame->Initialize(nullptr)) &&
      SUCCEEDED(frame->SetSize(width, height)) &&
      SUCCEEDED(frame->SetPixelFormat(&format)) &&
      SUCCEEDED(factory->CreateFormatConverter(&converter)) &&
      SUCCEEDED(converter->Initialize(source.Get(), format,
                                      WICBitmapDitherTypeNone, nullptr, 0.0,
                                      WICBitmapPaletteTypeCustom)) &&
      SUCCEEDED(frame->WriteSource(converter.Get(), nullptr)) &&
      SUCCEEDED(frame->Commit()) && SUCCEEDED(encoder->Commit());
  if (!saved) {
    // Release the file before removing what was written of it.
    frame.Reset();
    encoder.Reset();
    stream.Reset();
    std::error_code ignored;
    fs::remove(file, ignored);
  }
  return saved;
}

// The image on the clipboard saved as a PNG; empty when there is none or
// it couldn't be saved. The clipboard is open.
std::string SaveClipboardImage() {
  const UINT png = RegisterClipboardFormatW(L"PNG");
  const bool has_png = png != 0 && IsClipboardFormatAvailable(png);
  if (!has_png && !IsClipboardFormatAvailable(CF_BITMAP)) return {};
  const fs::path dir = PasteFolder();
  if (dir.empty()) return {};
  const fs::path file = NewImagePath(dir);
  bool saved = false;
  if (has_png) {
    if (HANDLE data = GetClipboardData(png)) saved = SavePngData(data, file);
  }
  if (!saved && IsClipboardFormatAvailable(CF_BITMAP)) {
    if (auto bitmap = static_cast<HBITMAP>(GetClipboardData(CF_BITMAP))) {
      saved = SaveBitmap(bitmap, file);
    }
  }
  if (!saved) {
    OutputDebugStringW(L"Kumo: saving the pasted image failed\n");
    return {};
  }
  return Utf8FromUtf16(file.c_str());
}

// What a paste puts in as paths: copied files, or an image with no text.
// Null when the clipboard's text is what goes in.
EncodableValue ClipboardPaths(HWND owner) {
  ClipboardLock clipboard(owner);
  if (!clipboard.open()) return EncodableValue();
  if (IsClipboardFormatAvailable(CF_HDROP)) {
    if (auto files = static_cast<HDROP>(GetClipboardData(CF_HDROP))) {
      const auto paths = FilesIn(files);
      if (!paths.empty()) return ListOf(paths);
    }
  }
  if (IsClipboardFormatAvailable(CF_UNICODETEXT)) return EncodableValue();
  const std::string image = SaveClipboardImage();
  if (image.empty()) return EncodableValue();
  return ListOf({image});
}

}  // namespace

Pasteboard::Pasteboard(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "kumo/pasteboard",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "paths") {
          result->Success(ClipboardPaths(window_));
        } else {
          result->NotImplemented();
        }
      });

  // Files dragged from Explorer land on the terminal under the pointer.
  // Not while Kumo runs elevated, as in Windows Terminal: letting a
  // lower-integrity process's WM_DROPFILES through would let it type into
  // an elevated shell.
  DragAcceptFiles(window_, TRUE);
}

Pasteboard::~Pasteboard() {
  if (IsWindow(window_)) DragAcceptFiles(window_, FALSE);
  channel_->SetMethodCallHandler(nullptr);
}

std::optional<LRESULT> Pasteboard::HandleMessage(UINT message, WPARAM wparam,
                                                 LPARAM /*lparam*/) {
  if (message != WM_DROPFILES) return std::nullopt;
  Drop(reinterpret_cast<HDROP>(wparam));
  return 0;
}

void Pasteboard::Drop(HDROP drop) {
  const auto paths = FilesIn(drop);
  POINT point{};
  DragQueryPoint(drop, &point);
  DragFinish(drop);
  if (paths.empty()) return;
  // Flutter's coordinates: logical pixels from the top left of its view,
  // which fills the client area.
  const double scale =
      FlutterDesktopGetDpiForMonitor(
          MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST)) /
      96.0;
  channel_->InvokeMethod(
      "drop", std::make_unique<EncodableValue>(EncodableMap{
                  {EncodableValue("paths"), ListOf(paths)},
                  {EncodableValue("x"), EncodableValue(point.x / scale)},
                  {EncodableValue("y"), EncodableValue(point.y / scale)},
              }));
}
