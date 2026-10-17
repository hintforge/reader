# Opens the artifact launcher as a chromeless browser window.
#
# Refreshes the index first so newly built artifacts show up without a separate
# step, then opens index.html with --app= (a real browser window with no tabs,
# address bar or bookmarks chrome -- the browser IS the launcher).
#
# Run directly:  powershell -NoProfile -File launch.ps1
# The desktop shortcut created by install_shortcut.ps1 runs this hidden.
# ASCII only in this file: Windows PowerShell mangles non-ASCII characters inside
# double-quoted strings depending on the console code page.

[CmdletBinding()]
param(
    [switch]$NoRefresh,      # skip the rescan and open the existing index.html
    [switch]$Edge,           # force Edge even if Chrome is installed
    [string]$WindowSize = '1680,1000',
    [switch]$NoBridge        # do not start the save helper (state_bridge.ps1)
)

$ErrorActionPreference = 'Stop'

# See build_index.ps1: $PSScriptRoot is not reliable on every 5.1 invocation path.
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }

$index = Join-Path $here 'index.html'

if (-not $NoRefresh) {
    try {
        & (Join-Path $here 'build_index.ps1') -Quiet
    } catch {
        # A failed rescan must not cost you the launcher: fall through to
        # whatever index.html was last built and say so.
        Write-Warning "Index refresh failed, opening the last build. $($_.Exception.Message)"
    }
}
if (-not (Test-Path -LiteralPath $index)) {
    throw "index.html not found and could not be built. Run build_index.ps1 manually: $index"
}

$fileUrl = 'file:///' + (($index -replace '\\', '/') -replace ' ', '%20')

$candidates = @()
if (-not $Edge) {
    $candidates += @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
}
$candidates += @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)

$browser = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $browser) {
    foreach ($appPath in 'chrome.exe', 'msedge.exe') {
        try {
            $found = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$appPath" -ErrorAction Stop).'(default)'
            if ($found -and (Test-Path -LiteralPath $found)) { $browser = $found; break }
        } catch { }
    }
}
if (-not $browser) { throw 'Could not find Chrome or Edge. Open index.html in any browser instead.' }

Start-Process -FilePath $browser -ArgumentList "--app=$fileUrl", "--window-size=$WindowSize"

# The save helper: lets a page whose guide declares "writes_state" in artifacts/artifacts.json
# save "taken" marks back into that guide. A second launch finds it running and leaves it be.
if (-not $NoBridge) {
    $bridge = Join-Path $here 'state_bridge.ps1'
    $conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
    $ps = (Get-Command powershell.exe -ErrorAction Stop).Source
    Start-Process -FilePath $conhost -ArgumentList @(
        '--headless', ('"{0}"' -f $ps), '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $bridge)
    ) -WindowStyle Hidden
}
