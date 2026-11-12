#requires -Version 7
<#
.SYNOPSIS
  Sets up and verifies a studio workstation from nothing, on Windows, macOS or Linux.

.DESCRIPTION
    check    prints PASA / FALLA / NO APLICA / PERSONA per check, changes nothing, exits 1 on any FALLA.
    install  installs what is missing with the system package manager, clones the repos, sets the
             git hooks and pulls the Drive library; then runs check.

  A step that needs the person (a browser login, an invitation) is never automated: it is printed
  as PERSONA with the exact command to run.

.EXAMPLE
  pwsh tools/puesto.ps1 install
  pwsh tools/puesto.ps1 check -Perfil arte
  pwsh tools/puesto.ps1 check -Json
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('check', 'install')][string]$Action = 'check',
    # arte: models, map, ideas, tests. codigo: the game toolchain too. todo: both.
    [ValidateSet('arte', 'codigo', 'todo')][string]$Perfil = 'todo',
    # Where clones and the library live. Pick once and keep it.
    [string]$Base = (Join-Path $HOME 'Nashei'),
    [string]$Repos = (Join-Path $Base 'repos'),
    [string]$Biblioteca = (Join-Path $Base 'biblioteca'),
    [string]$Org = 'Nashei-Studios',
    [string]$Remote = 'nashei',
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$os = $IsWindows ? 'windows' : ($IsMacOS ? 'macos' : 'linux')
$wantArt = $Perfil -in 'arte', 'todo'
$wantCode = $Perfil -in 'codigo', 'todo'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result { param([string]$Id, [string]$State, [string]$What, [string]$Detail = '')
    $results.Add([pscustomobject]@{ id = $Id; state = $State; what = $What; detail = $Detail }) }
function Test-Cmd { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Invoke-Quiet { param([string]$Exe, [string[]]$ExeArgs)
    try { $out = & $Exe @ExeArgs 2>&1; return [pscustomobject]@{ ok = ($LASTEXITCODE -eq 0); out = ($out | Out-String).Trim() } }
    catch { return [pscustomobject]@{ ok = $false; out = "$_" } } }

# One row per tool: command that proves it, package id per system, who needs it.
# A missing id means there is no package for that system: the row says where to get it.
$tools = @(
    @{ id = 'git';     cmd = 'git';     need = $true;      windows = 'Git.Git';                  macos = 'git';              linux = 'git' }
    @{ id = 'gh';      cmd = 'gh';      need = $true;      windows = 'GitHub.cli';               macos = 'gh';               linux = 'gh' }
    @{ id = 'rclone';  cmd = 'rclone';  need = $true;      windows = 'Rclone.Rclone';            macos = 'rclone';           linux = 'rclone' }
    @{ id = 'node';    cmd = 'node';    need = $true;      windows = 'OpenJS.NodeJS.LTS';        macos = 'node';             linux = 'nodejs' }
    @{ id = 'blender'; cmd = 'blender'; need = $wantArt;   windows = 'BlenderFoundation.Blender'; macos = '--cask blender';  linux = 'blender'
       paths = @('C:\Program Files\Blender Foundation', '/Applications/Blender.app') }
    @{ id = 'obsidian'; cmd = 'obsidian'; need = $true;   windows = 'Obsidian.Obsidian';         macos = '--cask obsidian'; help = 'https://obsidian.md'
       paths = @((Join-Path ($env:LOCALAPPDATA ?? '/nonexistent') 'Programs/Obsidian'), (Join-Path ($env:LOCALAPPDATA ?? '/nonexistent') 'Obsidian'), '/Applications/Obsidian.app') }
    @{ id = 'rokit';   cmd = 'rokit';   need = $wantCode;  windows = 'Rojo.Rokit'; help = 'https://github.com/rojo-rbx/rokit#installation' }
    @{ id = 'vscode';  cmd = 'code';    need = $wantCode;  windows = 'Microsoft.VisualStudioCode'; macos = '--cask visual-studio-code'; help = 'https://code.visualstudio.com' }
)

function Test-Tool { param($Tool)
    if (Test-Cmd $Tool.cmd) { return $true }
    foreach ($p in @($Tool.paths)) { if ($p -and (Test-Path -LiteralPath $p)) { return $true } }
    return $false }

function Install-Tool { param($Tool)
    $pkg = $Tool[$os]
    if (-not $pkg) { return $false }
    switch ($os) {
        'windows' { if (-not (Test-Cmd winget)) { return $false }
                    & winget install --id $pkg --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null }
        'macos'   { if (-not (Test-Cmd brew)) { return $false }
                    & brew install @($pkg -split ' ') | Out-Null }
        'linux'   { if (Test-Cmd apt-get) { & sudo apt-get install -y $pkg | Out-Null }
                    elseif (Test-Cmd dnf) { & sudo dnf install -y $pkg | Out-Null }
                    elseif (Test-Cmd pacman) { & sudo pacman -S --noconfirm $pkg | Out-Null }
                    else { return $false } }
    }
    # A fresh install is not on PATH of this process on Windows: re-read it.
    if ($IsWindows) { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
    return (Test-Tool $Tool) }

# ---- 1. Tools ----
foreach ($tool in $tools) {
    if (-not $tool.need) { Add-Result $tool.id 'NO APLICA' "Herramienta $($tool.id)" "no la pide el perfil $Perfil"; continue }
    $have = Test-Tool $tool
    if (-not $have -and $Action -eq 'install') { $have = Install-Tool $tool }
    $hint = $tool[$os] ? "paquete $($tool[$os])" : "sin paquete para $os`: $($tool.help)"
    Add-Result $tool.id ($have ? 'PASA' : 'FALLA') "Herramienta $($tool.id)" ($have ? '' : $hint) }

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
New-Item -ItemType Directory -Force $Repos | Out-Null
$missing = @(); $noHooks = @()
foreach ($repo in @($list)) {
    $dir = Join-Path $Repos $repo.name
    if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) {
        if ($Action -eq 'install') { & gh repo clone "$Org/$($repo.name)" $dir -- --quiet 2>$null | Out-Null }
        if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) { $missing += $repo.name; continue }
    }
    if (Test-Path -LiteralPath (Join-Path $dir '.githooks')) {
        if ($Action -eq 'install') { & git -C $dir config core.hooksPath .githooks }
        if ((& git -C $dir config core.hooksPath) -ne '.githooks') { $noHooks += $repo.name }
    }
}
if ($login) {
    Add-Result 'clones' ($missing.Count ? 'FALLA' : 'PASA') "Clones en $Repos" ($missing -join ', ')
    Add-Result 'hooks' ($noHooks.Count ? 'FALLA' : 'PASA') 'Protección local de ramas (core.hooksPath)' ($noHooks -join ', ')
}

# ---- 4. Drive library ----
$libOk = $false
if (Test-Cmd rclone) {
    $env:RCLONE_LOG_LEVEL = 'ERROR'
    $remotes = Invoke-Quiet rclone @('listremotes')
    if ($remotes.out -notmatch "(?m)^$([regex]::Escape($Remote)):") {
        Add-Result 'drive' 'PERSONA' "Remoto de rclone '$Remote'" 'ver docs/drive.md, sección "Tenerlo todo al día": se autoriza una vez en el navegador'
    } else {
        $ls = Invoke-Quiet rclone @('lsf', "${Remote}:", '--dirs-only')
        $libOk = $ls.ok -and $ls.out -match '10-kits'
        Add-Result 'drive' ($libOk ? 'PASA' : 'FALLA') 'Drive del estudio' ($libOk ? '' : "el remoto no lista 10-kits; si venció la sesión: rclone config reconnect ${Remote}:")
    }
} else { Add-Result 'drive' 'FALLA' 'Drive del estudio' 'falta rclone' }

# Every Drive folder that carries a manifest is a library folder: discovered, not listed here.
$kits = Join-Path $PSScriptRoot 'kits.ps1'
if ($libOk) {
    $folders = @((Invoke-Quiet rclone @('lsf', "${Remote}:", '--dirs-only')).out -split "`n" | ForEach-Object { $_.Trim().TrimEnd('/') } | Where-Object { $_ })
    $behind = @()
    foreach ($folder in $folders) {
        if (-not (Invoke-Quiet rclone @('lsf', "${Remote}:$folder/manifest.json")).out) { continue }
        $local = Join-Path $Biblioteca $folder
        if ($Action -eq 'install') { & pwsh -NoProfile -File $kits pull -Path $local -Remote $Remote -Folder $folder | Out-Null }
        $status = & pwsh -NoProfile -File $kits status -Path $local -Remote $Remote -Folder $folder
        $n = @($status | Where-Object { $_ -match '^(only in Drive|differs)' }).Count
        if ($n) { $behind += "$folder ($n)" }
    }
    Add-Result 'biblioteca' ($behind.Count ? 'FALLA' : 'PASA') "Biblioteca al día en $Biblioteca" ($behind -join ', ')
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

# ---- Report ----
if ($Json) { [pscustomobject]@{ os = $os; perfil = $Perfil; base = $Base; login = $login; results = $results } | ConvertTo-Json -Depth 4 }
else {
    "Puesto de $($login ?? 'sin sesión') en $os, perfil $Perfil, base $Base"
    $results | ForEach-Object { '{0,-9} {1}{2}' -f $_.state, $_.what, ($_.detail ? ": $($_.detail)" : '') }
    $count = { param($s) @($results | Where-Object state -eq $s).Count }
    "PASA $(& $count 'PASA') · FALLA $(& $count 'FALLA') · PERSONA $(& $count 'PERSONA') · NO APLICA $(& $count 'NO APLICA')"
}
if (@($results | Where-Object state -eq 'FALLA').Count) { exit 1 }
