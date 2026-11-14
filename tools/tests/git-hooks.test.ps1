#requires -Version 7
# Tests of .githooks/pre-commit and .githooks/pre-push (issue 108): the branch rule enforced by git itself, which
# sees the real branch and the refs a push really updates however the command was written. A temporary repo
# uses this repo's .githooks; a local bare repo stands in for origin. No network.
# Run: pwsh tools/tests/git-hooks.test.ps1
$ErrorActionPreference = 'Stop'
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '../../.githooks')).Path -replace '\\', '/'
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }

$work = Join-Path ([IO.Path]::GetTempPath()) "nashei-githooks-$PID"
$savedCommit = $env:ALLOW_PROTECTED_COMMIT; $savedPush = $env:ALLOW_PROTECTED_PUSH
try {
    $origin = Join-Path $work 'origin.git'; $repo = Join-Path $work 'repo'
    & git init --quiet --bare -b develop $origin
    & git init --quiet -b develop $repo
    & git -C $repo config user.email t@t; & git -C $repo config user.name t
    & git -C $repo remote add origin $origin
    # The first commit and push happen before the hooks are on (a fresh repo has no other way to start).
    Set-Content (Join-Path $repo 'a.txt') 'a'; & git -C $repo add -A; & git -C $repo commit --quiet -m init
    & git -C $repo push --quiet origin develop 2>$null
    & git -C $repo config core.hooksPath $hooks
    $try = { param([scriptblock]$Cmd) & $Cmd *> $null; $LASTEXITCODE }

    Set-Content (Join-Path $repo 'a.txt') 'b'; & git -C $repo add -A
    Assert ((& $try { git -C $repo commit -m x }) -ne 0) 'pre-commit refuses a commit on develop'
    Assert ((& $try { git -C $repo -c alias.ci=commit ci -m x }) -ne 0) 'an alias does not get past it'
    Assert ((& $try { git -C $repo commit --no-verify -m x }) -eq 0) 'only --no-verify skips it (the shell guard denies that flag)'
    & git -C $repo reset --quiet --soft HEAD~1
    & git -C $repo switch --quiet -c main
    Assert ((& $try { git -C $repo commit -m x }) -ne 0) 'pre-commit refuses a commit on main'
    & git -C $repo switch --quiet -c feat/1-x
    Assert ((& $try { git -C $repo commit -m x }) -eq 0) 'a commit on a work branch passes'
    Assert ((& $try { git -C $repo push --quiet origin feat/1-x }) -eq 0) 'pushing a work branch passes'
    Assert ((& $try { git -C $repo push --quiet origin HEAD:develop }) -ne 0) 'pre-push refuses a fast-forward push onto develop'
    Assert ((& $try { git -C $repo push --quiet origin HEAD:main }) -ne 0) 'pre-push refuses a push onto main'
    & git -C $repo config remote.origin.push 'HEAD:refs/heads/develop'
    Assert ((& $try { git -C $repo push --quiet }) -ne 0) 'a remote.origin.push refspec that targets develop is refused too'
    & git -C $repo config --unset remote.origin.push
    Assert ((& $try { git -C $repo push --quiet origin --delete develop }) -ne 0) 'pre-push refuses deleting develop'
    $env:ALLOW_PROTECTED_PUSH = '1'
    Assert ((& $try { git -C $repo push --quiet origin HEAD:develop }) -eq 0) 'the stated emergency override lets a push through'
    $env:ALLOW_PROTECTED_PUSH = $savedPush
    & git -C $repo switch --quiet --detach
    Set-Content (Join-Path $repo 'a.txt') 'c'; & git -C $repo add -A
    Assert ((& $try { git -C $repo commit -m detached }) -eq 0) 'a detached HEAD is not a protected branch'
}
finally {
    $env:ALLOW_PROTECTED_COMMIT = $savedCommit; $env:ALLOW_PROTECTED_PUSH = $savedPush
    if (Test-Path $work) { Get-ChildItem $work -Recurse -Force | ForEach-Object { $_.Attributes = 'Normal' }; Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failed) { "$failed failed"; exit 1 }
'all passed'
