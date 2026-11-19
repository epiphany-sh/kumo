# Kumo's shell integration for PowerShell (pwsh and Windows PowerShell 5.1).
#
# PowerShell runs this inline (-NoExit -EncodedCommand) after your profile,
# so no script file is read and the execution policy doesn't apply. It marks
# each prompt (OSC 133;A), where you type (B), where a command's output
# starts (C) and when it's done, with its status (D), so Kumo can mark the
# lines you ran. It also says the folder at each prompt (633;P;Cwd=) and
# the line you ran (633;E, signed with the nonce Kumo gave this shell), so
# Kumo can remember and suggest it. Your prompt looks as it did: B takes no
# room. C and E need PSReadLine, which reads the lines you type.
#
# Where only constrained language runs (AppLocker, WDAC), the shell starts
# as it is: what this needs isn't allowed there.
if (-not $global:__KumoMarks -and
    $ExecutionContext.SessionState.LanguageMode -eq 'FullLanguage') {
    $global:__KumoMarks = $true

    # A shell variable, not in the environment: what you run here never
    # sees it.
    $global:__KumoNonce = $env:KUMO_NONCE
    Remove-Item Env:\KUMO_NONCE -ErrorAction SilentlyContinue

    $global:__KumoUserPrompt = $function:prompt
    $global:__KumoReadLine = $null
    $global:__KumoLastExit = $global:LASTEXITCODE
    $global:__KumoLastError = $global:Error[0]

    # $Value as UTF-8 with `\`, `;`, control characters and anything past
    # ASCII escaped: what's written is plain ASCII, whatever the console's
    # code page.
    function global:__KumoEscape([string] $Value) {
        $out = New-Object System.Text.StringBuilder
        foreach ($byte in [System.Text.Encoding]::UTF8.GetBytes($Value)) {
            if ($byte -eq 0x5c) {
                [void] $out.Append('\\')
            } elseif ($byte -lt 0x20 -or $byte -eq 0x3b -or $byte -ge 0x7f) {
                [void] $out.Append(('\x{0:x2}' -f $byte))
            } else {
                [void] $out.Append([char] $byte)
            }
        }
        $out.ToString()
    }

    # Whether PSReadLine keeps $Line in the history file: one it keeps in
    # memory only (a line with a password, by default) isn't remembered.
    function global:__KumoRemembered([string] $Line) {
        if ([string]::IsNullOrWhiteSpace($Line)) {
            return $false
        }
        try {
            $handler = (Get-PSReadLineOption).AddToHistoryHandler
            if ($handler) {
                # A bool before PSReadLine 2.2, an AddToHistoryOption since.
                $answer = "$($handler.Invoke($Line))"
                return $answer -eq 'True' -or $answer -eq 'MemoryAndFile'
            }
        } catch {
        }
        $true
    }

    # Wraps PSReadLine's line reader, once it's loaded: what it returns is
    # the line about to run.
    function global:__KumoWrapReadLine {
        if ($global:__KumoReadLine) {
            return
        }
        $reader = Get-Command PSConsoleHostReadLine -CommandType Function -ErrorAction SilentlyContinue
        if (-not $reader) {
            return
        }
        $global:__KumoReadLine = $reader.ScriptBlock
        function global:PSConsoleHostReadLine {
            $line = & $global:__KumoReadLine
            $e = [char] 0x1b
            $bel = [char] 7
            $marks = ''
            if ($global:__KumoNonce -and (__KumoRemembered $line)) {
                $marks += "$e]633;E;$(__KumoEscape $line);$($global:__KumoNonce)$bel"
            }
            [Console]::Write("$marks$e]133;C$bel")
            $line
        }
    }

    # D, A and the folder before your prompt runs (it may write to the
    # screen itself), B after what it returns. A D with no command before
    # it (the first prompt, an empty line) is ignored.
    function global:prompt {
        $ok = $global:?
        $exit = $global:LASTEXITCODE
        # $? says the line failed. A native program's code is its status:
        # one that changed, or one left when no cmdlet failed (a cmdlet's
        # error goes to $Error, a program's code alone doesn't).
        $errored = $global:Error.Count -gt 0 -and
            -not [object]::ReferenceEquals($global:Error[0], $global:__KumoLastError)
        $native = $exit -is [int] -and $exit -ne 0 -and
            ($exit -ne $global:__KumoLastExit -or -not $errored)
        $code = if ($ok) {
            0
        } elseif ($native) {
            $exit
        } else {
            1
        }
        $e = [char] 0x1b
        $bel = [char] 7
        $marks = "$e]133;D;$code$bel$e]133;A$bel"
        if ($PWD.Provider.Name -eq 'FileSystem') {
            $marks += "$e]633;P;Cwd=$(__KumoEscape $PWD.ProviderPath)$bel"
        }
        [Console]::Write($marks)
        __KumoWrapReadLine
        $prompt = if ($global:__KumoUserPrompt) {
            (& $global:__KumoUserPrompt) -join ''
        } else {
            "PS $($PWD.Path)> "
        }
        # What your prompt ran doesn't change the status you see.
        if ($null -ne $exit) {
            $global:LASTEXITCODE = $exit
        }
        $global:__KumoLastExit = $exit
        $global:__KumoLastError = $global:Error[0]
        "$prompt$e]133;B$bel"
    }
}
