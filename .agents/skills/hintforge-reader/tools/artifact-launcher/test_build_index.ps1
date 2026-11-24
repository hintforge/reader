# test_build_index.ps1 -- checks which pages build_index.ps1 hands the save key ("writes").
#
#   powershell -NoProfile -File test_build_index.ps1
#   pwsh -NoProfile -File test_build_index.ps1     (run under both: most fixtures are one-entry
#                                                   manifests, which PowerShell 7 parses differently)
#
# Builds throwaway guides in a temporary folder and an index of them (never the real
# guides or the real index.html). Checks:
#   - two declared pages that share a file name in different subfolders both get the key,
#     and an undeclared same-named page does not;
#   - a bare-name declaration covers a page in a subfolder when it is the only page with
#     that name, and covers none (with a warning) when two pages share the name;
#   - a declaration spelled with dot segments ("artifacts/./maps/x.html") matches its page;
#   - a bare-name declaration for a page directly in artifacts/ still works.
# Prints one PASS/FAIL line per check; exits 0 only when all pass.

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('hfindextest_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$utf8 = New-Object System.Text.UTF8Encoding($false)

function New-Guide([string]$name, [string]$manifest, [string[]]$pages) {
    $a = Join-Path (Join-Path $root $name) 'artifacts'
    foreach ($p in $pages) {
        $f = Join-Path $a $p
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f) | Out-Null
        [System.IO.File]::WriteAllText($f, '<!doctype html><title>t</title>', $utf8)
    }
    [System.IO.File]::WriteAllText((Join-Path $a 'artifacts.json'), $manifest, $utf8)
}

$results = New-Object System.Collections.Generic.List[object]
function Check([string]$n, [bool]$ok, [string]$d = '') { $results.Add(@($n, $ok, $d)) }

try {
    New-Guide 'g_same' '[{"file":"maps/full_map.html","writes_state":"a.json"},{"file":"archive/full_map.html","writes_state":"b.json"}]' @('maps\full_map.html', 'archive\full_map.html', 'other\full_map.html')
    New-Guide 'g_bare' '[{"file":"full_map.html","writes_state":"a.json"}]' @('maps\full_map.html')
    New-Guide 'g_ambig' '[{"file":"full_map.html","writes_state":"a.json"}]' @('maps\full_map.html', 'old\full_map.html')
    New-Guide 'g_dots' '[{"file":"artifacts/./maps/../maps/full_map.html","writes_state":"a.json"}]' @('maps\full_map.html')
    New-Guide 'g_root' '[{"file":"full_map.html","writes_state":"a.json"}]' @('full_map.html', 'notes.html')
    $odd = 'carte-' + [char]0x00E9 + '.html'
    New-Guide 'g_odd' ('[{"file":"maps/Act 1/' + $odd + '","writes_state":"a.json"}]') @(('maps\Act 1\' + $odd))

    $out = Join-Path $root 'index.html'
    $warn = & (Join-Path $here 'build_index.ps1') -GuidesRoot $root -OutFile $out -Quiet 3>&1 | ForEach-Object { [string]$_ }
    $html = [System.IO.File]::ReadAllText($out)
    $m = [regex]::Match($html, 'var DATA = (\{"generated".*?\}) \|\| \{', 'Singleline')
    $data = $m.Groups[1].Value.Replace('<\/', '</') | ConvertFrom-Json
    $w = @{}
    foreach ($g in $data.games) { foreach ($x in $g.artifacts) { $w[$g.slug + '/' + $x.rel] = [bool]$x.writes } }

    Check 'same file name, two declared subfolders: both get the key' ($w['g_same/artifacts/maps/full_map.html'] -and $w['g_same/artifacts/archive/full_map.html']) ''
    Check 'same file name, undeclared subfolder: no key' (-not $w['g_same/artifacts/other/full_map.html']) ''
    Check 'bare-name declaration, only page with that name in a subfolder: key' ($w['g_bare/artifacts/maps/full_map.html']) ''
    Check 'bare-name declaration, two pages with that name: neither gets the key' (-not $w['g_ambig/artifacts/maps/full_map.html'] -and -not $w['g_ambig/artifacts/old/full_map.html']) ''
    Check 'ambiguous bare-name declaration is warned about' ([bool]($warn | Where-Object { $_ -match 'g_ambig' -and $_ -match '2 pages' })) ($warn -join ' | ')
    Check 'dot segments in a declaration are resolved' ($w['g_dots/artifacts/maps/full_map.html']) ''
    Check 'a declared path with a space and an accent gets the key' ($w['g_odd/artifacts/maps/Act 1/' + $odd]) (($w.Keys | Where-Object { $_ -like 'g_odd*' }) -join ',')
    Check 'bare-name declaration for a page in artifacts/ itself: key, other page none' ($w['g_root/artifacts/full_map.html'] -and -not $w['g_root/artifacts/notes.html']) ''
} catch {
    Check 'test ran' $false $_.Exception.Message
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

$failed = 0
foreach ($x in $results) { if ($x[1]) { Write-Output "PASS $($x[0])" } else { Write-Output "FAIL $($x[0]) ($($x[2]))"; $failed++ } }
if ($failed) { Write-Output "SOME FAILED ($failed of $($results.Count))"; exit 1 }
Write-Output "ALL PASS ($($results.Count))"
exit 0
