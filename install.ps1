# killsuru installer for PowerShell (Windows PowerShell 5.1 / PowerShell 7+).
#
#   .\install.ps1               install for the current user
#   .\install.ps1 -Uninstall    remove it again
#
# Or without cloning:
#   irm https://raw.githubusercontent.com/araaki12345/killsuru/main/install.ps1 | iex
#
# Environment:
#   KILLSURU_HOME       install directory
#                       (default: %LOCALAPPDATA%\killsuru, or
#                        ~/.local/share/killsuru on Linux / macOS)
#   KILLSURU_PROFILE    profile file to hook (default: $PROFILE.CurrentUserAllHosts)
#   KILLSURU_NO_RC=1    do not touch the profile
#   KILLSURU_REF        branch / tag to download when not run from a checkout
#                       (default: main)
#   KILLSURU_UNINSTALL=1  same as -Uninstall (for use with `irm | iex`)
#
# Keep this file pure ASCII (see share/killsuru/killsuru.ps1).
param(
    [switch]$Uninstall
)

# Everything runs in a child scope so that `irm | iex` leaves no functions,
# variables or preference changes behind in the caller's session.
& {
$ErrorActionPreference = 'Stop'

$repo = 'araaki12345/killsuru'
$ref = $env:KILLSURU_REF
if (-not $ref) { $ref = 'main' }
if ($env:KILLSURU_UNINSTALL -eq '1') { $Uninstall = $true }

$onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
$beginMark = '# >>> killsuru >>>'
$endMark = '# <<< killsuru <<<'
$files = 'killsuru.ps1', 'art.txt'

# --- where things go ---------------------------------------------------------

$customHome = [bool]$env:KILLSURU_HOME
if ($customHome) {
    $dest = $env:KILLSURU_HOME
} elseif ($onWindows) {
    $dest = Join-Path $env:LOCALAPPDATA 'killsuru'
} else {
    $dest = Join-Path (Join-Path (Join-Path $HOME '.local') 'share') 'killsuru'
}

$profilePath = $env:KILLSURU_PROFILE
if (-not $profilePath) { $profilePath = $PROFILE.CurrentUserAllHosts }

# The line written into the profile. With the default location it is spelled
# with environment variables, so the profile stays ASCII-only and survives a
# non-ASCII user name whatever the profile's encoding is.
if ($customHome) {
    $quoted = "'" + (Join-Path $dest 'killsuru.ps1').Replace("'", "''") + "'"
    $hookLine = "if (Test-Path -LiteralPath $quoted) { . $quoted }"
} elseif ($onWindows) {
    $hookLine = 'if (Test-Path -LiteralPath "$env:LOCALAPPDATA\killsuru\killsuru.ps1") { . "$env:LOCALAPPDATA\killsuru\killsuru.ps1" }'
} else {
    $hookLine = 'if (Test-Path -LiteralPath "$HOME/.local/share/killsuru/killsuru.ps1") { . "$HOME/.local/share/killsuru/killsuru.ps1" }'
}

# --- profile editing (encoding preserving) -----------------------------------

function Read-TextFile([string]$Path) {
    # BOM if present, otherwise the edition's default (ANSI on 5.1, UTF-8 on 7).
    $reader = New-Object System.IO.StreamReader($Path, [System.Text.Encoding]::Default, $true)
    try {
        $text = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    } finally {
        $reader.Dispose()
    }
    return @{ Text = $text; Encoding = $encoding }
}

function Remove-HookBlock([string]$Text) {
    $pattern = '(\r?\n)?' + [regex]::Escape($beginMark) + '[\s\S]*?' + [regex]::Escape($endMark) + '(\r?\n)?'
    return [regex]::Replace($Text, $pattern, '$2')
}

function Add-Hook {
    $dir = Split-Path -Parent $profilePath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $text = ''
    $encoding = [System.Text.Encoding]::Default
    if (Test-Path -LiteralPath $profilePath) {
        $file = Read-TextFile $profilePath
        $text = $file.Text
        $encoding = $file.Encoding
    }
    if ($text.Contains($beginMark)) { return }

    $nl = [Environment]::NewLine
    if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $text += $nl }
    $text += $nl + $beginMark + $nl + $hookLine + $nl + $endMark + $nl
    [System.IO.File]::WriteAllText($profilePath, $text, $encoding)
    Write-Host "  hooked  $profilePath"
}

function Remove-Hook {
    if (-not (Test-Path -LiteralPath $profilePath)) { return }
    $file = Read-TextFile $profilePath
    if (-not $file.Text.Contains($beginMark)) { return }
    [System.IO.File]::WriteAllText($profilePath, (Remove-HookBlock $file.Text), $file.Encoding)
    Write-Host "  unhooked $profilePath"
}

# --- commands ----------------------------------------------------------------

function Install-Killsuru {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    $src = $null
    if ($PSScriptRoot) {
        $candidate = Join-Path (Join-Path $PSScriptRoot 'share') 'killsuru'
        if (Test-Path -LiteralPath (Join-Path $candidate 'killsuru.ps1')) { $src = $candidate }
    }

    foreach ($f in $files) {
        $target = Join-Path $dest $f
        if ($src) {
            Copy-Item -LiteralPath (Join-Path $src $f) -Destination $target -Force
        } else {
            $url = "https://raw.githubusercontent.com/$repo/$ref/share/killsuru/$f"
            Write-Host "Downloading $url"
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
        }
    }
    Write-Host "Installed killsuru into $dest"

    if ($env:KILLSURU_NO_RC -eq '1') {
        Write-Host 'Add this line to your PowerShell profile ($PROFILE):'
        Write-Host "  $hookLine"
    } else {
        Add-Hook
        Write-Host 'Open a new PowerShell window and try:  $p = Start-Process notepad -PassThru; kill $p.Id'
    }

    if ($onWindows) {
        $policy = Get-ExecutionPolicy
        if ($policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
            Write-Warning "The execution policy is '$policy', so PowerShell will not load your profile or killsuru."
            Write-Warning 'To allow local scripts for your user, run:'
            Write-Warning '  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
        }
    }
}

function Uninstall-Killsuru {
    if ($env:KILLSURU_NO_RC -ne '1') { Remove-Hook }
    foreach ($f in $files) {
        $target = Join-Path $dest $f
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    if ((Test-Path -LiteralPath $dest) -and -not (Get-ChildItem -LiteralPath $dest -Force)) {
        Remove-Item -LiteralPath $dest -Force
    }
    Write-Host "Uninstalled killsuru from $dest"
}

if ($Uninstall) { Uninstall-Killsuru } else { Install-Killsuru }
}
