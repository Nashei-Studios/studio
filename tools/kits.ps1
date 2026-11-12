#requires -Version 7
<#
.SYNOPSIS
  Keeps the studio library (kits, research, media packs) identical on every machine,
  with Google Drive as the single distribution point.

.DESCRIPTION
  One zip per package plus one manifest.json per Drive folder. Drive throttles thousands of
  small files, so nothing is uploaded loose.

    push   zips every sub-folder of -Path that changed and uploads it, then updates the manifest.
    pull   downloads and extracts every package whose hash differs from the local copy.
    status prints what differs, changes nothing.

  Needs rclone with a remote that points at the studio folder (docs/drive.md).

.EXAMPLE
  pwsh tools/kits.ps1 pull -Path D:\Roblox\kits
  pwsh tools/kits.ps1 push -Path D:\Roblox\kits
  pwsh tools/kits.ps1 pull -Path D:\Roblox\kits -Only kenney-food-kit,icons-pack
  pwsh tools/kits.ps1 push -Path D:\Roblox\research -Folder 20-investigacion
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('push', 'pull', 'status')][string]$Action,
    [Parameter(Mandatory)][string]$Path,
    [string]$Remote = 'nashei',
    [string]$Folder = '10-kits',
    [string[]]$Only = @(),
    [string]$Stage = (Join-Path ([IO.Path]::GetTempPath()) 'nashei-kits-stage')
)

$ErrorActionPreference = 'Stop'
# `pwsh -File` hands "a,b" over as one string; split it so both call styles work.
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$env:RCLONE_LOG_LEVEL = 'ERROR'
$target = "${Remote}:$Folder"
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
$stateFile = Join-Path $Path '.kits-state.json'

function Invoke-Rclone {
    param([Parameter(ValueFromRemainingArguments)][string[]]$RcloneArgs)
    & rclone @RcloneArgs
    if ($LASTEXITCODE -ne 0) { throw "rclone $($RcloneArgs -join ' ') exited with $LASTEXITCODE" }
}

function Read-JsonFile {
    param([string]$File)
    if (-not (Test-Path -LiteralPath $File)) { return @{} }
    $raw = Get-Content -LiteralPath $File -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
    return $raw | ConvertFrom-Json -AsHashtable
}

function Get-RemoteManifest {
    $local = Join-Path $Stage 'manifest.json'
    Remove-Item -LiteralPath $local -Force -ErrorAction SilentlyContinue
    & rclone copy "$target/manifest.json" $Stage 2>$null
    $manifest = Read-JsonFile $local
    if (-not $manifest.ContainsKey('packages')) { $manifest = @{ packages = @{} } }
    return $manifest
}

function Save-RemoteManifest {
    param([hashtable]$Manifest)
    $Manifest.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $local = Join-Path $Stage 'manifest.json'
    $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $local -Encoding utf8
    Invoke-Rclone copy $local $target
}

# Cheap change detector: number of files, total bytes and newest write time.
function Get-Fingerprint {
    param([string]$Dir)
    $files = Get-ChildItem -LiteralPath $Dir -Recurse -File -Force
    $sum = ($files | Measure-Object Length -Sum).Sum
    $newest = ($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
    return '{0}:{1}:{2}' -f $files.Count, [long]$sum, ($newest ? $newest.ToString('yyyyMMddHHmmss') : '0')
}

function Get-Packages {
    Get-ChildItem -LiteralPath $Path -Directory |
        Where-Object { $_.Name -notmatch '^[_.]' } |
        Where-Object { $Only.Count -eq 0 -or $Only -contains $_.Name }
}

New-Item -ItemType Directory -Force $Stage | Out-Null
New-Item -ItemType Directory -Force $Path | Out-Null
$manifest = Get-RemoteManifest
$state = Read-JsonFile $stateFile

# Optional per-package metadata (licence, source, whether it may ship in a game).
$index = @{}
$indexFile = Join-Path $Path 'INDEX.json'
if (Test-Path -LiteralPath $indexFile) {
    foreach ($k in (Read-JsonFile $indexFile).kits) { $index[$k.slug] = $k }
}

switch ($Action) {
    'push' {
        foreach ($dir in Get-Packages) {
            $slug = $dir.Name
            $print = Get-Fingerprint $dir.FullName
            $entry = $manifest.packages[$slug]
            if ($entry -and $entry.fingerprint -eq $print) { "same  $slug"; continue }
            $zip = Join-Path $Stage "$slug.zip"
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            & $tar -a -cf $zip -C $dir.Parent.FullName $slug
            if ($LASTEXITCODE -ne 0) { "FAIL  $slug (zip exited with $LASTEXITCODE)"; continue }
            $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
            try { Invoke-Rclone copy $zip $target } catch { "FAIL  $slug ($_)"; continue }
            $meta = $index[$slug]
            $manifest.packages[$slug] = @{
                file        = "$slug.zip"
                sha256      = $hash
                bytes       = (Get-Item -LiteralPath $zip).Length
                files       = [int]($print -split ':')[0]
                fingerprint = $print
                license     = $meta ? $meta.license : $null
                ships       = $meta ? $meta.ships : $null
                source      = $meta ? $meta.source : $null
                uploadedAt  = (Get-Date).ToUniversalTime().ToString('o')
            }
            Save-RemoteManifest $manifest
            $state[$slug] = $hash
            $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding utf8
            Remove-Item -LiteralPath $zip -Force
            "sent  $slug"
        }
    }
    'pull' {
        foreach ($slug in ($manifest.packages.Keys | Sort-Object)) {
            if ($Only.Count -gt 0 -and $Only -notcontains $slug) { continue }
            $entry = $manifest.packages[$slug]
            $dest = Join-Path $Path $slug
            if ($state[$slug] -eq $entry.sha256 -and (Test-Path -LiteralPath $dest)) { "same  $slug"; continue }
            try { Invoke-Rclone copy "$target/$($entry.file)" $Stage } catch { "FAIL  $slug ($_)"; continue }
            $zip = Join-Path $Stage $entry.file
            $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne $entry.sha256) { "FAIL  $slug (hash does not match the manifest)"; continue }
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            & $tar -xf $zip -C $Path
            if ($LASTEXITCODE -ne 0) { "FAIL  $slug (unzip exited with $LASTEXITCODE)"; continue }
            $state[$slug] = $hash
            $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding utf8
            Remove-Item -LiteralPath $zip -Force
            "got   $slug"
        }
    }
    'status' {
        $local = @{}
        foreach ($dir in Get-Packages) { $local[$dir.Name] = Get-Fingerprint $dir.FullName }
        foreach ($slug in (@($local.Keys) + @($manifest.packages.Keys) | Sort-Object -Unique)) {
            $entry = $manifest.packages[$slug]
            $line = if (-not $entry) { 'only here   ' }
            elseif (-not $local.ContainsKey($slug)) { 'only in Drive' }
            elseif ($entry.fingerprint -eq $local[$slug] -or $state[$slug] -eq $entry.sha256) { 'same        ' }
            else { 'differs     ' }
            "$line $slug"
        }
    }
}
'DONE'
