# test_state_bridge.ps1 -- checks the save helper (state_bridge.ps1) against a throwaway guide.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File test_state_bridge.ps1
#
# Starts its own copy of the helper on a spare port, with a temporary guides root, token file
# and browser profile folder, so no real guide, launcher or browser window is touched. Checks:
#   - a write with no token, or the wrong token, is refused, even from a file:// page (Origin
#     "null", which a sandboxed web iframe also sends), and leaves the file alone;
#   - a read with no token is refused;
#   - "taken" must be a JSON true or false: the string "false", null or a missing value is refused;
#   - a correct write marks and unmarks the item;
#   - a web Origin is refused;
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
        else { $r = Invoke-WebRequest -UseBasicParsing -Method POST -Uri $url -Headers $h -Body $body -ContentType 'text/plain' -TimeoutSec 10 }
        return @{ Code = [int]$r.StatusCode; Text = $r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { return @{ Code = [int]$resp.StatusCode; Text = '' } }
        return @{ Code = -1; Text = $_.Exception.Message }
    }
}
function Taken { @((Get-Content -LiteralPath $status -Raw -Encoding UTF8 | ConvertFrom-Json).taken) }
function Post([hashtable]$b, [string]$origin = 'null') { Call 'POST' $base ($b | ConvertTo-Json -Compress) $origin }

$ps = (Get-Command powershell.exe).Source
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
