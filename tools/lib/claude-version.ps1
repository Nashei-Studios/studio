#requires -Version 7
# The Claude Code version row of puesto check (issue 108, finding 2). The studio's hooks use fields an older
# Claude Code ignores without a word: onFailure "block" (the start lock fails closed when its script fails or
# times out, from 2.1.295) and if (the shell branch guard only starts for git commands). The minimum comes from
# agente.claude_code_minimo of config/ecosistema.json. Tested by tools/tests/claude-version.test.ps1.

function Get-ClaudeCodeVersion { param([string]$VersionOutput)
    <# The version `claude --version` prints ("2.1.325 (Claude Code)"); $null when there is none. #>
    if ("$VersionOutput" -match '(\d+)\.(\d+)\.(\d+)') { return [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])" }
    $null }

function Get-ClaudeVersionRow { param([string]$VersionOutput, [string]$Minimum, [string]$Modo)
    <# PASA at or above the minimum; PERSONA below it (the person runs the update) or when unreadable. #>
    $have = Get-ClaudeCodeVersion $VersionOutput
    $need = [version]$Minimum
    if (-not $have) {
        return @{ state = 'PERSONA'; detail = "no pude leer la versión: corre claude --version (mínimo $Minimum)" }
    }
    if ($have -ge $need) { return @{ state = 'PASA'; detail = "$have (mínimo $Minimum)" } }
    # An older Claude Code ignores both fields: what that costs depends on the modo.
    $risk = ($Modo -in 'estricto', 'autonomo') ?
        "ignora onFailure: con modo $Modo el candado falla abierto si su script se cae o se demora" :
        'ignora if: la guardia de rama puede arrancar en cada comando de la shell y no solo con git'
    @{ state = 'PERSONA'; detail = "tienes $have y los hooks del estudio piden $Minimum ($risk). Actualiza con: claude update" } }
