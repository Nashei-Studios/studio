#requires -Version 7
# Unit tests of tools/lib/pinned-skills.ps1 (the pinned art skill). No network: the "remote" is a local git repo.
# Run: pwsh tools/tests/pinned-skills.test.ps1
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/pinned-skills.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
function Get-Head { param([string]$Repo) (& git -C $Repo rev-parse HEAD | Out-String).Trim() }

$work = Join-Path ([IO.Path]::GetTempPath()) "nashei-pinned-skills-$PID"
try {
    $remote = Join-Path $work 'remote/owner/skills.git'
    New-Item -ItemType Directory -Force (Join-Path $remote 'my-skill/scripts') | Out-Null
    Set-Content (Join-Path $remote 'my-skill/SKILL.md') 'v1' -NoNewline
    Set-Content (Join-Path $remote 'my-skill/scripts/build.py') 'print(1)' -NoNewline
    & git -C $remote init --quiet
    & git -C $remote add -A
    & git -C $remote -c user.name=t -c user.email=t@t commit --quiet -m one
    $first = Get-Head $remote
    Set-Content (Join-Path $remote 'my-skill/SKILL.md') 'v2' -NoNewline
    & git -C $remote -c user.name=t -c user.email=t@t commit --quiet -am two
    $second = Get-Head $remote
    $base = ([Uri](Join-Path $work 'remote')).AbsoluteUri
    $skills = Join-Path $work 'home/.claude/skills'
    $spec = [pscustomobject]@{ id = 'my-skill'; repo = 'owner/skills'; carpeta = 'my-skill'; sha = $first; licencia = 'MIT' }

    Assert ((Test-PinnedSkill $skills $spec).state -eq 'PERSONA') 'a missing skill is PERSONA, with the install command'
    $why = Install-PinnedSkill $skills $spec $base
    Assert ($why -eq '') "install succeeds ($why)"
    Assert ((Get-Content (Join-Path $skills 'my-skill/SKILL.md') -Raw) -eq 'v1') 'installs the pinned commit, not the newest one'
    Assert (Test-Path (Join-Path $skills 'my-skill/scripts/build.py')) 'copies the whole skill folder'
    Assert ((Test-PinnedSkill $skills $spec).state -eq 'PASA') 'check passes once installed'

    $moved = [pscustomobject]@{ id = 'my-skill'; repo = 'owner/skills'; carpeta = 'my-skill'; sha = $second; licencia = 'MIT' }
    Assert ((Test-PinnedSkill $skills $moved).state -eq 'PERSONA') 'a new pin is reported until install runs'
    Assert ((Install-PinnedSkill $skills $moved $base) -eq '') 're-install moves to the new pin'
    Assert ((Get-Content (Join-Path $skills 'my-skill/SKILL.md') -Raw) -eq 'v2') 'the folder now holds the new commit'
    Assert ((Test-PinnedSkill $skills $moved).state -eq 'PASA') 'check passes at the new pin'

    $bad = [pscustomobject]@{ id = 'my-skill'; repo = 'owner/skills'; carpeta = 'my-skill'; sha = ('0' * 40); licencia = 'MIT' }
    Assert ((Install-PinnedSkill $skills $bad $base) -ne '') 'a commit that does not exist is refused with a reason'
    $nofolder = [pscustomobject]@{ id = 'x'; repo = 'owner/skills'; carpeta = 'nope'; sha = $first; licencia = 'MIT' }
    Assert ((Install-PinnedSkill $skills $nofolder $base) -like '*SKILL.md*') 'a folder without SKILL.md is refused'

    $cfg = Get-Content (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json
    $real = @($cfg.skills_arte | Where-Object id -eq 'momentum-3d-models')
    Assert ($real.Count -eq 1 -and $real[0].sha -match '^[0-9a-f]{40}$') 'the ecosystem config pins momentum-3d-models to a full sha'
}
finally {
    if (Test-Path $work) {
        Get-ChildItem $work -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if ($failed) { "$failed failed"; exit 1 }
'all passed'
