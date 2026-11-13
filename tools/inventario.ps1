#requires -Version 7
<#
.SYNOPSIS
  Lists the art material on this computer and says how much of it is already in the studio Drive.

.DESCRIPTION
  Read-only. It walks the given folders, keeps only art and game files (by extension), hashes them
  and compares against Drive: loose files by their MD5 and packaged files by the per-file index that
  kits.ps1 uploads next to every zip. It never opens a document, never uploads and never deletes.

  Output, inside -Out: inventario.json (every file) and resumen.md (what a person reads).
  The report stays on this computer; the person decides what is shared.

.EXAMPLE
  pwsh tools/inventario.ps1
  pwsh tools/inventario.ps1 -Roots D:\Arte,E:\Proyectos -Con texturas,audio
  pwsh tools/inventario.ps1 -ConRepos      # also look inside git clones
#>
[CmdletBinding()]
param(
    # Folders to walk. Default: the home folder and, on Windows, every other fixed drive.
    [string[]]$Roots = @(),
    # Extra families besides models, Roblox files and 2D sources.
    [ValidateSet('texturas', 'audio')][string[]]$Con = @(),
    # Git clones are skipped by default: what lives in a repo is already shared through it.
    [switch]$ConRepos,
    [string]$Remote = 'nashei',
    [string]$Out = (Join-Path $HOME 'Nashei' 'inventario' (Get-Date -Format 'yyyy-MM-dd')),
    # Files smaller than this are noise (thumbnails, caches).
    [int]$MinBytes = 2048
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Roots = @($Roots | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Con = @($Con | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$families = [ordered]@{
    modelos  = 'blend', 'fbx', 'obj', 'glb', 'gltf', 'stl', 'dae', 'ply', 'abc', 'usd', 'usda', 'usdc', 'usdz', 'ztl', 'zpr', 'spp', 'sbs', 'sbsar', 'max', 'ma', 'mb', 'c4d', '3ds', 'vox'
    roblox   = 'rbxl', 'rbxlx', 'rbxm', 'rbxmx'
    fuentes2d = 'psd', 'psb', 'kra', 'xcf', 'aseprite', 'ase', 'clip', 'afdesign', 'afphoto', 'ai', 'fig', 'procreate', 'sai', 'sai2'
}
if ($Con -contains 'texturas') { $families.texturas = 'png', 'jpg', 'jpeg', 'tga', 'exr', 'hdr', 'tif', 'tiff', 'webp', 'dds' }
if ($Con -contains 'audio') { $families.audio = 'wav', 'flac', 'ogg', 'mp3', 'aif', 'aiff' }
$familyOf = @{}
foreach ($f in $families.Keys) { foreach ($e in $families[$f]) { $familyOf[".$e"] = $f } }

# Folders that never hold a person's own art: system, caches, dependencies, version control.
$skip = 'Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', '$Recycle.Bin', 'System Volume Information',
    'AppData', 'Library', 'node_modules', '.git', '.cache', '.venv', 'venv', '__pycache__', 'site-packages',
    'scoop', '.rustup', '.cargo', '.nuget', 'Steam', 'steamapps', 'Epic Games', 'Riot Games', '.Trash', 'proc', 'sys', 'dev', 'snap',
    'toolchain', 'Sdk', 'extensions', 'logs', 'Applications', 'usr', 'opt', 'var'

if (-not $Roots.Count) {
    $Roots = @($HOME)
    if ($IsWindows) {
        $homeDrive = [IO.Path]::GetPathRoot($HOME)
        $Roots += [IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady -and $_.Name -ne $homeDrive } | ForEach-Object Name
    }
}

function Get-ArtFiles { param([string]$Root)
    $stack = [System.Collections.Generic.Stack[string]]::new(); $stack.Push($Root)
    $options = [IO.EnumerationOptions]@{ IgnoreInaccessible = $true; AttributesToSkip = 'ReparsePoint, System' }
    while ($stack.Count) {
        $dir = $stack.Pop()
        try {
            foreach ($sub in [IO.Directory]::EnumerateDirectories($dir, '*', $options)) {
                $name = [IO.Path]::GetFileName($sub)
                if ($skip -contains $name -or $name.StartsWith('.')) { continue }
                # A git clone or worktree: .git is a folder in the first, a file in the second.
                if (-not $ConRepos -and (Test-Path -LiteralPath (Join-Path $sub '.git'))) { continue }
                $stack.Push($sub)
            }
            foreach ($file in [IO.Directory]::EnumerateFiles($dir, '*', $options)) {
                $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
                if ($familyOf.ContainsKey($ext)) { [IO.FileInfo]$file }
            }
        } catch [UnauthorizedAccessException], [IO.IOException] { Write-Verbose "skipped $dir`: $_" }
    }
}

# ---- 1. What Drive already has: MD5 of loose files plus the per-file index of every package ----
$inDrive = @{}; $driveNote = ''
if (Get-Command rclone -ErrorAction SilentlyContinue) {
    $env:RCLONE_LOG_LEVEL = 'ERROR'
    $listing = & rclone lsjson -R --hash --files-only "${Remote}:" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $remoteFiles = @($listing | ConvertFrom-Json)
        foreach ($f in $remoteFiles) { if ($f.Hashes.md5) { $inDrive[$f.Hashes.md5] = $f.Path } }
        $stage = Join-Path ([IO.Path]::GetTempPath()) 'nashei-inventario'
        New-Item -ItemType Directory -Force $stage | Out-Null
        foreach ($idx in @($remoteFiles | Where-Object { $_.Name -like '*.files.json' })) {
            & rclone copyto "${Remote}:$($idx.Path)" (Join-Path $stage 'index.json') 2>$null
            if ($LASTEXITCODE -ne 0) { continue }
            foreach ($entry in (Get-Content -LiteralPath (Join-Path $stage 'index.json') -Raw | ConvertFrom-Json).files) {
                $inDrive[$entry.md5] = "$($idx.Path -replace '\.files\.json$', '.zip'):$($entry.path)"
            }
        }
        $driveNote = "$($remoteFiles.Count) archivos en Drive, $($inDrive.Count) huellas conocidas"
    } else { $driveNote = "el remoto '$Remote' no respondió: nada se pudo contrastar" }
} else { $driveNote = 'falta rclone: nada se pudo contrastar' }

# ---- 2. Walk and hash ----
$md5 = [Security.Cryptography.MD5]::Create()
$files = foreach ($root in $Roots) {
    foreach ($info in Get-ArtFiles $root) {
        if ($info.Length -lt $MinBytes -or $info.Name -match '\.blend\d+$') { continue }
        $hash = $null
        try { $stream = $info.OpenRead(); try { $hash = [Convert]::ToHexString($md5.ComputeHash($stream)).ToLowerInvariant() } finally { $stream.Dispose() } }
        catch [IO.IOException], [UnauthorizedAccessException] { Write-Verbose "unreadable $($info.FullName)" }
        [pscustomobject]@{
            path = $info.FullName; folder = $info.DirectoryName; family = $familyOf[$info.Extension.ToLowerInvariant()]
            bytes = $info.Length; modified = $info.LastWriteTimeUtc.ToString('yyyy-MM-dd'); md5 = $hash
            inDrive = ($hash -and $inDrive.ContainsKey($hash)) ? $inDrive[$hash] : $null
        }
    }
}
$files = @($files)

# ---- 3. Report ----
New-Item -ItemType Directory -Force $Out | Out-Null
$files | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $Out 'inventario.json') -Encoding utf8
$mb = { param($b) '{0:N1} MB' -f ($b / 1MB) }
$sum = { param($set) [long](($set | Measure-Object bytes -Sum).Sum ?? 0) }
$unique = @($files | Where-Object md5 | Group-Object md5)
$dupes = @($unique | Where-Object Count -gt 1)
$missing = @($files | Where-Object { -not $_.inDrive })
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Inventario de arte de este computador ($(Get-Date -Format 'yyyy-MM-dd'))")
$lines.Add(''); $lines.Add("Carpetas recorridas: $($Roots -join ', '). Drive: $driveNote.")
$lines.Add(''); $lines.Add('| Familia | Archivos | Tamaño | Ya en Drive | Faltan en Drive |'); $lines.Add('|---|---|---|---|---|')
foreach ($family in $families.Keys) {
    $set = @($files | Where-Object family -eq $family); if (-not $set.Count) { continue }
    $have = @($set | Where-Object inDrive)
    $lines.Add("| $family | $($set.Count) | $(& $mb (& $sum $set)) | $($have.Count) | $($set.Count - $have.Count) |")
}
$lines.Add(''); $lines.Add("Duplicados dentro del computador: $($dupes.Count) archivos repetidos en $(($dupes | Measure-Object Count -Sum).Sum ?? 0) copias.")
$lines.Add(''); $lines.Add('## Carpetas con material que falta en Drive'); $lines.Add('')
$lines.Add('Ordenadas por tamaño. Cada una es candidata a paquete: se revisa con la persona antes de subir.'); $lines.Add('')
$lines.Add('| Carpeta | Archivos que faltan | Tamaño | Familias | Último cambio |'); $lines.Add('|---|---|---|---|---|')
$missing | Group-Object folder | Sort-Object { -(& $sum $_.Group) } | Select-Object -First 60 | ForEach-Object {
    $lines.Add("| ``$($_.Name)`` | $($_.Count) | $(& $mb (& $sum $_.Group)) | $((($_.Group.family | Sort-Object -Unique) -join ', ')) | $(@($_.Group.modified | Sort-Object -Descending)[0]) |")
}
if ($dupes.Count) {
    $lines.Add(''); $lines.Add('## Duplicados más pesados'); $lines.Add('')
    $dupes | Sort-Object { - $_.Group[0].bytes } | Select-Object -First 25 | ForEach-Object {
        $lines.Add("- $(& $mb $_.Group[0].bytes), $($_.Count) copias: " + (($_.Group.path | ForEach-Object { "``$_``" }) -join ' · '))
    }
}
$lines | Set-Content -LiteralPath (Join-Path $Out 'resumen.md') -Encoding utf8
"$($files.Count) archivos, $(& $mb (& $sum $files)); faltan en Drive $($missing.Count) ($(& $mb (& $sum $missing))); duplicados $($dupes.Count)"
"Informe: $(Join-Path $Out 'resumen.md')"
