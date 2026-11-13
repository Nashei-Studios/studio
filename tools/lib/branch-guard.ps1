#requires -Version 7
# Branch guard: nobody edits code straight on develop or main of an organization clone (docs/en-vivo-y-ramas.md).
# Used by `board-hook.ps1 rama` (PreToolUse for Edit, Write, MultiEdit and NotebookEdit) and tested by
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

function Get-BranchViolation { param([string]$Path, $Ecosystem)
    <# $null unless $Path sits inside a clone of an organization repo whose current branch is protected. #>
    $dir = Split-Path $Path -Parent
    while ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        $up = Split-Path $dir -Parent
        if ($up -eq $dir) { return $null }
        $dir = $up
    }
    if (-not $dir) { return $null }
    $top = (& git -C $dir rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $top) { return $null }
    $org = "$($Ecosystem.github.organizacion)"
    if (-not (Test-OrgRemote $top 'origin' $org)) { return $null }
    $branch = (& git -C $top branch --show-current 2>$null | Out-String).Trim()
    if (-not $branch -or $branch -notin (Get-ProtectedBranches $Ecosystem)) { return $null }
    [pscustomobject]@{ top = ($top -replace '\\', '/'); name = (Split-Path $top -Leaf); branch = $branch } }

function Get-BranchDecision { param([string]$Modo)
    <# estricto and autonomo deny; preguntar asks the person. #>
    $Modo -in 'estricto', 'autonomo' ? 'deny' : 'ask' }

function Format-BranchReason { param($Violation, [string]$Modo)
    $v = $Violation
    $new = "git -C `"$($v.top)`" switch -c feat/<n>-<slug>"
    $tree = "git -C `"$($v.top)`" worktree add -b feat/<n>-<slug> `"<carpeta>`" origin/$($v.branch)"
    "Guardia de rama (modo ${Modo}): $($v.name) está en $($v.branch) y ahí no se edita código; todo entra por PR (docs/en-vivo-y-ramas.md). Toma el issue (work.ps1 claim <n>) y crea tu rama: $new (o fix/ para un arreglo). Si hay otra sesión en este clon, usa un worktree: $tree. Luego repite la edición." }
