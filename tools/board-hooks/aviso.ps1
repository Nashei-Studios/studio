#requires -Version 7
<#
.SYNOPSIS
  Work notices on the Agent Board (docs/flujo-arte-y-avisos.md), filled in from what the hooks logged (issue 67).

.DESCRIPTION
    empiezo   -Issue N [-Repo owner/name] -Que "..." [-Espero "..."]
              checks the issue is open and assigned to you, posts "empiezo", and opens the start lock for the session.
    retomo    the issue started in another session (less than 24 h ago) opens the lock of this one. Posts nothing.
    avance    -Que "..."          posts what changed, with the list of what was touched, and clears that list.
    cierro    -Que "..." [-Pr url] [-Asset id]   the same, and closes the lock again.
    pendiente                     shows the active issue and what is touched but not announced. Posts nothing.
    suelto                        forgets the active issue on this computer (release the claim with work.ps1).

  -Sesion: the Claude Code session id that the hooks print. With it, a notice lists only that session's changes
  and the lock opens only for it. Without it, every logged change is listed.
  Everything posted goes through ConvertTo-SafeText (no secrets, no personal paths); an @login is written as code
  so nobody is notified unless -Mencionar is given. The board is issue 1 of studio.
  Env: BOARD_LOGIN (override gh user), NASHEI_BASE (config folder).
  Tests only, and only with NASHEI_TEST=1 in CI: NASHEI_TABLERO_SIMULADO (file that receives the posts) and
  NASHEI_ISSUE_SIMULADO (issue JSON). Anywhere else those variables are refused.

.EXAMPLE
  pwsh tools/board-hooks/aviso.ps1 empiezo -Issue 12 -Repo Nashei-Studios/drain-for-loot -Que "bahía con arrecife y boyas" -Sesion <id>
  pwsh tools/board-hooks/aviso.ps1 avance -Que "océano y boyas listos; falta la isla" -Sesion <id>
  pwsh tools/board-hooks/aviso.ps1 cierro -Que "bahía terminada" -Pr https://github.com/Nashei-Studios/drain-for-loot/pull/30 -Sesion <id>
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('empiezo', 'retomo', 'avance', 'cierro', 'pendiente', 'suelto')][string]$Action = 'pendiente',
    [int]$Issue = 0,
    [string]$Repo = '',
    [string]$Que = '',
    [string]$Espero = 'nada',
    [string]$Pr = '',
    [string]$Asset = '',
    [string]$Sesion = '',
    [switch]$Mencionar
)
$ErrorActionPreference = 'Stop'
$studio = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $studio 'tools/lib/touch-log.ps1')
$eco = Get-Content -LiteralPath (Join-Path $studio 'config/ecosistema.json') -Raw | ConvertFrom-Json
$studioSlug = $eco.github.repos.studio.slug
$state = Get-NasheiStateDir

function Exit-Refused { param([string]$Message) [Console]::Error.WriteLine("aviso: $Message"); exit 2 }

# The test seams can never open the lock outside a test run in CI.
$seams = $env:NASHEI_TABLERO_SIMULADO -or $env:NASHEI_ISSUE_SIMULADO
$testing = $env:NASHEI_TEST -eq '1' -and [bool]$env:CI
if ($seams -and -not $testing) { Exit-Refused 'NASHEI_TABLERO_SIMULADO y NASHEI_ISSUE_SIMULADO solo valen en las pruebas (NASHEI_TEST=1 en CI); quítalas' }

function Invoke-GhTimed { param([string[]]$GhArgs, [int]$Seconds = 20)
    # gh without network would hang the agent's shell: give up after a while.
    $job = Start-ThreadJob { param($a) $o = & gh @a 2>&1; [pscustomobject]@{ code = $LASTEXITCODE; out = ($o | Out-String).Trim() } } -ArgumentList (, $GhArgs)
    if (-not (Wait-Job $job -Timeout $Seconds)) { Stop-Job $job; Remove-Job $job -Force; throw "aviso: gh no respondió en $Seconds s (¿hay red?)" }
    $r = Receive-Job $job; Remove-Job $job -Force
    $r }

function Get-Login {
    $l = $env:BOARD_LOGIN
    if (-not $l) {
        # tools/board caches the login of this clone; ask gh only when there is no cache yet.
        $cache = Join-Path $studio '.board/login'
        $l = (Test-Path -LiteralPath $cache) ? (Get-Content -LiteralPath $cache -Raw).Trim() : (Invoke-GhTimed @('api', 'user', '--jq', '.login')).out
    }
    if ($l -notmatch '^[A-Za-z0-9-]+$') { throw 'aviso: no hay sesión de GitHub (gh auth login)' }
    $l }

function Get-IssueInfo { param([string]$R, [int]$N)
    if ($testing -and $env:NASHEI_ISSUE_SIMULADO) { return $env:NASHEI_ISSUE_SIMULADO | ConvertFrom-Json }
    $r = Invoke-GhTimed @('issue', 'view', "$N", '-R', $R, '--json', 'state,title,assignees')
    if ($r.code -ne 0) { throw "aviso: no pude leer $R#$N ($($r.out))" }
    $r.out | ConvertFrom-Json }

function Test-Taken { param($Info, [string]$Login)
    "$($Info.state)" -eq 'OPEN' -and (@($Info.assignees | ForEach-Object { "$($_.login)".ToLowerInvariant() }) -contains $Login.ToLowerInvariant()) }

function Send-Board { param([string]$Text)
    if ($testing -and $env:NASHEI_TABLERO_SIMULADO) { Add-Content -LiteralPath $env:NASHEI_TABLERO_SIMULADO -Value $Text -Encoding utf8; return }
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
function Format-Free { param([string]$Text, [int]$Max)
    $t = ConvertTo-SafeText $Text $Max
    $Mencionar ? $t : (ConvertTo-NoMention $t) }

$active = Get-ActiveIssue $state
$entries = @(Get-TouchEntries $state $Sesion)

switch ($Action) {
    'pendiente' {
        if ($active) { "Issue activo: $(Format-Ref $active.repo $active.number) $($active.title) (sesión $($active.session))" } else { 'Sin issue activo (el candado está cerrado).' }
        if ($entries.Count) { "Sin avisar: $(Format-TouchList $entries -Max 4000)" } else { 'Nada tocado sin avisar.' }
    }
    'suelto' {
        Clear-ActiveIssue $state
        'Issue activo olvidado en este equipo. Para soltar el reclamo: pwsh tools/work.ps1 release N (en el repo del issue).'
    }
    'retomo' {
        if (-not $Sesion) { Exit-Refused 'retomo necesita -Sesion <id> (la imprime el hook al iniciar la sesión)' }
        if (-not $active) { Exit-Refused 'no hay un issue empezado en las últimas 24 h; empieza con: aviso.ps1 empiezo' }
        if (-not (Test-Taken (Get-IssueInfo $active.repo ([int]$active.number)) (Get-Login))) { Exit-Refused "$($active.repo)#$($active.number) ya no está abierto o tomado por ti" }
        Set-ActiveIssue $state $active.repo ([int]$active.number) $active.title $Sesion
        "Retomo $(Format-Ref $active.repo $active.number) en la sesión $Sesion."
    }
    'empiezo' {
        if ($Issue -lt 1 -or -not $Que.Trim()) { throw 'aviso empiezo: hacen falta -Issue N y -Que "..."' }
        if (-not $Repo) { $Repo = $studioSlug }
        if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'aviso: -Repo va como owner/name' }
        $login = Get-Login
        $info = Get-IssueInfo $Repo $Issue
        if (-not (Test-Taken $info $login)) {
            Exit-Refused "$Repo#$Issue no está abierto o no está tomado por $login. Tómalo primero: pwsh tools/work.ps1 claim $Issue (en ese repo) o gh issue edit $Issue -R $Repo --add-assignee @me"
        }
        $toca = $entries.Count ? (Format-TouchList $entries) : 'por ver'
        $text = "$(Get-AgentLabel $eco $login) empiezo $(Format-Ref $Repo $Issue): $(Format-Free $Que 300). Toca: $toca. Espero: $(Format-Free $Espero 120)."
        Send-Board $text
        Set-ActiveIssue $state $Repo $Issue (ConvertTo-SafeText "$($info.title)" 100) $Sesion
        Clear-TouchEntries $state $entries
    }
    { $_ -in 'avance', 'cierro' } {
        if (-not $Que.Trim()) { throw "aviso ${Action}: hace falta -Que `"...`"" }
        $r = $Repo ? $Repo : ($active ? $active.repo : '')
        $n = $Issue ? $Issue : ($active ? [int]$active.number : 0)
        if (-not $r -or $n -lt 1) { throw "aviso ${Action}: no hay issue activo; usa -Issue N -Repo owner/name o empieza con: aviso.ps1 empiezo" }
        $login = Get-Login
        $text = "$(Get-AgentLabel $eco $login) $Action $(Format-Ref $r $n): $(Format-Free $Que 300). Toca: $(Format-TouchList $entries)."
        if ($Pr) { $text += " PR $(ConvertTo-SafeText $Pr 200)." }
        if ($Asset) { $text += " Asset $(ConvertTo-SafeText $Asset 60)." }
        Send-Board $text
        Clear-TouchEntries $state $entries
        if ($Action -eq 'cierro') { Clear-ActiveIssue $state }
    }
}
