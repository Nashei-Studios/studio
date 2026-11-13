#requires -Version 7
# The studio's Claude Code hooks at user level (issue 67): puesto.ps1 install writes them into the person's
# settings.json pointing at tools/board-hooks/board-hook.ps1 of the studio clone, so they run in any folder.
# Only entries that call board-hook.ps1 are ever replaced; the rest of the file is left as it was.
# Tested by tools/tests/board-hooks.test.ps1 against a CLAUDE_CONFIG_DIR in a temporary folder.

$script:HookMarker = 'board-hooks/board-hook.ps1'

function Get-ClaudeSettingsPath {
    $dir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    Join-Path $dir 'settings.json' }

function Get-NasheiHookSpec { param([string]$HookScript)
    <# Event -> one matcher group. Exec form (command + args): no shell, so the same entry works in cmd,
       PowerShell, Git Bash, zsh and bash, and a path with spaces needs no quoting. #>
    $script = ($HookScript -replace '\\', '/')
    $entry = { param([string]$Mode, [int]$Timeout, [hashtable]$Extra = @{})
        $h = [ordered]@{ type = 'command'; command = 'pwsh'; args = @('-NoProfile', '-File', $script, $Mode, '-Usuario'); timeout = $Timeout }
        foreach ($k in $Extra.Keys) { $h[$k] = $Extra[$k] }
        $h }
    [ordered]@{
        SessionStart     = [ordered]@{ matcher = 'startup|resume|clear'; hooks = @(& $entry 'session-start' 20) }
        UserPromptSubmit = [ordered]@{ hooks = @(& $entry 'prompt' 10) }
        # The lock must not fail open: if pwsh cannot even start, the Studio edit is blocked.
        PreToolUse       = [ordered]@{ matcher = 'mcp__.*[Rr]oblox.*'; hooks = @(& $entry 'candado' 10 @{ onFailure = 'block' }) }
        PostToolUse      = [ordered]@{ matcher = 'mcp__.*[Rr]oblox.*|mcp__.*[Gg]oogle.?[Dd]rive.*|^Bash$|^PowerShell$'; hooks = @(& $entry 'registro' 10) }
        Stop             = [ordered]@{ hooks = @(& $entry 'cierre' 15) }
    } }

function Test-IsNasheiHook { param($Hook)
    $text = (@($Hook.command) + @($Hook.args) | ForEach-Object { "$_" }) -join ' '
    ($text -replace '\\', '/') -match [regex]::Escape($script:HookMarker) }

function Merge-UserHooks { param($Settings, $Spec)
    <# Returns the settings with every board-hook.ps1 entry replaced by $Spec. Other hooks keep their order. #>
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
        $list += , $Spec[$event]   # the comma keeps the group as one element
        $hooks[$event] = $list
    }
    $out.hooks = $hooks
    $out }

function Test-UserHooks { param($Settings, [string]$HookScript)
    <# Events whose board-hook.ps1 entry is missing or points somewhere else. Empty = all present. #>
    $want = ($HookScript -replace '\\', '/')
    $spec = Get-NasheiHookSpec $HookScript
    $missing = @()
    foreach ($event in $spec.Keys) {
        $mode = $spec[$event].hooks[0].args[3]
        $found = @($Settings.hooks.$event | ForEach-Object { @($_.hooks) } | Where-Object {
                $args2 = @($_.args | ForEach-Object { "$_" -replace '\\', '/' })
                (Test-IsNasheiHook $_) -and ($args2 -contains $mode) -and
                ($IsWindows ? ($args2 -icontains $want) : ($args2 -ccontains $want)) })
        if (-not $found.Count) { $missing += $event }
    }
    if (-not (Test-Path -LiteralPath $HookScript)) { $missing += 'script' }
    $missing }

function Read-ClaudeSettings { param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{} }
    $raw = Get-Content -LiteralPath $Path -Raw
    if (-not $raw.Trim()) { return [ordered]@{} }
    $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop }

function Install-UserHooks { param([string]$HookScript, [string]$Path = (Get-ClaudeSettingsPath))
    <# Writes the hooks. Returns '' on success or the reason it did not touch the file. #>
    try { $settings = Read-ClaudeSettings $Path }
    catch { return "$Path no es JSON válido: no se tocó; corrígelo y vuelve a correr install" }
    $merged = Merge-UserHooks $settings (Get-NasheiHookSpec $HookScript)
    New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
    if (Test-Path -LiteralPath $Path) { Copy-Item -LiteralPath $Path -Destination "$Path.bak-nashei" -Force }
    $tmp = "$Path.tmp-$PID"
    $merged | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $tmp -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
    '' }
