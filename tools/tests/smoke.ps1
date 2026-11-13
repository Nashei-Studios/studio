#requires -Version 7
<#
.SYNOPSIS
  Smoke test of the workstation tools on the current system, against a Drive simulated by rclone.
.DESCRIPTION
  Needs rclone. Touches only a temporary folder. Exits 1 on the first failed expectation.
  Run by CI on Windows, macOS and Linux; run it by hand with: pwsh tools/tests/smoke.ps1
#>
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
$work = Join-Path ([IO.Path]::GetTempPath()) "nashei-smoke-$PID"
$failed = 0
function Assert { param([bool]$Condition, [string]$What)
    if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
function New-Blob { param([string]$File, [int]$Seed)
    New-Item -ItemType Directory -Force (Split-Path $File) | Out-Null
    $bytes = [byte[]]::new(4096); [Random]::new($Seed).NextBytes($bytes); [IO.File]::WriteAllBytes($File, $bytes) }

try {
    # 1. The three scripts parse.
    foreach ($name in 'puesto', 'kits', 'inventario') {
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $tools "$name.ps1"), [ref]$null, [ref]$errors)
        Assert ($errors.Count -eq 0) "$name.ps1 parses"
    }

    # 2. A Drive that is a local folder: rclone reads the remote from the environment.
    $drive = Join-Path $work 'drive'; New-Item -ItemType Directory -Force $drive | Out-Null
    $env:RCLONE_CONFIG_SMOKE_TYPE = 'alias'
    $env:RCLONE_CONFIG_SMOKE_REMOTE = $drive
    $stage = Join-Path $work 'stage'
    $mine = Join-Path $work 'mine'
    New-Blob (Join-Path $mine 'casas-low-poly' 'casa.blend') 1
    New-Blob (Join-Path $mine 'casas-low-poly' 'sub carpeta' 'techo.fbx') 2
    New-Blob (Join-Path $mine '_privado' 'borrador.blend') 3

    $out = & pwsh -NoProfile -File (Join-Path $tools 'kits.ps1') push -Path $mine -Remote smoke -Folder 50-arte -Stage $stage
    Assert ($out -contains 'sent  casas-low-poly') 'kits push sends the package'
    Assert (Test-Path (Join-Path $drive '50-arte' 'casas-low-poly.zip')) 'the zip is in the Drive'
    Assert (Test-Path (Join-Path $drive '50-arte' 'casas-low-poly.files.json')) 'the per-file index is in the Drive'
    Assert (-not (Test-Path (Join-Path $drive '50-arte' '_privado.zip'))) 'a folder starting with _ is not uploaded'

    $theirs = Join-Path $work 'theirs'
    $out = & pwsh -NoProfile -File (Join-Path $tools 'kits.ps1') pull -Path $theirs -Remote smoke -Folder 50-arte -Stage $stage
    Assert ($out -contains 'got   casas-low-poly') 'kits pull downloads the package'
    $a = (Get-FileHash (Join-Path $mine 'casas-low-poly' 'sub carpeta' 'techo.fbx')).Hash
    $b = (Get-FileHash (Join-Path $theirs 'casas-low-poly' 'sub carpeta' 'techo.fbx') -ErrorAction SilentlyContinue).Hash
    Assert ($a -eq $b) 'a nested file with a space in its path survives the round trip'
    $out = & pwsh -NoProfile -File (Join-Path $tools 'kits.ps1') status -Path $theirs -Remote smoke -Folder 50-arte -Stage $stage
    Assert ([bool]($out -match '^same\s+casas-low-poly')) 'kits status reports the copy as up to date'

    # 3. Inventory: what was pushed is known, a new file is missing, a copy is a duplicate.
    New-Blob (Join-Path $mine 'sueltos' 'nuevo.glb') 4
    Copy-Item (Join-Path $mine 'sueltos' 'nuevo.glb') (Join-Path $mine 'sueltos' 'nuevo copia.glb')
    New-Blob (Join-Path $mine 'un-repo' 'modelo.blend') 5
    New-Item -ItemType Directory -Force (Join-Path $mine 'un-repo' '.git') | Out-Null
    New-Blob (Join-Path $mine 'logs' 'captura.rbxl') 6
    $report = Join-Path $work 'report'
    & pwsh -NoProfile -File (Join-Path $tools 'inventario.ps1') -Roots $mine -Remote smoke -Out $report | Out-Null
    $files = @(Get-Content (Join-Path $report 'inventario.json') -Raw | ConvertFrom-Json)
    Assert ($files.Count -eq 5) "inventory lists the 5 art files and skips the git clone and the logs folder (got $($files.Count))"
    & pwsh -NoProfile -File (Join-Path $tools 'inventario.ps1') -Roots $mine -Remote smoke -Out $report -ConRepos | Out-Null
    $withRepos = @(Get-Content (Join-Path $report 'inventario.json') -Raw | ConvertFrom-Json)
    Assert ($withRepos.Count -eq 6) "-ConRepos also lists what is inside a git clone (got $($withRepos.Count))"
    & pwsh -NoProfile -File (Join-Path $tools 'inventario.ps1') -Roots $mine -Remote smoke -Out $report | Out-Null
    Assert (@($files | Where-Object { $_.inDrive }).Count -eq 2) 'the 2 packaged files are recognised as already in the Drive'
    Assert ([bool](Select-String -LiteralPath (Join-Path $report 'resumen.md') -Pattern 'Duplicados dentro del computador: 1 ' -Quiet)) 'the duplicate is reported'

    # 4. puesto check: never crashes, always returns a parseable report.
    $json = & pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base (Join-Path $work 'base')
    $parsed = $null
    try { $parsed = ($json | Out-String) | ConvertFrom-Json } catch { "puesto output: $json" }
    Assert ($null -ne $parsed -and $parsed.results.Count -ge 8) 'puesto check returns its report as JSON'
    Assert ($parsed.os -in 'windows', 'macos', 'linux') "puesto detects the system ($($parsed.os))"

    # 5. Roblox keys: presence only, simulated, no real value anywhere.
    $none = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base (Join-Path $work 'base') -LlavesSimuladas ninguna | Out-String | ConvertFrom-Json).results
    $all = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base (Join-Path $work 'base') -LlavesSimuladas 'ROBLOX_API_KEY,ROBLOX_MONETIZATION_API_KEY' | Out-String | ConvertFrom-Json).results
    Assert (@($none | Where-Object { $_.id -like 'llave-*' -and $_.state -eq 'PERSONA' }).Count -eq 2) 'absent Roblox keys are PERSONA'
    Assert (@($all | Where-Object { $_.id -like 'llave-*' -and $_.state -eq 'PASA' }).Count -eq 2) 'present Roblox keys are PASA'
    Assert (@($none | Where-Object { $_.id -eq 'comunidad' -and $_.state -eq 'PERSONA' }).Count -eq 1) 'community membership without a user id is PERSONA'
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failed) { "$failed expectation(s) failed"; exit 1 }
'smoke passed'
exit 0  # puesto check exits 1 on a bare runner; that is not this script's result
