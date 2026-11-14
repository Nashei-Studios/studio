#requires -Version 7
# Branch guard: nobody edits code straight on develop or main of an organization clone (docs/en-vivo-y-ramas.md).
# Used by `board-hook.ps1 rama` (PreToolUse for Edit, Write, MultiEdit and NotebookEdit, and for `git commit` and
# `git push` in Bash and PowerShell, issue 108) and tested by
# tools/tests/board-hooks.test.ps1. Which branches are protected and which organization counts both come from
# config/ecosistema.json, never from a name written here. Needs touch-log.ps1 (Test-OrgRemote) loaded.

function Get-ProtectedBranches { param($Ecosystem)
    <# github.ramas_protegidas; without it, the integration branch plus every rama_base. #>
    $listed = @($Ecosystem.github.ramas_protegidas | Where-Object { $_ })
    if ($listed.Count) { return $listed }
    $bases = @($Ecosystem.github.repos.PSObject.Properties | ForEach-Object { $_.Value.rama_base })
    @(@($Ecosystem.github.rama_integracion) + $bases | Where-Object { $_ } | Select-Object -Unique) }

function Get-EditTarget { param($ToolInput, [string]$Cwd)
    <# The file an edit tool is about to change, absolute; $null when the call names none. #>
    $path = "$($ToolInput.file_path)"
    if (-not $path) { $path = "$($ToolInput.notebook_path)" }
    if (-not $path) { return $null }
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path ($Cwd ? $Cwd : (Get-Location).Path) $path }
    $path }

function Get-OrgCloneTop { param([string]$Dir, $Ecosystem)
    <# The top folder of the organization clone that holds $Dir (an existing folder); $null otherwise. #>
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir -PathType Container)) { return $null }
    $top = (& git -C $Dir rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $top) { return $null }
    if (-not (Test-OrgRemote $top 'origin' "$($Ecosystem.github.organizacion)")) { return $null }
    $top }

function Get-CurrentBranch { param([string]$Top) (& git -C $Top branch --show-current 2>$null | Out-String).Trim() }

function Get-BranchViolation { param([string]$Path, $Ecosystem)
    <# $null unless $Path sits inside a clone of an organization repo whose current branch is protected. #>
    $dir = Split-Path $Path -Parent
    while ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        $up = Split-Path $dir -Parent
        if ($up -eq $dir) { return $null }
        $dir = $up
    }
    $top = Get-OrgCloneTop $dir $Ecosystem
    if (-not $top) { return $null }
    $branch = Get-CurrentBranch $top
    if (-not $branch -or $branch -notin (Get-ProtectedBranches $Ecosystem)) { return $null }
    [pscustomobject]@{ top = ($top -replace '\\', '/'); name = (Split-Path $top -Leaf); branch = $branch } }

function Get-ShellGitOps { param([string]$Command, [string]$Cwd)
    <# Each `git commit` and `git push` of a Bash or PowerShell command (issue 108, finding 3): where it runs
       (git -C <dir>, else the last cd / Set-Location / Push-Location before it, else the hook's cwd) and, for a
       push, the branches its refspecs name (empty = the current branch). Heuristic on purpose: aliases, scripts
       and variables are not followed, so anything it cannot read passes (the guard fails open). #>
    $quoted = '"[^"]+"|''[^'']+''|[^\s;&|]+'
    $rx = "(?i)(?<![\w-])git(?<opts>(?:\s+-C\s+(?:$quoted)|\s+-c\s+\S+)*)\s+(?<op>commit|push)(?![\w-])(?<rest>[^;&|\n]*)"
    $ops = @()
    foreach ($m in [regex]::Matches($Command, $rx)) {
        $dir = ''
        $c = [regex]::Match($m.Groups['opts'].Value, "-C\s+(?<d>$quoted)")
        if ($c.Success) { $dir = $c.Groups['d'].Value.Trim('"', "'") }
        if (-not $dir) {
            $before = $Command.Substring(0, $m.Index)
            $cds = [regex]::Matches($before, "(?i)(?:^|[;&|]\s*)(?:cd|pushd|Set-Location|Push-Location|sl)\s+(?:-(?:Literal)?Path\s+)?(?<d>$quoted)")
            if ($cds.Count) { $dir = $cds[$cds.Count - 1].Groups['d'].Value.Trim('"', "'") }
        }
        if ($dir -match '^~') { $dir = $HOME + $dir.Substring(1) }
        if (-not $dir) { $dir = $Cwd }
        elseif ($Cwd -and -not [IO.Path]::IsPathRooted($dir)) { $dir = Join-Path $Cwd $dir }
        $targets = @()
        if ($m.Groups['op'].Value -ieq 'push') {
            # The first word after the options is the remote; the rest are refspecs (src:dst, +force, refs/heads/x).
            $words = @($m.Groups['rest'].Value.Trim() -split '\s+' | Where-Object { $_ -and $_ -notmatch '^-' })
            foreach ($ref in @($words | Select-Object -Skip 1)) {
                $dst = (($ref -split ':')[-1]).TrimStart('+') -replace '^refs/heads/', ''
                if ($dst -and $dst -ne 'HEAD') { $targets += $dst }
            }
        }
        $ops += [pscustomobject]@{ op = $m.Groups['op'].Value.ToLowerInvariant(); dir = ($dir -replace '\\', '/'); targets = $targets }
    }
    $ops }

function Get-ShellBranchViolation { param($Op, $Ecosystem)
    <# $null unless the commit lands on, or the push goes to, a protected branch of an organization clone. #>
    $top = Get-OrgCloneTop $Op.dir $Ecosystem
    if (-not $top) { return $null }
    $protected = @(Get-ProtectedBranches $Ecosystem)
    $current = Get-CurrentBranch $top
    $names = ($Op.op -eq 'push' -and @($Op.targets).Count) ? @($Op.targets) : @($current)
    $hit = @($names | Where-Object { $_ -and $_ -in $protected } | Select-Object -First 1)
    if (-not $hit.Count) { return $null }
    [pscustomobject]@{ top = ($top -replace '\\', '/'); name = (Split-Path $top -Leaf); branch = $hit[0]; op = $Op.op } }

function Format-ShellBranchReason { param($Violation, [string]$Modo)
    $v = $Violation
    $what = $v.op -eq 'push' ? "git push a $($v.branch)" : "git commit en $($v.branch)"
    $new = "git -C `"$($v.top)`" switch -c feat/<n>-<slug>"
    "Guardia de rama (modo ${Modo}): $what de $($v.name). En develop y main no se hace commit ni push directo; todo entra por PR (docs/en-vivo-y-ramas.md). Toma el issue (work.ps1 claim <n>), crea tu rama con $new (o un worktree) y repite el comando ahí." }

function Get-BranchDecision { param([string]$Modo)
    <# estricto and autonomo deny; preguntar asks the person. #>
    $Modo -in 'estricto', 'autonomo' ? 'deny' : 'ask' }

function Format-BranchReason { param($Violation, [string]$Modo)
    $v = $Violation
    $new = "git -C `"$($v.top)`" switch -c feat/<n>-<slug>"
    $tree = "git -C `"$($v.top)`" worktree add -b feat/<n>-<slug> `"<carpeta>`" origin/$($v.branch)"
    "Guardia de rama (modo ${Modo}): $($v.name) está en $($v.branch) y ahí no se edita código; todo entra por PR (docs/en-vivo-y-ramas.md). Toma el issue (work.ps1 claim <n>) y crea tu rama: $new (o fix/ para un arreglo). Si hay otra sesión en este clon, usa un worktree: $tree. Luego repite la edición." }
