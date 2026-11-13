# Integration-branch handling for the studio clones. Dot-sourced by puesto.ps1 and by tools/tests/smoke.ps1.
# Gitflow: main only receives releases, so a working clone lives on the integration branch. That branch comes
# from the ecosystem config (rama_base per repo, rama_integracion as the default), never from a name written here.

function Get-IntegrationBranch { param([string]$Dir, [string]$Name, $Ecosystem, [string]$Org)
    $entry = $Ecosystem.github.repos.PSObject.Properties | Where-Object { $_.Value.slug -eq "$Org/$Name" } | Select-Object -First 1
    $want = $entry ? $entry.Value.rama_base : $Ecosystem.github.rama_integracion
    if (-not $want) { return $null }
    & git -C $Dir rev-parse --verify --quiet "refs/remotes/origin/$want" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0 ? $want : $null) }

# Returns '' when the clone is where it should be, otherwise the reason it is not (a person must act).
# Without -Install it only looks. With -Install it fetches, moves a clean clone that sits on the remote's
# default branch to the integration branch, and fast-forwards it.
function Sync-CloneBranch { param([string]$Dir, [string]$Name, $Ecosystem, [string]$Org, [switch]$Install)
    if ($Install) { & git -C $Dir fetch --quiet --prune origin 2>$null | Out-Null }
    $target = Get-IntegrationBranch -Dir $Dir -Name $Name -Ecosystem $Ecosystem -Org $Org
    if (-not $target) { return '' }
    $current = (& git -C $Dir branch --show-current 2>$null | Out-String).Trim()
    $default = ((& git -C $Dir symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null | Out-String).Trim() -replace '^origin/', '')
    if (-not $Install) {
        return (($current -and $current -eq $default -and $current -ne $target) ? "$Name está en $current y el trabajo va en $target (corre install)" : '') }
    $dirty = [bool]((& git -C $Dir status --porcelain 2>$null | Out-String).Trim())
    if ($current -ne $target) {
        # Only a clone sitting on the default branch is moved; any other branch is somebody's work.
        if ($current -and $current -ne $default) { return '' }
        if ($dirty) { return "$Name está en $current con cambios sin guardar: guárdalos o descártalos y vuelve a correr install para pasar a $target" }
        $ahead = [int](& git -C $Dir rev-list --count $current --not --remotes=origin 2>$null | Out-String).Trim()
        if ($ahead -gt 0) { return "$Name tiene $ahead commit(s) propios sin empujar en ${current}: empújalos o muévelos a una rama y vuelve a correr install para pasar a $target" }
        & git -C $Dir checkout --quiet $target 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return "$Name no pudo pasar a $target" }
    } elseif ($dirty) { return '' }
    & git -C $Dir pull --ff-only --quiet 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0 ? '' : "$Name no avanza con pull --ff-only en ${target}: revisa la rama a mano") }
