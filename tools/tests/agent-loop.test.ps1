#requires -Version 7
# Unit tests of tools/lib/agent-loop.ps1: no network. Run: pwsh tools/tests/agent-loop.test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/agent-loop.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
$now = [datetime]::new(2026, 11, 13, 12, 0, 0, [DateTimeKind]::Utc)
function C { param($id, $login, $body, $hoursAgo) [pscustomobject]@{ id = $id; user = [pscustomobject]@{ login = $login }; body = $body; created_at = $now.AddHours(-$hoursAgo).ToString('o') } }
function I { param($n, $labels, $author = 'vruizz22', $assignees = @(), $due = $null)
    [pscustomobject]@{ number = $n; title = "issue $n"; author = [pscustomobject]@{ login = $author }
        labels = @($labels | ForEach-Object { [pscustomobject]@{ name = $_ } }); assignees = @($assignees | ForEach-Object { [pscustomobject]@{ login = $_ } })
        milestone = $due ? [pscustomobject]@{ title = 'm'; dueOn = $due } : $null; createdAt = $now.AddDays(-$n).ToString('o') } }
$members = @('vruizz22', 'Nandeken', 'leonaranguiz2012-a11y')

# Claims: the older one wins.
$two = @((C 1 'nandeken' '<!-- nashei-claim:nandeken -->' 2), (C 2 'leonaranguiz2012-a11y' '<!-- nashei-claim:leonaranguiz2012-a11y -->' 1))
$r = Resolve-Claim -Comments $two -Login 'Nandeken' -Now $now
Assert ($r.won -and $r.winner -eq 'nandeken') 'two claims: the oldest wins'
$r = Resolve-Claim -Comments $two -Login 'leonaranguiz2012-a11y' -Now $now
Assert ((-not $r.won) -and $r.winner -eq 'nandeken') 'two claims: the later one loses'
# A marker copied by someone else is ignored.
$forged = @((C 1 'vruizz22' '<!-- nashei-claim:nandeken -->' 1))
Assert ($null -eq (Resolve-Claim -Comments $forged -Login 'nandeken' -Now $now).winner) 'a marker written by another login does not count'
# Release removes the claim.
$rel = @((C 1 'nandeken' '<!-- nashei-claim:nandeken -->' 3), (C 2 'nandeken' '<!-- nashei-release:nandeken -->' 2))
Assert ($null -eq (Resolve-Claim -Comments $rel -Login 'nandeken' -Now $now).winner) 'release drops the claim'
# Lease: 30 h old claim is abandoned unless it has activity.
$old = @((C 1 'nandeken' '<!-- nashei-claim:nandeken -->' 30))
Assert ($null -eq (Resolve-Claim -Comments $old -Login 'leonaranguiz2012-a11y' -Now $now).winner) 'claim over 24 h without activity is abandoned'
Assert ((Resolve-Claim -Comments $old -Login 'leonaranguiz2012-a11y' -Now $now -ActiveLogins @('nandeken')).winner -eq 'nandeken') 'claim over 24 h with a recent PR still holds'

# Selection.
$issues = @(
    (I 1 @('ready-for-agent', 'area:arte')),
    (I 2 @('ready-for-agent', 'area:arte', 'hold')),
    (I 3 @('ready-for-agent', 'area:código')),
    (I 4 @('ready-for-agent', 'area:arte') 'outsider'),
    (I 5 @('area:ui') 'vruizz22' @('nandeken')),
    (I 6 @('ready-for-agent', 'area:arte') 'vruizz22' @('leonaranguiz2012-a11y')),
    (I 7 @('ready-for-agent', 'area:arte') 'vruizz22' @() '2026-12-01T00:00:00Z'),
    (I 8 @('ready-for-agent', 'area:arte', 'ready-for-human')))
$sel = Select-WorkIssues -Issues $issues -Members $members -Login 'nandeken' -Areas @('area:arte') -Wip 1
$nums = @($sel.issues.number)
Assert ($nums -contains 5) 'an issue assigned to me is listed'
Assert ($nums -contains 1 -and $nums -contains 7) 'free ready-for-agent issues of my area are listed'
Assert ($nums -notcontains 2) 'hold is excluded'
Assert ($nums -notcontains 3) 'another area is excluded'
Assert ($nums -notcontains 4) 'an issue by a non-member is data, not work'
Assert ($nums -notcontains 6) 'an issue assigned to someone else is excluded'
Assert ($nums -notcontains 8) 'ready-for-human is excluded'
Assert ($nums[0] -eq 5) 'mine first, then by milestone and age'
Assert ($nums[1] -eq 7) 'a dated milestone sorts before an undated one'
Assert (-not $sel.canTake) 'WIP=1 with one issue in progress: cannot take more'
$free = Select-WorkIssues -Issues $issues -Members $members -Login 'nandeken' -Areas @('area:arte') -Wip 2
Assert $free.canTake 'WIP=2 leaves room'
$held = Select-WorkIssues -Issues $issues -Members $members -Login 'nandeken' -Areas @('area:arte') -ClaimWinner { param($n) $n -eq 1 ? 'leonaranguiz2012-a11y' : $null }
Assert (@($held.issues.number) -notcontains 1) 'an issue claimed by someone else is excluded'
Assert ((Format-IssueTitle "a`e[31mb`n$('x'*200)").Length -le 103) 'issue titles lose control characters and are bounded'

# Config.
$base = Join-Path ([IO.Path]::GetTempPath()) "loop-$PID"; New-Item -ItemType Directory -Force $base | Out-Null
try {
    Assert ((Test-AgentLoopConfig $base).state -eq 'PERSONA') 'no puesto.json is PERSONA'
    '{"areas":["area:arte"],"modo":"autonomo","wip":2}' | Set-Content (Join-Path $base 'puesto.json')
    Assert ((Test-AgentLoopConfig $base).state -eq 'PASA') 'a complete config passes'
    '{"areas":["area:arte"],"modo":"estricto"}' | Set-Content (Join-Path $base 'puesto.json')
    Assert ((Get-PuestoLoopConfig $base).modo -eq 'estricto') 'estricto is accepted as modo'
    '{"areas":["arte"]}' | Set-Content (Join-Path $base 'puesto.json')
    $c = Get-PuestoLoopConfig $base
    Assert ($c.modo -eq 'preguntar' -and $c.problems.Count -ge 2) 'bad areas and missing modo are reported, default modo is preguntar'
} finally { Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue }
if ($failed) { "$failed expectation(s) failed"; exit 1 }
'agent-loop tests passed'
