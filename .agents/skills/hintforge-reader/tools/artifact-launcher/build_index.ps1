# Builds index.html: one local page listing every guide's local HTML artifact.
#
# Scans  <guides-root>\<game>\artifacts\**\*.html  (skipping *.template.html),
# normalizes whatever artifacts.json each guide happens to have (manifest shapes
# differ between guides, and a guide may have none at all), and writes the result
# into index.template.html as an inlined data island.
#
# The data is INLINED rather than fetched because a page opened from file:// cannot
# fetch() a sibling file -- Chrome gives the document an opaque origin. Re-run this
# script to pick up new artifacts; launch.ps1 runs it automatically.
#
# ASCII only in this file: Windows PowerShell mangles non-ASCII characters inside
# double-quoted strings depending on the console code page.

[CmdletBinding()]
param(
    [string]$GuidesRoot,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Resolved in the body, not in the param defaults: Windows PowerShell 5.1 leaves
# $PSScriptRoot empty there for some invocation paths, and the script then dies
# on an empty Split-Path instead of finding its own folder.
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutFile) { $OutFile = Join-Path $here 'index.html' }

function Test-GuidesRoot {
    # A guides root is any folder holding at least one <game>/artifacts/*.html.
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $false }
    foreach ($d in (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)) {
        $a = Join-Path $d.FullName 'artifacts'
        if (Test-Path -LiteralPath $a) {
            if (Get-ChildItem -LiteralPath $a -Recurse -File -Filter '*.html' -ErrorAction SilentlyContinue |
                Select-Object -First 1) { return $true }
        }
    }
    return $false
}

if (-not $GuidesRoot) {
    # 1. guides_root.txt beside this script, if you keep your guides somewhere
    #    this script cannot guess (one line, an absolute path).
    $configFile = Join-Path $here 'guides_root.txt'
    if (Test-Path -LiteralPath $configFile) {
        $GuidesRoot = (Get-Content -LiteralPath $configFile -TotalCount 1 -Encoding UTF8).Trim()
    }
}
if (-not $GuidesRoot) {
    # 2. Otherwise walk up from this script looking for a folder whose children
    #    hold artifacts/, which is what a folder of guides looks like.
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
if (-not $GuidesRoot) {
    throw ("Could not find your guides. Pass -GuidesRoot '<path to the folder holding your guide folders>', " +
           "or put that path in guides_root.txt next to this script.")
}

$template = Join-Path $here 'index.template.html'
if (-not (Test-Path -LiteralPath $template)) { throw "Template not found: $template" }
if (-not (Test-Path -LiteralPath $GuidesRoot)) { throw "Guides root not found: $GuidesRoot" }

function ConvertTo-FileUrl {
    param([string]$Path)
    'file:///' + ($Path -replace '\\', '/' -replace ' ', '%20')
}

function Get-GameName {
    # The guide README's H1 is "<Game> <dash> Hintforge Companion". Split on the
    # suffix and trim whatever punctuation joined them, so no dash literal is
    # needed in this file.
    param([string]$GameDir, [string]$Slug)
    $readme = Join-Path $GameDir 'README.md'
    if (Test-Path -LiteralPath $readme) {
        # -Encoding UTF8 is load-bearing: Windows PowerShell 5.1 (what the desktop
        # shortcut runs) otherwise decodes these files as ANSI, and the em-dash in
        # every guide's H1 turns into mojibake whose leading char is a letter, so it
        # survives the punctuation trim, leaving a stray letter on the name. PS 7 defaults to
        # UTF-8 and hides the bug entirely.
        $h1 = Get-Content -LiteralPath $readme -TotalCount 12 -Encoding UTF8 |
              Where-Object { $_ -match '^#\s+\S' } | Select-Object -First 1
        if ($h1) {
            $name = ($h1 -replace '^#\s+', '') -split 'Hintforge Companion' | Select-Object -First 1
            $name = ($name.Trim() -replace '[^\p{L}\p{N}\)\]]+$', '').Trim()
            if ($name) { return $name }
        }
    }
    (Get-Culture).TextInfo.ToTitleCase(($Slug -replace '[_-]', ' '))
}

function Get-TitleFromFile {
    # Prefer the artifact's own <title>; fall back to a prettified filename.
    param([string]$Path, [string]$BaseName)
    try {
        $head = Get-Content -LiteralPath $Path -TotalCount 40 -Encoding UTF8 -ErrorAction Stop
        $m = [regex]::Match(($head -join "`n"), '<title>(.*?)</title>', 'Singleline,IgnoreCase')
        if ($m.Success) {
            $t = $m.Groups[1].Value.Trim() -replace '\s+', ' '
            if ($t) { return $t }
        }
    } catch { }
    (Get-Culture).TextInfo.ToTitleCase(($BaseName -replace '[_-]', ' '))
}

function Read-Manifest {
    # Returns a hashtable keyed by lowercase file BASENAME. Manifests in the wild
    # use different field names for the same things, so this reads either shape:
    # name/file/kind/spoiler_class, or codename/real_name/local_path/known_stale.
    # An unknown shape is skipped rather than guessed at, and an unmatched file
    # still gets listed -- a stale manifest never hides an artifact.
    param([string]$ArtifactsDir)
    $index = @{}
    $manifestPath = Join-Path $ArtifactsDir 'artifacts.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { return $index }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "Unreadable manifest, listing files without it: $manifestPath"
        return $index
    }
    foreach ($entry in @($manifest.artifacts)) {
        if (-not $entry) { continue }
        $rel = $null
        foreach ($prop in 'local_path', 'file', 'path') {
            if ($entry.PSObject.Properties.Name -contains $prop -and $entry.$prop) { $rel = [string]$entry.$prop; break }
        }
        if (-not $rel) { continue }
        $key = [System.IO.Path]::GetFileName(($rel -replace '\\', '/')).ToLowerInvariant()

        $title = $null
        if ($entry.PSObject.Properties.Name -contains 'name' -and $entry.name) {
            $title = [string]$entry.name
        } elseif ($entry.PSObject.Properties.Name -contains 'codename' -and $entry.codename) {
            $title = [string]$entry.codename
            if ($entry.PSObject.Properties.Name -contains 'real_name' -and $entry.real_name) {
                $title = '{0} ({1})' -f $entry.codename, $entry.real_name
            }
        }

        $index[$key] = [ordered]@{
            title    = $title
            kind     = if ($entry.PSObject.Properties.Name -contains 'kind') { [string]$entry.kind } else { $null }
            spoiler  = if ($entry.PSObject.Properties.Name -contains 'spoiler_class') { [string]$entry.spoiler_class } else { $null }
            stale    = if ($entry.PSObject.Properties.Name -contains 'known_stale') { [bool]$entry.known_stale } else { $false }
            status   = if ($entry.PSObject.Properties.Name -contains 'status') { [string]$entry.status } else { $null }
            note     = if ($entry.PSObject.Properties.Name -contains 'spoiler_note') { [string]$entry.spoiler_note } else { $null }
            published = if ($entry.PSObject.Properties.Name -contains 'published_url') { [string]$entry.published_url } else { $null }
        }
    }
    return $index
}

$games = @()
$totalArtifacts = 0

foreach ($gameDir in (Get-ChildItem -LiteralPath $GuidesRoot -Directory | Sort-Object Name)) {
    if ($gameDir.Name -like '.*' -or $gameDir.Name -like '_*') { continue }
    $artifactsDir = Join-Path $gameDir.FullName 'artifacts'
    if (-not (Test-Path -LiteralPath $artifactsDir)) { continue }

    $files = Get-ChildItem -LiteralPath $artifactsDir -Recurse -File -Filter '*.html' |
             Where-Object { $_.Name -notlike '*.template.html' } |
             Sort-Object FullName
    if (-not $files) { continue }

    $manifest = Read-Manifest -ArtifactsDir $artifactsDir
    $items = @()

    foreach ($file in $files) {
        $key  = $file.Name.ToLowerInvariant()
        $meta = $manifest[$key]
        # A kind declared in the manifest carries real information; one inferred from
        # the folder name just repeats the folder heading the sidebar already shows,
        # so the page needs to know which it got.
        $kindSource = 'folder'
        if ($meta -and $meta.kind) {
            $kind = $meta.kind
            $kindSource = 'manifest'
        } else {
            $kind = $file.Directory.Name
            if ($kind -eq 'artifacts') { $kind = 'artifact' }
            $kind = ($kind -replace 's$', '') -replace '[_-]', ' '
        }

        $title = if ($meta -and $meta.title) { $meta.title } else { Get-TitleFromFile -Path $file.FullName -BaseName $file.BaseName }

        # Which folder under artifacts/ the file sits in, at any depth:
        # artifacts/dossiers/antler.html -> "dossiers"; artifacts/maps/act1/x.html
        # -> "maps/act1"; a file sitting loose in artifacts/ -> "". The sidebar
        # groups on this, so a guide can add subfolders later and they just appear.
        $groupRel = $file.DirectoryName.Substring($artifactsDir.Length).TrimStart('\') -replace '\\', '/'
        $groupLabel = ''
        if ($groupRel) {
            $parts = $groupRel -split '/' | ForEach-Object {
                (Get-Culture).TextInfo.ToTitleCase(($_ -replace '[_-]', ' '))
            }
            $groupLabel = $parts -join ' / '
        }

        $items += [ordered]@{
            group      = $groupRel
            groupLabel = $groupLabel
            title      = $title
            kind       = $kind
            kindSource = $kindSource
            url       = ConvertTo-FileUrl -Path $file.FullName
            path      = $file.FullName
            rel       = $file.FullName.Substring($gameDir.FullName.Length).TrimStart('\') -replace '\\', '/'
            id        = ($gameDir.Name + '/' + $file.Name).ToLowerInvariant()
            modified  = $file.LastWriteTime.ToString('yyyy-MM-dd')
            modifiedTs = [int64]($file.LastWriteTimeUtc - [datetime]'1970-01-01').TotalSeconds
            sizeKb    = [math]::Round($file.Length / 1KB)
            spoiler   = if ($meta) { $meta.spoiler } else { $null }
            stale     = if ($meta) { [bool]$meta.stale } else { $false }
            status    = if ($meta) { $meta.status } else { $null }
            note      = if ($meta) { $meta.note } else { $null }
            published = if ($meta) { $meta.published } else { $null }
            inManifest = [bool]$meta
        }
    }

    # PNG first, SVG as the fallback -- Planet Zoo ships only the SVG, and without
    # this its tile is the one blank card in the grid.
    $card = $null
    foreach ($candidate in 'assets\readme-status-card.png', 'assets\readme-status-card.svg') {
        $cardPath = Join-Path $gameDir.FullName $candidate
        if (Test-Path -LiteralPath $cardPath) { $card = ConvertTo-FileUrl -Path $cardPath; break }
    }
    $games += [ordered]@{
        slug      = $gameDir.Name
        name      = Get-GameName -GameDir $gameDir.FullName -Slug $gameDir.Name
        folderUrl = ConvertTo-FileUrl -Path $artifactsDir
        card      = $card
        hasManifest = (Test-Path -LiteralPath (Join-Path $artifactsDir 'artifacts.json'))
        artifacts = $items
    }
    $totalArtifacts += $items.Count
}

$payload = [ordered]@{
    generated = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    guidesUrl = ConvertTo-FileUrl -Path $GuidesRoot
    count     = $totalArtifacts
    games     = $games
}

$json = $payload | ConvertTo-Json -Depth 8 -Compress
# A manifest note or <title> containing "</script>" would otherwise close the
# inline script tag early. "<\/" is a legal JSON escape for "/".
$json = $json.Replace('</', '<\/')
$html = Get-Content -LiteralPath $template -Raw -Encoding UTF8
# The token includes the trailing `null` so the replacement leaves a complete
# expression -- swapping the comment alone would strand the literal after it and
# break the whole script with a syntax error.
$token = '/*__ARTIFACT_DATA__*/null'
if (-not $html.Contains($token)) {
    throw "Template is missing the $token placeholder: $template"
}
$html = $html.Replace($token, $json)
Set-Content -LiteralPath $OutFile -Value $html -Encoding UTF8

if (-not $Quiet) {
    Write-Output ("Indexed {0} artifacts across {1} games -> {2}" -f $totalArtifacts, $games.Count, $OutFile)
}
