# capture.ps1 -- screenshot the game's window for the Hintforge reader (Windows only).
#
# Usage:
#   pwsh -NoProfile -File capture.ps1 -Window <program name> [-Out <png>]
#   pwsh -NoProfile -File capture.ps1 -List
#   pwsh -NoProfile -File capture.ps1 -Desktop [-Out <png>]
#
# -Window   Program name of the game, without .exe (the guide's `game_window_process:` value).
#           Crops the shot to that program's window. Exits 3 if the program is not running, is
#           minimized or has no window on screen. It never falls back to the whole desktop.
# -List     Prints one line per visible application window: `<program>|<fullscreen yes/no>|<title>`.
#           Common non-game programs (shells, browsers, chat apps, launchers, system windows) are
#           left out. The reader uses this on the first screenshot of a guide to find the game.
# -Desktop  Captures every monitor. Only when the player explicitly asks for the whole screen.
# -Out      Output PNG. Default: a time-stamped file in the user's temp folder.
# -Direct   Copies the screen from this shell with no scheduled task. Only for a shell that is
#           known to run on the player's visible desktop.
#
# Why a scheduled task: an agent shell can run in Windows session 0, which has no desktop, so a
# screen copy fails with "The handle is invalid". A one-time scheduled task created with /it runs
# inside the signed-in user's desktop session and can copy the screen. The task's console starts
# through `conhost.exe --headless`, so no console window is drawn over the game.
#
# Limits: this copies the screen, so a window that really sits on top of the game (a chat app, a
# notification) shows in the shot. A locked PC or a game in exclusive fullscreen copies as black;
# the script detects an all-black shot, deletes it and exits 4 instead of returning it.
#
# Exit codes: 0 ok (prints the PNG path, or the window list), 2 bad arguments or path too long,
# 3 game window not found, 4 no desktop session, an all-black shot, or the capture did not finish.
param(
    [string]$Window = '',
    [string]$Out = '',
    [switch]$List,
    [switch]$Desktop,
    [switch]$Direct,
    [string]$Inner = ''
)

$ErrorActionPreference = 'Stop'

# Programs that are never the game. Matched against the program name, case-insensitive.
$NotGames = @(
    'explorer','ShellExperienceHost','StartMenuExperienceHost','SearchHost','SearchApp','TextInputHost',
    'TabTip','ApplicationFrameHost','SystemSettings','LockApp','WindowsTerminal','OpenConsole','conhost',
    'cmd','powershell','pwsh','mintty','Code','claude','ChatGPT','Codex','msedge','chrome','firefox',
    'brave','opera','vivaldi','Discord','Slack','Teams','ms-teams','Telegram','WhatsApp','Spotify',
    'Obsidian','notepad','Taskmgr','SnippingTool','ScreenClippingHost','steam','steamwebhelper',
    'EpicGamesLauncher','EADesktop','GalaxyClient','Battle.net','RiotClientUx','XboxPcApp','GameBar',
    'Overwolf','obs64'
)

function Get-WorkBase([string]$token) { Join-Path ([System.IO.Path]::GetTempPath()) ('hf_ss_' + $token) }

function Add-WinApi {
    if (-not ('HfWinRect' -as [type])) {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public struct HfWR { public int L, T, R, B; } public static class HfWinRect { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out HfWR r); [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h); [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out HfWR r, int s); }'
    }
}

function Get-Rect([IntPtr]$h) {
    $r = New-Object HfWR
    if ([HfWinRect]::DwmGetWindowAttribute($h, 9, [ref]$r, 16) -ne 0) { [void][HfWinRect]::GetWindowRect($h, [ref]$r) }
    return $r
}

# Runs inside the desktop session. Writes <base>.png plus <base>.txt (ok|geometry or error|message),
# or <base>.lst for -List.
function Invoke-Inner([string]$base, [string]$win, [bool]$listOnly) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-WinApi
    if ($listOnly) {
        $screens = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
        $lines = foreach ($p in (Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle })) {
            if ($NotGames -contains $p.ProcessName) { continue }
            if ([HfWinRect]::IsIconic($p.MainWindowHandle)) { continue }
            $r = Get-Rect $p.MainWindowHandle
            if (($r.R - $r.L) -le 0 -or ($r.B - $r.T) -le 0) { continue }
            $full = 'no'
            foreach ($s in $screens) { if ($r.L -le $s.X -and $r.T -le $s.Y -and $r.R -ge ($s.X + $s.Width) -and $r.B -ge ($s.Y + $s.Height)) { $full = 'yes' } }
            '{0}|{1}|{2}' -f $p.ProcessName, $full, ($p.MainWindowTitle -replace '\|', '/')
        }
        Set-Content -Path ($base + '.lst') -Value (@('ok') + @($lines)) -Encoding UTF8
        return
    }
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $x = $b.Left; $y = $b.Top; $w = $b.Width; $h = $b.Height
    if ($win) {
        $proc = Get-Process -Name $win -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if (-not $proc) { Set-Content -Path ($base + '.txt') -Value "error|The program '$win' is not running or has no visible window." -Encoding UTF8; return }
        if ([HfWinRect]::IsIconic($proc.MainWindowHandle)) { Set-Content -Path ($base + '.txt') -Value "error|The program '$win' is minimized." -Encoding UTF8; return }
        $r = Get-Rect $proc.MainWindowHandle
        $l = [Math]::Max($r.L, $b.Left); $t = [Math]::Max($r.T, $b.Top)
        $rr = [Math]::Min($r.R, $b.Right); $bb = [Math]::Min($r.B, $b.Bottom)
        if (($rr - $l) -le 0 -or ($bb - $t) -le 0) { Set-Content -Path ($base + '.txt') -Value "error|The program '$win' has no window on screen." -Encoding UTF8; return }
        $x = $l; $y = $t; $w = $rr - $l; $h = $bb - $t
    }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size)
    $g.Dispose()
    # An all-black copy means a locked screen or exclusive fullscreen, not the game.
    $lit = $false
    for ($i = 1; $i -le 20 -and -not $lit; $i++) { for ($j = 1; $j -le 20 -and -not $lit; $j++) {
        $px = $bmp.GetPixel([int]($w * $i / 21), [int]($h * $j / 21))
        if (($px.R + $px.G + $px.B) -gt 24) { $lit = $true }
    } }
    if (-not $lit) { $bmp.Dispose(); Set-Content -Path ($base + '.txt') -Value 'black|The screenshot came back black. The PC may be locked, or the game may be in exclusive fullscreen; borderless-windowed mode fixes the second.' -Encoding UTF8; return }
    $bmp.Save($base + '.png', [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Set-Content -Path ($base + '.txt') -Value ('ok|{0},{1},{2},{3}' -f $x, $y, $w, $h) -Encoding UTF8
}

if ($Inner) {
    $ib = Get-WorkBase $Inner
    try { Invoke-Inner $ib $Window $List.IsPresent } catch { Set-Content -Path ($ib + '.txt') -Value ('error|' + $_.Exception.Message) -Encoding UTF8 }
    exit 0
}

if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { Write-Output 'The screenshot tool runs on Windows only.'; exit 2 }
$modes = @($List.IsPresent, $Desktop.IsPresent, [bool]$Window) | Where-Object { $_ }
if (@($modes).Count -ne 1) { Write-Output 'Give exactly one of -Window <program name>, -List or -Desktop.'; exit 2 }
if (-not $Out) { $Out = Join-Path ([System.IO.Path]::GetTempPath()) ('hintforge_ss_{0}.png' -f (Get-Date -Format 'yyyyMMdd_HHmmss')) }

$token = [guid]::NewGuid().ToString('N').Substring(0, 8)
$base = Get-WorkBase $token
$resultFile = if ($List) { $base + '.lst' } else { $base + '.txt' }

$desktopSessions = @(Get-Process explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.SessionId })
if ($desktopSessions.Count -eq 0) { Write-Output 'No signed-in desktop was found, so there is no screen to capture.'; exit 4 }

if ($Direct) {
    try { Invoke-Inner $base $Window $List.IsPresent } catch { Set-Content -Path ($base + '.txt') -Value ('error|' + $_.Exception.Message) -Encoding UTF8 }
} else {
    $task = 'hintforge_ss_' + $token
    # Windows PowerShell (always present) runs the inner capture; short flags keep the command
    # under the scheduled-task length limit.
    $winArg = if ($Window) { ' -Window "{0}"' -f $Window } else { '' }
    $listArg = if ($List) { ' -List' } else { '' }
    $tr = 'conhost.exe --headless powershell -nop -w Hidden -ep Bypass -File "{0}" -Inner {1}{2}{3}' -f $PSCommandPath, $token, $winArg, $listArg
    if ($tr.Length -gt 261) { Write-Output 'The capture command is longer than Windows allows for a scheduled task (261 characters). Install the reader at a shorter path.'; exit 2 }
    $null = schtasks /create /tn $task /tr $tr /sc once /st 23:59 /ru $env:USERNAME /it /f 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Output 'Windows refused to create the one-time capture task, so no screenshot was taken.'; exit 4 }
    $null = schtasks /run /tn $task 2>&1
    for ($i = 0; $i -lt 40 -and -not (Test-Path $resultFile) -and -not (Test-Path ($base + '.txt')); $i++) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Milliseconds 300
    $null = schtasks /delete /tn $task /f 2>&1
}

if (-not (Test-Path $resultFile)) {
    if (Test-Path ($base + '.txt')) { $resultFile = $base + '.txt' }
    else { Write-Output 'The capture did not finish within 20 seconds. Is someone signed in at this PC?'; exit 4 }
}

$content = @(Get-Content $resultFile -Encoding UTF8)
Remove-Item $resultFile -ErrorAction SilentlyContinue
if ($content[0] -like 'error|*') { Write-Output $content[0].Substring(6); Remove-Item ($base + '.png') -ErrorAction SilentlyContinue; exit 3 }
if ($content[0] -like 'black|*') { Write-Output $content[0].Substring(6); exit 4 }
if ($List) { $content | Select-Object -Skip 1; exit 0 }
Move-Item ($base + '.png') $Out -Force
Write-Output $Out
exit 0
