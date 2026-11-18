#requires -Version 7
# Skills of Claude Code for the art role, installed at user level and pinned to one commit of their repo
# (config/ecosistema.json, skills_arte). Pinned, not "latest": the skill runs a script with the person's rights,
# so what was audited is exactly what gets installed. No window is opened: only git, with output captured.
# Tested by tools/tests/pinned-skills.test.ps1.

$script:PinMarker = '.pinned-sha'

function Get-PinnedSkillDir { param([string]$SkillsRoot, $Spec) Join-Path $SkillsRoot $Spec.id }

function Test-PinnedSkill { param([string]$SkillsRoot, $Spec)
    <# PASA when the skill sits at the pinned commit; PERSONA when it is missing or at another commit (install fixes it). #>
    $dir = Get-PinnedSkillDir $SkillsRoot $Spec
    $skillFile = Join-Path $dir 'SKILL.md'
    $marker = Join-Path $dir $script:PinMarker
    if (-not (Test-Path -LiteralPath $skillFile)) {
        return @{ state = 'PERSONA'; detail = "falta la skill $($Spec.id): corre pwsh tools/puesto.ps1 install" } }
    $have = (Test-Path -LiteralPath $marker) ? (Get-Content -LiteralPath $marker -Raw).Trim() : ''
    if ($have -ne $Spec.sha) {
        return @{ state = 'PERSONA'; detail = "la skill $($Spec.id) no está en el commit fijado $($Spec.sha.Substring(0, 7)): corre pwsh tools/puesto.ps1 install" } }
    @{ state = 'PASA'; detail = "$($Spec.id) en $($Spec.sha.Substring(0, 7)) ($($Spec.licencia))" } }

function Install-PinnedSkill { param([string]$SkillsRoot, $Spec, [string]$RemoteBase = 'https://github.com')
    <# Fetches exactly $Spec.sha and copies $Spec.carpeta to <SkillsRoot>/<id>. Returns '' or the reason it failed. #>
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nashei-skill-$PID-$($Spec.id)"
    try {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        New-Item -ItemType Directory -Force $tmp | Out-Null
        & git -C $tmp init --quiet 2>$null
        & git -C $tmp remote add origin "$RemoteBase/$($Spec.repo).git" 2>$null
        & git -C $tmp fetch --quiet --depth 1 origin $Spec.sha 2>$null
        if ($LASTEXITCODE -ne 0) { & git -C $tmp fetch --quiet origin 2>$null }
        if ($LASTEXITCODE -ne 0) { return "no pude bajar $($Spec.repo) (¿hay internet?)" }
        & git -C $tmp -c advice.detachedHead=false checkout --quiet --force $Spec.sha 2>$null
        if ($LASTEXITCODE -ne 0) { return "el commit $($Spec.sha.Substring(0, 7)) no existe en $($Spec.repo)" }
        $src = Join-Path $tmp $Spec.carpeta
        if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) { return "$($Spec.carpeta)/SKILL.md no está en ese commit" }
        $dest = Get-PinnedSkillDir $SkillsRoot $Spec
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        New-Item -ItemType Directory -Force $SkillsRoot | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
        Set-Content -LiteralPath (Join-Path $dest $script:PinMarker) -Value $Spec.sha -NoNewline -Encoding utf8NoBOM
        return ''
    }
    catch { return "no pude instalar $($Spec.id): $($_.Exception.Message)" }
    finally {
        if (Test-Path -LiteralPath $tmp) {
            # git marks pack files read-only: clear it so the cleanup works on Windows.
            Get-ChildItem -LiteralPath $tmp -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    } }
