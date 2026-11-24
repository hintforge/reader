# test_state_bridge.ps1 -- checks the save helper (state_bridge.ps1) against a throwaway guide.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File test_state_bridge.ps1
#   pwsh -NoProfile -File test_state_bridge.ps1        (run under both; the helper uses the same shell)
#
# Starts its own copy of the helper on a spare port, with a temporary guides root, token file
# and browser profile folder, so no real guide, launcher or browser window is touched. Checks:
#   - a write with no token, or the wrong token, is refused, even from a file:// page (Origin
#     "null", which a sandboxed web iframe also sends), and leaves the file alone;
#   - a read with no token is refused;
#   - "taken" must be a JSON true or false: the string "false", null or a missing value is refused;
#   - a correct write marks and unmarks the item;
#   - a web Origin is refused;
#   - once the guide's CHECKPOINT.md names a run, a read or write for any other run (or none) is refused;
#   - a page declared by its path under artifacts/ saves, by the same rule build_index.ps1 uses (full
#     path, dot segments resolved, a bare file name only when one page has it); a one-entry manifest
#     list is read under PowerShell 7 as under 5.1;
#   - launch.ps1 hands the helper its browser profile, and the helper exits once the only browser
#     using that profile closes (a headless browser stands in for the launcher window).
# Prints one PASS/FAIL line per check; exits 0 only when all pass. Stops every process it started.

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
$bridge = Join-Path $here 'state_bridge.ps1'
$port = 47893
$base = "http://127.0.0.1:$port/taken"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ('hfbridgetest_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$guides = Join-Path $root 'guides'
$guideDir = Join-Path $guides 'test_guide'
New-Item -ItemType Directory -Force -Path (Join-Path $guideDir 'artifacts'), (Join-Path $guideDir 'extract_tools') | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $guideDir 'artifacts\artifacts.json'), '[{"file":"map.html","writes_state":"extract_tools/item_status.json"}]', $utf8)
[System.IO.File]::WriteAllText((Join-Path $guideDir 'artifacts\map.html'), '<!doctype html><title>t</title>', $utf8)
$status = Join-Path $guideDir 'extract_tools\item_status.json'
[System.IO.File]::WriteAllText($status, "{`n  `"as_of`": `"`",`n  `"taken`": []`n}`n", $utf8)
$tokenFile = Join-Path $root 'bridge_token.txt'
$profileDir = Join-Path $root 'browser-profile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

$results = New-Object System.Collections.Generic.List[object]
function Check([string]$name, [bool]$ok, [string]$detail = '') { $results.Add(@($name, $ok, $detail)) }

function Call([string]$method, [string]$url, [string]$body, [string]$origin) {
    $h = @{}
    if ($origin) { $h['Origin'] = $origin }
    try {
        if ($method -eq 'GET') { $r = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $url -Headers $h -TimeoutSec 10 }
        # Sent as UTF-8 bytes, as a browser sends it, whatever the shell's default body encoding.
        else { $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri $url -Headers $h -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'text/plain; charset=utf-8' -TimeoutSec 10 }
        return @{ Code = [int]$r.StatusCode; Text = $r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { return @{ Code = [int]$resp.StatusCode; Text = '' } }
        return @{ Code = -1; Text = $_.Exception.Message }
    }
}
function Taken { @((Get-Content -LiteralPath $status -Raw -Encoding UTF8 | ConvertFrom-Json).taken) }
function Post([hashtable]$b, [string]$origin = 'null') { Call 'POST' $base ($b | ConvertTo-Json -Compress) $origin }

# The helper runs under the same PowerShell as this test, so running the test under both
# Windows PowerShell 5.1 and PowerShell 7 checks the helper under both.
$ps = (Get-Process -Id $PID).Path
$helper = $null
$browserPids = @()
try {
    $helperArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $bridge), '-GuidesRoot', ('"{0}"' -f $guides),
        '-Port', $port, '-ProfileDir', ('"{0}"' -f $profileDir), '-TokenFile', ('"{0}"' -f $tokenFile), '-WindowCheckSeconds', 1, '-MaxHours', 0.1)
    # A real browser process using the profile, standing in for the launcher window.
    $exe = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($exe) { Start-Process -FilePath $exe -ArgumentList @('--headless=new', '--disable-gpu', ('"--user-data-dir={0}"' -f $profileDir), 'about:blank') | Out-Null }
    $helper = Start-Process -FilePath $ps -ArgumentList $helperArgs -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 50 -and -not (Test-Path -LiteralPath $tokenFile); $i++) { Start-Sleep -Milliseconds 200 }
    $token = if (Test-Path -LiteralPath $tokenFile) { (Get-Content -LiteralPath $tokenFile -Raw).Trim() } else { '' }
    Check 'helper writes a per-launch token file' ($token -match '^[0-9a-f]{32,}$') "token file present: $(Test-Path -LiteralPath $tokenFile)"
    for ($i = 0; $i -lt 25; $i++) { if ((Call 'GET' "$base`?guide=x&artifact=x.html" '' '').Code -ne -1) { break }; Start-Sleep -Milliseconds 200 }

    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $true }
    Check 'write with no token is refused (Origin null)' ($r.Code -eq 403 -and (Taken).Count -eq 0) "HTTP $($r.Code), taken $((Taken) -join ',')"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $true; token = 'ab' * 24 }
    Check 'write with the wrong token is refused' ($r.Code -eq 403 -and (Taken).Count -eq 0) "HTTP $($r.Code)"
    $r = Call 'GET' "$base`?guide=test_guide&artifact=map.html" '' 'null'
    Check 'read with no token is refused' ($r.Code -eq 403) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $true; token = $token } 'https://example.com'
    Check 'web origin is refused even with the token' ($r.Code -eq 403 -and (Taken).Count -eq 0) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = 'false'; token = $token }
    Check 'taken "false" (a string) is refused, nothing marked' ($r.Code -eq 400 -and (Taken).Count -eq 0) "HTTP $($r.Code), taken $((Taken) -join ',')"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; token = $token }
    Check 'missing taken is refused' ($r.Code -eq 400) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $null; token = $token }
    Check 'taken null is refused' ($r.Code -eq 400) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $true; token = $token }
    Check 'a correct write marks the item' ($r.Code -eq 200 -and (Taken) -contains 'src:1') "HTTP $($r.Code), taken $((Taken) -join ',')"
    $r = Call 'GET' "$base`?guide=test_guide&artifact=map.html&token=$token" '' 'null'
    Check 'read with the token works' ($r.Code -eq 200 -and $r.Text -match 'src:1') "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $false; token = $token } ''
    Check 'a correct write unmarks the item (no Origin, a local tool)' ($r.Code -eq 200 -and (Taken).Count -eq 0) "HTTP $($r.Code)"

    # Runs: the guide's CHECKPOINT.md "run:" line is the live run; a request for any other run is refused.
    $cp = Join-Path $guideDir 'CHECKPOINT.md'
    [System.IO.File]::WriteAllText($cp, "# t`n`n## Player`n- **Name:** P`n`nrun: 1`n", $utf8)
    # Each run's marks are in runs/<run>/<declared path>; the declared file itself is the no-run file.
    function RunTaken([string]$run, [string]$file = 'item_status.json') {
        $p = Join-Path $guideDir ("runs\$run\extract_tools\$file")
        if (-not (Test-Path -LiteralPath $p)) { return @() }
        @((Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json).taken)
    }
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:2'; taken = $true; token = $token; run = '1' }
    Check 'a write naming the live run marks the item in that run''s own file' ($r.Code -eq 200 -and (RunTaken '1') -contains 'src:2' -and (Taken).Count -eq 0) "HTTP $($r.Code), run 1 $((RunTaken '1') -join ',')"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:3'; taken = $true; token = $token }
    Check 'a write with no run is refused once the guide names a run' ($r.Code -eq 409 -and -not ((Taken) -contains 'src:3')) "HTTP $($r.Code)"
    [System.IO.File]::WriteAllText($cp, "# t`n`n## Player`n- **Name:** P`n`nrun: Rebels`n", $utf8)
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:1'; taken = $true; token = $token; run = '1' }
    Check 'a write from an earlier run is refused and the new run stays empty' ($r.Code -eq 409 -and (RunTaken 'Rebels').Count -eq 0) "HTTP $($r.Code)"
    $r = Call 'GET' "$base`?guide=test_guide&artifact=map.html&token=$token&run=1" '' 'null'
    Check 'a read from an earlier run is refused' ($r.Code -eq 409) "HTTP $($r.Code)"
    $r = Call 'GET' "$base`?guide=test_guide&artifact=map.html&token=$token&run=Rebels" '' 'null'
    Check 'a read naming the live run works and starts empty' ($r.Code -eq 200 -and $r.Text -match '"taken":\[\]') "HTTP $($r.Code) $($r.Text)"
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:4'; taken = $true; token = $token; run = 'Rebels' }
    Check 'a write naming the new live run marks the item' ($r.Code -eq 200 -and (RunTaken 'Rebels') -contains 'src:4' -and -not ((RunTaken '1') -contains 'src:4')) "HTTP $($r.Code)"
    foreach ($bad in 'CON', 'com1', 'Lpt9') {
        [System.IO.File]::WriteAllText($cp, "# t`n`nrun: $bad`n", $utf8)
        $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:5'; taken = $true; token = $token; run = $bad }
        Check "a Windows device name as a run ($bad) is refused" ($r.Code -eq 400) "HTTP $($r.Code)"
    }
    [System.IO.File]::WriteAllText($cp, "# t`n`n## Player`n- **Name:** P`n`nrun: Rebels`n", $utf8)

    # A page in a subfolder, declared by its path under artifacts/, saves; so does an older page
    # that sends only its file name while it is the only page with that name.
    $nested = Join-Path $guideDir 'extract_tools\nested_status.json'
    [System.IO.File]::WriteAllText($nested, "{`n  `"as_of`": `"`",`n  `"taken`": []`n}`n", $utf8)
    New-Item -ItemType Directory -Force -Path (Join-Path $guideDir 'artifacts\maps') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $guideDir 'artifacts\maps\full_map.html'), '<!doctype html><title>t</title>', $utf8)
    [System.IO.File]::WriteAllText((Join-Path $guideDir 'artifacts\artifacts.json'),
        '[{"file":"map.html","writes_state":"extract_tools/item_status.json"},{"file":"maps/full_map.html","writes_state":"extract_tools/nested_status.json"}]', $utf8)
    function NestedTaken { RunTaken 'Rebels' 'nested_status.json' }
    $r = Post @{ guide = 'test_guide'; artifact = 'maps/full_map.html'; id = 'src:7'; taken = $true; token = $token; run = 'Rebels' }
    Check 'a nested page declared by its path saves into its own file' ($r.Code -eq 200 -and (NestedTaken) -contains 'src:7' -and -not ((RunTaken 'Rebels') -contains 'src:7')) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = './maps/../maps/full_map.html'; id = 'src:8'; taken = $true; token = $token; run = 'Rebels' }
    Check 'dot segments in the page path are resolved' ($r.Code -eq 200 -and (NestedTaken) -contains 'src:8') "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'full_map.html'; id = 'src:9'; taken = $true; token = $token; run = 'Rebels' }
    Check 'an older page sending only its unique file name still saves' ($r.Code -eq 200 -and (NestedTaken) -contains 'src:9') "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = '../other/full_map.html'; id = 'src:10'; taken = $true; token = $token; run = 'Rebels' }
    Check 'a page path climbing out of artifacts/ is refused' ($r.Code -eq 400) "HTTP $($r.Code)"
    New-Item -ItemType Directory -Force -Path (Join-Path $guideDir 'artifacts\old') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $guideDir 'artifacts\old\full_map.html'), '<!doctype html><title>t</title>', $utf8)
    $r = Post @{ guide = 'test_guide'; artifact = 'full_map.html'; id = 'src:11'; taken = $true; token = $token; run = 'Rebels' }
    Check 'a file name two pages share is refused' ($r.Code -eq 400 -and -not ((NestedTaken) -contains 'src:11')) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'old/full_map.html'; id = 'src:12'; taken = $true; token = $token; run = 'Rebels' }
    Check 'an undeclared same-named page is refused' ($r.Code -eq 400) "HTTP $($r.Code)"
    $r = Post @{ guide = 'test_guide'; artifact = 'maps/full_map.html'; id = 'src:13'; taken = $true; token = $token; run = 'Rebels' }
    Check 'the declared nested page still saves beside a same-named page' ($r.Code -eq 200 -and (NestedTaken) -contains 'src:13') "HTTP $($r.Code)"

    # A declared page whose path has a space and an accented letter saves too, as the launcher lists it.
    $odd = 'maps/Act 1/carte-' + [char]0x00E9 + '.html'
    New-Item -ItemType Directory -Force -Path (Join-Path $guideDir 'artifacts\maps\Act 1') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $guideDir ('artifacts\' + ($odd -replace '/', '\'))), '<!doctype html><title>t</title>', $utf8)
    $manJson = '[{"file":"map.html","writes_state":"extract_tools/item_status.json"},{"file":"maps/full_map.html","writes_state":"extract_tools/nested_status.json"},{"file":"' + $odd + '","writes_state":"extract_tools/nested_status.json"}]'
    [System.IO.File]::WriteAllText((Join-Path $guideDir 'artifacts\artifacts.json'), $manJson, $utf8)
    $r = Post @{ guide = 'test_guide'; artifact = $odd; id = 'src:14'; taken = $true; token = $token; run = 'Rebels' }
    Check 'a declared page with a space and an accent in its path saves' ($r.Code -eq 200 -and (NestedTaken) -contains 'src:14') "HTTP $($r.Code)"
    $r = Call 'GET' ("$base`?guide=test_guide&artifact=" + [uri]::EscapeDataString($odd) + "&token=$token&run=Rebels") '' 'null'
    Check 'a read for that page works' ($r.Code -eq 200 -and $r.Text -match 'src:14') "HTTP $($r.Code)"

    # While the reader switches runs, run: holds "(switching <old> -> <new>)", which no page carries,
    # so a page of any run is refused until the switch is done.
    [System.IO.File]::WriteAllText($cp, "# t`n`n## Player`n- **Name:** P`n`nrun: (switching Rebels -> Third)`n", $utf8)
    $r = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:15'; taken = $true; token = $token; run = 'Rebels' }
    $r2 = Post @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:15'; taken = $true; token = $token }
    Check 'during a run switch every page is refused' ($r.Code -eq 409 -and $r2.Code -eq 409 -and -not ((RunTaken 'Rebels') -contains 'src:15')) "HTTP $($r.Code) / $($r2.Code)"

    # A write already accepted for the old run, paused (second helper, -TestPauseMs) while the guide
    # switches runs, must not land in the new run's file: it is refused at the write-time check.
    [System.IO.File]::WriteAllText($cp, "# t`n`n## Player`n- **Name:** P`n`nrun: Rebels`n", $utf8)
    $tokenFile2 = Join-Path $root 'bridge_token2.txt'
    $helper2 = Start-Process -FilePath $ps -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        ('"{0}"' -f $bridge), '-GuidesRoot', ('"{0}"' -f $guides), '-Port', ($port + 1), '-TokenFile', ('"{0}"' -f $tokenFile2), '-MaxHours', 0.05, '-TestPauseMs', 4000)
    for ($i = 0; $i -lt 50 -and -not (Test-Path -LiteralPath $tokenFile2); $i++) { Start-Sleep -Milliseconds 200 }
    $token2 = (Get-Content -LiteralPath $tokenFile2 -Raw).Trim()
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $body = @{ guide = 'test_guide'; artifact = 'map.html'; id = 'src:20'; taken = $true; token = $token2; run = 'Rebels' } | ConvertTo-Json -Compress
    $pendingPost = $client.PostAsync("http://127.0.0.1:$($port + 1)/taken", (New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, 'text/plain')))
    Start-Sleep -Milliseconds 1500
    [System.IO.File]::WriteAllText($cp, "# t`n`n## Player`n- **Name:** P`n`nrun: Third`n", $utf8)
    $code = if ($pendingPost.Wait(15000)) { [int]$pendingPost.Result.StatusCode } else { -1 }
    $client.Dispose()
    Check 'an old-run write paused across a run switch is refused and leaves both runs untouched' ($code -eq 409 -and (RunTaken 'Third').Count -eq 0 -and -not ((RunTaken 'Rebels') -contains 'src:20')) "HTTP $code"
    Stop-Process -Id $helper2.Id -Force -ErrorAction SilentlyContinue

    $launch = Get-Content -LiteralPath (Join-Path $here 'launch.ps1') -Raw
    Check 'launch.ps1 opens its own browser profile and hands it to the helper' (($launch -match '--user-data-dir=') -and ($launch -match "'-ProfileDir'")) ''
    if (-not $exe) { Check 'helper exits after the launcher window closes' $false 'no Chrome or Edge to stand in for the window' }
    else {
        Start-Sleep -Seconds 3
        Check 'helper stays up while a browser uses its profile' (-not $helper.HasExited) ''
        $browserPids = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) } | ForEach-Object { $_.ProcessId })
        foreach ($p in $browserPids) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
        $gone = $helper.WaitForExit(15000)
        Check 'helper exits after the launcher window closes' $gone "browser processes stopped: $($browserPids.Count)"
        Check 'helper removes its token file on exit' ($gone -and -not (Test-Path -LiteralPath $tokenFile)) ''
    }
} finally {
    if ($helper -and -not $helper.HasExited) { Stop-Process -Id $helper.Id -Force -ErrorAction SilentlyContinue }
    @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) }) |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

$failed = 0
foreach ($x in $results) { if ($x[1]) { Write-Output "PASS $($x[0])" } else { Write-Output "FAIL $($x[0]) ($($x[2]))"; $failed++ } }
if ($failed) { Write-Output "SOME FAILED ($failed of $($results.Count))"; exit 1 }
Write-Output "ALL PASS ($($results.Count))"
exit 0
