#requires -Version 7
# Tests of tools/lib/pinned-hooks.ps1 (issue 108, finding 1): the user-level hooks run from a worktree pinned to
# the latest release tag on main, never from the live branch of the studio clone. No network: a local bare repo
# stands in for origin. Run: pwsh tools/tests/pinned-hooks.test.ps1
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/pinned-hooks.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }

$work = Join-Path ([IO.Path]::GetTempPath()) "nashei-pinned-$PID"
try {
    $origin = Join-Path $work 'origin.git'; $clone = Join-Path $work 'studio'; $pin = Join-Path $work 'hooks/studio'
    & git init --quiet --bare -b main $origin
    & git clone --quiet $origin $clone 2>$null
    & git -C $clone config user.email t@t; & git -C $clone config user.name t
    $commit = { param([string]$msg) Set-Content (Join-Path $clone 'tools.txt') $msg; & git -C $clone add -A; & git -C $clone commit --quiet -m $msg }
    & $commit 'one'; & git -C $clone tag v0.1.0
    & $commit 'two'; & git -C $clone tag v0.2.0
    & git -C $clone push --quiet origin main --tags 2>$null
    # A tag that is not on main (a release candidate on a side branch) never counts.
    & git -C $clone switch --quiet -c develop; & $commit 'three'; & git -C $clone tag v0.3.0
    & git -C $clone push --quiet origin develop --tags 2>$null
    & git -C $clone fetch --quiet origin

    Assert ((Get-LatestReleaseTag $clone) -eq 'v0.2.0') 'the latest tag merged into origin/main wins; a tag only on develop does not'
    $state = Test-PinnedHooks $clone $pin
    Assert ($state.state -eq 'PERSONA' -and $state.detail -like '*install*') 'no pinned copy yet: PERSONA asking for install'

    Assert ((Install-PinnedHooks $clone $pin) -eq '') 'install pins a worktree'
    Assert ((& git -C $pin rev-parse HEAD) -eq (& git -C $clone rev-parse 'v0.2.0^{commit}')) 'the worktree sits on the release commit'
    Assert (-not "$(& git -C $pin branch --show-current)".Trim()) 'the worktree is detached: no branch to pull into it'
    $state = Test-PinnedHooks $clone $pin
    Assert ($state.state -eq 'PASA' -and $state.detail -like '*v0.2.0*') 'a pinned, clean copy passes and names its tag'

    & git -C $clone switch --quiet develop; & $commit 'four'
    Assert ((Test-PinnedHooks $clone $pin).state -eq 'PASA') 'work on the live clone does not touch the pinned copy'

    Set-Content (Join-Path $pin 'tools.txt') 'tampered'
    $state = Test-PinnedHooks $clone $pin
    Assert ($state.state -eq 'FALLA' -and $state.detail -like '*cambios*') 'a changed file in the pinned copy is a FALLA'
    Assert ((Install-PinnedHooks $clone $pin) -eq '' -and (Test-PinnedHooks $clone $pin).state -eq 'PASA') 'install puts the pinned copy back to the tag'

    & git -C $clone switch --quiet main; & $commit 'five'; & git -C $clone tag v0.4.0
    & git -C $clone push --quiet origin main --tags 2>$null; & git -C $clone fetch --quiet origin
    $state = Test-PinnedHooks $clone $pin
    Assert ($state.state -eq 'PERSONA' -and $state.detail -like '*v0.4.0*') 'a newer release asks for install again'
    Assert ((Install-PinnedHooks $clone $pin) -eq '' -and (Test-PinnedHooks $clone $pin).detail -like '*v0.4.0*') 'install moves the pin to the new release'

    $none = Join-Path $work 'no-tags'; & git init --quiet -b main $none
    Assert ((Install-PinnedHooks $none (Join-Path $work 'pin2')) -like '*tag*') 'a clone without a release tag is not pinned and says why'
}
finally {
    if (Test-Path $work) { Get-ChildItem $work -Recurse -Force | ForEach-Object { $_.Attributes = 'Normal' }; Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failed) { "$failed failed"; exit 1 }
'all passed'
