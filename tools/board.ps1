#requires -Version 7
# PowerShell front door for tools/board: finds Git Bash and forwards the arguments unchanged.
# Usage: pwsh tools/board.ps1 <post|read|unread|wait|whoami> [args]
Set-StrictMode -Version Latest
$board = Join-Path $PSScriptRoot 'board'
$bash = $null
$cmd = Get-Command bash -ErrorAction SilentlyContinue
if ($cmd -and $cmd.Source -notmatch 'WindowsApps|System32') { $bash = $cmd.Source }
if (-not $bash) {
    foreach ($c in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")) {
        if (Test-Path $c) { $bash = $c; break }
    }
}
if (-not $bash) { Write-Error 'board: Git Bash not found. Install Git for Windows.'; exit 1 }
& $bash $board @args
exit $LASTEXITCODE
