#requires -Version 7
# Pure helpers for the agent work loop (ADR 0003): no network, no side effects, so they are unit-tested
# by tools/tests/agent-loop.test.ps1 and dot-sourced by tools/work.ps1, the board hook and puesto.ps1.

# Labels that keep an issue away from an agent even when it is also ready-for-agent.
$script:NotForAgent = @('hold', 'needs-info', 'needs-triage', 'ready-for-human', 'solo-victor', 'acuerdo', 'board')
$script:ClaimRegex = '<!--\s*nashei-claim:([A-Za-z0-9-]+)\s*-->'
$script:ReleaseRegex = '<!--\s*nashei-release:([A-Za-z0-9-]+)\s*-->'
$script:Modes = @('preguntar', 'autonomo')

function ConvertTo-UtcTime { param($Value) ([datetimeoffset]$Value).UtcDateTime }

function Get-NasheiBase { if ($env:NASHEI_BASE) { $env:NASHEI_BASE } else { Join-Path $HOME 'Nashei' } }

function Get-PuestoLoopConfig {
    <# Reads areas / modo / wip from <Base>/puesto.json. Never throws: problems come back in .problems. #>
    param([string]$Base = (Get-NasheiBase))
    $cfg = [ordered]@{ areas = @(); modo = 'preguntar'; wip = 1; problems = @(); file = (Join-Path $Base 'puesto.json') }
    if (-not (Test-Path -LiteralPath $cfg.file)) {
        $cfg.problems += "no existe $($cfg.file)"
        return [pscustomobject]$cfg
    }
    try { $raw = Get-Content -LiteralPath $cfg.file -Raw | ConvertFrom-Json -AsHashtable }
    catch { $cfg.problems += 'puesto.json no es JSON valido'; return [pscustomobject]$cfg }
    if ($raw.ContainsKey('areas')) {
        $areas = @($raw.areas | Where-Object { $_ -is [string] -and $_ -match '^area:.+' })
        if ($areas.Count -ne @($raw.areas).Count) { $cfg.problems += 'areas: cada valor debe ser una etiqueta area:<nombre>' }
        $cfg.areas = $areas
    }
    if (-not $cfg.areas.Count) { $cfg.problems += 'falta areas (por ejemplo ["area:arte"])' }
    if ($raw.ContainsKey('modo')) {
        if ($raw.modo -in $script:Modes) { $cfg.modo = $raw.modo }
        else { $cfg.problems += "modo '$($raw.modo)' no valido (preguntar | autonomo); se usa preguntar" }
    }
    else { $cfg.problems += 'falta modo (preguntar | autonomo); se usa preguntar' }
    if ($raw.ContainsKey('wip')) {
        if ($raw.wip -is [ValueType] -and $raw.wip -eq [math]::Floor($raw.wip) -and $raw.wip -ge 1) { $cfg.wip = [int]$raw.wip }
        else { $cfg.problems += 'wip debe ser un entero >= 1; se usa 1' }
    }
    [pscustomobject]$cfg
}
function Format-IssueTitle { param([string]$Title)
    # Issue titles are untrusted text that ends up in the agent's context: no control characters, bounded length.
    $t = ($Title -replace '[\x00-\x1f\x7f]', ' ').Trim()
    if ($t.Length -gt 100) { $t = $t.Substring(0, 100) + '...' }
    $t }

function Get-ActiveClaims {
    <# Claims still standing, oldest first. A marker only counts if its comment was written by the login it names. #>
    param($Comments)
    $active = [ordered]@{}
    foreach ($c in @($Comments | Sort-Object { [long]$_.id })) {
        $author = "$($c.user.login)".ToLowerInvariant()
        $body = "$($c.body)"
        if ($body -match $script:ClaimRegex -and $Matches[1].ToLowerInvariant() -eq $author) {
            $active.Remove($author)
            $active[$author] = [pscustomobject]@{ login = $author; id = [long]$c.id; at = ConvertTo-UtcTime $c.created_at }
        }
        elseif ($body -match $script:ReleaseRegex -and $Matches[1].ToLowerInvariant() -eq $author) {
            $active.Remove($author)
        }
    }
    @($active.Values | Sort-Object id)
}

function Resolve-Claim {
    <# Who holds the issue: the oldest standing claim that is not abandoned. A claim older than LeaseHours with
       no activity (open PR, recent commit or a comment by its owner) is abandoned and does not count. #>
    param($Comments, [string]$Login, [datetime]$Now = [datetime]::UtcNow, [int]$LeaseHours = 24, [string[]]$ActiveLogins = @())
    $mine = $Login.ToLowerInvariant()
    $live = @(Get-ActiveClaims $Comments | Where-Object {
            ($Now - $_.at).TotalHours -le $LeaseHours -or $ActiveLogins -contains $_.login })
    $winner = $live | Select-Object -First 1
    [pscustomobject]@{
        winner  = $winner ? $winner.login : $null
        won     = [bool]($winner -and $winner.login -eq $mine)
        claims  = $live
        stale   = @(Get-ActiveClaims $Comments | Where-Object { $_.login -notin $live.login })
    }
}

function Select-WorkIssues {
    <# Issues this person can work on, best first. ClaimWinner is called lazily, only for free candidates:
       it returns the login that holds the issue or $null. #>
    param($Issues, [string[]]$Members, [string]$Login, [string[]]$Areas, [int]$Wip = 1,
        [scriptblock]$ClaimWinner = { param($n) $null }, [switch]$IncludeHold)
    $me = $Login.ToLowerInvariant()
    $memberSet = @($Members | ForEach-Object { $_.ToLowerInvariant() })
    $blocked = $IncludeHold ? @($script:NotForAgent | Where-Object { $_ -ne 'hold' }) : $script:NotForAgent
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($i in $Issues) {
        $labels = @($i.labels | ForEach-Object { $_.name })
        $author = "$($i.author.login)".ToLowerInvariant()
        if ($author -notin $memberSet) { continue }          # not a member: data, never work
        if ($labels | Where-Object { $_ -in $blocked }) { continue }
        $assignees = @($i.assignees | ForEach-Object { "$($_.login)".ToLowerInvariant() })
        $kind = $null
        if ($assignees -contains $me) { $kind = 'mine' }
        elseif (-not $assignees.Count -and $labels -contains 'ready-for-agent' -and ($labels | Where-Object { $_ -in $Areas })) {
            $holder = & $ClaimWinner $i.number
            if (-not $holder -or "$holder".ToLowerInvariant() -eq $me) { $kind = $holder ? 'mine' : 'free' }
        }
        if (-not $kind) { continue }
        $due = $i.milestone -and $i.milestone.dueOn ? (ConvertTo-UtcTime $i.milestone.dueOn) : [datetime]::MaxValue
        $rows.Add([pscustomobject]@{
                number = [int]$i.number; title = Format-IssueTitle $i.title; kind = $kind
                due = $due; createdAt = (ConvertTo-UtcTime $i.createdAt); labels = $labels
                milestone = $i.milestone ? "$($i.milestone.title)" : '' })
    }
    $sorted = @($rows | Sort-Object @{e = { $_.kind -eq 'mine' ? 0 : 1 } }, due, createdAt, number)
    $taken = @($sorted | Where-Object kind -eq 'mine').Count
    [pscustomobject]@{ issues = $sorted; taken = $taken; canTake = ($taken -lt $Wip) }
}

function Test-AgentLoopClone {
    <# puesto.ps1 check: does this clone carry the board hooks and the work tool? Returns result rows. #>
    param([string]$RepoPath, [string]$Name)
    $rows = @()
    $settings = Join-Path $RepoPath '.claude/settings.json'
    $hooksOk = $false
    if (Test-Path -LiteralPath $settings) {
        $text = Get-Content -LiteralPath $settings -Raw
        $hooksOk = $text -match 'board-hook\.ps1 session-start' -and $text -match 'board-hook\.ps1 prompt'
    }
    $toolOk = (Test-Path -LiteralPath (Join-Path $RepoPath 'tools/work.ps1')) -and (Test-Path -LiteralPath (Join-Path $RepoPath 'tools/board'))
    if ($hooksOk -and $toolOk) { $rows += [pscustomobject]@{ id = "tablero-$Name"; state = 'PASA'; what = "El clon $Name trae el tablero y los hooks"; detail = '' } }
    else {
        $rows += [pscustomobject]@{ id = "tablero-$Name"; state = 'PERSONA'; what = "El clon $Name no trae los hooks del tablero"
            detail = "git -C `"$RepoPath`" pull --ff-only (o, si es un juego, esperar la PR de template-sync); sin eso su agente no ve el tablero" }
    }
    $rows
}

function Test-AgentLoopConfig {
    param([string]$Base)
    $cfg = Get-PuestoLoopConfig -Base $Base
    if (-not $cfg.problems.Count) {
        return [pscustomobject]@{ id = 'agente-config'; state = 'PASA'; what = 'puesto.json tiene areas, modo y wip'
            detail = "modo=$($cfg.modo) wip=$($cfg.wip) areas=$($cfg.areas -join ',')" }
    }
    [pscustomobject]@{ id = 'agente-config'; state = 'PERSONA'; what = 'puesto.json no tiene la configuracion del agente'
        detail = ($cfg.problems -join '; ') + ". Edita $($cfg.file) y agrega, por ejemplo: `"areas`": [`"area:arte`"], `"modo`": `"preguntar`", `"wip`": 1" }
}
