; Kumo's Windows installer (Inno Setup 6), built by packaging/windows-installer.sh
; from the Kumo folder of the release zip:
;
;   iscc /DAppVersion=X.Y.Z[-pre] /DSourceDir=<Kumo folder> /DOutputDir=dist \
;        /DReleaseRepo=owner/name packaging\windows\kumo.iss
;     → dist\Kumo-X.Y.Z-windows-x64-setup.exe
;
; Per user, no admin: Kumo goes to %LOCALAPPDATA%\Programs\Kumo (where
; install.ps1 puts it, so an install from either upgrades the other), with a
; Start menu shortcut and an uninstaller in Apps & Features (HKCU).
;
; Kumo's updater runs it silently (kumo-ui/lib/platform/updates_windows.dart):
;
;   Kumo-X.Y.Z-windows-x64-setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
;       /WAITPID=<Kumo's pid> /LOG=<file> [/RELAUNCH]
;
;   /WAITPID=<pid>  wait for that process (the Kumo asking) to exit first, and
;                   report a failed update in %LOCALAPPDATA%\Kumo\updates\update.log
;                   as install.ps1 does ("Kumo wasn't updated: ...")
;   /RELAUNCH       open Kumo once done; if the install fails, open the Kumo
;                   that is there (the old one, put back)
;
; A running kumod.exe, and the DLLs it loaded, can't be overwritten or deleted,
; but they can be renamed: before copying, they are set aside as
; <name>.<id>.old and the new ones go in their place. kumod keeps running (with
; its terminals) from the old files; Kumo restarts it on the new ones once
; it's idle. A failed install puts them back. The .old files go on the next
; install, once nothing runs them. Kumo.exe windows still open are closed
; (Restart Manager), never kumod.

#ifndef AppVersion
  #error Define AppVersion: iscc /DAppVersion=X.Y.Z
#endif
#ifndef SourceDir
  #error Define SourceDir: the Kumo folder to install (Kumo.exe, kumod.exe, ...)
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef ReleaseRepo
  #define ReleaseRepo "epiphany-sh/kumo"
#endif
; Windows' version resources take numbers only: 0.10.0-beta.1 → 0.10.0. The
; full version stays in AppVersion and ProductVersion, which Kumo's updater
; reads to check the installer is the version it was published as.
#if Pos("-", AppVersion) > 0
  #define NumericVersion Copy(AppVersion, 1, Pos("-", AppVersion) - 1)
#else
  #define NumericVersion AppVersion
#endif

[Setup]
; Never change it: it's how Windows knows a new version is the same app.
AppId={{AB1AC572-2FF3-48E8-9B1C-DAB9E572E5A2}
AppName=Kumo
AppVersion={#AppVersion}
AppVerName=Kumo {#AppVersion}
AppPublisher=Epiphany
AppPublisherURL=https://github.com/{#ReleaseRepo}
AppSupportURL=https://github.com/{#ReleaseRepo}/issues
AppUpdatesURL=https://github.com/{#ReleaseRepo}/releases
VersionInfoVersion={#NumericVersion}
VersionInfoProductName=Kumo
VersionInfoProductVersion={#NumericVersion}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoTextVersion={#AppVersion}
VersionInfoDescription=Kumo Setup
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Kumo
DisableDirPage=yes
UsePreviousAppDir=no
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=Kumo-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\kumo-ui\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Kumo.exe
UninstallDisplayName=Kumo
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Kumo windows still open are closed to replace their files. Only files of
; the UI are checked: kumod's are set aside first (PrepareToInstall), and
; kumod must keep running, never be closed.
CloseApplications=force
CloseApplicationsFilter=Kumo.exe,flutter_windows.dll,app.so
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; The same shortcut install.ps1 makes.
Name: "{autoprograms}\Kumo"; Filename: "{app}\Kumo.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Kumo.exe"; Description: "{cm:LaunchProgram,Kumo}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\Kumo.exe"; WorkingDir: "{app}"; Flags: nowait; Check: RelaunchAfterSilentInstall

[UninstallDelete]
; Files install.ps1 or an update added, the .old ones, and downloaded updates.
; Settings and data (%LOCALAPPDATA%\kumo) stay.
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{localappdata}\Kumo\updates"

[Code]
const
  SYNCHRONIZE = $00100000;
  WAIT_PID_MS = 60000;

var
  AppDir: String;
  Updating: Boolean;
  Installed: Boolean;
  AsideId: String;
  AsideNames: TArrayOfString;
  Failure: String;

function OpenProcess(Access: DWORD; Inherit: BOOL; Pid: DWORD): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function WaitForSingleObject(Handle: THandle; Milliseconds: DWORD): DWORD;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CloseHandle(Handle: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';

function HasSwitch(const Name: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Name) = 0 then
      Result := True;
end;

function RelaunchAfterSilentInstall(): Boolean;
begin
  Result := WizardSilent and HasSwitch('/RELAUNCH');
end;

{ What install.ps1 writes, in the same file, for Kumo to report (updates only). }
procedure UpdateLog(const Message: String);
var
  Dir: String;
begin
  if not Updating then
    Exit;
  Dir := ExpandConstant('{localappdata}\Kumo\updates');
  ForceDirectories(Dir);
  SaveStringToFile(Dir + '\update.log',
    GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':') + ' ' + Message + #13#10, True);
  Log(Message);
end;

procedure WaitForPid(Pid: Integer);
var
  Handle: THandle;
begin
  if Pid <= 0 then
    Exit;
  Handle := OpenProcess(SYNCHRONIZE, False, Pid);
  if Handle = 0 then
    Exit; { gone already }
  Log(Format('Waiting for Kumo (%d) to quit', [Pid]));
  WaitForSingleObject(Handle, WAIT_PID_MS);
  CloseHandle(Handle);
end;

function InitializeSetup(): Boolean;
var
  Pid: Integer;
begin
  AppDir := ExpandConstant('{localappdata}\Programs\Kumo');
  Pid := StrToIntDef(ExpandConstant('{param:WAITPID|0}'), 0);
  Updating := Pid > 0;
  UpdateLog('Installing Kumo {#AppVersion}');
  WaitForPid(Pid);
  Result := True;
end;

{ What earlier installs set aside, unless still running: those go next time. }
procedure DeleteOldFiles();
var
  Found: TFindRec;
  Path: String;
begin
  if not FindFirst(AppDir + '\*.old', Found) then
    Exit;
  try
    repeat
      Path := AppDir + '\' + Found.Name;
      if Found.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then
        DelTree(Path, True, True, True)
      else
        DeleteFile(Path);
    until not FindNext(Found);
  finally
    FindClose(Found);
  end;
end;

function SetAside(const Name: String): Boolean;
var
  N: Integer;
begin
  Result := True;
  if not FileExists(AppDir + '\' + Name) then
    Exit;
  Result := RenameFile(AppDir + '\' + Name, AppDir + '\' + Name + '.' + AsideId + '.old');
  if Result then begin
    N := GetArrayLength(AsideNames);
    SetArrayLength(AsideNames, N + 1);
    AsideNames[N] := Name;
  end;
end;

{ kumod.exe and the DLLs next to it (it loads the VC++ runtime from there). }
function SetAsideDaemon(): String;
var
  Found: TFindRec;
begin
  Result := '';
  if not SetAside('kumod.exe') then begin
    Result := 'Couldn''t set kumod.exe aside to replace it.';
    Exit;
  end;
  if FindFirst(AppDir + '\*.dll', Found) then
    try
      repeat
        if (Found.Attributes and FILE_ATTRIBUTE_DIRECTORY = 0) and not SetAside(Found.Name) then begin
          Result := 'Couldn''t set ' + Found.Name + ' aside to replace it.';
          Exit;
        end;
      until not FindNext(Found);
    finally
      FindClose(Found);
    end;
end;

procedure PutBack();
var
  I: Integer;
  Name: String;
begin
  for I := 0 to GetArrayLength(AsideNames) - 1 do begin
    Name := AsideNames[I];
    if not FileExists(AppDir + '\' + Name) then
      if not RenameFile(AppDir + '\' + Name + '.' + AsideId + '.old', AppDir + '\' + Name) then
        UpdateLog('Couldn''t put back ' + Name);
  end;
  SetArrayLength(AsideNames, 0);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not DirExists(AppDir) then
    Exit;
  DeleteOldFiles();
  AsideId := GetDateTimeString('yyyymmddhhnnss', #0, #0) + '-' + IntToStr(Random(1000000));
  Result := SetAsideDaemon();
  if Result <> '' then begin
    PutBack();
    Failure := Result;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  I: Integer;
begin
  if CurStep = ssPostInstall then begin
    Installed := True;
    { What this install set aside and nothing runs any more. }
    for I := 0 to GetArrayLength(AsideNames) - 1 do
      DeleteFile(AppDir + '\' + AsideNames[I] + '.' + AsideId + '.old');
    UpdateLog('Kumo is in ' + AppDir + ' (and in the Start menu)');
  end;
end;

procedure DeinitializeSetup();
var
  Code: Integer;
begin
  if Installed then
    Exit;
  PutBack();
  if Failure = '' then
    Failure := 'the installer stopped before it finished (see setup.log)';
  UpdateLog('Kumo wasn''t updated: ' + Failure);
  { Whichever Kumo is there now: the old one, put back. }
  if HasSwitch('/RELAUNCH') and FileExists(AppDir + '\Kumo.exe') then
    Exec(AppDir + '\Kumo.exe', '', AppDir, SW_SHOWNORMAL, ewNoWait, Code);
end;

{ Uninstalling: Kumo and its daemon (and their terminals) stop, so their files
  can go. Only the ones running from here: a build elsewhere keeps running. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Dir: String;
  Code: Integer;
begin
  if CurUninstallStep <> usUninstall then
    Exit;
  Dir := ExpandConstant('{app}');
  StringChangeEx(Dir, '''', '''''', True);
  Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -NonInteractive -Command "Get-Process Kumo,kumod -ErrorAction SilentlyContinue | ' +
    'Where-Object { $_.Path -like ''' + Dir + '\*'' } | Stop-Process -Force; Start-Sleep -Milliseconds 500"',
    '', SW_HIDE, ewWaitUntilTerminated, Code);
end;
