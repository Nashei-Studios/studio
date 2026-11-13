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

# Child pwsh processes write UTF-8; decode them as UTF-8 even when the console code page is OEM (850 on es-CL Windows).
$savedConsoleEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
try {
    # 1. The scripts parse.
    foreach ($name in 'puesto', 'kits', 'inventario', 'work', 'board-hooks/board-hook', 'board-hooks/aviso', 'lib/touch-log', 'lib/user-hooks') {
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $tools "$name.ps1"), [ref]$null, [ref]$errors)
        Assert ($errors.Count -eq 0) "$name.ps1 parses"
    }

    # 2. A Drive that is a local folder: rclone reads the remote from the environment.
    $drive = Join-Path $work 'drive'; New-Item -ItemType Directory -Force $drive | Out-Null
    # The real rclone config (and its 'nashei' remote) must never be reachable from this test: point rclone at a file that does not exist.
    $env:RCLONE_CONFIG = Join-Path $work 'no-rclone.conf'
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

    # 4b. The agent loop: the config row exists, and the pure tests pass on this system.
    Assert (@($parsed.results | Where-Object { $_.id -eq 'agente-config' }).Count -eq 1) 'puesto check reports the agent configuration'
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'agent-loop.test.ps1') | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'agent-loop unit tests pass'

    # 4c. User hooks (issue 67): the row exists, and the hook tests pass on this system.
    Assert (@($parsed.results | Where-Object { $_.id -eq 'hooks-usuario' }).Count -eq 1) 'puesto check reports the user hooks'
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'board-hooks.test.ps1') | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'board-hooks tests pass'

    # 5. Roblox keys: presence only, simulated, no real value anywhere.
    $none = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base (Join-Path $work 'base') -LlavesSimuladas ninguna | Out-String | ConvertFrom-Json).results
    $all = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base (Join-Path $work 'base') -LlavesSimuladas 'ROBLOX_API_KEY,ROBLOX_MONETIZATION_API_KEY' | Out-String | ConvertFrom-Json).results
    Assert (@($none | Where-Object { $_.id -like 'llave-*' -and $_.state -eq 'PERSONA' }).Count -eq 2) 'absent Roblox keys are PERSONA'
    Assert (@($all | Where-Object { $_.id -like 'llave-*' -and $_.state -eq 'PASA' }).Count -eq 2) 'present Roblox keys are PASA'
    Assert (@($none | Where-Object { $_.id -eq 'comunidad' -and $_.state -eq 'PERSONA' }).Count -eq 1) 'community membership without a user id is PERSONA'
    # 5b. The real path: keys present in the environment and no simulated parameter must give PASA.
    if ($true) {
        $savedKeys = @($env:ROBLOX_API_KEY, $env:ROBLOX_MONETIZATION_API_KEY)
        $env:ROBLOX_API_KEY = 'smoke-not-a-real-key'; $env:ROBLOX_MONETIZATION_API_KEY = 'smoke-not-a-real-key'
        try {
            $real = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base (Join-Path $work 'base') | Out-String | ConvertFrom-Json).results
            Assert (@($real | Where-Object { $_.id -like 'llave-*' -and $_.state -eq 'PASA' }).Count -eq 2) 'real environment keys without the simulated parameter are PASA'
        } finally { $env:ROBLOX_API_KEY = $savedKeys[0]; $env:ROBLOX_MONETIZATION_API_KEY = $savedKeys[1] }
    }
    $paramSrc = Get-Content (Join-Path $tools 'puesto.ps1') -Raw
    Assert ($paramSrc -match "PSBoundParameters\.ContainsKey\('LlavesSimuladas'\)" -and $paramSrc -notmatch '\$null -[en]q \$(script:)?LlavesSimuladas') 'the key simulation is keyed on the bound parameter, never on $null'

    # 5c. Clones: one stays on main with develop available. check flags it; install moves it only when clean.
    . (Join-Path $tools 'lib/clone-branch.ps1')
    $eco = Get-Content (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json
    $origin = Join-Path $work 'origin.git'; $seed = Join-Path $work 'seed'; $clone = Join-Path $work 'repos' 'studio'
    $git = @('-c', 'user.name=smoke', '-c', 'user.email=smoke@example.com')
    & git init --quiet --bare -b main $origin
    & git clone --quiet $origin $seed 2>$null
    & git -C $seed @git commit --quiet --allow-empty -m init
    & git -C $seed push --quiet origin main
    & git -C $seed push --quiet origin main:develop
    & git clone --quiet $origin $clone 2>$null
    & git -C $clone remote set-head origin main | Out-Null
    $sync = { param([switch]$Install) Sync-CloneBranch -Dir $clone -Name 'studio' -Ecosystem $eco -Org 'Nashei-Studios' -Install:$Install }
    Assert ([bool](& $sync)) 'check flags a clone on main when develop exists'
    & git -C $clone @git commit --quiet --allow-empty -m local
    Assert ([bool](& $sync -Install) -and (& git -C $clone branch --show-current) -eq 'main') 'install leaves a clone with unpushed commits on main and says why'
    & git -C $clone reset --quiet --hard origin/main
    Set-Content (Join-Path $clone 'wip.txt') 'x'; & git -C $clone add wip.txt
    Assert ([bool](& $sync -Install) -and (& git -C $clone branch --show-current) -eq 'main') 'install leaves a dirty clone on main and says why'
    & git -C $clone reset --quiet --hard origin/main
    Assert (-not (& $sync -Install) -and (& git -C $clone branch --show-current) -eq 'develop') 'install moves a clean clone from main to develop'
    & git -C $seed @git commit --quiet --allow-empty -m next; & git -C $seed push --quiet origin main:develop
    Assert (-not (& $sync -Install) -and (& git -C $clone rev-parse HEAD) -eq (& git -C $seed rev-parse HEAD)) 'install fast-forwards the integration branch'
    & git -C $clone checkout --quiet -b feature/x
    Assert (-not (& $sync -Install) -and (& git -C $clone branch --show-current) -eq 'feature/x') 'install never moves a clone off a feature branch'

    # 6. Drive remote: a simulated rclone (node script behind an rclone shim on PATH).
    $fake = Join-Path $work 'fakebin'; New-Item -ItemType Directory -Force $fake | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'fake-rclone.mjs') $fake
    if ($IsWindows) { Set-Content (Join-Path $fake 'rclone.cmd') '@node "%~dp0fake-rclone.mjs" %*' -Encoding ascii }
    else { Set-Content (Join-Path $fake 'rclone') "#!/bin/sh`nexec node `"`$(dirname `"`$0`")/fake-rclone.mjs`" `"`$@`"" -NoNewline; & chmod +x (Join-Path $fake 'rclone') }
    $state = Join-Path $work 'rclone-state'; New-Item -ItemType Directory -Force $state | Out-Null
    $savedPath = $env:PATH; $env:PATH = $fake + [IO.Path]::PathSeparator + $env:PATH; $env:FAKE_RCLONE_STATE = $state
    $savedDisplay = @($env:DISPLAY, $env:SSH_CONNECTION); $env:DISPLAY = ':0'; $env:SSH_CONNECTION = $null
    try {
        $rootId = (Get-Content (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json).drive.raiz.id
        $drive1 = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -SoloDrive -Json -Base (Join-Path $work 'b1') | Out-String | ConvertFrom-Json).results | Where-Object id -eq 'drive'
        Assert ($drive1.state -eq 'PERSONA' -and $drive1.detail -like "*root_folder_id=$rootId*") 'check without the remote is PERSONA and prints the exact create command with the id from the config'
        Assert (-not (Test-Path (Join-Path $state 'remote.txt'))) 'check does not create the remote'

        $drive2 = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') install -SoloDrive -Json -Base (Join-Path $work 'b2') | Out-String | ConvertFrom-Json).results | Where-Object id -eq 'drive'
        Assert ((Test-Path (Join-Path $state 'remote.txt')) -and (Get-Content (Join-Path $state 'remote.txt') -Raw) -like "*root_folder_id=$rootId*") 'install creates the remote with root_folder_id from the config'
        Assert ($drive2.state -eq 'PASA') 'install verifies the library lists 10-kits'

        Remove-Item (Join-Path $state 'remote.txt'); $env:FAKE_RCLONE_ACCESS = 'no'
        $drive3 = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') install -SoloDrive -Json -Base (Join-Path $work 'b3') | Out-String | ConvertFrom-Json).results | Where-Object id -eq 'drive'
        Assert ($drive3.state -eq 'PERSONA' -and $drive3.detail -like '*pide a Leon, dueño de la carpeta*') 'an empty listing is PERSONA asking Leon to share the folder'
        $env:FAKE_RCLONE_ACCESS = $null

        Remove-Item (Join-Path $state 'remote.txt'); $env:DISPLAY = $null; $env:SSH_CONNECTION = '1 2 3 4'
        $drive4 = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') install -SoloDrive -Json -Base (Join-Path $work 'b4') | Out-String | ConvertFrom-Json).results | Where-Object id -eq 'drive'
        Assert ($drive4.state -eq 'PERSONA' -and $drive4.detail -like '*rclone authorize*' -and -not (Test-Path (Join-Path $state 'remote.txt'))) 'without a browser install explains rclone authorize and does not try to open one'
    } finally { $env:PATH = $savedPath; $env:DISPLAY = $savedDisplay[0]; $env:SSH_CONNECTION = $savedDisplay[1]; $env:FAKE_RCLONE_ACCESS = $null }

    # 7. fix(security): installers are never run from a predictable temp path.
    $src = Get-Content (Join-Path $tools 'puesto.ps1') -Raw
    Assert ($src -match 'NewGuid' -and $src -notmatch 'nashei-install-\$\(\$Tool\.id\)\.sh') 'installer scripts are downloaded to a random private folder'
} finally {
    $env:RCLONE_CONFIG = $null
    [Console]::OutputEncoding = $savedConsoleEncoding
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failed) { "$failed expectation(s) failed"; exit 1 }
'smoke passed'
exit 0  # puesto check exits 1 on a bare runner; that is not this script's result
