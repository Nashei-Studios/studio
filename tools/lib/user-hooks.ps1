#requires -Version 7
# The studio's Claude Code hooks at user level (issue 67): puesto.ps1 install writes them into the person's
# settings.json pointing at tools/board-hooks/board-hook.ps1 of the studio clone, so they run in any folder.
# Only entries that call board-hook.ps1 are ever replaced; the rest of the file is left as it was.
# Tested by tools/tests/board-hooks.test.ps1 against a CLAUDE_CONFIG_DIR in a temporary folder.

$script:HookMarker = 'board-hooks/board-hook.ps1'

function Get-ClaudeSettingsPath {
    $dir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    Join-Path $dir 'settings.json' }

function Get-NasheiHookSpec { param([string]$HookScript, [string]$Modo = 'preguntar')
    <# Event -> one matcher group. Exec form (command + args): no shell, so the same entry works in cmd,
       PowerShell, Git Bash, zsh and bash, and a path with spaces needs no quoting. #>
    $script = ($HookScript -replace '\\', '/')
    $studioTools = 'mcp__[Rr]oblox[_-]?[Ss]tudio__.*'
    # onFailure (Claude Code 2.1.295+): in a blocking modo the lock fails closed; with preguntar a broken pwsh
    # must not stop the person's own Studio work.
    $lockExtra = ($Modo -in 'estricto', 'autonomo') ? @{ onFailure = 'block' } : @{}
    $entry = { param([string]$Mode, [int]$Timeout, [hashtable]$Extra = @{})
        $h = [ordered]@{ type = 'command'; command = 'pwsh'; args = @('-NoProfile', '-File', $script, $Mode, '-Usuario'); timeout = $Timeout }
        foreach ($k in $Extra.Keys) { $h[$k] = $Extra[$k] }
        $h }
    [ordered]@{
        SessionStart     = [ordered]@{ matcher = 'startup|resume|clear'; hooks = @(& $entry 'session-start' 20) }
        UserPromptSubmit = [ordered]@{ hooks = @(& $entry 'prompt' 10) }
        PreToolUse       = @(
            [ordered]@{ matcher = $studioTools; hooks = @(& $entry 'candado' 10 $lockExtra) },
            [ordered]@{ matcher = 'Edit|Write|MultiEdit|NotebookEdit'; hooks = @(& $entry 'rama' 10) })
        PostToolUse      = [ordered]@{ matcher = "$studioTools|mcp__.*[Gg]oogle.?[Dd]rive.*|^Bash$|^PowerShell$"; hooks = @(& $entry 'registro' 10) }
        Stop             = [ordered]@{ hooks = @(& $entry 'cierre' 15) }
    } }

function Test-IsNasheiHook { param($Hook)
    $text = (@($Hook.command) + @($Hook.args) | ForEach-Object { "$_" }) -join ' '
    ($text -replace '\\', '/') -match [regex]::Escape($script:HookMarker) }

function Merge-UserHooks { param($Settings, $Spec)
    <# Returns the settings with every board-hook.ps1 entry replaced by $Spec (removed when $Spec is empty).
       Other hooks keep their order. #>
    $out = [ordered]@{}
    if ($Settings) { foreach ($k in $Settings.Keys) { $out[$k] = $Settings[$k] } }
    $hooks = [ordered]@{}
    if ($out.Contains('hooks') -and $out.hooks) { foreach ($k in $out.hooks.Keys) { $hooks[$k] = $out.hooks[$k] } }
    foreach ($event in @($hooks.Keys)) {
        $groups = @()
        foreach ($g in @($hooks[$event])) {
            $kept = @(@($g.hooks) | Where-Object { $_ -and -not (Test-IsNasheiHook $_) })
            if (-not $kept.Count) { continue }
            $copy = [ordered]@{}
            foreach ($k in $g.Keys) { $copy[$k] = $g[$k] }
            $copy.hooks = $kept
            $groups += $copy
        }
        if ($groups.Count) { $hooks[$event] = $groups } else { $hooks.Remove($event) }
    }
    foreach ($event in $Spec.Keys) {
        $list = @($hooks[$event] | Where-Object { $_ })
        foreach ($group in @($Spec[$event])) { $list += , $group }   # the comma keeps each group as one element
        $hooks[$event] = $list
    }
    if ($hooks.Count) { $out.hooks = $hooks } else { $out.Remove('hooks') }
    $out }

function Remove-UserHooks { param($Settings) Merge-UserHooks $Settings ([ordered]@{}) }

function Test-UserHooks { param($Settings, [string]$HookScript, [string]$Modo = 'preguntar')
    <# Events whose board-hook.ps1 entry is missing, points somewhere else or does not match the modo (the lock
       must fail closed in a blocking modo). Empty = all present. #>
    $want = ($HookScript -replace '\\', '/')
    $spec = Get-NasheiHookSpec $HookScript $Modo
    $missing = @()
    foreach ($event in $spec.Keys) { foreach ($want1 in @($spec[$event])) {
        $mode = $want1.hooks[0].args[3]
        $found = @($Settings.hooks.$event | ForEach-Object { @($_.hooks) } | Where-Object {
                $args2 = @($_.args | ForEach-Object { "$_" -replace '\\', '/' })
                (Test-IsNasheiHook $_) -and ($args2 -contains $mode) -and
                ($IsWindows ? ($args2 -icontains $want) : ($args2 -ccontains $want)) -and
                ("$($_.onFailure)" -eq "$($want1.hooks[0].onFailure)") })
        if (-not $found.Count) { $missing += $event; break }
    } }
    if (-not (Test-Path -LiteralPath $HookScript)) { $missing += 'script' }
    $missing }

function Read-ClaudeSettings { param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{} }
    $raw = Get-Content -LiteralPath $Path -Raw
    if (-not $raw.Trim()) { return [ordered]@{} }
    $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop }

function Save-ClaudeSettings { param([string]$Path, $Settings)
    New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
    # The first backup is the file as it was before the studio ever touched it: later runs keep it.
    if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath "$Path.bak-nashei")) { Copy-Item -LiteralPath $Path -Destination "$Path.bak-nashei" }
    $tmp = "$Path.tmp-$PID"
    $Settings | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $tmp -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $Path -Force }

function Install-UserHooks { param([string]$HookScript, [string]$Path = (Get-ClaudeSettingsPath), [string]$Modo = 'preguntar')
    <# Writes the hooks. Returns '' on success or the reason it did not touch the file. #>
    try { $settings = Read-ClaudeSettings $Path }
    catch { return "$Path no es JSON válido: no se tocó; corrígelo y vuelve a correr install" }
    Save-ClaudeSettings $Path (Merge-UserHooks $settings (Get-NasheiHookSpec $HookScript $Modo))
    '' }

function Uninstall-UserHooks { param([string]$Path = (Get-ClaudeSettingsPath))
    <# Removes only the studio's entries. Returns '' on success or the reason it did not touch the file. #>
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    try { $settings = Read-ClaudeSettings $Path }
    catch { return "$Path no es JSON válido: no se tocó" }
    Save-ClaudeSettings $Path (Remove-UserHooks $settings)
    '' }
