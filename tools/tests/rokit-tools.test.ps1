#requires -Version 7
# Unit tests of tools/lib/rokit-tools.ps1 (the herramientas-juego row of puesto check, issue 144). No network.
# Run: pwsh tools/tests/rokit-tools.test.ps1
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/rokit-tools.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }

# --- rokit.toml ---
$toml = @'
# Toolchain pinned for reproducible builds.
[tools]
rojo = "rojo-rbx/rojo@7.7.1"
luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"   # trailing comment
luau = "luau-lang/luau@0.745.0"

[other]
notatool = "x/y@1"
'@
$parsed = Get-RokitTools $toml
Assert ($parsed.Count -eq 3) 'reads the three entries of [tools] and nothing from other tables'
Assert ($parsed['luau-lsp'] -eq 'JohnnyMorganz/luau-lsp@1.70.1') 'keeps the full spec of a tool with a dash in its name'
Assert (-not $parsed.Contains('notatool')) 'ignores keys outside [tools]'
Assert ((Get-RokitTools '').Count -eq 0) 'an empty file has no tools'
Assert ((Get-RokitToolProbeArgs 'luau') -join ' ' -eq '--help') 'luau has no --version: it is probed with --help'
Assert ((Get-RokitToolProbeArgs 'rojo') -join ' ' -eq '--version') 'every other tool is probed with --version'
$trust = Get-RokitTrustCommand $parsed
Assert ($trust -eq 'rokit trust rojo-rbx/rojo JohnnyMorganz/luau-lsp luau-lang/luau; rokit install') 'the trust command lists owner/repo without versions'

# --- Smart App Control ---
Assert ((Get-SmartAppControlState 0) -eq 'off') 'registry 0 is off'
Assert ((Get-SmartAppControlState 1) -eq 'on') 'registry 1 is on'
Assert ((Get-SmartAppControlState 2) -eq 'evaluation') 'registry 2 is evaluation'
Assert ((Get-SmartAppControlState $null) -eq '') 'no value (not Windows or older build) is unknown'

# --- the row ---
$ok = Get-RokitToolchainRow -Repo 'drain-for-loot' -Total 7 -Failures @() -SacState 'on' -TrustCommand $trust
Assert ($ok.state -eq 'PASA' -and $ok.detail -like '*7*drain-for-loot*') 'every tool runs: PASA with the count and the clone'

$blocked = @([pscustomobject]@{ name = 'luau'; out = 'error: Una directiva de Control de aplicaciones bloqueó este archivo. (os error 4551)' })
$row = Get-RokitToolchainRow -Repo 'drain-for-loot' -Total 7 -Failures $blocked -SacState 'on' -TrustCommand $trust
Assert ($row.state -eq 'PERSONA') 'blocked by Application Control with Smart App Control on: PERSONA'
Assert ($row.detail -like '*luau*' -and $row.detail -like '*Smart App Control*' -and $row.detail -like '*CI*') 'the PERSONA row names the tool, the cause and that the step stays in CI'
$english = @([pscustomobject]@{ name = 'luau'; out = 'Program failed to run: An Application Control policy has blocked this file' })
Assert ((Get-RokitToolchainRow -Repo 'r' -Total 7 -Failures $english -SacState 'evaluation' -TrustCommand $trust).state -eq 'PERSONA') 'the English message and the evaluation mode also give PERSONA'
Assert ((Get-RokitToolchainRow -Repo 'r' -Total 7 -Failures $blocked -SacState 'off' -TrustCommand $trust).state -eq 'FALLA') 'the same error with Smart App Control off is a FALLA: something else blocks it'

$missing = @([pscustomobject]@{ name = 'zap'; out = 'Tool zap is not installed. Run rokit install' })
$row = Get-RokitToolchainRow -Repo 'drain-for-loot' -Total 7 -Failures $missing -SacState 'off' -TrustCommand $trust
Assert ($row.state -eq 'FALLA' -and $row.detail -like '*zap*' -and $row.detail -like "*$trust*") 'a tool that is not installed: FALLA with the trust and install command'

if ($failed) { "$failed failed"; exit 1 }
'all passed'
