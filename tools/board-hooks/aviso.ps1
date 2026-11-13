#requires -Version 7
<#
.SYNOPSIS
  Work notices on the Agent Board (docs/flujo-arte-y-avisos.md), filled in from what the hooks logged (issue 67).

.DESCRIPTION
    empiezo   -Issue N [-Repo owner/name] -Que "..." [-Espero "..."]
              checks the issue is open and assigned to you, posts "empiezo", and opens the start lock.
    avance    -Que "..."          posts what changed, with the list of what was touched, and clears that list.
    cierro    -Que "..." [-Pr url] [-Asset id]   the same, and closes the lock again.
    pendiente                     shows the active issue and what is touched but not announced. Posts nothing.
    suelto                        forgets the active issue on this computer (release the claim with work.ps1).

  The list of touched things comes from <Base>/estado, written by board-hook.ps1 registro. Everything posted goes
  through ConvertTo-SafeText: no secrets, no personal paths. The board is issue 1 of studio (or BOARD_ISSUE).
  Env: BOARD_LOGIN (override gh user), NASHEI_BASE (config folder).
  Tests only: NASHEI_TABLERO_SIMULADO (file that receives the posts) and NASHEI_ISSUE_SIMULADO (issue JSON).

.EXAMPLE
  pwsh tools/board-hooks/aviso.ps1 empiezo -Issue 12 -Repo Nashei-Studios/drain-for-loot -Que "bahía con arrecife y boyas"
  pwsh tools/board-hooks/aviso.ps1 avance -Que "océano y boyas listos; falta la isla"
  pwsh tools/board-hooks/aviso.ps1 cierro -Que "bahía terminada" -Pr https://github.com/Nashei-Studios/drain-for-loot/pull/30
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('empiezo', 'avance', 'cierro', 'pendiente', 'suelto')][string]$Action = 'pendiente',
    [int]$Issue = 0,
    [string]$Repo = '',
    [string]$Que = '',
    [string]$Espero = 'nada',
    [string]$Pr = '',
    [string]$Asset = ''
)
$ErrorActionPreference = 'Stop'
$studio = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $studio 'tools/lib/touch-log.ps1')
$eco = Get-Content -LiteralPath (Join-Path $studio 'config/ecosistema.json') -Raw | ConvertFrom-Json
$studioSlug = $eco.github.repos.studio.slug
$state = Get-NasheiStateDir

function Get-Login {
    $l = $env:BOARD_LOGIN
    if (-not $l) { $l = (& gh api user --jq .login 2>$null | Out-String).Trim() }
    if ($l -notmatch '^[A-Za-z0-9-]+$') { throw 'aviso: no hay sesión de GitHub (gh auth login)' }
    $l }

function Get-IssueInfo { param([string]$R, [int]$N)
    if ($env:NASHEI_ISSUE_SIMULADO) { return $env:NASHEI_ISSUE_SIMULADO | ConvertFrom-Json }
    $json = & gh issue view $N -R $R --json state,title,assignees 2>&1
    if ($LASTEXITCODE -ne 0) { throw "aviso: no pude leer $R#$N ($(($json | Out-String).Trim()))" }
    $json | ConvertFrom-Json }

function Send-Board { param([string]$Text)
    if ($env:NASHEI_TABLERO_SIMULADO) { Add-Content -LiteralPath $env:NASHEI_TABLERO_SIMULADO -Value $Text -Encoding utf8; return }
    $saved = $env:BOARD_REPO
    try {
        # The Agent Board is the one of studio, whichever folder the agent is in.
        $env:BOARD_REPO = $studioSlug
        Push-Location $studio
        $out = & pwsh -NoProfile -File (Join-Path $studio 'tools/board.ps1') post $Text 2>&1
        if ($LASTEXITCODE -ne 0) { throw "aviso: el tablero no aceptó el mensaje ($(($out | Out-String).Trim()))" }
        ($out | Select-Object -Last 1)
    } finally { Pop-Location; $env:BOARD_REPO = $saved } }

function Format-Ref { param([string]$R, [int]$N) ($R -eq $studioSlug) ? "#$N" : "$R#$N" }

$active = Get-ActiveIssue $state
$entries = @(Get-TouchEntries $state)

switch ($Action) {
    'pendiente' {
        if ($active) { "Issue activo: $(Format-Ref $active.repo $active.number) $($active.title)" } else { 'Sin issue activo (el candado está cerrado).' }
        if ($entries.Count) { "Sin avisar: $(Format-TouchList $entries -Max 4000)" } else { 'Nada tocado sin avisar.' }
    }
    'suelto' {
        Clear-ActiveIssue $state
        'Issue activo olvidado en este equipo. Para soltar el reclamo: pwsh tools/work.ps1 release N (en el repo del issue).'
    }
    'empiezo' {
        if ($Issue -lt 1 -or -not $Que.Trim()) { throw 'aviso empiezo: hacen falta -Issue N y -Que "..."' }
        if (-not $Repo) { $Repo = $studioSlug }
        if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'aviso: -Repo va como owner/name' }
        $login = Get-Login
        $info = Get-IssueInfo $Repo $Issue
        if ("$($info.state)" -ne 'OPEN') { [Console]::Error.WriteLine("aviso: $Repo#$Issue no está abierto"); exit 2 }
        $assigned = @($info.assignees | ForEach-Object { "$($_.login)".ToLowerInvariant() })
        if ($assigned -notcontains $login.ToLowerInvariant()) {
            [Console]::Error.WriteLine("aviso: $Repo#$Issue no está tomado por $login. Tómalo primero: pwsh tools/work.ps1 claim $Issue (en ese repo) o gh issue edit $Issue -R $Repo --add-assignee @me")
            exit 2
        }
        $toca = $entries.Count ? (Format-TouchList $entries) : 'por ver'
        $text = "$(Get-AgentLabel $eco $login) empiezo $(Format-Ref $Repo $Issue): $(ConvertTo-SafeText $Que 300). Toca: $toca. Espero: $(ConvertTo-SafeText $Espero 120)."
        Send-Board $text
        Set-ActiveIssue $state $Repo $Issue (ConvertTo-SafeText "$($info.title)" 100)
        Clear-TouchEntries $state $entries.Count
    }
    { $_ -in 'avance', 'cierro' } {
        if (-not $Que.Trim()) { throw "aviso ${Action}: hace falta -Que `"...`"" }
        $r = $Repo ? $Repo : ($active ? $active.repo : '')
        $n = $Issue ? $Issue : ($active ? [int]$active.number : 0)
        if (-not $r -or $n -lt 1) { throw "aviso ${Action}: no hay issue activo; usa -Issue N -Repo owner/name o empieza con: aviso.ps1 empiezo" }
        $login = Get-Login
        $text = "$(Get-AgentLabel $eco $login) $Action $(Format-Ref $r $n): $(ConvertTo-SafeText $Que 300). Toca: $(Format-TouchList $entries)."
        if ($Pr) { $text += " PR $(ConvertTo-SafeText $Pr 200)." }
        if ($Asset) { $text += " Asset $(ConvertTo-SafeText $Asset 60)." }
        Send-Board $text
        Clear-TouchEntries $state $entries.Count
        if ($Action -eq 'cierro') { Clear-ActiveIssue $state }
    }
}
