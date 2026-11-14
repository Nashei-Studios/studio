#requires -Version 7
# Trusted path for the user-level hooks (issue 108, finding 1). They run in every session of every repo, so they
# must not run from the live branch of the studio clone: whatever lands on that branch would run with the
# person's rights. `puesto.ps1 install` pins a git worktree of the studio clone, detached, at the latest release
# tag merged into origin/main (it passed PR, CI and the release), and registers the hooks from there. `check`
# verifies the worktree still sits on that tag with no local change. A worktree, not a loose copy, so board.ps1,
# work.ps1 and aviso.ps1 keep finding the repo and its remote.
# Tested by tools/tests/pinned-hooks.test.ps1.

function Get-LatestReleaseTag { param([string]$Clone)
    <# The newest v* tag reachable from origin/main; '' when there is none. Reads local refs: fetch first. #>
    $tags = @(& git -C $Clone tag --list 'v*' --sort=-v:refname --merged origin/main 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $tags.Count) { return '' }
    "$($tags[0])".Trim() }

function Get-TagCommit { param([string]$Clone, [string]$Tag)
    (& git -C $Clone rev-parse --verify --quiet "$Tag^{commit}" 2>$null | Out-String).Trim() }

function Install-PinnedHooks { param([string]$Clone, [string]$Dir)
    <# Pins $Dir to the latest release tag. Returns '' on success or the reason it did not. #>
    $tag = Get-LatestReleaseTag $Clone
    if (-not $tag) { return "el clon de studio no tiene un tag de release en origin/main (git -C `"$Clone`" fetch --tags origin)" }
    $isWorktree = (Test-Path -LiteralPath (Join-Path $Dir '.git')) -and
        ((& git -C $Dir rev-parse --git-common-dir 2>$null | Out-String).Trim() -ne '')
    if ($isWorktree) {
        # Back to the tag, dropping any local change: the pinned copy is never edited by hand.
        & git -C $Dir checkout --quiet --force --detach $tag 2>$null
        if ($LASTEXITCODE -eq 0) { & git -C $Dir clean --quiet -fdx 2>$null }
    }
    else {
        if (Test-Path -LiteralPath $Dir) { return "$Dir existe y no es la copia fijada de los hooks: muévelo y vuelve a correr install" }
        New-Item -ItemType Directory -Force (Split-Path $Dir -Parent) | Out-Null
        & git -C $Clone worktree add --quiet --detach $Dir $tag 2>$null
    }
    if ($LASTEXITCODE -ne 0) { return "no pude dejar $Dir en $tag" }
    '' }

function Test-PinnedHooks { param([string]$Clone, [string]$Dir)
    <# PASA when $Dir is a clean worktree on the latest release tag; PERSONA when it is missing or a newer release
       exists (install fixes it); FALLA when it has local changes or sits on another commit. #>
    $tag = Get-LatestReleaseTag $Clone
    if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) {
        return @{ state = 'PERSONA'; detail = "los hooks no corren desde una copia fijada: corre pwsh tools/puesto.ps1 install" }
    }
    $head = (& git -C $Dir rev-parse HEAD 2>$null | Out-String).Trim()
    $dirty = (& git -C $Dir status --porcelain 2>$null | Out-String).Trim()
    if ($dirty) { return @{ state = 'FALLA'; detail = "la copia fijada $Dir tiene cambios locales; nadie la edita: corre pwsh tools/puesto.ps1 install para dejarla en $tag" } }
    $pinnedTag = @(& git -C $Clone tag --points-at $head --list 'v*' 2>$null | Sort-Object -Descending)
    if (-not $pinnedTag.Count) { return @{ state = 'FALLA'; detail = "la copia fijada $Dir no está en un tag de release: corre pwsh tools/puesto.ps1 install" } }
    if ($tag -and $head -ne (Get-TagCommit $Clone $tag)) {
        return @{ state = 'PERSONA'; detail = "hay una versión nueva de los hooks ($tag; tienes $($pinnedTag[0])): corre pwsh tools/puesto.ps1 install" }
    }
    @{ state = 'PASA'; detail = "$($pinnedTag[0]) en $Dir" } }
