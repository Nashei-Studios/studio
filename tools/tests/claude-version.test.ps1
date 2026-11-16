#requires -Version 7
# Unit tests of tools/lib/claude-version.ps1 (issue 108, finding 2): the Claude Code version row of puesto check.
# No network. Run: pwsh tools/tests/claude-version.test.ps1
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/claude-version.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
$eco = Get-Content (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json

Assert ("$((Get-ClaudeCodeVersion '2.1.325 (Claude Code)'))" -eq '2.1.325') 'reads the version claude --version prints'
Assert ($null -eq (Get-ClaudeCodeVersion 'command not found')) 'no version in the output is unknown'
Assert ("$($eco.agente.claude_code_minimo)" -match '^\d+\.\d+\.\d+$') 'the minimum comes from config/ecosistema.json'

$ok = Get-ClaudeVersionRow '2.1.325 (Claude Code)' '2.1.295' 'estricto'
Assert ($ok.state -eq 'PASA' -and $ok.detail -like '*2.1.325*') 'a newer version passes and is shown'
Assert ((Get-ClaudeVersionRow '2.1.295 (Claude Code)' '2.1.295' 'estricto').state -eq 'PASA') 'the minimum itself passes'
$old = Get-ClaudeVersionRow '2.1.210 (Claude Code)' '2.1.295' 'estricto'
Assert ($old.state -eq 'PERSONA' -and $old.detail -like '*claude update*' -and $old.detail -like '*falla abierto*') 'an older version in a blocking modo asks for an update and says the lock fails open'
$oldAsk = Get-ClaudeVersionRow '2.1.210 (Claude Code)' '2.1.295' 'preguntar'
Assert ($oldAsk.state -eq 'PERSONA' -and $oldAsk.detail -like '*claude update*') 'an older version with preguntar still asks for an update (the shell guard needs the if field)'
Assert ((Get-ClaudeVersionRow '2.10.0 (Claude Code)' '2.9.300' 'estricto').state -eq 'PASA') 'versions compare as numbers, not text'
$unknown = Get-ClaudeVersionRow 'error' '2.1.295' 'estricto'
Assert ($unknown.state -eq 'PERSONA' -and $unknown.detail -like '*claude --version*') 'an unreadable version asks the person to look'

if ($failed) { "$failed failed"; exit 1 }
'all passed'
