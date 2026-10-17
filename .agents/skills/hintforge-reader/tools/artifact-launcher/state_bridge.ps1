# Lets an artifact open in the launcher save "taken" marks back into its guide.
#
# A page opened from file:// cannot write files, so this listens on
# http://127.0.0.1:47831/ and edits ONE kind of thing: the "taken" id list of a
# JSON file that the guide itself declares writable. A guide opts in through its
# own artifacts/artifacts.json: an entry whose "file" is the page and whose
# "writes_state" names the guide-relative JSON file, for example
#   { "file": "full_map.html", "writes_state": "extract_tools/item_status.json", ... }
# No central list names any guide. The page keeps its marks in browser storage
# too, so nothing is lost while this is not running.
#
#   GET  /taken?guide=<folder>&artifact=<file>&token=<t>   -> {"ok":true,"taken":[...],"as_of":"..."}
#   POST /taken  body {"guide","artifact","id","taken":true|false,"token"}  (sent as text/plain,
#        so the browser needs no CORS preflight)
#
# Guards: every request must carry this run's token. The helper makes a fresh random
# token each time it starts and writes it to TokenFile (default
# %LOCALAPPDATA%\HintforgeArtifactLauncher\bridge_token.txt, inside this Windows user's
# own app-data folder); launch.ps1 reads it and passes it to the launcher page, which hands it
# to the artifacts that declare writes_state. Origin "null" alone proves nothing: a
# sandboxed iframe on any web page sends it too. A request carrying a web Origin is
# refused outright. "taken" must be a JSON true or false. Only the "taken" list and
# "as_of" are edited, and a result that no longer parses is never written; each
# change is logged with its time to %LOCALAPPDATA%\HintforgeArtifactLauncher\bridge.log.
# Started hidden by launch.ps1; exits when the launcher window closes (no browser
# process uses ProfileDir for two checks in a row), after MaxHours, or at once if
# another copy runs.
# ASCII only in this file: Windows PowerShell mangles non-ASCII characters inside
# double-quoted strings depending on the console code page.

[CmdletBinding()]
param(
    [string]$ProfileDir,          # launcher browser profile; empty = never auto-exit on window close
    [string]$GuidesRoot,
    [int]$Port = 47831,
    [double]$MaxHours = 24,
    [string]$TokenFile,           # where this run's token is written; empty = the default above
    [int]$WindowCheckSeconds = 30
)

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }

function Test-GuidesRoot {
    # Same rule as build_index.ps1: a guides root holds at least one <game>/artifacts/*.html.
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $false }
    foreach ($d in (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)) {
        $a = Join-Path $d.FullName 'artifacts'
        if ((Test-Path -LiteralPath $a) -and (Get-ChildItem -LiteralPath $a -File -Filter '*.html' -ErrorAction SilentlyContinue | Select-Object -First 1)) { return $true }
    }
    return $false
}
if (-not $GuidesRoot) {
    $configFile = Join-Path $here 'guides_root.txt'
    if (Test-Path -LiteralPath $configFile) { $GuidesRoot = (Get-Content -LiteralPath $configFile -TotalCount 1 -Encoding UTF8).Trim() }
}
if (-not $GuidesRoot) {
    $probe = $here
    for ($i = 0; $i -lt 8 -and $probe; $i++) {
        if (Test-GuidesRoot -Path $probe) { $GuidesRoot = $probe; break }
        foreach ($child in (Get-ChildItem -LiteralPath $probe -Directory -ErrorAction SilentlyContinue)) {
            if (Test-GuidesRoot -Path $child.FullName) { $GuidesRoot = $child.FullName; break }
        }
        if ($GuidesRoot) { break }
        $probe = Split-Path -Parent $probe
    }
}

$logDir = Join-Path $env:LOCALAPPDATA 'HintforgeArtifactLauncher'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'bridge.log'

function Write-Log([string]$msg) {
    try { Add-Content -LiteralPath $log -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) } catch { }
}

if (-not $GuidesRoot) { Write-Log 'no guides root found; bridge not started'; exit 1 }
$GuidesRoot = [System.IO.Path]::GetFullPath($GuidesRoot)

$mutex = New-Object System.Threading.Mutex($false, "Local\HintforgeArtifactLauncherBridge$Port")
if (-not $mutex.WaitOne(0)) { exit 0 }

if (-not $TokenFile) { $TokenFile = Join-Path $logDir 'bridge_token.txt' }
$tokenBytes = New-Object byte[] 24
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($tokenBytes); $rng.Dispose()
$Token = -join ($tokenBytes | ForEach-Object { $_.ToString('x2') })

function Test-Token([string]$t) {
    # Same-length, every-character comparison, so the time taken says nothing about a near miss.
    if (-not $t -or $t.Length -ne $Token.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $t.Length; $i++) { $diff = $diff -bor ([int][char]$t[$i] -bxor [int][char]$Token[$i]) }
    return ($diff -eq 0)
}

function Resolve-StateFile([string]$guide, [string]$artifact) {
    if ($guide -notmatch '^[A-Za-z0-9_-]+$' -or $artifact -notmatch '^[A-Za-z0-9_.-]+\.html$') { return $null }
    $guideDir = Join-Path $GuidesRoot $guide
    $manifest = Join-Path $guideDir 'artifacts\artifacts.json'
    if (-not (Test-Path -LiteralPath $manifest)) { return $null }
    $m = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $entries = if ($m -is [System.Array]) { $m } else { @($m.artifacts) }
    $entry = $entries | Where-Object { $_ -and $_.file -eq $artifact -and $_.writes_state } | Select-Object -First 1
    if (-not $entry) { return $null }
    $rel = [string]$entry.writes_state
    if ($rel -notmatch '\.json$') { return $null }
    $full = [System.IO.Path]::GetFullPath((Join-Path $guideDir $rel))
    if (-not $full.StartsWith($guideDir + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
    $full
}

function Read-State([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return @{ text = "{`n  `"as_of`": `"`",`n  `"taken`": []`n}`n"; taken = @(); as_of = '' } }
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $obj = $text | ConvertFrom-Json
    @{ text = $text; taken = @($obj.taken | Where-Object { $_ }); as_of = [string]$obj.as_of }
}

function Write-State([string]$path, $state, [string[]]$taken, [string]$asOf) {
    # Edit the two fields in place so the file's other keys and layout survive
    # (ConvertTo-Json in 5.1 would reflow and re-escape the whole file).
    $lines = for ($i = 0; $i -lt $taken.Count; $i += 5) {
        '    ' + (($taken[$i..([Math]::Min($i + 4, $taken.Count - 1))] | ForEach-Object { '"' + $_ + '"' }) -join ', ')
    }
    $arr = if ($taken.Count) { "[`n" + ($lines -join ",`n") + "`n  ]" } else { '[]' }
    $text = [regex]::Replace($state.text, '"taken"\s*:\s*\[[^\]]*\]', { param($m) '"taken": ' + $arr })
    if ($text -match '"as_of"\s*:') {
        $text = [regex]::Replace($text, '"as_of"\s*:\s*"[^"]*"', { param($m) '"as_of": "' + $asOf + '"' })
    }
    $null = $text | ConvertFrom-Json   # never write a file that no longer parses
    $tmp = $path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

function Send([System.Net.HttpListenerContext]$ctx, [int]$code, $body) {
    $r = $ctx.Response
    $r.StatusCode = $code
    $r.Headers['Access-Control-Allow-Origin'] = '*'
    $r.Headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    $r.Headers['Access-Control-Allow-Headers'] = 'Content-Type'
    # Chrome's local-network check: a file:// page reaching 127.0.0.1 may ask first.
    $r.Headers['Access-Control-Allow-Private-Network'] = 'true'
    $r.ContentType = 'application/json; charset=utf-8'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 4))
    $r.ContentLength64 = $bytes.Length
    $r.OutputStream.Write($bytes, 0, $bytes.Length)
    $r.Close()
}

function Handle([System.Net.HttpListenerContext]$ctx) {
    $req = $ctx.Request
    $origin = $req.Headers['Origin']
    if ($origin -and $origin -ne 'null') { Send $ctx 403 @{ ok = $false; error = 'web origins are not allowed' }; return }
    if ($req.HttpMethod -eq 'OPTIONS') { Send $ctx 200 @{ ok = $true }; return }
    if ($req.Url.AbsolutePath -ne '/taken') { Send $ctx 404 @{ ok = $false; error = 'not found' }; return }

    if ($req.HttpMethod -eq 'GET') {
        if (-not (Test-Token $req.QueryString['token'])) { Send $ctx 403 @{ ok = $false; error = 'bad token' }; return }
        $path = Resolve-StateFile $req.QueryString['guide'] $req.QueryString['artifact']
        if (-not $path) { Send $ctx 400 @{ ok = $false; error = 'artifact not allowed' }; return }
        $st = Read-State $path
        Send $ctx 200 @{ ok = $true; taken = @($st.taken); as_of = $st.as_of }
        return
    }
    if ($req.HttpMethod -ne 'POST') { Send $ctx 405 @{ ok = $false; error = 'method' }; return }

    $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd(); $reader.Close()
    if ($raw.Length -gt 4096) { Send $ctx 413 @{ ok = $false; error = 'too large' }; return }
    $b = $raw | ConvertFrom-Json
    if (-not (Test-Token ([string]$b.token))) { Send $ctx 403 @{ ok = $false; error = 'bad token' }; return }
    $path = Resolve-StateFile ([string]$b.guide) ([string]$b.artifact)
    if (-not $path) { Send $ctx 400 @{ ok = $false; error = 'artifact not allowed' }; return }
    $id = [string]$b.id
    if ($id -notmatch '^[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$') { Send $ctx 400 @{ ok = $false; error = 'bad id' }; return }
    # Only a JSON true or false: a cast would read the string "false" as true and a missing value as false.
    if ($b.taken -isnot [bool]) { Send $ctx 400 @{ ok = $false; error = 'taken must be true or false' }; return }

    $st = Read-State $path
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($t in $st.taken) { if (-not $list.Contains([string]$t)) { $list.Add([string]$t) } }
    $want = $b.taken
    $changed = $false
    if ($want -and -not $list.Contains($id)) { $list.Add($id); $changed = $true }
    if (-not $want -and $list.Contains($id)) { [void]$list.Remove($id); $changed = $true }
    $asOf = $st.as_of
    if ($changed) {
        $asOf = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC'
        Write-State $path $st $list.ToArray() $asOf
        Write-Log ("{0} {1} in {2}" -f $(if ($want) { 'marked' } else { 'unmarked' }), $id, $path)
    }
    Send $ctx 200 @{ ok = $true; taken = @($list.ToArray()); as_of = $asOf; changed = $changed }
}

function Test-WindowOpen {
    $procs = Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" -ErrorAction SilentlyContinue
    [bool]($procs | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($ProfileDir) } | Select-Object -First 1)
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try { $listener.Start() } catch { Write-Log "could not listen on port ${Port}: $($_.Exception.Message)"; $mutex.ReleaseMutex(); exit 1 }
try { [System.IO.File]::WriteAllText($TokenFile, $Token, (New-Object System.Text.UTF8Encoding($false))) }
catch { Write-Log "could not write the token file: $($_.Exception.Message)"; $listener.Stop(); $mutex.ReleaseMutex(); exit 1 }
Write-Log "bridge started (pid $PID, port $Port, guides $GuidesRoot)"

$deadline = (Get-Date).AddHours($MaxHours)
$lastCheck = Get-Date
$missed = 0
try {
    $pending = $listener.GetContextAsync()
    while ((Get-Date) -lt $deadline) {
        if ($pending.Wait(1000)) {
            $ctx = $pending.Result
            $pending = $listener.GetContextAsync()
            try { Handle $ctx }
            catch {
                Write-Log "request failed: $($_.Exception.Message)"
                try { Send $ctx 500 @{ ok = $false; error = $_.Exception.Message } } catch { }
            }
        }
        # Every WindowCheckSeconds: is the launcher window still open? Two misses in
        # a row, so a browser restart in progress is not mistaken for a close.
        if ($ProfileDir -and ((Get-Date) - $lastCheck).TotalSeconds -ge $WindowCheckSeconds) {
            $lastCheck = Get-Date
            if (Test-WindowOpen) { $missed = 0 } else { $missed++ }
            if ($missed -ge 2) { Write-Log 'launcher window closed; bridge exiting'; break }
        }
    }
} finally {
    $listener.Stop(); $listener.Close()
    try {
        if ((Test-Path -LiteralPath $TokenFile) -and ([System.IO.File]::ReadAllText($TokenFile) -eq $Token)) { Remove-Item -LiteralPath $TokenFile -Force }
    } catch { }
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
