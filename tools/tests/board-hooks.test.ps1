#requires -Version 7
# Tests of the user hooks (issue 67): tools/lib/touch-log.ps1, tools/lib/user-hooks.ps1, and board-hook.ps1 /
# aviso.ps1 end to end with hook JSON on stdin. No network: the board and the issue are simulated, and the state
# and settings live in a temporary folder. Run: pwsh tools/tests/board-hooks.test.ps1
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/agent-loop.ps1')
. (Join-Path $tools 'lib/touch-log.ps1')
. (Join-Path $tools 'lib/user-hooks.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
$eco = Get-Content (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json
$place = $eco.roblox.places[0]

# 1. Which tool calls are edits.
Assert (Test-StudioEdit 'mcp__Roblox_Studio__multi_edit' @{ file_path = 'game.ServerScriptService.Main' }) 'multi_edit is an edit'
Assert (-not (Test-StudioEdit 'mcp__Roblox_Studio__script_read' @{})) 'script_read is not'
Assert (Test-StudioEdit 'mcp__roblox-studio__execute_luau' ([pscustomobject]@{ datamodel_type = 'Edit' })) 'execute_luau in Edit is an edit, whatever the server is called'
Assert (-not (Test-StudioEdit 'mcp__Roblox_Studio__execute_luau' ([pscustomobject]@{ datamodel_type = 'Client' }))) 'execute_luau during a playtest is not'
Assert (Test-StudioEdit 'mcp__Roblox_Studio__some_new_tool' @{}) 'an unknown Studio tool counts as an edit'
Assert (-not (Test-StudioEdit 'mcp__blender__execute_blender_code' @{})) 'another server is not a Studio edit'

# 2. Nothing secret or personal leaves the computer.
$homeWin = 'C:\Users\Alguien\Desktop\mapa.rbxl'
$dirty = "subí $HOME/arte/casa.blend y $homeWin y /home/otra/x.fbx con gho_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456 ya29.a0AehfTOkXYZ-abc_123 eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.SflKxwRJSMeKKF2QT4 api_key=supersecreto $('Ab3' * 15) rama-larga-solo-en-minusculas-que-no-es-secreta"
$clean = ConvertTo-SafeText $dirty 1000
Assert (-not $clean.Contains($HOME) -and $clean -notmatch 'Alguien|/home/otra') 'personal paths become ~'
Assert ($clean -notmatch 'gho_|ya29|eyJhbGci|supersecreto|Ab3Ab3Ab3') "tokens and secrets are hidden ($clean)"
Assert ($clean -match 'rama-larga-solo-en-minusculas-que-no-es-secreta') 'a long readable name is not taken for a secret'
Assert ((ConvertTo-SafeText 'PR https://github.com/Nashei-Studios/drain-for-loot/pull/30') -eq 'PR https://github.com/Nashei-Studios/drain-for-loot/pull/30') 'a URL is kept'
Assert ((ConvertTo-SafeText 'Workspace.World.Scenery (reubiqué 3 rocas)') -eq 'Workspace.World.Scenery (reubiqué 3 rocas)') 'ordinary text is kept as is'
Assert ((ConvertTo-SafeText ('a' * 10 + ' ' + 'b' * 300) 20).Length -le 23) 'text is bounded'

# 3. Instance paths named by a Luau snippet.
$code = @'
local sg = game:GetService("StarterGui")
game.StarterGui.Crosshair:Destroy()
for _, m in ipairs(workspace.World.Scenery:GetChildren()) do end
game:GetService("Lighting").Atmosphere.Density = 0.3
'@
$paths = @(Get-LuauPaths $code)
Assert ($paths -contains 'StarterGui.Crosshair' -and $paths -contains 'Workspace.World.Scenery') "Luau paths are found ($($paths -join ', '))"
Assert (@($paths | Where-Object { $_ -like 'Lighting.Atmosphere*' }).Count -eq 1 -and $paths -notcontains 'StarterGui') 'GetService paths count, and a shorter path covered by a longer one is dropped'

# 4. The studio list maps a studio id to its place.
$listText = (@{ studios = @(@{ id = 'st-1'; name = "Drain the Sea! (placeId: $($place.place_id))"; placeId = $place.place_id; universeId = $place.universe_id }) } | ConvertTo-Json -Depth 4 -Compress)
$map = Get-StudioMapFromList ([pscustomobject]@{ content = @([pscustomobject]@{ type = 'text'; text = $listText }) })
Assert ($map['st-1'].placeId -eq "$($place.place_id)" -and $map['st-1'].name -eq 'Drain the Sea!') 'list_roblox_studios (content parts) gives the place of each studio'
Assert ((Get-StudioMapFromList $listText)['st-1'].universeId -eq "$($place.universe_id)") 'a plain text result works too'
Assert ((Get-StudioMapFromList 'no json here').Count -eq 0) 'an unknown result shape gives an empty map'

# 5. Tool calls -> log entries.
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'mcp__Roblox_Studio__multi_edit'; tool_input = [pscustomobject]@{ studio_id = 'st-1'; file_path = 'game.ServerScriptService.Main' } }) $map
Assert ($t.kind -eq 'studio' -and $t.place -eq "$($place.place_id)" -and $t.detail -eq 'ServerScriptService.Main') 'a script edit is logged with its place and path'
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'Bash'; tool_input = [pscustomobject]@{ command = 'git push -u origin feat/67-hooks' } })
Assert ($t.kind -eq 'push' -and $t.detail -eq 'git push origin feat/67-hooks') 'git push is logged with its branch'
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'PowerShell'; tool_input = [pscustomobject]@{ command = "pwsh $HOME/Nashei/repos/studio/tools/kits.ps1 push -Path $HOME/Nashei/biblioteca/50-arte -Folder 50-arte" } })
Assert ($t.kind -eq 'drive' -and $t.detail -eq 'Drive 50-arte') 'kits push is logged as a Drive upload, without the local path'
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'Bash'; tool_input = [pscustomobject]@{ command = 'rclone copy ./x nashei:35-beta-testing/drain/v1' } })
Assert ($t.kind -eq 'drive' -and $t.detail -like '*35-beta-testing/drain/v1*') 'rclone to the studio remote is logged'
Assert ($null -eq (Get-ToolTouch ([pscustomobject]@{ tool_name = 'Bash'; tool_input = [pscustomobject]@{ command = 'git status; ls -la' } }))) 'an ordinary command is not logged'
Assert ($null -eq (Get-ToolTouch ([pscustomobject]@{ tool_name = 'Bash'; tool_input = [pscustomobject]@{ command = 'rclone lsf nashei: --dirs-only' } }))) 'reading the Drive is not logged'
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'mcp__claude_ai_Google_Drive__create_file'; tool_input = [pscustomobject]@{ title = 'acta.md' } })
Assert ($t.kind -eq 'drive') 'a Drive MCP write is logged'
$list = Format-TouchList @(
    [pscustomobject]@{ kind = 'studio'; tool = 'multi_edit'; place = '1'; placeName = 'P'; detail = 'A.B' },
    [pscustomobject]@{ kind = 'studio'; tool = 'multi_edit'; place = '1'; placeName = 'P'; detail = 'A.B' },
    [pscustomobject]@{ kind = 'push'; tool = 'git push'; place = ''; placeName = ''; detail = 'git push origin x' })
Assert ($list -eq 'place P (1): A.B [multi_edit] | git push origin x') "the touched list groups by place and drops repeats ($list)"

# 6. The lock.
Assert ((Get-LockDecision 'estricto' $null $true) -eq 'deny') 'estricto without an issue denies an edit to a group place'
Assert ((Get-LockDecision 'preguntar' $null $true) -eq 'ask') 'preguntar asks the person'
Assert ((Get-LockDecision 'estricto' @{ number = 1 } $true) -eq 'allow') 'an active issue opens the lock'
Assert ((Get-LockDecision 'estricto' $null $false) -eq 'allow') 'a place outside the group is not locked'
Assert (Test-GroupPlace $null (Get-GroupPlaces $eco)) 'a studio that was never listed counts as a group place'
Assert (-not (Test-GroupPlace @{ placeId = '1'; universeId = '2' } (Get-GroupPlaces $eco))) 'another place is not'
Assert ((Get-AgentLabel $eco 'leonaranguiz2012-a11y') -eq "[Leon's Claude]") 'the board label uses the name from the ecosystem config'
Assert ('estricto' -in $script:Modes) 'estricto is a valid modo of puesto.json'

# 7. settings.json: only our entries change, and twice is the same as once.
$hook = Join-Path $tools 'board-hooks/board-hook.ps1'
$existing = [ordered]@{ model = 'opus'; hooks = [ordered]@{
        PreToolUse = @([ordered]@{ matcher = 'Bash'; hooks = @([ordered]@{ type = 'command'; command = 'echo mine' }) })
        Stop = @([ordered]@{ hooks = @([ordered]@{ type = 'command'; command = 'pwsh'; args = @('-File', 'D:/old/tools/board-hooks/board-hook.ps1', 'cierre') }) }) } }
$merged = Merge-UserHooks $existing (Get-NasheiHookSpec $hook)
Assert ($merged.model -eq 'opus' -and @($merged.hooks.PreToolUse | ForEach-Object { $_.hooks } | Where-Object { $_.command -eq 'echo mine' }).Count -eq 1) 'other settings and hooks are kept'
Assert (@($merged.hooks.Stop | ForEach-Object { $_.hooks } | Where-Object { ($_.args -join ' ') -like '*D:/old*' }).Count -eq 0) 'an old studio hook at another path is replaced'
Assert (-not (Test-UserHooks $merged $hook).Count) 'all five events are registered'
$again = Merge-UserHooks ($merged | ConvertTo-Json -Depth 32 | ConvertFrom-Json -AsHashtable) (Get-NasheiHookSpec $hook)
Assert (($again | ConvertTo-Json -Depth 32) -eq ($merged | ConvertTo-Json -Depth 32)) 'merging twice changes nothing'
Assert ((Test-UserHooks $existing $hook) -contains 'SessionStart') 'a missing event is reported'

$work = Join-Path ([IO.Path]::GetTempPath()) "nashei-hooks-$PID"
$saved = @{ NASHEI_BASE = $env:NASHEI_BASE; CLAUDE_CONFIG_DIR = $env:CLAUDE_CONFIG_DIR; BOARD_LOGIN = $env:BOARD_LOGIN; CLAUDE_PROJECT_DIR = $env:CLAUDE_PROJECT_DIR
    NASHEI_TABLERO_SIMULADO = $env:NASHEI_TABLERO_SIMULADO; NASHEI_ISSUE_SIMULADO = $env:NASHEI_ISSUE_SIMULADO }
$savedConsoleEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); $OutputEncoding = [Text.UTF8Encoding]::new($false)
try {
    New-Item -ItemType Directory -Force $work | Out-Null
    $env:CLAUDE_CONFIG_DIR = Join-Path $work 'claude'
    $settingsPath = Get-ClaudeSettingsPath
    Assert ((Install-UserHooks -HookScript $hook -Path $settingsPath) -eq '' -and -not (Test-UserHooks (Read-ClaudeSettings $settingsPath) $hook).Count) 'install writes the hooks into CLAUDE_CONFIG_DIR/settings.json'
    Set-Content $settingsPath '{ not json' -Encoding utf8
    Assert ((Install-UserHooks -HookScript $hook -Path $settingsPath) -like '*no es JSON*' -and (Get-Content $settingsPath -Raw).Trim() -eq '{ not json') 'a broken settings.json is reported and left untouched'

    # 8. End to end: the hooks read JSON on stdin and keep their state in NASHEI_BASE/estado.
    $env:NASHEI_BASE = Join-Path $work 'base'; New-Item -ItemType Directory -Force $env:NASHEI_BASE | Out-Null
    $env:CLAUDE_PROJECT_DIR = $work
    '{"areas":["area:arte"],"modo":"estricto","wip":1}' | Set-Content (Join-Path $env:NASHEI_BASE 'puesto.json')
    $state = Join-Path $env:NASHEI_BASE 'estado'
    function Invoke-Hook { param([string]$Mode, $InputObject)
        ($InputObject | ConvertTo-Json -Depth 8 -Compress) | & pwsh -NoProfile -File $hook $Mode -Usuario | Out-String }
    $edit = @{ hook_event_name = 'PreToolUse'; tool_name = 'mcp__Roblox_Studio__multi_edit'; tool_input = @{ studio_id = 'st-1'; file_path = 'game.Workspace.World'; edits = @() } }

    $out = Invoke-Hook 'candado' $edit
    Assert ($out -match '"permissionDecision":"deny"' -and $out -match 'list_roblox_studios') 'estricto denies an edit to a studio that was never listed'
    Invoke-Hook 'registro' @{ hook_event_name = 'PostToolUse'; tool_name = 'mcp__Roblox_Studio__list_roblox_studios'; tool_input = @{}; tool_response = @(@{ type = 'text'; text = $listText }) } | Out-Null
    Assert ((Get-StudioMap $state)['st-1'].placeId -eq "$($place.place_id)") 'registro learns the place of each studio from list_roblox_studios'
    $out = Invoke-Hook 'candado' $edit
    Assert ($out -match '"permissionDecision":"deny"' -and $out -match [regex]::Escape("$($place.place_id)")) 'estricto denies an edit to the group place without an issue'
    Assert ((Invoke-Hook 'candado' @{ tool_name = 'mcp__Roblox_Studio__script_read'; tool_input = @{ studio_id = 'st-1' } }).Trim() -eq '') 'a read is never locked'
    '{"areas":["area:arte"],"modo":"preguntar"}' | Set-Content (Join-Path $env:NASHEI_BASE 'puesto.json')
    Assert ((Invoke-Hook 'candado' $edit) -match '"permissionDecision":"ask"') 'preguntar asks the person instead'
    '{"areas":["area:arte"],"modo":"estricto"}' | Set-Content (Join-Path $env:NASHEI_BASE 'puesto.json')

    Assert ((Invoke-Hook 'cierre' @{ hook_event_name = 'Stop'; stop_hook_active = $false }).Trim() -eq '') 'with nothing touched the turn ends freely'
    Invoke-Hook 'registro' @{ hook_event_name = 'PostToolUse'; tool_name = 'mcp__Roblox_Studio__execute_luau'; tool_input = @{ studio_id = 'st-1'; datamodel_type = 'Edit'; code = $code } } | Out-Null
    Assert (@(Get-TouchEntries $state).Count -eq 1) 'registro logs an Edit-mode execute_luau'
    $stop = Invoke-Hook 'cierre' @{ hook_event_name = 'Stop'; stop_hook_active = $false } | ConvertFrom-Json
    Assert ($stop.decision -eq 'block' -and $stop.reason -match 'Workspace\.World\.Scenery' -and $stop.reason -match 'aviso\.ps1') 'cierre blocks the end of the turn and gives the notice command with the list'
    $stop = Invoke-Hook 'cierre' @{ hook_event_name = 'Stop'; stop_hook_active = $true } | ConvertFrom-Json
    Assert (-not $stop.decision -and $stop.systemMessage -match 'sin avisar') 'the second time it lets the turn end and warns the person'

    # 9. aviso.ps1 against a simulated board and issue.
    $board = Join-Path $work 'tablero.txt'; $env:NASHEI_TABLERO_SIMULADO = $board; $env:BOARD_LOGIN = 'leonaranguiz2012-a11y'
    $aviso = Join-Path $tools 'board-hooks/aviso.ps1'
    $env:NASHEI_ISSUE_SIMULADO = '{"state":"OPEN","title":"bahía","assignees":[{"login":"otra"}]}'
    & pwsh -NoProfile -File $aviso empiezo -Issue 12 -Repo Nashei-Studios/drain-for-loot -Que 'bahía' 2>$null | Out-Null
    Assert ($LASTEXITCODE -eq 2 -and -not (Test-Path $board)) 'empiezo refuses an issue taken by someone else'
    $env:NASHEI_ISSUE_SIMULADO = '{"state":"OPEN","title":"bahía","assignees":[{"login":"leonaranguiz2012-a11y"}]}'
    & pwsh -NoProfile -File $aviso empiezo -Issue 12 -Repo Nashei-Studios/drain-for-loot -Que 'bahía con arrecife' | Out-Null
    $posted = Get-Content $board -Raw
    Assert ($posted -match "^\[Leon's Claude\] empiezo Nashei-Studios/drain-for-loot#12: bahía con arrecife\. Toca: place Drain the Sea! \($($place.place_id)\): .*Workspace\.World\.Scenery") "empiezo posts with the label, the issue and what was touched ($($posted.Trim()))"
    Assert ((Get-ActiveIssue $state).number -eq 12 -and -not @(Get-TouchEntries $state).Count) 'empiezo opens the lock and clears the announced list'
    Assert ((Invoke-Hook 'candado' $edit).Trim() -eq '') 'with an issue started the edit goes through'

    Invoke-Hook 'registro' @{ tool_name = 'Bash'; tool_input = @{ command = "git -C $HOME/Nashei/repos/drain-for-loot push origin feat/12-bahia" } } | Out-Null
    & pwsh -NoProfile -File $aviso cierro -Que "listo; ver $HOME/notas.txt gho_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456" -Pr 'https://github.com/Nashei-Studios/drain-for-loot/pull/30' | Out-Null
    $last = @(Get-Content $board)[-1]
    Assert ($last -match '^\[Leon''s Claude\] cierro Nashei-Studios/drain-for-loot#12: .*Toca: git push origin feat/12-bahia\. PR https://') "cierro posts the push and the PR ($last)"
    Assert (-not $last.Contains($HOME) -and $last -notmatch 'gho_') 'the posted notice has no personal path and no token'
    Assert ($null -eq (Get-ActiveIssue $state)) 'cierro closes the lock again'
    Assert ((Invoke-Hook 'candado' $edit) -match '"permissionDecision":"deny"') 'after cierro an edit needs a new issue'
} finally {
    foreach ($k in $saved.Keys) { Set-Item "env:$k" $saved[$k] -ErrorAction SilentlyContinue; if ($null -eq $saved[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } }
    [Console]::OutputEncoding = $savedConsoleEncoding
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failed) { "$failed expectation(s) failed"; exit 1 }
'board-hooks tests passed'
