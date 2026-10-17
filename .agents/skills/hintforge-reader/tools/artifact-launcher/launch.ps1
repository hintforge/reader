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

# The launcher runs in its own browser profile, so the save helper can tell when THIS
# window has closed: it looks for a browser process using this folder. A window opened
# into an already-running everyday browser would leave no such process to find.
$stateDir = Join-Path $env:LOCALAPPDATA 'HintforgeArtifactLauncher'
$profileDir = Join-Path $stateDir 'browser-profile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

# The save helper: lets a page whose guide declares "writes_state" in artifacts/artifacts.json
# save "taken" marks back into that guide. It starts first because it makes this run's
# token, which the page must send with every request; the launcher page gets the token in
# its address and hands it only to artifacts that write state. A second launch finds the
# helper running and reuses its token.
$token = ''
if (-not $NoBridge) {
    $tokenFile = Join-Path $stateDir 'bridge_token.txt'
    $existing = $null
    if ([System.Threading.Mutex]::TryOpenExisting('Local\HintforgeArtifactLauncherBridge47831', [ref]$existing)) {
        $existing.Dispose()
    } else {
        # No helper is running, so any token file is left over from one that did not exit cleanly.
        Remove-Item -LiteralPath $tokenFile -Force -ErrorAction SilentlyContinue
        $bridge = Join-Path $here 'state_bridge.ps1'
        $conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
        $ps = (Get-Command powershell.exe -ErrorAction Stop).Source
        Start-Process -FilePath $conhost -ArgumentList @(
            '--headless', ('"{0}"' -f $ps), '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $bridge), '-ProfileDir', ('"{0}"' -f $profileDir)
        ) -WindowStyle Hidden
    }
    for ($i = 0; $i -lt 50 -and -not (Test-Path -LiteralPath $tokenFile); $i++) { Start-Sleep -Milliseconds 100 }
    if (Test-Path -LiteralPath $tokenFile) { $token = ([System.IO.File]::ReadAllText($tokenFile)).Trim() }
    else { Write-Warning 'The save helper did not start; marks stay in the browser until it runs.' }
}
$pageUrl = if ($token -match '^[0-9a-f]+$') { $fileUrl + '?bridge=' + $token } else { $fileUrl }

$browserArgs = @(
    "--user-data-dir=$profileDir",
    '--no-first-run',
    '--no-default-browser-check',
    "--app=$pageUrl",
    "--window-size=$WindowSize"
)
# Start-Process joins an argument array with spaces and does not quote, so any
# argument holding a space (the profile path can) is quoted here.
$quoted = $browserArgs | ForEach-Object { if ($_ -match ' ') { '"' + $_ + '"' } else { $_ } }
Start-Process -FilePath $browser -ArgumentList $quoted
