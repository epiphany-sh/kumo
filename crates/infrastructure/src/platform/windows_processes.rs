//! Other processes, read through Win32 and ntdll: Windows has no `ps`,
//! and its WMI is far too slow to ask every second. The only unsafe code
//! of the crate, kept to these calls; each checks what it reads.

use std::ffi::c_void;
use std::path::PathBuf;

use windows_sys::Wdk::System::Threading::{
    NtQueryInformationProcess, ProcessBasicInformation, ProcessCommandLineInformation,
    ProcessWow64Information,
};
use windows_sys::Win32::Foundation::{CloseHandle, FILETIME, HANDLE, INVALID_HANDLE_VALUE};
use windows_sys::Win32::System::Diagnostics::Debug::ReadProcessMemory;
use windows_sys::Win32::System::Diagnostics::ToolHelp::{
    CreateToolhelp32Snapshot, PROCESSENTRY32W, Process32FirstW, Process32NextW, TH32CS_SNAPPROCESS,
};
use windows_sys::Win32::System::Threading::{
    GetProcessTimes, OpenProcess, PROCESS_NAME_WIN32, PROCESS_QUERY_INFORMATION,
    PROCESS_QUERY_LIMITED_INFORMATION, PROCESS_VM_READ, QueryFullProcessImageNameW,
};

use super::process_tree::ProcessRow;

/// A handle, closed when dropped.
struct Handle(HANDLE);

impl Handle {
    fn open(pid: u32, access: u32) -> Option<Self> {
        // SAFETY: no pointers; a null handle is checked.
        let handle = unsafe { OpenProcess(access, 0, pid) };
        (!handle.is_null()).then_some(Self(handle))
    }
}

impl Drop for Handle {
    fn drop(&mut self) {
        // SAFETY: a handle this owns, closed once.
        unsafe { CloseHandle(self.0) };
    }
}

/// Every process: pid, parent and executable name, in one snapshot.
/// `created` is left None: [`created`] reads it for the few that need it.
pub(super) fn snapshot() -> Vec<ProcessRow> {
    // SAFETY: no pointers; the handle is checked.
    let raw = unsafe { CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0) };
    if raw == INVALID_HANDLE_VALUE || raw.is_null() {
        return Vec::new();
    }
    let snapshot = Handle(raw);
    let mut rows = Vec::new();
    let mut entry = PROCESSENTRY32W {
        dwSize: u32::try_from(size_of::<PROCESSENTRY32W>()).unwrap_or(0),
        ..PROCESSENTRY32W::default()
    };
    // SAFETY: `entry` is a PROCESSENTRY32W with its size set, as asked.
    let mut more = unsafe { Process32FirstW(snapshot.0, &raw mut entry) } != 0;
    while more {
        let name = &entry.szExeFile;
        let len = name.iter().position(|c| *c == 0).unwrap_or(name.len());
        rows.push(ProcessRow {
            pid: entry.th32ProcessID,
            ppid: entry.th32ParentProcessID,
            name: String::from_utf16_lossy(&name[..len]),
            created: None,
        });
        // SAFETY: as above.
        more = unsafe { Process32NextW(snapshot.0, &raw mut entry) } != 0;
    }
    rows
}

/// When `pid` started, in 100 ns since 1601.
pub(super) fn created(pid: u32) -> Option<u64> {
    let process = Handle::open(pid, PROCESS_QUERY_LIMITED_INFORMATION)?;
    let zero = FILETIME {
        dwLowDateTime: 0,
        dwHighDateTime: 0,
    };
    let (mut created, mut exited, mut kernel, mut user) = (zero, zero, zero, zero);
    // SAFETY: four FILETIMEs this owns.
    let ok = unsafe {
        GetProcessTimes(
            process.0,
            &raw mut created,
            &raw mut exited,
            &raw mut kernel,
            &raw mut user,
        )
    };
    (ok != 0).then(|| u64::from(created.dwHighDateTime) << 32 | u64::from(created.dwLowDateTime))
}

/// The full path of `pid`'s executable.
pub(super) fn exe(pid: u32) -> Option<PathBuf> {
    let process = Handle::open(pid, PROCESS_QUERY_LIMITED_INFORMATION)?;
    let mut buffer = vec![0u16; 32 * 1024];
    let mut len = u32::try_from(buffer.len()).ok()?;
    // SAFETY: `buffer` holds `len` u16s; the call writes back how many it used.
    let ok = unsafe {
        QueryFullProcessImageNameW(
            process.0,
            PROCESS_NAME_WIN32,
            buffer.as_mut_ptr(),
            &raw mut len,
        )
    };
    let len = usize::try_from(len).ok()?.min(buffer.len());
    (ok != 0).then(|| PathBuf::from(String::from_utf16_lossy(&buffer[..len])))
}

/// `STATUS_INFO_LENGTH_MISMATCH`: the buffer was too small.
const INFO_LENGTH_MISMATCH: i32 = 0xC000_0004_u32.cast_signed();

/// `pid`'s command line, as it was started with (Windows 8.1 and later).
pub(super) fn command_line(pid: u32) -> Option<String> {
    let process = Handle::open(pid, PROCESS_QUERY_LIMITED_INFORMATION)?;
    let mut needed = 0u32;
    // SAFETY: asks for the size only: no buffer.
    let status = unsafe {
        NtQueryInformationProcess(
            process.0,
            ProcessCommandLineInformation,
            std::ptr::null_mut(),
            0,
            &raw mut needed,
        )
    };
    if status != INFO_LENGTH_MISMATCH || needed == 0 {
        return None;
    }
    // u64s: aligned for the UNICODE_STRING at its start.
    let mut buffer = vec![0u64; usize::try_from(needed).ok()?.div_ceil(8)];
    let size = u32::try_from(buffer.len() * 8).ok()?;
    // SAFETY: `buffer` holds `size` bytes.
    let status = unsafe {
        NtQueryInformationProcess(
            process.0,
            ProcessCommandLineInformation,
            buffer.as_mut_ptr().cast::<c_void>(),
            size,
            &raw mut needed,
        )
    };
    if status < 0 {
        return None;
    }
    let bytes: Vec<u8> = buffer.iter().flat_map(|w| w.to_ne_bytes()).collect();
    // A UNICODE_STRING (length in bytes, then a pointer) whose text
    // follows it in the same buffer.
    let len = usize::from(u16::from_ne_bytes([bytes[0], bytes[1]]));
    let pointer = usize::from_ne_bytes(bytes[8..16].try_into().ok()?);
    let start = pointer.checked_sub(buffer.as_ptr() as usize)?;
    let text = bytes.get(start..start.checked_add(len)?)?;
    Some(utf16(text))
}

/// UTF-16 bytes as text.
fn utf16(bytes: &[u8]) -> String {
    let units: Vec<u16> = bytes
        .as_chunks::<2>()
        .0
        .iter()
        .map(|pair| u16::from_ne_bytes(*pair))
        .collect();
    String::from_utf16_lossy(&units)
}

/// `size` bytes at `address` in `process`.
fn read(process: &Handle, address: usize, size: usize) -> Option<Vec<u8>> {
    let mut bytes = vec![0u8; size];
    let mut done = 0usize;
    // SAFETY: `bytes` holds `size` bytes; the other process's memory is
    // only read, and a bad address fails the call.
    let ok = unsafe {
        ReadProcessMemory(
            process.0,
            address as *const c_void,
            bytes.as_mut_ptr().cast::<c_void>(),
            size,
            &raw mut done,
        )
    };
    (ok != 0 && done == size).then_some(bytes)
}

fn word(bytes: &[u8]) -> Option<usize> {
    Some(usize::from_ne_bytes(
        bytes.get(..size_of::<usize>())?.try_into().ok()?,
    ))
}

/// Where `pid` is (its current directory), read from its process
/// parameters: Windows has no call for it. 64-bit processes only (the
/// offsets below are theirs); a 32-bit one gives None.
#[cfg(target_pointer_width = "64")]
pub(super) fn cwd(pid: u32) -> Option<PathBuf> {
    /// `PEB.ProcessParameters`.
    const PARAMETERS: usize = 0x20;
    /// `RTL_USER_PROCESS_PARAMETERS.CurrentDirectory.DosPath`.
    const CURRENT_DIRECTORY: usize = 0x38;
    /// The longest path Windows takes, in bytes.
    const LONGEST: usize = 32 * 1024 * 2;

    let process = Handle::open(pid, PROCESS_QUERY_INFORMATION | PROCESS_VM_READ)?;
    let mut info = [0usize; 6];
    let mut wow64 = 0usize;
    let mut returned = 0u32;
    // SAFETY: `wow64` and `info` (PROCESS_BASIC_INFORMATION's six words)
    // are this function's, of the sizes given.
    let (wow64_status, status) = unsafe {
        (
            NtQueryInformationProcess(
                process.0,
                ProcessWow64Information,
                (&raw mut wow64).cast::<c_void>(),
                u32::try_from(size_of::<usize>()).ok()?,
                &raw mut returned,
            ),
            NtQueryInformationProcess(
                process.0,
                ProcessBasicInformation,
                info.as_mut_ptr().cast::<c_void>(),
                u32::try_from(size_of_val(&info)).ok()?,
                &raw mut returned,
            ),
        )
    };
    if wow64_status < 0 || wow64 != 0 || status < 0 {
        return None;
    }
    let peb = info[1];
    let parameters = word(&read(&process, peb.checked_add(PARAMETERS)?, 8)?)?;
    // UNICODE_STRING: length in bytes, maximum, padding, then the pointer.
    let path = read(&process, parameters.checked_add(CURRENT_DIRECTORY)?, 16)?;
    let len = usize::from(u16::from_ne_bytes([path[0], path[1]]));
    if len == 0 || len > LONGEST || len % 2 != 0 {
        return None;
    }
    let text = utf16(&read(&process, word(&path[8..])?, len)?);
    // `C:\x\` → `C:\x`; `C:\` stays.
    let trimmed = match text.strip_suffix('\\') {
        Some(rest) if !rest.ends_with(':') => rest.to_owned(),
        _ => text,
    };
    Some(PathBuf::from(trimmed))
}

#[cfg(not(target_pointer_width = "64"))]
pub(super) fn cwd(_pid: u32) -> Option<PathBuf> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_this_process_and_finds_its_parent() {
        let me = std::process::id();
        let rows = snapshot();
        let row = rows.iter().find(|r| r.pid == me).expect("in the snapshot");
        assert!(row.name.to_ascii_lowercase().ends_with(".exe"), "{row:?}");
        assert!(
            rows.iter().any(|r| r.pid == row.ppid),
            "the parent ({}) is listed",
            row.ppid
        );
        assert!(created(me).is_some());

        let exe = exe(me).unwrap();
        assert_eq!(exe, std::env::current_exe().unwrap());
        let line = command_line(me).unwrap();
        let args = super::super::process_tree::split_command_line(&line);
        let expected: Vec<String> = std::env::args().skip(1).collect();
        assert_eq!(args[1..], expected[..], "{line}");
        let cwd = cwd(me).unwrap();
        assert_eq!(
            super::super::canonical(cwd),
            super::super::canonical(std::env::current_dir().unwrap())
        );
    }

    #[test]
    fn reads_a_child_and_nothing_of_a_gone_one() {
        let dir = tempfile::tempdir().unwrap();
        let mut child = std::process::Command::new("cmd.exe")
            .args(["/d", "/q", "/k", "rem waiting for \"Kumo\""])
            .current_dir(dir.path())
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::null())
            .spawn()
            .unwrap();
        let pid = child.id();
        let line = command_line(pid).unwrap();
        let args = super::super::process_tree::split_command_line(&line);
        assert_eq!(args[1..], ["/d", "/q", "/k", r#"rem waiting for "Kumo""#]);
        assert_eq!(
            super::super::canonical(cwd(pid).unwrap()),
            super::super::canonical(dir.path())
        );
        let row = snapshot().into_iter().find(|r| r.pid == pid).unwrap();
        assert_eq!(row.ppid, std::process::id());

        child.kill().unwrap();
        child.wait().unwrap();
        assert_eq!(command_line(pid), None);
        assert_eq!(exe(pid), None);
    }
}
