#requires -Version 7
<#
.SYNOPSIS
  Sets up and verifies a studio workstation from nothing, on Windows, macOS or Linux.

.DESCRIPTION
    check    prints PASA / FALLA / NO APLICA / PERSONA per check, changes nothing, exits 1 on any FALLA.
    install  installs what is missing with the system package manager, clones the repos, sets the
             git hooks, registers the studio's Claude Code hooks at user level (tools/board-hooks) and
             pulls the Drive library; then runs check.
    uninstall-hooks  removes only the studio's entries from the user's Claude Code settings.json.

  A step that needs the person (a browser login, an invitation) is never automated: it is printed
  as PERSONA with the exact command to run.

  Someone whose repos or library already live elsewhere writes <Base>/puesto.json once:
    { "repos": ["D:/code/nashei", "D:/code/roblox"], "biblioteca": { "10-kits": "D:/Roblox/kits" } }
  The agent works on its own from the board and the issues (ADR 0003). It needs, in the same file:
    "areas": ["area:arte"]       issue labels it may take (area:código, area:ui, area:arte, area:economía, ...)
    "modo":  "preguntar"         preguntar = proposes the issue and waits for a yes (default); autonomo = takes it;
                                 estricto = like preguntar. With autonomo and estricto an MCP edit to a group place is
                                 blocked without a started issue; with preguntar the person is asked
    "wip":   2                   optional personal cap on issues in progress; unset = no cap
  The first folder of "repos" receives the clones that are missing. A clone is recognised by its
  origin URL, not by its folder name.

.EXAMPLE
  pwsh tools/puesto.ps1 install
  pwsh tools/puesto.ps1 check -Perfil arte
  pwsh tools/puesto.ps1 check -Json
  pwsh tools/puesto.ps1 uninstall-hooks
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('check', 'install', 'uninstall-hooks')][string]$Action = 'check',
    # arte: models, map, ideas, tests. codigo: the game toolchain too. todo: both.
    [ValidateSet('arte', 'codigo', 'todo')][string]$Perfil = 'todo',
    # Where clones and the library live. Pick once and keep it.
    [string]$Base = (Join-Path $HOME 'Nashei'),
    [string[]]$Repos = @(),
    [string]$Biblioteca = '',
    [string]$Org = 'Nashei-Studios',
    # Empty = drive.remoto of config/ecosistema.json.
    [string]$Remote = '',
    # Runs only the Drive step (remote, library, Whisper model): no tool installs, no clones. Used by the smoke test.
    [switch]$SoloDrive,
    # Test hook: comma-separated names to treat as present ('ninguna' = none) instead of the real environment.
    # Only active when the parameter is passed: an unbound [string] is '' (never $null) in PowerShell.
    [string]$LlavesSimuladas,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/agent-loop.ps1')
. (Join-Path $PSScriptRoot 'lib/clone-branch.ps1')
. (Join-Path $PSScriptRoot 'lib/user-hooks.ps1')
[Console]::OutputEncoding = [Text.Encoding]::UTF8
if ($Action -eq 'uninstall-hooks') {
    $why = Uninstall-UserHooks
    if ($why) { "PERSONA   Hooks del estudio a nivel usuario: $why"; exit 1 }
    "PASA      Hooks del estudio quitados de $(Get-ClaudeSettingsPath) (el resto del archivo quedó igual)"
    exit 0
}
$os = $IsWindows ? 'windows' : ($IsMacOS ? 'macos' : 'linux')
$wantArt = $Perfil -in 'arte', 'todo'
$wantCode = $Perfil -in 'codigo', 'todo'
$results = [System.Collections.Generic.List[object]]::new()
$doInstall = $Action -eq 'install' -and -not $SoloDrive
$keysSimulated = $PSBoundParameters.ContainsKey('LlavesSimuladas')

# Everything about the Drive (remote name, root id, link, Whisper model) comes from the ecosystem config, never from this script.
$ecosystem = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../config/ecosistema.json') -Raw | ConvertFrom-Json
if (-not $Remote) { $Remote = $ecosystem.drive.remoto }

$config = @{}
$configFile = Join-Path $Base 'puesto.json'
if (Test-Path -LiteralPath $configFile) { $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json -AsHashtable }
$Repos = @($Repos | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if (-not $Repos.Count) { $Repos = $config.repos ? @($config.repos) : @(Join-Path $Base 'repos') }
if (-not $Biblioteca) { $Biblioteca = Join-Path $Base 'biblioteca' }
$libraryMap = $config.biblioteca ?? @{}

function Add-Result { param([string]$Id, [string]$State, [string]$What, [string]$Detail = '')
    $results.Add([pscustomobject]@{ id = $Id; state = $State; what = $What; detail = $Detail }) }
function Test-Cmd { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Invoke-Quiet { param([string]$Exe, [string[]]$ExeArgs)
    try { $out = & $Exe @ExeArgs 2>&1; return [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); out = ($out | Out-String).Trim() } }
    catch { return [pscustomobject]@{ ok = $false; out = "$_" } } }

# One row per tool: command that proves it, package id per system, who needs it.
# A missing id means there is no package for that system: the row says where to get it.
# "snap:<name>" installs a classic snap; "script:<url>" runs the project's own installer.
$rokitScript = 'https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh'
$tools = @(
    @{ id = 'git';     cmd = 'git';     need = $true;      windows = 'Git.Git';                  macos = 'git';              linux = 'git' }
    @{ id = 'gh';      cmd = 'gh';      need = $true;      windows = 'GitHub.cli';               macos = 'gh';               linux = 'gh' }
    @{ id = 'rclone';  cmd = 'rclone';  need = $true;      windows = 'Rclone.Rclone';            macos = 'rclone';           linux = 'rclone' }
    @{ id = 'node';    cmd = 'node';    need = $true;      windows = 'OpenJS.NodeJS.LTS';        macos = 'node';             linux = 'nodejs' }
    @{ id = 'blender'; cmd = 'blender'; need = $wantArt;   windows = 'BlenderFoundation.Blender'; macos = '--cask blender';  linux = 'blender'
       paths = @('C:\Program Files\Blender Foundation', '/Applications/Blender.app') }
    @{ id = 'obsidian'; cmd = 'obsidian'; need = $true;   windows = 'Obsidian.Obsidian';         macos = '--cask obsidian'; linux = 'snap:obsidian'; help = 'https://obsidian.md'
       paths = @((Join-Path ($env:LOCALAPPDATA ?? '/nonexistent') 'Programs/Obsidian'), (Join-Path ($env:LOCALAPPDATA ?? '/nonexistent') 'Obsidian'), '/Applications/Obsidian.app', '/snap/bin/obsidian') }
    @{ id = 'rokit';   cmd = 'rokit';   need = $wantCode;  windows = 'Rojo.Rokit'; macos = "script:$rokitScript"; linux = "script:$rokitScript"; help = 'https://github.com/rojo-rbx/rokit#installation'
       paths = @((Join-Path $HOME '.rokit/bin/rokit')) }
    @{ id = 'vscode';  cmd = 'code';    need = $wantCode;  windows = 'Microsoft.VisualStudioCode'; macos = '--cask visual-studio-code'; linux = 'snap:code'; help = 'https://code.visualstudio.com'
       paths = @('/Applications/Visual Studio Code.app', '/snap/bin/code') }
)

function Get-ToolVersion { param($Tool)
    if (-not (Test-Cmd $Tool.cmd) -or $Tool.cmd -in 'code', 'obsidian', 'blender') { return '' }
    $v = Invoke-Quiet $Tool.cmd @('--version')
    return $v.ok ? (($v.out -split "`n")[0] -replace '^\D*', '').Trim() : '' }

function Test-Tool { param($Tool)
    if (Test-Cmd $Tool.cmd) { return $true }
    foreach ($p in @($Tool.paths)) { if ($p -and (Test-Path -LiteralPath $p)) { return $true } }
    return $false }

# Runs an installer and keeps the tail of what it printed: a failed install must say why.
$script:installLog = ''; $script:aptUpdated = $false
function Invoke-Install { param([string]$Exe, [string[]]$ExeArgs)
    $r = Invoke-Quiet $Exe $ExeArgs
    $script:installLog = $r.ok ? '' : (($r.out -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 2) -join ' | ') }

function Install-Tool { param($Tool)
    $script:installLog = ''
    $pkg = $Tool[$os]
    if (-not $pkg) { return $false }
    if ($pkg -like 'script:*') {
        # The installer is downloaded to a fresh, randomly named folder only the user can use, so no other
        # process can swap the file between download and run (TOCTOU). The folder is removed afterwards.
        # No SHA-256 check: the rokit installer publishes no hash and its URL tracks the main branch.
        $dir = Join-Path ([IO.Path]::GetTempPath()) "nashei-install-$([guid]::NewGuid().ToString('N'))"
        try {
            New-Item -ItemType Directory -Path $dir | Out-Null
            if (-not $IsWindows) { & chmod 700 $dir }
            $file = Join-Path $dir "$($Tool.id).sh"
            try { Invoke-WebRequest -Uri $pkg.Substring(7) -OutFile $file -UseBasicParsing } catch { return $false }
            Invoke-Install bash @($file)
        } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        return (Test-Tool $Tool)
    }
    if ($pkg -like 'snap:*') {
        if (-not (Test-Cmd snap)) { $script:installLog = 'falta snap'; return $false }
        # The snap store times out now and then (HTTP 408): three attempts before giving up.
        foreach ($attempt in 1..3) {
            Invoke-Install sudo @('snap', 'install', $pkg.Substring(5), '--classic')
            if (Test-Tool $Tool) { return $true }
            if ($attempt -lt 3) { Start-Sleep -Seconds (15 * $attempt) }
        }
        return $false
    }
    switch ($os) {
        'windows' { if (-not (Test-Cmd winget)) { $script:installLog = 'falta winget (App Installer)'; return $false }
                    Invoke-Install winget @('install', '--id', $pkg, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') }
        'macos'   { if (-not (Test-Cmd brew)) { $script:installLog = 'falta Homebrew: https://brew.sh'; return $false }
                    Invoke-Install brew (@('install') + @($pkg -split ' ')) }
        'linux'   { if (Test-Cmd apt-get) {
                        # A machine that never refreshed its package index cannot find anything.
                        if (-not $script:aptUpdated) { Invoke-Install sudo @('apt-get', 'update', '-qq'); $script:aptUpdated = $true }
                        Invoke-Install sudo @('apt-get', 'install', '-y', '-qq', $pkg) }
                    elseif (Test-Cmd dnf) { Invoke-Install sudo @('dnf', 'install', '-y', $pkg) }
                    elseif (Test-Cmd pacman) { Invoke-Install sudo @('pacman', '-S', '--noconfirm', $pkg) }
                    else { $script:installLog = 'no hay apt-get, dnf ni pacman'; return $false } }
    }
    # A fresh install is not on PATH of this process on Windows: re-read it.
    if ($IsWindows) { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
    return (Test-Tool $Tool) }

# ---- 1. Tools ----
foreach ($tool in $tools) {
    if (-not $tool.need) { Add-Result $tool.id 'NO APLICA' "Herramienta $($tool.id)" "no la pide el perfil $Perfil"; continue }
    $have = Test-Tool $tool
    if (-not $have -and $doInstall) { $have = Install-Tool $tool }
    $hint = $tool[$os] ? "paquete $($tool[$os])" : "sin paquete para $os`: $($tool.help)"
    if (-not $have -and $script:installLog) { $hint += " ($($script:installLog))" }
    Add-Result $tool.id ($have ? 'PASA' : 'FALLA') "Herramienta $($tool.id)" ($have ? (Get-ToolVersion $tool) : $hint)
    $results[$results.Count - 1] | Add-Member -NotePropertyName installable -NotePropertyValue ([bool]$tool[$os]) }

# Roblox Studio has no Linux build and no package: it is installed from create.roblox.com.
$studioPaths = @((Join-Path ($env:LOCALAPPDATA ?? '/nonexistent') 'Roblox\Versions'), '/Applications/RobloxStudio.app')
if ($os -eq 'linux') { Add-Result 'studio-app' 'NO APLICA' 'Roblox Studio' 'no existe para Linux' }
elseif ($studioPaths | Where-Object { Test-Path -LiteralPath $_ }) { Add-Result 'studio-app' 'PASA' 'Roblox Studio' }
else { Add-Result 'studio-app' 'PERSONA' 'Roblox Studio' 'instalar desde https://create.roblox.com y entrar con tu cuenta' }

# ---- 2. GitHub session and membership ----
$login = $null; $list = @()
if (Test-Cmd gh) {
    $who = Invoke-Quiet gh @('api', 'user', '--jq', '.login')
    if ($who.ok) { $login = $who.out; Add-Result 'gh-sesion' 'PASA' 'Sesión de GitHub' $login }
    else { Add-Result 'gh-sesion' 'PERSONA' 'Sesión de GitHub' 'correr: gh auth login --git-protocol https --web' }
} else { Add-Result 'gh-sesion' 'FALLA' 'Sesión de GitHub' 'falta gh' }

if ($login) {
    $member = Invoke-Quiet gh @('api', "user/memberships/orgs/$Org", '--jq', '.state')
    if ($member.ok -and $member.out -eq 'active') { Add-Result 'org' 'PASA' "Miembro de $Org" }
    elseif ($member.ok) { Add-Result 'org' 'PERSONA' "Miembro de $Org" "invitación $($member.out): aceptarla en https://github.com/$Org" }
    else { Add-Result 'org' 'FALLA' "Miembro de $Org" 'pedir la invitación en el Agent Board; si el token no tiene el scope: gh auth refresh -s read:org' }
    $listing = Invoke-Quiet gh @('repo', 'list', $Org, '--limit', '100', '--json', 'name,isPrivate,isArchived')
    $list = $listing.ok ? @($listing.out | ConvertFrom-Json | Where-Object { -not $_.isArchived }) : @()
    $private = @($list | Where-Object isPrivate).Count
    Add-Result 'repos' ($private -gt 0 ? 'PASA' : 'FALLA') 'Ves los repos privados' "$($list.Count) repos, $private privados"
}

# ---- 3. Clones. Every repo of the organization, discovered, never a fixed list. ----
New-Item -ItemType Directory -Force $Repos[0] | Out-Null
# Existing clones, by origin URL: two levels deep under every root.
$clones = @{}
foreach ($root in $Repos) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $level1 = @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue)
    $level2 = @($level1 | Where-Object { -not (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) } |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory -Force -ErrorAction SilentlyContinue })
    foreach ($dir in $level1 + $level2) {
        if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName '.git'))) { continue }
        $url = & git -C $dir.FullName remote get-url origin 2>$null
        if ("$url" -match "[:/]$([regex]::Escape($Org))/(.+?)(\.git)?/?$" -and -not $clones.ContainsKey($Matches[1])) { $clones[$Matches[1]] = $dir.FullName }
    }
}

$missing = @(); $noHooks = @(); $loopRows = @(); $branchIssues = @()
foreach ($repo in @($list)) {
    $dir = $clones[$repo.name]
    if (-not $dir) {
        $dir = Join-Path $Repos[0] $repo.name
        if ($doInstall) { & gh repo clone "$Org/$($repo.name)" $dir -- --quiet 2>$null | Out-Null }
        if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) { $missing += $repo.name; continue }
    }
    $why = Sync-CloneBranch -Dir $dir -Name $repo.name -Ecosystem $ecosystem -Org $Org -Install:$doInstall
    if ($why) { $branchIssues += $why }
    if (Test-Path -LiteralPath (Join-Path $dir '.githooks')) {
        if ($doInstall) { & git -C $dir config core.hooksPath .githooks }
        if ((& git -C $dir config core.hooksPath) -ne '.githooks') { $noHooks += $repo.name }
    }
    # Every clone with an AGENTS.md is a place where the agent works: it must carry the board hooks.
    if (Test-Path -LiteralPath (Join-Path $dir 'AGENTS.md')) { $loopRows += Test-AgentLoopClone -RepoPath $dir -Name $repo.name }
}
if ($login) {
    Add-Result 'clones' ($missing.Count ? 'FALLA' : 'PASA') "Clones en $($Repos -join ', ')" ($missing -join ', ')
    Add-Result 'ramas' ($branchIssues.Count ? 'PERSONA' : 'PASA') 'Clones en la rama de integración' ($branchIssues -join '; ')
    foreach ($row in $loopRows) { Add-Result $row.id $row.state $row.what $row.detail }
    Add-Result 'hooks' ($noHooks.Count ? 'FALLA' : 'PASA') 'Protección local de ramas (core.hooksPath)' ($noHooks -join ', ')
}

# ---- 4. Drive library ----
$libOk = $false
if (Test-Cmd rclone) {
    $env:RCLONE_LOG_LEVEL = 'ERROR'
    $root = $ecosystem.drive.raiz
    $hasRemote = { (Invoke-Quiet rclone @('listremotes')).out -match "(?m)^$([regex]::Escape($Remote)):" }
    $createCmd = "rclone config create $Remote drive scope=drive root_folder_id=$($root.id)"
    $noBrowser = (-not $IsWindows -and -not $IsMacOS -and -not $env:DISPLAY -and -not $env:WAYLAND_DISPLAY) -or [bool]$env:SSH_CONNECTION
    if (-not (& $hasRemote) -and $Action -eq 'install' -and -not $noBrowser) {
        # Opens the browser: the person authorizes with the Google account the folder was shared with.
        Invoke-Quiet rclone (@('config', 'create', $Remote, 'drive', 'scope=drive', "root_folder_id=$($root.id)")) | Out-Null
    }
    if (-not (& $hasRemote)) {
        $detail = $noBrowser `
            ? "este equipo no tiene navegador: en uno que sí lo tenga corre rclone authorize `"drive`", copia el token que imprime y aquí corre: $createCmd config_token=<token>" `
            : "corre pwsh tools/puesto.ps1 install (crea el remoto y abre el navegador para autorizar con tu cuenta de Google) o a mano: $createCmd"
        Add-Result 'drive' 'PERSONA' "Remoto de rclone '$Remote'" $detail
    } else {
        $ls = Invoke-Quiet rclone @('lsf', "${Remote}:", '--dirs-only')
        $libOk = $ls.ok -and $ls.out -match '10-kits'
        if ($libOk) { Add-Result 'drive' 'PASA' 'Drive del estudio' }
        elseif ($ls.ok) { Add-Result 'drive' 'PERSONA' 'Drive del estudio' "tu cuenta aún no ve la carpeta $($root.nombre): pide a Leon, dueño de la carpeta, que la comparta con tu cuenta de Google (Editor) y abre $($root.url) para confirmar que la ves; Leon solo verifica que rclone y el MCP de Drive vean la carpeta" }
        else { Add-Result 'drive' 'FALLA' 'Drive del estudio' "rclone no pudo listar el remoto; si venció la sesión: rclone config reconnect ${Remote}:" }
    }
} else { Add-Result 'drive' 'FALLA' 'Drive del estudio' 'falta rclone' }

# Whisper model for meeting transcription: a path under the home folder, same on the three systems.
$model = ($ecosystem.transcripcion.modelo -replace '^~', $HOME)
if (Test-Path -LiteralPath $model) { Add-Result 'modelo-whisper' 'PASA' 'Modelo de transcripción' }
else { Add-Result 'modelo-whisper' 'PERSONA' 'Modelo de transcripción (solo para transcribir reuniones)' "descárgalo con: curl -L --create-dirs -o `"$model`" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" }

# Every Drive folder that carries a manifest is a library folder: discovered, not listed here.
$kits = Join-Path $PSScriptRoot 'kits.ps1'
if ($libOk) {
    $folders = @((Invoke-Quiet rclone @('lsf', "${Remote}:", '--dirs-only')).out -split "`n" | ForEach-Object { $_.Trim().TrimEnd('/') } | Where-Object { $_ })
    $behind = @()
    foreach ($folder in $folders) {
        if (-not (Invoke-Quiet rclone @('lsf', "${Remote}:$folder/manifest.json")).out) { continue }
        $local = $libraryMap[$folder] ?? (Join-Path $Biblioteca $folder)
        if ($Action -eq 'install') { & pwsh -NoProfile -File $kits pull -Path $local -Remote $Remote -Folder $folder | Out-Null }
        $status = & pwsh -NoProfile -File $kits status -Path $local -Remote $Remote -Folder $folder
        $n = @($status | Where-Object { $_ -match '^(only in Drive|differs)' }).Count
        if ($n) { $behind += "$folder ($n)" }
    }
    Add-Result 'biblioteca' ($behind.Count ? 'FALLA' : 'PASA') 'Biblioteca al día con el Drive' ($behind -join ', ')
}

# ---- 5. Agent connections. Only what can be read without opening an app. ----
if (Test-Cmd claude) {
    $mcp = Invoke-Quiet claude @('mcp', 'list')
    foreach ($server in 'notion-studio', 'Roblox_Studio', 'blender') {
        $skip = ($server -eq 'blender' -and -not $wantArt) -or ($server -eq 'Roblox_Studio' -and $os -eq 'linux')
        if ($skip) { Add-Result "mcp-$server" 'NO APLICA' "Agente conectado a $server"; continue }
        $line = @($mcp.out -split "`n" | Where-Object { $_ -match "^$server\b" })[0]
        $state = -not $line ? 'PERSONA' : ($line -match 'Connected' ? 'PASA' : 'PERSONA')
        Add-Result "mcp-$server" $state "Agente conectado a $server" ($state -eq 'PASA' ? '' : 'ver docs/primera-vez.md, tabla de conexiones')
    }
} else { Add-Result 'mcp' 'NO APLICA' 'Conexiones MCP' 'no hay Claude Code en este equipo; tu agente usa su propio modo de conectarse' }

# Informational, never blocks: the Blender MCP warns about protocol 15 and expects 16 when the addon is stale.
if ($wantArt -and (Test-Tool ($tools | Where-Object id -eq 'blender'))) {
    Add-Result 'blender-addon' 'INFO' 'Addon de Blender (el MCP espera el protocolo 16)' 'si el MCP avisa protocolo 15, actualiza con: uvx mcp-for-blender install-addon, y reactiva el addon en Blender (Edit > Preferences > Add-ons)'
}
# ---- 5a. The studio's hooks at user level (issue 67): board in any folder, log of what was touched, notice
# before ending the turn, start lock. They point at the studio clone, so a pull updates them. ----
if (Test-Cmd claude) {
    $studioClone = $clones['studio'] ?? (Split-Path $PSScriptRoot -Parent)
    $hookScript = Join-Path $studioClone 'tools/board-hooks/board-hook.ps1'
    $settingsPath = Get-ClaudeSettingsPath
    $why = ''
    if ($doInstall -and (Test-Path -LiteralPath $hookScript)) { $why = Install-UserHooks -HookScript $hookScript -Path $settingsPath -Modo (Get-PuestoLoopConfig -Base $Base).modo }
    elseif ($doInstall) { $why = 'el clon de studio no trae tools/board-hooks/board-hook.ps1: actualízalo y vuelve a correr install' }
    $missingHooks = @()
    try { $missingHooks = @(Test-UserHooks (Read-ClaudeSettings $settingsPath) $hookScript (Get-PuestoLoopConfig -Base $Base).modo) }
    catch { if (-not $why) { $why = "$settingsPath no es JSON válido: corrígelo y vuelve a correr install" } }
    $hooksOk = -not $why -and -not $missingHooks.Count
    $hooksDetail = $hooksOk ? "modo=$((Get-PuestoLoopConfig -Base $Base).modo)" : ($why ? $why : "faltan $($missingHooks -join ', '): corre pwsh tools/puesto.ps1 install")
    Add-Result 'hooks-usuario' ($hooksOk ? 'PASA' : 'PERSONA') 'Hooks del estudio a nivel usuario (tablero, registro, aviso al cerrar, candado, guardia de rama)' $hooksDetail
} else { Add-Result 'hooks-usuario' 'NO APLICA' 'Hooks del estudio a nivel usuario' 'no hay Claude Code en este equipo' }

# ---- 5b. Roblox keys (presence only) and community. The key value is never read into a variable. ----
# The Roblox community comes from the ecosystem config, like every other id.
$communityId = [long]$ecosystem.roblox.grupo_id
$communityUrl = "https://www.roblox.com/communities/$communityId"
$keysFile = Join-Path $HOME '.config/nashei/claves.env'
function Test-KeyPresent { param([string]$Name)
    if ($script:keysSimulated) { return ($Name -in ($script:LlavesSimuladas -split ',')) }
    # The current process environment counts on every system (a variable exported for this session is present).
    if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($Name))) { return $true }
    if ($IsWindows) { return -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($Name, 'User')) }
    # Only the line shape NAME=<something> is tested; the matched text is discarded.
    return (Test-Path -LiteralPath $keysFile) -and [bool](Select-String -LiteralPath $keysFile -Pattern "^(export\s+)?$Name=.+" -Quiet) }
foreach ($key in 'ROBLOX_API_KEY', 'ROBLOX_MONETIZATION_API_KEY') {
    $present = Test-KeyPresent $key
    Add-Result "llave-$key" ($present ? 'PASA' : 'PERSONA') "Llave de Roblox $key" ($present ? '' : "crea tu llave de usuario en create.roblox.com/dashboard/credentials con acceso a la experiencia del grupo $communityId y guárdala con los comandos de docs/primera-vez.md") }

$robloxUserId = $config.robloxUserId
$inCommunity = $null
if ($robloxUserId -and -not $keysSimulated) {
    try {
        $roles = Invoke-RestMethod -Uri "https://groups.roblox.com/v2/users/$robloxUserId/groups/roles" -TimeoutSec 15
        $inCommunity = [bool](@($roles.data | Where-Object { $_.group.id -eq $communityId }).Count)
    } catch { $inCommunity = $null }
}
if ($inCommunity) { Add-Result 'comunidad' 'PASA' "Miembro de la comunidad de Roblox $communityId" }
else { Add-Result 'comunidad' 'PERSONA' "Miembro de la comunidad de Roblox $communityId" "unirse en $communityUrl y pedir el rol a un admin (para que el chequeo automático funcione, escribe robloxUserId en puesto.json)" }

# The agent's own configuration: areas, modo and wip in puesto.json (ADR 0003).
$loop = Test-AgentLoopConfig -Base $Base
Add-Result $loop.id $loop.state $loop.what $loop.detail

# ---- Report ----
if ($Json) { [pscustomobject]@{ os = $os; perfil = $Perfil; base = $Base; login = $login; results = $results } | ConvertTo-Json -Depth 4 }
else {
    "Puesto de $($login ?? 'sin sesión') en $os, perfil $Perfil, base $Base"
    $results | ForEach-Object { '{0,-9} {1}{2}' -f $_.state, $_.what, ($_.detail ? ": $($_.detail)" : '') }
    $count = { param($s) @($results | Where-Object state -eq $s).Count }
    "PASA $(& $count 'PASA') · FALLA $(& $count 'FALLA') · PERSONA $(& $count 'PERSONA') · NO APLICA $(& $count 'NO APLICA')"
}
if (@($results | Where-Object state -eq 'FALLA').Count) { exit 1 }
