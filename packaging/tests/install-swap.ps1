# Smoke test for install.ps1's swap and rollback (no Pester), on Windows:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File packaging/tests/install-swap.ps1
#
# A running kumod.exe keeps the DLLs it loaded: they can be renamed, not
# deleted. Here another process loads a real DLL from the install folder,
# and install.ps1 -From must still swap everything in, or put it all back.
$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ("kumo-swap-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$installer = Join-Path $root 'install.ps1'
(Get-Content -Raw (Join-Path $PSScriptRoot '..\install.ps1.in')).Replace('@RELEASE_REPO@', 'example/kumo') |
    Set-Content -LiteralPath $installer -Encoding ASCII
$log = Join-Path $root 'update.log'
$dll = Join-Path $env:SystemRoot 'System32\version.dll'

$script:failures = 0
function Check([bool]$Ok, [string]$What) {
    if ($Ok) { Write-Host "ok   $What" } else { Write-Host "FAIL $What"; $script:failures++ }
}

# A Kumo folder of version $Version.
function New-Kumo([string]$Dir, [string]$Version) {
    New-Item -ItemType Directory -Path (Join-Path $Dir 'data') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $Dir 'Kumo.exe') "kumo $Version"
    Set-Content -LiteralPath (Join-Path $Dir 'kumod.exe') "kumod $Version"
    Set-Content -LiteralPath (Join-Path $Dir 'data\app.so') "app $Version"
    Copy-Item -LiteralPath $dll -Destination (Join-Path $Dir 'runtime.dll')
    $Dir
}

# Another process with $Path loaded, as kumod has vcruntime140.dll.
function Start-DllHolder([string]$Path) {
    $ready = "$Path.loaded"
    $code = @"
Add-Type -Namespace Kumo -Name Native -MemberDefinition '[DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr LoadLibraryW(string path);'
if ([Kumo.Native]::LoadLibraryW('$Path') -eq [IntPtr]::Zero) { exit 1 }
Set-Content -LiteralPath '$ready' 'yes'
Start-Sleep -Seconds 300
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $holder = Start-Process powershell -ArgumentList '-NoProfile', '-EncodedCommand', $encoded -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Test-Path -LiteralPath $ready) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    Remove-Item -LiteralPath $ready -ErrorAction SilentlyContinue
    $holder
}

function Invoke-Installer([string[]]$Arguments) {
    # Its errors are expected sometimes; Windows PowerShell would throw on them.
    $ErrorActionPreference = 'Continue'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer @Arguments *> $null
    $LASTEXITCODE
}

function Read-Text([string]$Path) {
    if (Test-Path -LiteralPath $Path) { (Get-Content -Raw -LiteralPath $Path).Trim() } else { $null }
}

# A Kumo.exe that only leaves launched.txt next to itself, to see it opened.
$fakeKumo = Join-Path $root 'fake\Kumo.exe'
New-Item -ItemType Directory -Path (Split-Path $fakeKumo) | Out-Null
Add-Type -OutputAssembly $fakeKumo -OutputType WindowsApplication -TypeDefinition @'
public static class FakeKumo {
    public static void Main() {
        System.IO.File.WriteAllText(System.IO.Path.Combine(System.AppDomain.CurrentDomain.BaseDirectory, "launched.txt"), "yes");
    }
}
'@

function Wait-Launched([string]$Dir) {
    $marker = Join-Path $Dir 'launched.txt'
    $deadline = (Get-Date).AddSeconds(15)
    while (-not (Test-Path -LiteralPath $marker) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    Test-Path -LiteralPath $marker
}

# The lock install.ps1 takes on $Dir, as it names it.
function New-InstallLock([string]$Dir) {
    $key = [IO.Path]::GetFullPath($Dir).TrimEnd('\').ToUpperInvariant()
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($key)) | ForEach-Object { $_.ToString('x2') })
    New-Object System.Threading.Mutex($false, "Local\KumoInstall-$hash")
}

$holders = @()
$lock = $null
$mutex = $null
try {
    Write-Host 'Update while a DLL is loaded:'
    $dest = New-Kumo (Join-Path $root 'dest') '1'
    Set-Content -LiteralPath (Join-Path $dest 'stale.txt.00000000-0000-0000-0000-000000000000.old') 'left by an older update'
    Set-Content -LiteralPath (Join-Path $dest 'unins000.exe') 'the setup.exe uninstaller'
    $holders += Start-DllHolder (Join-Path $dest 'runtime.dll')
    $deletable = $true
    try { [IO.File]::Delete((Join-Path $dest 'runtime.dll')) } catch { $deletable = $false }
    Check (-not $deletable) 'the loaded DLL can not be deleted (as with a running kumod)'

    $new = New-Kumo (Join-Path $root 'new2') '2'
    Set-Content -LiteralPath (Join-Path $new 'new-only.txt') 'new'
    $exit = Invoke-Installer @('-From', $new, '-Dest', $dest, '-NoRelaunch', '-Log', $log)
    Check ($exit -eq 0) "install.ps1 succeeds (exit $exit)"
    Check ((Read-Text (Join-Path $dest 'Kumo.exe')) -eq 'kumo 2') 'Kumo.exe is the new one'
    Check ((Read-Text (Join-Path $dest 'data\app.so')) -eq 'app 2') 'folders are the new ones'
    Check ((Read-Text (Join-Path $dest 'new-only.txt')) -eq 'new') 'new files are added'
    Check (Test-Path -LiteralPath (Join-Path $dest 'runtime.dll')) 'the new DLL is in place'
    Check ((Read-Text (Join-Path $dest 'unins000.exe')) -eq 'the setup.exe uninstaller') 'the uninstaller stays in place'
    $old = @(Get-ChildItem -LiteralPath $dest -Filter '*.old' | ForEach-Object Name)
    Check (-not ($old -like 'stale.txt.*')) 'leftovers of an older update are gone'
    Check (@($old -like 'Kumo.exe.*.old').Count -eq 1 -and @($old -like 'runtime.dll.*.old').Count -eq 1 -and @($old -like 'data.*.old').Count -eq 1) "the old files are set aside ($($old -join ', '))"
    $oldKumo = Get-ChildItem -LiteralPath $dest -Filter 'Kumo.exe.*.old' | Select-Object -First 1
    Check ($oldKumo -and (Read-Text $oldKumo.FullName) -eq 'kumo 1') 'what is set aside is the old version'
    Check ((Read-Text $log) -like '*Installing Kumo from*') 'the log says what happened'

    Write-Host 'Another update, the old DLL still loaded:'
    $exit = Invoke-Installer @('-From', (New-Kumo (Join-Path $root 'new3') '3'), '-Dest', $dest, '-NoRelaunch', '-Log', $log)
    Check ($exit -eq 0) "install.ps1 succeeds (exit $exit)"
    Check ((Read-Text (Join-Path $dest 'Kumo.exe')) -eq 'kumo 3') 'Kumo.exe is the newest one'
    $old = @(Get-ChildItem -LiteralPath $dest -Filter '*.old' | ForEach-Object Name)
    Check (@($old -like 'Kumo.exe.*.old').Count -eq 1) 'old copies that are not in use are deleted'
    Check (@($old -like 'runtime.dll.*.old').Count -eq 2) 'the DLL still loaded stays, for next time'

    Write-Host 'A failed copy puts the old version back:'
    $dest = New-Kumo (Join-Path $root 'dest-fail') '1'
    $holders += Start-DllHolder (Join-Path $dest 'runtime.dll')
    $new = New-Kumo (Join-Path $root 'new-fail') '2'
    # Unreadable, so the copy fails halfway through.
    $lock = [IO.File]::Open((Join-Path $new 'data\app.so'), 'Open', 'Read', 'None')
    $exit = Invoke-Installer @('-From', $new, '-Dest', $dest, '-NoRelaunch', '-Log', $log)
    Check ($exit -ne 0) "install.ps1 fails (exit $exit)"
    Check ((Read-Text (Join-Path $dest 'Kumo.exe')) -eq 'kumo 1') 'Kumo.exe is the old one'
    Check ((Read-Text (Join-Path $dest 'data\app.so')) -eq 'app 1') 'folders are the old ones'
    Check (Test-Path -LiteralPath (Join-Path $dest 'runtime.dll')) 'the loaded DLL is back under its name'
    Check (@(Get-ChildItem -LiteralPath $dest -Filter '*.old').Count -eq 0) 'nothing is left set aside'
    Check ((Read-Text $log) -like '*putting the old one back*') 'the log says why'

    Write-Host 'A folder without Kumo.exe installs nothing:'
    $empty = Join-Path $root 'empty'
    New-Item -ItemType Directory -Path $empty | Out-Null
    $exit = Invoke-Installer @('-From', $empty, '-Dest', $dest, '-NoRelaunch', '-Log', $log)
    Check ($exit -ne 0) "install.ps1 fails (exit $exit)"
    Check ((Read-Text (Join-Path $dest 'Kumo.exe')) -eq 'kumo 1') 'Kumo.exe is untouched'

    Write-Host 'An update that fails before the swap still opens Kumo again:'
    $dest = New-Kumo (Join-Path $root 'dest-relaunch') '1'
    Copy-Item -LiteralPath $fakeKumo -Destination (Join-Path $dest 'Kumo.exe') -Force
    $exit = Invoke-Installer @('-From', $empty, '-Dest', $dest, '-Log', $log)
    Check ($exit -ne 0) "install.ps1 fails (exit $exit)"
    Check (Wait-Launched $dest) 'the Kumo that is there is opened'

    Write-Host 'Another install running on the same folder blocks this one:'
    $dest = New-Kumo (Join-Path $root 'dest-locked') '1'
    Copy-Item -LiteralPath $fakeKumo -Destination (Join-Path $dest 'Kumo.exe') -Force
    $aside = Join-Path $dest 'kumod.exe.11111111-1111-1111-1111-111111111111.old'
    Set-Content -LiteralPath $aside 'set aside by the other install'
    $mutex = New-InstallLock $dest
    Check ($mutex.WaitOne(0)) 'the test holds the install lock'
    $exit = Invoke-Installer @('-From', (New-Kumo (Join-Path $root 'new-locked') '2'), '-Dest', $dest, '-LockTimeout', '2', '-Log', $log)
    Check ($exit -ne 0) "install.ps1 fails (exit $exit)"
    Check ((Get-FileHash (Join-Path $dest 'Kumo.exe')).Hash -eq (Get-FileHash $fakeKumo).Hash) 'Kumo.exe is untouched'
    Check (Test-Path -LiteralPath $aside) "the other install's set-aside files are kept"
    Check ((Read-Text $log) -like '*Another Kumo install*') 'the log says why'
    Check (Wait-Launched $dest) 'the Kumo that is there is opened'
} finally {
    if ($mutex) { try { $mutex.ReleaseMutex() } catch {}; $mutex.Dispose() }
    if ($lock) { $lock.Dispose() }
    $holders | Where-Object { $_ } | Stop-Process -Force -ErrorAction SilentlyContinue
    $holders | Where-Object { $_ } | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:failures) { throw "$($script:failures) check(s) failed" }
Write-Host 'All install.ps1 checks passed.'
