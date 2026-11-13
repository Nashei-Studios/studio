#requires -Version 7
# Unit tests of tools/lib/escritorio.ps1 and of the mcp-escritorio row. No network. Run: pwsh tools/tests/escritorio.test.ps1
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/escritorio.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
$eco = Get-Content -LiteralPath (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json

$list = "notion-studio: https://mcp.notion.com/mcp (HTTP) - Connected`nescritorio: uvx windows-mcp serve - Connected"
Assert ((Get-EscritorioState $list 'escritorio') -eq 'conectado') 'registered and connected is conectado (PASA)'
Assert ((Get-EscritorioState 'notion-studio: x - Connected' 'escritorio') -eq 'ausente') 'not registered is ausente (PERSONA)'
Assert ((Get-EscritorioState 'escritorio: uvx x - Failed to connect' 'escritorio') -eq 'registrado-sin-conexion') 'registered but failing is registrado-sin-conexion (PERSONA)'
Assert ((Get-EscritorioState 'escritorio-otro: x - Connected' 'escritorio') -eq 'ausente') 'a server with a longer name does not count'
Assert ($null -eq (Get-EscritorioSpec $eco 'linux')) 'Linux has no desktop MCP (NO APLICA)'

$win = Get-EscritorioAddArgs $eco 'windows' 'C:\bin\uvx.exe'
Assert (($win -join ' ') -like 'mcp add escritorio -s user -- C:\bin\uvx.exe windows-mcp serve --exclude-tools *') 'Windows registers uvx windows-mcp serve at user scope'
Assert (($win -join ' ') -match 'PowerShell,FileSystem,Registry,Scrape') 'Windows excludes the four dangerous tools'
$mac = Get-EscritorioAddArgs $eco 'macos'
Assert (($mac -join ' ') -eq 'mcp add escritorio -s user -- npx -y @steipete/peekaboo mcp') 'macOS registers peekaboo mcp over npx'
Assert ((Get-EscritorioAddArgs $eco 'linux').Count -eq 0) 'Linux has no registration command'

# The real row, with a fake claude first on PATH: absent gives PERSONA with the exact command, registered gives PASA.
$os = $IsWindows ? 'windows' : ($IsMacOS ? 'macos' : 'linux')
$fake = Join-Path ([IO.Path]::GetTempPath()) "nashei-fake-claude-$PID"
New-Item -ItemType Directory -Force $fake | Out-Null
$base = Join-Path $fake 'base'; New-Item -ItemType Directory -Force $base | Out-Null
$savedPath = $env:PATH
try {
    foreach ($case in @(@{ out = 'notion-studio: x - Connected'; want = 'PERSONA' }, @{ out = 'escritorio: x - Connected'; want = 'PASA' })) {
        if ($IsWindows) { Set-Content (Join-Path $fake 'claude.cmd') "@echo off`r`necho $($case.out)" }
        else { Set-Content (Join-Path $fake 'claude') "#!/bin/sh`necho '$($case.out)'"; & chmod +x (Join-Path $fake 'claude') }
        $env:PATH = $fake + [IO.Path]::PathSeparator + $savedPath
        $row = (& pwsh -NoProfile -File (Join-Path $tools 'puesto.ps1') check -Json -Base $base | Out-String | ConvertFrom-Json).results | Where-Object id -eq 'mcp-escritorio'
        $expected = $os -eq 'linux' ? 'NO APLICA' : $case.want
        Assert ($row -and $row.state -eq $expected) "puesto check row mcp-escritorio is $expected for '$($case.want)' on $os"
        if ($os -ne 'linux' -and $case.want -eq 'PERSONA') { Assert ($row.detail -like '*claude mcp add escritorio -s user -- *') 'the PERSONA row carries the exact command' }
    }
} finally { $env:PATH = $savedPath; Remove-Item $fake -Recurse -Force -ErrorAction SilentlyContinue }
if ($failed) { "$failed expectation(s) failed"; exit 1 }
'escritorio tests passed'
