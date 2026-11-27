# End-to-end test for the PowerShell side: install into a throw-away
# directory, kill a real process from a child PowerShell and check that the
# art shows up (and only then).
#
#   pwsh -NoProfile -File tests/test.ps1          (PowerShell 7+, any OS)
#   powershell -NoProfile -File tests\test.ps1    (Windows PowerShell 5.1)
#
# Keep this file pure ASCII.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$exe = (Get-Process -Id $PID).Path
$onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
$mark = 'SUSURU_TEST_MARK'
$script:fails = 0

function Check([string]$Description, [bool]$Condition) {
    if ($Condition) {
        Write-Host "ok   - $Description"
    } else {
        Write-Host "FAIL - $Description"
        $script:fails++
    }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('killsuru test ' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

$env:KILLSURU_HOME = Join-Path $tmp "app dir's"
$env:KILLSURU_PROFILE = Join-Path (Join-Path $tmp 'profile dir') 'profile.ps1'
$env:XDG_CONFIG_HOME = Join-Path $tmp 'config'
$env:KILLSURU_TEST_EXE = $exe
$env:KILLSURU_DISABLE = $null
$env:KILLSURU_NO_RC = $null
$env:KILLSURU_UNINSTALL = $null
New-Item -ItemType Directory -Path (Join-Path $env:XDG_CONFIG_HOME 'killsuru') -Force | Out-Null
Set-Content -LiteralPath (Join-Path (Join-Path $env:XDG_CONFIG_HOME 'killsuru') 'art.txt') -Value $mark

$baseArgs = @('-NoProfile')
if ($onWindows) { $baseArgs += @('-ExecutionPolicy', 'Bypass') }

# Run code in a fresh PowerShell that loads the hooked profile first.
function Invoke-Child([string]$Code, [switch]$Force) {
    if ($Force) { $env:KILLSURU_FORCE = '1' } else { $env:KILLSURU_FORCE = $null }
    $full = '. $env:KILLSURU_PROFILE' + "`n" + $Code
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($full))
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $exe @baseArgs -EncodedCommand $encoded 2>$null | Out-String
    } finally {
        $ErrorActionPreference = $old
        $env:KILLSURU_FORCE = $null
    }
    return $out
}

$spawn = '$p = Start-Process -FilePath $env:KILLSURU_TEST_EXE -ArgumentList "-NoProfile","-Command","Start-Sleep 60" -PassThru; Start-Sleep -Seconds 2'
$report = '"EXITED=" + $p.WaitForExit(10000)'

try {
    # --- install -------------------------------------------------------------
    & $exe @baseArgs -File (Join-Path $root 'install.ps1') | Out-Null
    Check 'install.ps1 exits 0' ($LASTEXITCODE -eq 0)
    & $exe @baseArgs -File (Join-Path $root 'install.ps1') | Out-Null
    Check 'install.ps1 is re-runnable' ($LASTEXITCODE -eq 0)
    Check 'hook script installed' (Test-Path -LiteralPath (Join-Path $env:KILLSURU_HOME 'killsuru.ps1'))
    Check 'art installed' (Test-Path -LiteralPath (Join-Path $env:KILLSURU_HOME 'art.txt'))
    $profileText = [System.IO.File]::ReadAllText($env:KILLSURU_PROFILE)
    Check 'profile hooked exactly once' (([regex]::Matches($profileText, '>>> killsuru >>>')).Count -eq 1)

    # --- the kill wrapper ----------------------------------------------------
    $out = Invoke-Child -Force "$spawn; kill `$p.Id; $report"
    Check 'art after successful kill' ($out.Contains($mark))
    Check 'the process really died' ($out.Contains('EXITED=True'))

    $out = Invoke-Child -Force 'kill 4999999 2>$null; "DONE"'
    Check 'no art after failed kill' (-not $out.Contains($mark))
    Check 'failed kill does not abort the session' ($out.Contains('DONE'))

    $env:KILLSURU_DISABLE = '1'
    $out = Invoke-Child -Force "$spawn; kill `$p.Id; $report"
    $env:KILLSURU_DISABLE = $null
    Check 'KILLSURU_DISABLE silences' ((-not $out.Contains($mark)) -and $out.Contains('EXITED=True'))

    $out = Invoke-Child -Force 'Show-Killsuru'
    Check 'Show-Killsuru prints the user art' ($out.Contains($mark))

    Remove-Item -LiteralPath (Join-Path (Join-Path $env:XDG_CONFIG_HOME 'killsuru') 'art.txt')
    $out = Invoke-Child -Force 'Show-Killsuru'
    $firstLine = (Get-Content -LiteralPath (Join-Path $root 'share/killsuru/art.txt') | Where-Object { $_.Trim() } | Select-Object -Skip 1 -First 1)
    Check 'default art found next to the hook script' ($out.Contains($firstLine))
    Set-Content -LiteralPath (Join-Path (Join-Path $env:XDG_CONFIG_HOME 'killsuru') 'art.txt') -Value $mark

    if ($onWindows) {
        $out = Invoke-Child -Force "$spawn; `$p | kill; $report"
        Check 'pipeline input works (Get-Process | kill)' ($out.Contains($mark) -and $out.Contains('EXITED=True'))

        $out = Invoke-Child -Force "$spawn; kill -Id `$p.Id -Force; $report"
        Check 'named parameters pass through' ($out.Contains($mark) -and $out.Contains('EXITED=True'))

        $out = Invoke-Child -Force "$spawn; kill `$p.Id -WhatIf; 'ALIVE=' + (-not `$p.HasExited); Stop-Process -Id `$p.Id"
        Check 'no art for -WhatIf' ((-not $out.Contains($mark)) -and $out.Contains('ALIVE=True'))
    } else {
        $out = Invoke-Child -Force 'kill -l'
        Check 'no art for kill -l' ((-not $out.Contains($mark)) -and $out.Trim().Length -gt 0)
    }

    $out = Invoke-Child '"HOOKED=" + [bool](Get-Command Invoke-KillsuruKill -ErrorAction SilentlyContinue)'
    Check 'non-interactive sessions untouched' ($out.Contains('HOOKED=False'))

    # --- uninstall -----------------------------------------------------------
    & $exe @baseArgs -File (Join-Path $root 'install.ps1') -Uninstall | Out-Null
    Check 'uninstall exits 0' ($LASTEXITCODE -eq 0)
    Check 'install dir removed' (-not (Test-Path -LiteralPath $env:KILLSURU_HOME))
    $profileText = [System.IO.File]::ReadAllText($env:KILLSURU_PROFILE)
    Check 'profile unhooked' (-not $profileText.Contains('killsuru'))
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:fails -eq 0) {
    Write-Host 'All tests passed.'
} else {
    Write-Host "$($script:fails) test(s) failed."
    exit 1
}
