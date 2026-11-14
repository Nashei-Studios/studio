#requires -Version 7
# The herramientas-juego row of puesto check (issue 144): the game tools pinned in each rokit.toml must run,
# not only exist. Smart App Control blocks unsigned binaries such as Rokit's luau.exe (os error 4551), which
# only showed up when the game's coverage step failed on a workstation that passed every other row.
# Pure functions here; puesto.ps1 runs the tools and feeds the results in. Tests: tools/tests/rokit-tools.test.ps1.

# Reads the [tools] table of a rokit.toml: name -> "owner/repo@version", in file order.
function Get-RokitTools { param([string]$TomlText)
    $tools = [ordered]@{}
    $inTools = $false
    foreach ($line in ($TomlText -split "`r?`n")) {
        $text = ($line -replace '#.*$', '').Trim()
        if ($text -match '^\[(.+)\]$') { $inTools = $Matches[1].Trim() -eq 'tools'; continue }
        if ($inTools -and $text -match '^([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"$') { $tools[$Matches[1]] = $Matches[2] }
    }
    return $tools
}

# The cheapest call that proves a tool runs. The luau CLI has no --version flag.
function Get-RokitToolProbeArgs { param([string]$Name)
    if ($Name -eq 'luau') { return @('--help') }
    return @('--version')
}

# The command that trusts and installs every tool of a rokit.toml, run inside that clone.
function Get-RokitTrustCommand { param([System.Collections.IDictionary]$Tools)
    $sources = @($Tools.Values | ForEach-Object { ($_ -split '@')[0] })
    return "rokit trust $($sources -join ' '); rokit install"
}

# Smart App Control from HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy\VerifiedAndReputablePolicyState.
# Empty when the value is missing: not Windows, or a build without the feature.
function Get-SmartAppControlState { param($Value)
    switch ($Value) {
        0 { return 'off' }
        1 { return 'on' }
        2 { return 'evaluation' }
        default { return '' }
    }
}

# Reads the registry value on Windows; $null anywhere else or when it is missing.
function Read-SmartAppControlValue {
    if (-not $IsWindows) { return $null }
    $key = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name VerifiedAndReputablePolicyState -ErrorAction SilentlyContinue
    return $key ? $key.VerifiedAndReputablePolicyState : $null
}

# Decides the row from the tools that did not run. Failures: objects with name and out (what the call printed).
# Blocked by Application Control while Smart App Control is on or evaluating is the person's decision (PERSONA):
# turning it off cannot be undone on Windows 11 without reinstalling, so the agent never suggests it as a fix.
function Get-RokitToolchainRow {
    param([string]$Repo, [int]$Total, [object[]]$Failures = @(), [string]$SacState, [string]$TrustCommand)
    if (-not $Failures.Count) { return @{ state = 'PASA'; detail = "$Total herramientas de $Repo responden" } }
    $names = ($Failures | ForEach-Object { $_.name }) -join ', '
    $blocked = @($Failures | Where-Object { "$($_.out)" -match '4551|Control de aplicaciones|Application Control' })
    if ($blocked.Count -and $SacState -in 'on', 'evaluation') {
        $blockedNames = ($blocked | ForEach-Object { $_.name }) -join ', '
        return @{ state = 'PERSONA'; detail = "Smart App Control ($SacState) bloquea $blockedNames en $Repo (binario sin firma, os error 4551): el paso del gate que lo usa queda solo en el CI (luau: coverage). Apagarlo lo decide la persona en Seguridad de Windows > Control de aplicaciones y navegador, y en Windows 11 no se vuelve a encender sin reinstalar." }
    }
    $first = ("$($Failures[0].out)" -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    return @{ state = 'FALLA'; detail = "no responden en ${Repo}: $names ($first). En ese clon: $TrustCommand" }
}
