#requires -Version 7
# Tests of the user hooks (issue 67): tools/lib/touch-log.ps1, tools/lib/user-hooks.ps1, and board-hook.ps1 /
# aviso.ps1 end to end with hook JSON on stdin. No network: the board and the issue are simulated, and the state
# and settings live in a temporary folder. Run: pwsh tools/tests/board-hooks.test.ps1
# The aviso.ps1 cases need CI set (its test seams only open with NASHEI_TEST=1 in CI); locally: $env:CI = '1' first.
$ErrorActionPreference = 'Stop'
$tools = Split-Path $PSScriptRoot -Parent
. (Join-Path $tools 'lib/agent-loop.ps1')
. (Join-Path $tools 'lib/touch-log.ps1')
. (Join-Path $tools 'lib/user-hooks.ps1')
$failed = 0
function Assert { param([bool]$Condition, [string]$What) if ($Condition) { "ok    $What" } else { "FAIL  $What"; $script:failed++ } }
$eco = Get-Content (Join-Path $tools '../config/ecosistema.json') -Raw | ConvertFrom-Json
$place = $eco.roblox.places[0]
$org = $eco.github.organizacion

# 1. Which tool calls are edits.
Assert (Test-StudioEdit 'mcp__Roblox_Studio__multi_edit' @{ file_path = 'game.ServerScriptService.Main' }) 'multi_edit is an edit'
Assert (-not (Test-StudioEdit 'mcp__Roblox_Studio__script_read' @{})) 'script_read is not'
Assert (Test-StudioEdit 'mcp__roblox-studio__execute_luau' ([pscustomobject]@{ datamodel_type = 'Edit' })) 'execute_luau in Edit is an edit, however the Studio server is spelled'
Assert (-not (Test-StudioEdit 'mcp__Roblox_Studio__execute_luau' ([pscustomobject]@{ datamodel_type = 'Client' }))) 'execute_luau during a playtest is not'
Assert (Test-StudioEdit 'mcp__Roblox_Studio__some_new_tool' @{}) 'an unknown Studio tool counts as an edit'
Assert (-not (Test-StudioEdit 'mcp__blender__execute_blender_code' @{})) 'another server is not a Studio edit'
Assert (-not (Test-StudioEdit 'mcp__roblox-vault__write_note' @{})) 'a server that only has "roblox" in its name is not Studio'

# 2. Nothing secret or personal leaves the computer.
$homeWin = 'C:\Users\Alguien\Desktop\mapa.rbxl'
$dirty = "subí $HOME/arte/casa.blend y $homeWin y /home/otra/x.fbx con gho_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456 ya29.a0AehfTOkXYZ-abc_123 eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.SflKxwRJSMeKKF2QT4 api_key=supersecreto $('Ab3' * 15) rama-larga-solo-en-minusculas-que-no-es-secreta"
$clean = ConvertTo-SafeText $dirty 1000
Assert (-not $clean.Contains($HOME) -and $clean -notmatch 'Alguien|/home/otra') 'personal paths become ~'
Assert ($clean -notmatch 'gho_|ya29|eyJhbGci|supersecreto|Ab3Ab3Ab3') "tokens and secrets are hidden ($clean)"
Assert ($clean -match 'rama-larga-solo-en-minusculas-que-no-es-secreta') 'a long readable name is not taken for a secret'
Assert ((ConvertTo-SafeText 'PR https://github.com/Nashei-Studios/drain-for-loot/pull/30') -eq 'PR https://github.com/Nashei-Studios/drain-for-loot/pull/30') 'a URL is kept'
Assert ((ConvertTo-SafeText 'git push https://yo:clave1@github.com/x/y.git y https://tok@host/z') -eq 'git push https://github.com/x/y.git y https://host/z') 'credentials inside a URL are dropped'
Assert ((ConvertTo-SafeText 'Workspace.World.Scenery (reubiqué 3 rocas)') -eq 'Workspace.World.Scenery (reubiqué 3 rocas)') 'ordinary text is kept as is'
Assert ((ConvertTo-SafeText ('a' * 10 + ' ' + 'b' * 300) 20).Length -le 23) 'text is bounded'
Assert ((ConvertTo-NoMention 'listo, @vruizz22 revisa; correo a@b.cl') -eq 'listo, `@vruizz22` revisa; correo a@b.cl') 'an @login is written as code so nobody is notified'

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
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'Bash'; cwd = '/w'; tool_input = [pscustomobject]@{ command = 'git push -u origin feat/67-hooks' } })
Assert ($t.kind -eq 'push' -and $t.detail -eq 'git push origin feat/67-hooks' -and $t.remote -eq 'origin' -and $t.dir -eq '/w') 'git push is logged with its branch, remote and folder'
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'Bash'; cwd = '/w'; tool_input = [pscustomobject]@{ command = 'cd "/r/mi repo" && git push' } })
Assert ($t.dir -eq '/r/mi repo' -and $t.remote -eq 'origin') 'cd before the push gives the folder; no remote means origin'
$t = Get-ToolTouch ([pscustomobject]@{ tool_name = 'PowerShell'; tool_input = [pscustomobject]@{ command = 'git -C D:/x push upstream main' } })
Assert ($t.dir -eq 'D:/x' -and $t.remote -eq 'upstream') 'git -C gives the folder'
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
Assert ((Get-LockDecision 'autonomo' $null $true) -eq 'deny') 'autonomo denies too'
Assert ((Get-LockDecision 'preguntar' $null $true) -eq 'ask') 'preguntar asks the person'
Assert ((Get-LockDecision 'otro' $null $true) -eq 'ask') 'an unknown modo asks'
Assert ((Get-LockDecision 'estricto' @{ number = 1 } $true) -eq 'allow') 'an active issue opens the lock'
Assert ((Get-LockDecision 'estricto' $null $false) -eq 'allow') 'a place outside the group is not locked'
Assert (Test-GroupPlace $null (Get-GroupPlaces $eco)) 'a studio that was never listed counts as a group place'
Assert (-not (Test-GroupPlace @{ placeId = '1'; universeId = '2' } (Get-GroupPlaces $eco))) 'another place is not'
Assert ((Get-AgentLabel $eco 'leonaranguiz2012-a11y') -eq "[Leon's Claude]") 'the board label uses the name from the ecosystem config'
Assert ('estricto' -in $script:Modes) 'estricto is a valid modo of puesto.json'

# 7. settings.json: only our entries change, twice is the same as once, and uninstall gives the original back.
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
$lockOf = { param($spec) $spec.PreToolUse.hooks[0] }
Assert ((& $lockOf (Get-NasheiHookSpec $hook 'estricto')).onFailure -eq 'block' -and (& $lockOf (Get-NasheiHookSpec $hook 'autonomo')).onFailure -eq 'block') 'in a blocking modo the lock fails closed'
Assert (-not (& $lockOf (Get-NasheiHookSpec $hook 'preguntar')).Contains('onFailure')) 'with preguntar a broken lock does not stop Studio work'
Assert ((Test-UserHooks $merged $hook 'estricto') -contains 'PreToolUse') 'check asks for install again when the modo became blocking'

$work = Join-Path ([IO.Path]::GetTempPath()) "nashei-hooks-$PID"
$saved = @{ NASHEI_BASE = $env:NASHEI_BASE; CLAUDE_CONFIG_DIR = $env:CLAUDE_CONFIG_DIR; BOARD_LOGIN = $env:BOARD_LOGIN; CLAUDE_PROJECT_DIR = $env:CLAUDE_PROJECT_DIR
    NASHEI_TABLERO_SIMULADO = $env:NASHEI_TABLERO_SIMULADO; NASHEI_ISSUE_SIMULADO = $env:NASHEI_ISSUE_SIMULADO; NASHEI_TEST = $env:NASHEI_TEST; PATH = $env:PATH }
$savedConsoleEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); $OutputEncoding = [Text.UTF8Encoding]::new($false)
try {
    New-Item -ItemType Directory -Force $work | Out-Null
    $env:CLAUDE_CONFIG_DIR = Join-Path $work 'claude'
    $settingsPath = Get-ClaudeSettingsPath
    New-Item -ItemType Directory -Force $env:CLAUDE_CONFIG_DIR | Out-Null
    $original = '{ "model": "opus", "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo mine" } ] } ] } }'
    Set-Content $settingsPath $original -Encoding utf8
    $normal = { param($p) (Get-Content $p -Raw | ConvertFrom-Json -AsHashtable | ConvertTo-Json -Depth 32 -Compress) }
    $before = & $normal $settingsPath
    Assert ((Install-UserHooks -HookScript $hook -Path $settingsPath) -eq '' -and -not (Test-UserHooks (Read-ClaudeSettings $settingsPath) $hook).Count) 'install writes the hooks into CLAUDE_CONFIG_DIR/settings.json'
    Install-UserHooks -HookScript $hook -Path $settingsPath -Modo estricto | Out-Null
    Assert ((& $normal "$settingsPath.bak-nashei") -eq $before) 'a second install keeps the first backup, the file as it was before the studio'
    Assert ((Uninstall-UserHooks -Path $settingsPath) -eq '' -and (& $normal $settingsPath) -eq $before) 'uninstall gives back exactly the original settings'
    Set-Content $settingsPath '{ not json' -Encoding utf8
    Assert ((Install-UserHooks -HookScript $hook -Path $settingsPath) -like '*no es JSON*' -and (Get-Content $settingsPath -Raw).Trim() -eq '{ not json') 'a broken settings.json is reported and left untouched'

    # 8. Pushes count only toward the organization.
    $orgRepo = Join-Path $work 'org-repo'; $ownRepo = Join-Path $work 'own-repo'
    foreach ($r in $orgRepo, $ownRepo) { & git init --quiet $r }
    & git -C $orgRepo remote add origin "https://github.com/$org/drain-for-loot.git"
    & git -C $ownRepo remote add origin 'git@github.com:alguien/personal.git'
    Assert (Test-OrgRemote $orgRepo 'origin' $org) 'a push to an organization repo counts'
    Assert (-not (Test-OrgRemote $ownRepo 'origin' $org)) 'a push to a personal repo does not'
    Assert (Test-OrgRemote '' "git@github.com:$org/studio.git" $org) 'a remote given as a URL is read as is'
    Assert (-not (Test-OrgRemote (Join-Path $work 'no-such') 'origin' $org)) 'an unknown folder does not count'

    # 9. End to end: the hooks read JSON on stdin and keep their state in NASHEI_BASE/estado.
    $env:NASHEI_BASE = Join-Path $work 'base'; New-Item -ItemType Directory -Force $env:NASHEI_BASE | Out-Null
    $env:CLAUDE_PROJECT_DIR = $work
    $setModo = { param($m) "{`"areas`":[`"area:arte`"],`"modo`":`"$m`"}" | Set-Content (Join-Path $env:NASHEI_BASE 'puesto.json') }
    & $setModo 'estricto'
    $state = Join-Path $env:NASHEI_BASE 'estado'
    function Invoke-Hook { param([string]$Mode, $InputObject)
        ($InputObject | ConvertTo-Json -Depth 8 -Compress) | & pwsh -NoProfile -File $hook $Mode -Usuario | Out-String }
    $edit = @{ session_id = 'A'; hook_event_name = 'PreToolUse'; tool_name = 'mcp__Roblox_Studio__multi_edit'; tool_input = @{ studio_id = 'st-1'; file_path = 'game.Workspace.World'; edits = @() } }
    $editB = @{} + $edit; $editB.session_id = 'B'

    $out = Invoke-Hook 'candado' $edit
    Assert ($out -match '"permissionDecision":"deny"' -and $out -match 'list_roblox_studios') 'estricto denies an edit to a studio that was never listed'
    Invoke-Hook 'registro' @{ session_id = 'A'; tool_name = 'mcp__Roblox_Studio__list_roblox_studios'; tool_input = @{}; tool_response = @(@{ type = 'text'; text = $listText }) } | Out-Null
    Assert ((Get-StudioMap $state)['st-1'].placeId -eq "$($place.place_id)") 'registro learns the place of each studio from list_roblox_studios'
    $out = Invoke-Hook 'candado' $edit
    Assert ($out -match '"permissionDecision":"deny"' -and $out -match [regex]::Escape("$($place.place_id)") -and $out -match '-Sesion A') 'estricto denies an edit to the group place without an issue, and gives the command for this session'
    Assert ((Invoke-Hook 'candado' @{ session_id = 'A'; tool_name = 'mcp__Roblox_Studio__script_read'; tool_input = @{ studio_id = 'st-1' } }).Trim() -eq '') 'a read is never locked'
    & $setModo 'autonomo'
    Assert ((Invoke-Hook 'candado' $edit) -match '"permissionDecision":"deny"') 'autonomo denies too'
    & $setModo 'preguntar'
    Assert ((Invoke-Hook 'candado' $edit) -match '"permissionDecision":"ask"') 'preguntar asks the person instead'

    # The lock's own failure: a copy of the hook whose ecosystem config is broken. A blocking modo denies, preguntar steps aside.
    $copy = Join-Path $work 'studio-roto'
    foreach ($d in 'tools/lib', 'tools/board-hooks', 'config') { New-Item -ItemType Directory -Force (Join-Path $copy $d) | Out-Null }
    Copy-Item (Join-Path $tools 'lib/*.ps1') (Join-Path $copy 'tools/lib'); Copy-Item (Join-Path $tools 'board-hooks/*.ps1') (Join-Path $copy 'tools/board-hooks')
    Set-Content (Join-Path $copy 'config/ecosistema.json') '{ roto'
    $brokenHook = Join-Path $copy 'tools/board-hooks/board-hook.ps1'
    $runBroken = { ($edit | ConvertTo-Json -Depth 8 -Compress) | & pwsh -NoProfile -File $brokenHook candado -Usuario | Out-String }
    & $setModo 'estricto'
    $failOut = & $runBroken
    Assert ($failOut -match '"permissionDecision":"deny"' -and $failOut -match 'El candado fall') 'a lock that fails denies in estricto'
    & $setModo 'preguntar'
    Assert ((& $runBroken).Trim() -eq '') 'a lock that fails steps aside with preguntar'
    & $setModo 'estricto'

    Assert ((Invoke-Hook 'cierre' @{ session_id = 'A'; stop_hook_active = $false }).Trim() -eq '') 'with nothing touched the turn ends freely'
    Invoke-Hook 'registro' @{ session_id = 'A'; tool_name = 'mcp__Roblox_Studio__execute_luau'; tool_input = @{ studio_id = 'st-1'; datamodel_type = 'Edit'; code = $code } } | Out-Null
    Invoke-Hook 'registro' @{ session_id = 'A'; cwd = $ownRepo; tool_name = 'Bash'; tool_input = @{ command = 'git push origin main' } } | Out-Null
    Assert (@(Get-TouchEntries $state).Count -eq 1) 'registro logs an Edit-mode execute_luau and skips a push to a personal repo'
    Invoke-Hook 'registro' @{ session_id = 'A'; cwd = $orgRepo; tool_name = 'Bash'; tool_input = @{ command = 'git push origin feat/12-bahia' } } | Out-Null
    Assert (@(Get-TouchEntries $state 'A').Count -eq 2) 'a push to an organization repo is logged'
    Assert ((Invoke-Hook 'cierre' @{ session_id = 'B'; stop_hook_active = $false }).Trim() -eq '') 'another session is not blocked by what this one touched'
    $stop = Invoke-Hook 'cierre' @{ session_id = 'A'; stop_hook_active = $false } | ConvertFrom-Json
    Assert ($stop.decision -eq 'block' -and $stop.reason -match 'Workspace\.World\.Scenery' -and $stop.reason -match 'aviso\.ps1' -and $stop.reason -match '-Sesion A') 'cierre blocks the end of the turn and gives the notice command for this session'
    $stop = Invoke-Hook 'cierre' @{ session_id = 'A'; stop_hook_active = $true } | ConvertFrom-Json
    Assert (-not $stop.decision -and $stop.systemMessage -match 'sin avisar') 'the second time it lets the turn end and warns the person'

    # 10. The active issue: one session, 24 h.
    Set-ActiveIssue $state 'o/r' 5 't' 'A'
    Assert ((Get-ActiveIssue $state 'A').number -eq 5 -and $null -eq (Get-ActiveIssue $state 'B')) 'the active issue belongs to the session that started it'
    Assert ($null -eq (Get-ActiveIssue $state 'A' ([datetime]::UtcNow.AddHours(25)))) 'it expires after 24 h'
    Clear-ActiveIssue $state

    # 11. aviso.ps1 against a simulated board and issue.
    $board = Join-Path $work 'tablero.txt'; $env:NASHEI_TABLERO_SIMULADO = $board; $env:BOARD_LOGIN = 'leonaranguiz2012-a11y'
    $aviso = Join-Path $tools 'board-hooks/aviso.ps1'
    $env:NASHEI_ISSUE_SIMULADO = '{"state":"OPEN","title":"bahía","assignees":[{"login":"leonaranguiz2012-a11y"}]}'
    $env:NASHEI_TEST = $null
    & pwsh -NoProfile -File $aviso empiezo -Issue 12 -Repo "$org/drain-for-loot" -Que 'bahía' -Sesion A 2>$null | Out-Null
    Assert ($LASTEXITCODE -eq 2 -and -not (Test-Path $board) -and $null -eq (Get-ActiveIssue $state)) 'the test variables are refused outside a test run: no post, the lock stays closed'
    if (-not $env:CI) { 'skip  aviso.ps1 with the simulated board (set CI=1 to run it locally)' }
    else {
        $env:NASHEI_TEST = '1'
        $env:NASHEI_ISSUE_SIMULADO = '{"state":"OPEN","title":"bahía","assignees":[{"login":"otra"}]}'
        & pwsh -NoProfile -File $aviso empiezo -Issue 12 -Repo "$org/drain-for-loot" -Que 'bahía' -Sesion A 2>$null | Out-Null
        Assert ($LASTEXITCODE -eq 2 -and -not (Test-Path $board)) 'empiezo refuses an issue taken by someone else'
        $env:NASHEI_ISSUE_SIMULADO = '{"state":"OPEN","title":"bahía","assignees":[{"login":"leonaranguiz2012-a11y"}]}'
        & pwsh -NoProfile -File $aviso empiezo -Issue 12 -Repo "$org/drain-for-loot" -Que 'bahía con arrecife, ojo @vruizz22' -Sesion A | Out-Null
        $posted = Get-Content $board -Raw
        Assert ($posted -match "^\[Leon's Claude\] empiezo $org/drain-for-loot#12: bahía con arrecife, ojo ``@vruizz22``\. Toca: place Drain the Sea! \($($place.place_id)\): .*Workspace\.World\.Scenery.*git push origin feat/12-bahia") "empiezo posts the label, the issue and what this session touched, without notifying anyone ($($posted.Trim()))"
        Assert ((Get-ActiveIssue $state 'A').number -eq 12 -and -not @(Get-TouchEntries $state 'A').Count) 'empiezo opens the lock for the session and clears what it announced'
        Assert ((Invoke-Hook 'candado' $edit).Trim() -eq '') 'with an issue started in this session the edit goes through'
        Assert ((Invoke-Hook 'candado' $editB) -match '"permissionDecision":"deny".*retomo') 'another session is still locked and is told how to resume'
        & pwsh -NoProfile -File $aviso retomo -Sesion B | Out-Null
        Assert ((Invoke-Hook 'candado' $editB).Trim() -eq '') 'retomo opens the lock of the new session'

        Invoke-Hook 'registro' @{ session_id = 'B'; tool_name = 'Bash'; tool_input = @{ command = "git -C $orgRepo push origin feat/12-bahia" } } | Out-Null
        & pwsh -NoProfile -File $aviso cierro -Que "listo; ver $HOME/notas.txt gho_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456" -Pr "https://github.com/$org/drain-for-loot/pull/30" -Sesion B | Out-Null
        $last = @(Get-Content $board)[-1]
        Assert ($last -match "^\[Leon's Claude\] cierro $org/drain-for-loot#12: .*Toca: git push origin feat/12-bahia\. PR https://") "cierro posts the push and the PR ($last)"
        Assert (-not $last.Contains($HOME) -and $last -notmatch 'gho_') 'the posted notice has no personal path and no token'
        Assert ($null -eq (Get-ActiveIssue $state)) 'cierro closes the lock again'
        Assert ((Invoke-Hook 'candado' $editB) -match '"permissionDecision":"deny"') 'after cierro an edit needs a new issue'

        # 12. The issue read through gh, the path of a real notice: a stand-in gh goes first on PATH.
        $fakeBin = Join-Path $work 'bin'; New-Item -ItemType Directory -Force $fakeBin | Out-Null
        $issueJson = '{"assignees":[{"login":"leonaranguiz2012-a11y"}],"state":"OPEN","title":"bahia"}'
        Set-Content (Join-Path $fakeBin 'gh.cmd') "@echo $issueJson" -Encoding ascii
        Set-Content (Join-Path $fakeBin 'gh') "#!/bin/sh`nprintf '%s\n' '$issueJson'" -Encoding ascii
        if (-not $IsWindows) { & chmod +x (Join-Path $fakeBin 'gh') }
        $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
        $env:NASHEI_ISSUE_SIMULADO = $null
        & pwsh -NoProfile -File $aviso empiezo -Issue 13 -Repo "$org/drain-for-loot" -Que 'bahía' -Sesion C 2>$null | Out-Null
        Assert ($LASTEXITCODE -eq 0 -and (Get-ActiveIssue $state 'C').number -eq 13) 'empiezo reads the issue through gh and opens the lock'
        Clear-ActiveIssue $state
    }
} finally {
    foreach ($k in $saved.Keys) { if ($null -eq $saved[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $saved[$k] } }
    [Console]::OutputEncoding = $savedConsoleEncoding
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($failed) { "$failed expectation(s) failed"; exit 1 }
'board-hooks tests passed'
