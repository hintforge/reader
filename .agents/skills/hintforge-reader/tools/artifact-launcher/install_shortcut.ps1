# Puts a "Game Artifacts" shortcut on the desktop that opens the launcher.
#
# Run once:  powershell -NoProfile -ExecutionPolicy Bypass -File install_shortcut.ps1
# Remove it with -Uninstall, or just delete the .lnk.
#
# Windows only. On macOS or Linux run launch.ps1 directly (PowerShell 7), or just
# open index.html in any browser after building it.
#
# The shortcut runs powershell.exe through conhost.exe rather than launching it
# directly. Where Windows Terminal is the default terminal host it takes the run
# into its own process, so -WindowStyle Hidden has nothing to hide and a terminal
# tab flashes up and stays open. conhost.exe forces the legacy console host,
# where Hidden actually hides.
#
# ASCII only in this file: Windows PowerShell mangles non-ASCII characters inside
# double-quoted strings depending on the console code page.

[CmdletBinding()]
param(
    [string]$Name = 'Game Artifacts',
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$desktop      = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop ($Name + '.lnk')

if ($Uninstall) {
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath
        Write-Output "Removed $shortcutPath"
    } else {
        Write-Output "Nothing to remove at $shortcutPath"
    }
    return
}

# See build_index.ps1: $PSScriptRoot is not reliable on every 5.1 invocation path.
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }

$launcher = Join-Path $here 'launch.ps1'
if (-not (Test-Path -LiteralPath $launcher)) { throw "Launcher not found: $launcher" }

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$conhost    = Join-Path $env:SystemRoot 'System32\conhost.exe'
if (-not (Test-Path -LiteralPath $conhost)) { throw "conhost.exe not found: $conhost" }

$icon = Join-Path $here 'artifacts.ico'
if (-not (Test-Path -LiteralPath $icon)) {
    # Fall back to the shell's generic document icon rather than failing.
    $icon = Join-Path $env:SystemRoot 'System32\shell32.dll,1'
}

$shell    = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $conhost
$shortcut.Arguments  = ('"{0}" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}"' -f $powershell, $launcher)
$shortcut.WorkingDirectory = $here
$shortcut.Description = 'Open every local game-guide HTML artifact in one window'
$shortcut.IconLocation = $icon
$shortcut.Save()

Write-Output "Installed $shortcutPath"
