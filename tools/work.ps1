#requires -Version 7
<#
.SYNOPSIS
  Work queue of an agent on top of the Agent Board (ADR 0003): list, claim and release issues.

.DESCRIPTION
    list     issues for this person: assigned to their login, or ready-for-agent in their areas, unassigned
             and without hold. Only issues written by org members count; the rest is data.
    claim N  assign to @me, post a claim marker, then verify nobody older holds it. The older claim wins,
             the other side releases itself. Exit 0 = yours, 3 = lost, 2 = refused (not workable, or the optional wip cap from puesto.json is full).
             A won claim moves the Project card to github.project_estados.al_tomar ("En curso").
    release N  drop the claim (assignee and marker), tell the board and move the card to al_soltar ("Listo").
    In review and done are moved by the Project's built-in workflows (PR linked, PR merged, item closed).
    mine     the issues you hold right now.

  Configuration comes from ~/Nashei/puesto.json (areas, modo, wip); see `puesto.ps1 -?`.
  Env: BOARD_LOGIN (override gh user, tests), BOARD_REPO (owner/name), NASHEI_BASE (config folder).
  Never publishes to Roblox, spends Robux, makes anything public or touches secrets: that stays with the person.

.EXAMPLE
  pwsh tools/work.ps1 list
  pwsh tools/work.ps1 claim 12
  pwsh tools/work.ps1 release 12
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('list', 'claim', 'release', 'mine')][string]$Action = 'list',
    [Parameter(Position = 1)][int]$Number = 0,
    [string]$Repo = $env:BOARD_REPO,
    [int]$LeaseHours = 24,
    # Tests only: show hold issues too, so a test issue never reaches a real agent.
    [switch]$IncludeHold,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/agent-loop.ps1')

function Invoke-Gh { param([string[]]$GhArgs)
    $out = & gh @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh $($GhArgs -join ' '): $(($out | Out-String).Trim())" }
    $out }

if (-not $Repo) {
    $url = (git remote get-url origin 2>$null)
    if ($url -match '[:/]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(\.git)?$') { $Repo = $Matches[1] }
}
if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'work: cannot determine the repo; set BOARD_REPO=owner/name' }
$org = $Repo.Split('/')[0]
$login = $env:BOARD_LOGIN
if (-not $login) { $login = (Invoke-Gh @('api', 'user', '--jq', '.login') | Out-String).Trim() }
if ($login -notmatch '^[A-Za-z0-9-]+$') { throw 'work: invalid login' }
$cfg = Get-PuestoLoopConfig

function Get-Members { @(Invoke-Gh @('api', "orgs/$org/members", '--paginate', '--jq', '.[].login') | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }
function Get-Comments { param([int]$N) @(Invoke-Gh @('api', "repos/$Repo/issues/$N/comments?per_page=100", '--paginate') | ConvertFrom-Json) }
function Get-ActiveLogins { param([int]$N)
    # Activity that keeps a claim alive: an open PR that closes/refers to the issue, updated within the lease.
    $cut = [datetime]::UtcNow.AddHours(-$LeaseHours)
    $prs = @(Invoke-Gh @('pr', 'list', '-R', $Repo, '--state', 'open', '--json', 'author,body,headRefName,updatedAt', '--limit', '50') | ConvertFrom-Json)
    @($prs | Where-Object { ($_.body -match "#$N\b" -or $_.headRefName -match "(^|[-/])$N([-/]|$)") -and (ConvertTo-UtcTime $_.updatedAt) -gt $cut } |
        ForEach-Object { "$($_.author.login)".ToLowerInvariant() })
}
function Get-Holder { param([int]$N)
    (Resolve-Claim -Comments (Get-Comments $N) -Login $login -LeaseHours $LeaseHours -ActiveLogins (Get-ActiveLogins $N)).winner }
function Write-Board { param([string]$Text)
    # Through board.ps1, which finds Git Bash: in Windows PowerShell `bash` is usually not on PATH.
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'board.ps1') post $Text *> $null }
function Set-IssueStatus { param([int]$N, [string]$Key)
    # Moves the issue's card in every Project that has the status field and option (issue 102). The field
    # and the option names come from config/ecosistema.json. A failure warns with the fix and never undoes
    # the claim: the board stays right even when the card cannot move.
    $states = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '../config/ecosistema.json') -Raw | ConvertFrom-Json).github.project_estados
    $status = $states.$Key
    if (-not $states -or -not $status) { return }
    $owner, $name = $Repo.Split('/')
    $query = 'query($o:String!,$r:String!,$n:Int!,$f:String!){ repository(owner:$o,name:$r){ issue(number:$n){ projectItems(first:20){ nodes{ id project{ id title field(name:$f){ ... on ProjectV2SingleSelectField{ id options{ id name } } } } } } } } }'
    $mutation = 'mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){ updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){ projectV2Item{ id } } }'
    try {
        $data = Invoke-Gh @('api', 'graphql', '-f', "query=$query", '-f', "o=$owner", '-f', "r=$name", '-F', "n=$N", '-f', "f=$($states.campo)") | Out-String | ConvertFrom-Json
        $sel = Select-StatusUpdates -Items $data.data.repository.issue.projectItems.nodes -Status $status
        foreach ($u in $sel.updates) {
            Invoke-Gh @('api', 'graphql', '-f', "query=$mutation", '-f', "p=$($u.projectId)", '-f', "i=$($u.itemId)", '-f', "f=$($u.fieldId)", '-f', "o=$($u.optionId)") | Out-Null
        }
        foreach ($s in $sel.skipped) { Write-Warning "work: #$N no se movió en '$($s.project)': $($s.why)" }
        if ($sel.updates.Count) { "#$N -> $status en $($sel.updates.Count) Project(s)" }
    } catch {
        Write-Warning "work: #$N no pasó a '$status' en el Project ($($_.Exception.Message)). Si falta el permiso: gh auth refresh -h github.com -s project"
    }
}

switch ($Action) {
    { $_ -in 'list', 'mine' } {
        $issues = @(Invoke-Gh @('issue', 'list', '-R', $Repo, '--state', 'open', '--limit', '100', '--json', 'number,title,labels,assignees,author,milestone,createdAt') | ConvertFrom-Json)
        $sel = Select-WorkIssues -Issues $issues -Members (Get-Members) -Login $login -Areas $cfg.areas -Wip $cfg.wip `
            -ClaimWinner { param($n) Get-Holder $n } -IncludeHold:$IncludeHold
        $rows = $Action -eq 'mine' ? @($sel.issues | Where-Object kind -eq 'mine') : $sel.issues
        if ($Json) { [pscustomobject]@{ modo = $cfg.modo; wip = $cfg.wip; taken = $sel.taken; canTake = $sel.canTake; issues = $rows } | ConvertTo-Json -Depth 5; break }
        "modo=$($cfg.modo) wip=$($cfg.wip -lt 1 ? 'sin tope' : $cfg.wip) en curso=$($sel.taken) login=$login"
        if (-not $rows.Count) { 'sin issues para ti' }
        foreach ($r in $rows) { '#{0} [{1}] {2}{3}' -f $r.number, $r.kind, $r.title, ($r.milestone ? " ($($r.milestone))" : '') }
    }
    'claim' {
        if ($Number -lt 1) { throw 'work claim: issue number required' }
        $issues = @(Invoke-Gh @('issue', 'list', '-R', $Repo, '--state', 'open', '--limit', '100', '--json', 'number,title,labels,assignees,author,milestone,createdAt') | ConvertFrom-Json)
        $sel = Select-WorkIssues -Issues $issues -Members (Get-Members) -Login $login -Areas $cfg.areas -Wip $cfg.wip `
            -ClaimWinner { param($n) Get-Holder $n } -IncludeHold:$IncludeHold
        $target = $sel.issues | Where-Object number -eq $Number
        if (-not $target) { Write-Error "work: #$Number is not workable for $login (not a member's issue, hold, other area or already held)"; exit 2 }
        if ($target.kind -ne 'mine' -and -not $sel.canTake) { Write-Error "work: wip cap full ($($sel.taken)/$($cfg.wip)); finish or release one first"; exit 2 }
        Invoke-Gh @('issue', 'edit', "$Number", '-R', $Repo, '--add-assignee', $login) | Out-Null
        Invoke-Gh @('api', "repos/$Repo/issues/$Number/comments", '-f', "body=<!-- nashei-claim:$login -->`n$login's agent takes this issue (lease $LeaseHours h without a PR or commits).") | Out-Null
        $res = Resolve-Claim -Comments (Get-Comments $Number) -Login $login -LeaseHours $LeaseHours -ActiveLogins (Get-ActiveLogins $Number)
        if ($res.won) {
            Write-Board "[$login's agente] tomo #$Number ($($target.title))."
            Set-IssueStatus $Number 'al_tomar'
            "claimed #$Number"; exit 0
        }
        Invoke-Gh @('issue', 'edit', "$Number", '-R', $Repo, '--remove-assignee', $login) | Out-Null
        Invoke-Gh @('api', "repos/$Repo/issues/$Number/comments", '-f', "body=<!-- nashei-release:$login -->`n$login's agent releases: $($res.winner) claimed first.") | Out-Null
        Write-Error "work: #$Number is held by $($res.winner) (older claim); released"; exit 3
    }
    'release' {
        if ($Number -lt 1) { throw 'work release: issue number required' }
        Invoke-Gh @('issue', 'edit', "$Number", '-R', $Repo, '--remove-assignee', $login) | Out-Null
        Invoke-Gh @('api', "repos/$Repo/issues/$Number/comments", '-f', "body=<!-- nashei-release:$login -->`n$login's agent releases this issue.") | Out-Null
        Write-Board "[$login's agente] suelto #$Number."
        Set-IssueStatus $Number 'al_soltar'
        "released #$Number"
    }
}
