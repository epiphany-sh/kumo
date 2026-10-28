//! `kumo-echo`: tiny cross-platform helper for the benchmarks, so Windows
//! (no `sh`/`stty`/`cat`) runs the same scenarios.
//!
//! - `kumo-echo`: raw mode, prints `READY`, echoes every byte back.
//! - `kumo-echo flood <bytes>`: prints `READY`, waits for one byte of
//!   input, writes `<bytes>` of `x` and exits.

use std::io::{Read, Write};

fn main() -> std::io::Result<()> {
    raw_mode::enable()?;
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.as_slice() {
        [] => echo(),
        [mode, bytes] if mode == "flood" => {
            let bytes = bytes.parse().map_err(std::io::Error::other)?;
            flood(bytes)
        }
        _ => Err(std::io::Error::other("usage: kumo-echo [flood <bytes>]")),
    }
}

fn echo() -> std::io::Result<()> {
    let (mut stdin, mut stdout) = (std::io::stdin().lock(), std::io::stdout().lock());
    stdout.write_all(b"READY")?;
    stdout.flush()?;
    let mut buffer = [0_u8; 4096];
    loop {
        let n = stdin.read(&mut buffer)?;
        if n == 0 {
            return Ok(());
        }
        stdout.write_all(&buffer[..n])?;
        stdout.flush()?;
    }
}

fn flood(mut remaining: u64) -> std::io::Result<()> {
    let (mut stdin, mut stdout) = (std::io::stdin().lock(), std::io::stdout().lock());
    stdout.write_all(b"READY")?;
    stdout.flush()?;
    stdin.read_exact(&mut [0_u8; 1])?;
    let block = [b'x'; 64 * 1024];
    while remaining > 0 {
        let n = remaining.min(block.len() as u64) as usize;
        stdout.write_all(&block[..n])?;
        remaining -= n as u64;
    }
    stdout.flush()
}

/// Puts the controlling terminal in raw mode: no line buffering, no echo.
#[allow(unsafe_code)]
mod raw_mode {
    #[cfg(unix)]
    pub fn enable() -> std::io::Result<()> {
        // SAFETY: termios is plain data; fd 0 is our stdin, and we only pass
        // pointers to a valid, live termios struct.
        unsafe {
            let mut termios: libc::termios = std::mem::zeroed();
            if libc::tcgetattr(libc::STDIN_FILENO, &mut termios) != 0 {
                return Err(std::io::Error::last_os_error());
            }
            libc::cfmakeraw(&mut termios);
            if libc::tcsetattr(libc::STDIN_FILENO, libc::TCSANOW, &termios) != 0 {
                return Err(std::io::Error::last_os_error());
            }
        }
        Ok(())
    }

    #[cfg(windows)]
    pub fn enable() -> std::io::Result<()> {
        use windows_sys::Win32::System::Console::{
            ENABLE_ECHO_INPUT, ENABLE_LINE_INPUT, ENABLE_PROCESSED_INPUT,
            ENABLE_VIRTUAL_TERMINAL_INPUT, GetConsoleMode, GetStdHandle, STD_INPUT_HANDLE,
            SetConsoleMode,
        };
        // SAFETY: the handle comes from GetStdHandle and `mode` outlives the
        // call that writes it.
        unsafe {
            let input = GetStdHandle(STD_INPUT_HANDLE);
            let mut mode = 0;
            if GetConsoleMode(input, &mut mode) == 0 {
                return Err(std::io::Error::last_os_error());
            }
            mode &= !(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT);
            mode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
            if SetConsoleMode(input, mode) == 0 {
                return Err(std::io::Error::last_os_error());
            }
        }
        Ok(())
    }
}
