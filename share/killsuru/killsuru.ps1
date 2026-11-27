# killsuru.ps1 - kill wrapper for interactive PowerShell sessions.
#
# Works in Windows PowerShell 5.1 and PowerShell 7+ (Windows, Linux, macOS).
# Dot-source it from your profile:
#
#   . "$env:LOCALAPPDATA\killsuru\killsuru.ps1"
#
# It re-points the `kill` alias to a small function that runs the real thing
# (Stop-Process on Windows, the native kill command elsewhere) and, when that
# succeeded, prints the SUSURUTV ASCII art. Stop-Process itself is untouched.
#
# Environment:
#   KILLSURU_DISABLE=1   suppress the art
#   KILLSURU_COLOR=N     ANSI color index (default 1 = red; 0-255)
#   NO_COLOR             if set, never colorize
#   KILLSURU_FORCE=1     hook even when the session does not look interactive
#
# Keep this file pure ASCII: Windows PowerShell 5.1 reads BOM-less scripts
# in the ANSI code page.

# Hook interactive sessions only - never disturb scripts.
function global:Test-KillsuruInteractive {
    if ($env:KILLSURU_FORCE -eq '1') { return $true }
    if (-not [Environment]::UserInteractive) { return $false }

    $cli = @([Environment]::GetCommandLineArgs() | Select-Object -Skip 1)
    $noExit = $false
    $runsSomething = $false
    # Options that consume the following argument.
    $valueOptions = 'executionpolicy', 'workingdirectory', 'windowstyle',
                    'configurationname', 'configurationfile', 'settingsfile',
                    'custompipename', 'inputformat', 'outputformat',
                    'psconsolefile', 'version'
    for ($i = 0; $i -lt $cli.Count; $i++) {
        $a = [string]$cli[$i]
        if ($a -notmatch '^-(.+)$') {
            # A bare argument is a script file (pwsh) or a command (5.1).
            $runsSomething = $true
            break
        }
        $name = $Matches[1].ToLowerInvariant()
        if ('noexit'.StartsWith($name) -and $name.Length -ge 3) { $noExit = $true; continue }
        if ($name -eq 'cwa' -or
            'command'.StartsWith($name) -or
            'commandwithargs'.StartsWith($name) -or
            'file'.StartsWith($name) -or
            'encodedcommand'.StartsWith($name) -or
            ('noninteractive'.StartsWith($name) -and $name.Length -ge 4)) {
            $runsSomething = $true
            break
        }
        if ($name -in 'ep', 'wd', 'if', 'of') { $i++; continue }
        if ($name.Length -ge 2 -or $name -in 'w', 'o', 'v') {
            foreach ($opt in $valueOptions) {
                if ($opt.StartsWith($name)) { $i++; break }
            }
        }
    }
    if ($runsSomething -and -not $noExit) { return $false }
    return $true
}

if (-not (Test-KillsuruInteractive)) { return }

$global:KillsuruHome = $PSScriptRoot

function global:Show-Killsuru {
    <#
    .SYNOPSIS
    Print the SUSURUTV ASCII art.
    #>
    if ($env:KILLSURU_DISABLE -eq '1') { return }

    $config = $env:XDG_CONFIG_HOME
    if (-not $config) { $config = Join-Path $HOME '.config' }
    $art = Join-Path (Join-Path $config 'killsuru') 'art.txt'
    if (-not (Test-Path -LiteralPath $art)) {
        $art = Join-Path $global:KillsuruHome 'art.txt'
    }
    if (-not (Test-Path -LiteralPath $art)) { return }

    $text = [System.IO.File]::ReadAllText($art, [System.Text.Encoding]::UTF8)
    $text = $text.TrimEnd("`r", "`n")

    $color = $env:KILLSURU_COLOR
    if (-not $color) { $color = '1' }
    $useColor = (-not $env:NO_COLOR) -and ($color -match '^[0-9]+$')
    if ($useColor) {
        try {
            $useColor = $Host.UI.SupportsVirtualTerminal -and
                        -not [Console]::IsOutputRedirected
        } catch {
            $useColor = $false
        }
    }

    if ($useColor) {
        $esc = [char]27
        if ([int]$color -le 7) { $on = "$esc[3${color}m" } else { $on = "$esc[38;5;${color}m" }
        Write-Host "$on$text$esc[0m"
    } else {
        Write-Host $text
    }
}

function global:Invoke-KillsuruKill {
    <#
    .SYNOPSIS
    Run the real kill, then show the art if it succeeded.
    #>
    $onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
    $ok = $false

    # Informational / dry-run invocations: pass through, never show the art.
    $quiet = $false
    foreach ($a in $args) {
        if ($a -is [string] -and
            $a -match '^(-l|-L|--help|--version|-\?|-wi|-wh[atif]*)(:.*)?$') {
            $quiet = $true
        }
    }

    if ($onWindows) {
        # `kill` is an alias of Stop-Process on Windows.
        if ($MyInvocation.ExpectingInput) {
            $input | Microsoft.PowerShell.Management\Stop-Process @args
            $ok = $?
        } else {
            Microsoft.PowerShell.Management\Stop-Process @args
            $ok = $?
        }
    } else {
        # On Linux / macOS `kill` is the native command.
        $native = Get-Command -Name kill -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $native) {
            Write-Error 'killsuru: native kill command not found'
            return
        }
        & $native.Source @args
        $ok = ($LASTEXITCODE -eq 0)
    }

    if ($ok -and -not $quiet) { Show-Killsuru }
}

Set-Alias -Name kill -Value Invoke-KillsuruKill -Scope Global -Option AllScope -Force
