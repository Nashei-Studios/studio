#requires -Version 7
# Helpers for the user hooks of issue 67: what an agent touched, kept on this computer, and the start lock.
# Pure except for the small file helpers at the end (state folder only). Dot-sourced by
# tools/board-hooks/board-hook.ps1 and tools/board-hooks/aviso.ps1, tested by tools/tests/board-hooks.test.ps1.
#
# What is "touched": an MCP edit to a Roblox Studio place (scripts or instances), a git push, an upload to the
# Drive. Everything that leaves this computer (the board notice) goes through ConvertTo-SafeText first:
# no secrets, no personal paths.

# Roblox Studio MCP tools that only read or drive a playtest. Any other tool of that server counts as an edit,
# so a tool added later is treated as an edit until someone lists it here.
$script:StudioReadOnly = @(
    'list_roblox_studios', 'get_studio_state', 'search_game_tree', 'inspect_instance', 'script_read', 'script_search',
    'script_grep', 'get_console_output', 'screen_capture', 'search_asset', 'list_skills', 'skill', 'wait_job_finished',
    'http_get', 'start_stop_play', 'character_navigation', 'user_keyboard_input', 'user_mouse_input', 'submit_feedback',
    'create_skill', 'edit_skill', 'subagent')
$script:DriveMcpWrites = @('create_file', 'update_file', 'copy_file', 'trash_file', 'share_file')
$script:LockModes = @{ preguntar = 'ask'; autonomo = 'ask'; estricto = 'deny' }

function Get-StudioToolName { param([string]$ToolName)
    # mcp__Roblox_Studio__multi_edit -> multi_edit; $null when the tool is not from a Roblox Studio server.
    if ($ToolName -notmatch '^mcp__(?<server>.+?)__(?<tool>[^_].*)$') { return $null }
    $server, $tool = $Matches.server, $Matches.tool
    if ($server -match '(?i)roblox') { return $tool }
    $null }

function Test-StudioEdit { param([string]$ToolName, $ToolInput)
    $tool = Get-StudioToolName $ToolName
    if (-not $tool -or $tool -in $script:StudioReadOnly) { return $false }
    # execute_luau during a playtest (Client or Server) changes nothing that is saved.
    if ($tool -eq 'execute_luau' -and "$($ToolInput.datamodel_type)" -ne 'Edit') { return $false }
    $true }

function ConvertTo-SafeText { param([string]$Text, [int]$Max = 160)
    if (-not $Text) { return '' }
    $t = $Text -replace '[\x00-\x1f\x7f]', ' '
    # Personal paths: the home folder in any spelling, then any other user folder.
    $homes = @($HOME, ($HOME -replace '\\', '/')) | Where-Object { $_ } | Sort-Object Length -Descending | Select-Object -Unique
    foreach ($h in $homes) { $t = $t -replace [regex]::Escape($h), '~' }
    $t = $t -replace '(?i)\b[A-Z]:[\\/]+(Users|Documents and Settings)[\\/]+[^\\/\s"'']+', '~'
    $t = $t -replace '(?i)/(Users|home)/[^/\s"'']+', '~'
    # Secrets: known token shapes first, then any long opaque piece that mixes letter cases or digits.
    $secret = @(
        'gh[pousr]_[A-Za-z0-9]{16,}', 'github_pat_[A-Za-z0-9_]{20,}', 'ya29\.[\w-]{10,}', '1//[\w-]{20,}', 'sk-[\w-]{16,}',
        'AIza[\w-]{30,}', 'xox[abprs]-[\w-]{10,}', 'ntn_[A-Za-z0-9]{20,}', 'eyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{4,}',
        '-----BEGIN [A-Z ]+-----[\s\S]*?(-----END [A-Z ]+-----|$)', '(?i)(api[_-]?key|token|secret|password|clave|llave)\s*[=:]\s*\S+')
    foreach ($p in $secret) { $t = $t -replace $p, '[oculto]' }
    # A URL or a kebab-case branch keeps its readable parts; a random-looking piece of 32+ characters does not.
    $t = [regex]::Replace($t, '[A-Za-z0-9+=_-]{32,}', {
            param($m)
            $v = $m.Value
            $classes = @('[0-9]', '[A-Z]', '[a-z]' | Where-Object { $v -cmatch $_ }).Count
            ($classes -ge 2) ? '[oculto]' : $v })
    $t = ($t -replace '\s+', ' ').Trim()
    if ($t.Length -gt $Max) { $t = $t.Substring(0, $Max) + '...' }
    $t }

function Get-LuauPaths { param([string]$Code, [int]$Limit = 8)
    <# Instance paths a Luau snippet names directly (game.X.Y, workspace.X, game:GetService("X").Y). Best effort:
       it is a hint for the notice, the agent still says what changed and why. #>
    if (-not $Code) { return @() }
    $found = [System.Collections.Generic.List[string]]::new()
    $ident = '[A-Za-z_][A-Za-z0-9_]*'
    $patterns = @(
        "game\s*:\s*GetService\(\s*[`"'](?<svc>$ident)[`"']\s*\)(?<rest>(\.$ident)*)",
        "\bgame\.(?<svc>$ident)(?<rest>(\.$ident)*)",
        "\b(?<svc>[Ww]orkspace)(?<rest>(\.$ident)+)")
    foreach ($p in $patterns) {
        foreach ($m in [regex]::Matches($Code, $p)) {
            $svc = $m.Groups['svc'].Value
            if ($svc -in 'GetService', 'FindFirstChild', 'WaitForChild') { continue }
            if ($svc -eq 'workspace') { $svc = 'Workspace' }
            $parts = @($svc) + @($m.Groups['rest'].Value -split '\.' | Where-Object { $_ })
            # Stop at the first method or property-looking member and keep paths short.
            $kept = @()
            foreach ($part in $parts) {
                if ($kept.Count -and $part -cmatch '^(Get|Find|Wait|Clone|Destroy|Set|Is|Connect|Fire|Invoke|Parent|Name|Position|CFrame|Size|Value|Source|Enabled|Visible|Transparency|Color|Material)') { break }
                $kept += $part
                if ($kept.Count -ge 5) { break }
            }
            $path = $kept -join '.'
            if ($path -and -not $found.Contains($path)) { $found.Add($path) }
        }
    }
    # A longer path already says the shorter one.
    $unique = @($found | Where-Object { $p = $_; -not ($found | Where-Object { $_ -ne $p -and $_.StartsWith("$p.") }) })
    @($unique | Select-Object -First $Limit) }

function Get-McpText { param($ToolResponse)
    # MCP results arrive as a string, as {content:[{type,text}]} or as an array of those parts.
    if ($null -eq $ToolResponse) { return '' }
    if ($ToolResponse -is [string]) { return $ToolResponse }
    $parts = if ($ToolResponse.PSObject.Properties['content']) { $ToolResponse.content } else { $ToolResponse }
    (@($parts) | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($_.PSObject.Properties['text']) { $_.text } } ) -join "`n" }

function Get-StudioMapFromList { param($ToolResponse)
    <# list_roblox_studios -> @{ <studio_id> = @{ placeId; universeId; name } }. Unknown shapes give an empty map. #>
    $map = @{}
    $text = Get-McpText $ToolResponse
    $start = $text.IndexOf('{')
    if ($start -lt 0) { return $map }
    try { $data = $text.Substring($start) | ConvertFrom-Json -ErrorAction Stop } catch { return $map }
    foreach ($s in @($data.studios)) {
        if (-not $s.id) { continue }
        $map["$($s.id)"] = @{ placeId = "$($s.placeId)"; universeId = "$($s.universeId)"; name = ConvertTo-SafeText ("$($s.name)" -replace '\s*\(placeId:.*$', '') 60 }
    }
    $map }

function Get-GroupPlaces { param($Ecosystem)
    @($Ecosystem.roblox.places | Where-Object { $_ } | ForEach-Object {
            [pscustomobject]@{ name = "$($_.nombre)"; placeId = "$($_.place_id)"; universeId = "$($_.universe_id)" } }) }

function Test-GroupPlace { param($Studio, $Places)
    <# $Studio from the studio map, or $null when the agent has not listed the studios yet (counts as group:
       the lock cannot tell, so it stays on the safe side). #>
    if (-not $Studio) { return $true }
    [bool]($Places | Where-Object { $_.placeId -eq $Studio.placeId -or ($Studio.universeId -and $_.universeId -eq $Studio.universeId) }) }

function Get-ToolTouch { param($HookInput, [hashtable]$StudioMap = @{}, [string]$Remote = 'nashei')
    <# One PostToolUse call -> a log entry, or $null when nothing shared was touched. #>
    $name = "$($HookInput.tool_name)"
    $in = $HookInput.tool_input
    if (Test-StudioEdit $name $in) {
        $tool = Get-StudioToolName $name
        $studio = $StudioMap["$($in.studio_id)"]
        $detail = switch ($tool) {
            'multi_edit' { "$($in.file_path)" -replace '^game\.', '' }
            'execute_luau' { $paths = Get-LuauPaths "$($in.code)"; $paths.Count ? ($paths -join ', ') : 'código Luau sin rutas directas' }
            'insert_asset' { "asset $($in.asset_id ?? $in.assetId)" }
            default { '' }
        }
        return [pscustomobject]@{
            kind = 'studio'; tool = $tool
            place = $studio ? $studio.placeId : ''; placeName = $studio ? $studio.name : 'studio sin identificar'
            detail = ConvertTo-SafeText $detail 200 }
    }
    if ($name -match '(?i)^mcp__.*google.?drive.*__(?<tool>.+)$' -and $Matches.tool -in $script:DriveMcpWrites) {
        $what = $in.title ?? $in.name ?? $in.fileId ?? ''
        return [pscustomobject]@{ kind = 'drive'; tool = $Matches.tool; place = ''; placeName = ''; detail = ConvertTo-SafeText "Drive (MCP) $($Matches.tool) $what" }
    }
    if ($name -in 'Bash', 'PowerShell') {
        $cmd = "$($in.command)"
        if ($cmd -match '(?i)\bgit\b(\s+-C\s+\S+)?\s+push\b(?<rest>[^;&|\n]*)') {
            $refs = @($Matches.rest -split '\s+' | Where-Object { $_ -and $_ -notmatch '^-' }) | Select-Object -Last 2
            return [pscustomobject]@{ kind = 'push'; tool = 'git push'; place = ''; placeName = ''; detail = ConvertTo-SafeText ("git push " + ($refs -join ' ')).Trim() }
        }
        if ($cmd -match '(?i)kits\.ps1[''"]?\s+push\b(?<rest>[^;&|\n]*)') {
            $rest = $Matches.rest
            $folder = if ($rest -match '(?i)-Folder\s+[''"]?(?<f>[\w.-]+)') { $Matches.f } else { '10-kits' }
            $only = if ($rest -match '(?i)-Only\s+[''"]?(?<o>[\w.,-]+)') { " ($($Matches.o))" } else { '' }
            return [pscustomobject]@{ kind = 'drive'; tool = 'kits push'; place = ''; placeName = ''; detail = ConvertTo-SafeText "Drive $folder$only" }
        }
        $r = [regex]::Escape($Remote)
        if ($cmd -match "(?i)\brclone\s+(?<op>copy|copyto|sync|move|moveto|delete|deletefile|purge|mkdir|rmdir|rcat)\b[^;&|\n]*?\b$r`:(?<path>[^\s'`"]*)") {
            return [pscustomobject]@{ kind = 'drive'; tool = "rclone $($Matches.op)"; place = ''; placeName = ''; detail = ConvertTo-SafeText "Drive $($Matches.path) (rclone $($Matches.op))" }
        }
    }
    $null }

function Format-TouchList { param($Entries, [int]$Max = 900)
    <# The "Toca:" part of a notice: one group per place, then pushes and Drive. Already safe text. #>
    $groups = [System.Collections.Generic.List[string]]::new()
    $studio = @($Entries | Where-Object kind -eq 'studio')
    foreach ($g in ($studio | Group-Object { "$($_.place)|$($_.placeName)" })) {
        $first = $g.Group[0]
        $label = $first.place ? "place $($first.placeName) ($($first.place))" : "place $($first.placeName)"
        $items = @($g.Group | ForEach-Object { $_.detail ? "$($_.detail) [$($_.tool)]" : "[$($_.tool)]" } | Select-Object -Unique)
        $groups.Add("${label}: $($items -join '; ')")
    }
    $other = @($Entries | Where-Object kind -ne 'studio' | ForEach-Object { $_.detail } | Select-Object -Unique)
    if ($other.Count) { $groups.Add($other -join '; ') }
    $text = $groups -join ' | '
    if (-not $text) { $text = 'nada registrado' }
    if ($text.Length -gt $Max) { $text = $text.Substring(0, $Max) + '... (lista completa: aviso.ps1 pendiente)' }
    $text }

function Get-LockDecision { param([string]$Modo, $Active, [bool]$GroupPlace)
    <# allow | ask | deny for an MCP edit. Only the group's places are locked; an active issue opens them. #>
    if (-not $GroupPlace -or $Active) { return 'allow' }
    $script:LockModes[$Modo] ?? 'ask' }

function Get-AgentLabel { param($Ecosystem, [string]$Login, [string]$Agent = 'Claude')
    # "[Leon's Claude]": the person's name from config/ecosistema.json, else the login.
    $who = $Login
    foreach ($p in @($Ecosystem.personas.PSObject.Properties)) {
        if ("$($p.Value.login)".ToLowerInvariant() -eq "$Login".ToLowerInvariant()) { $who = (Get-Culture).TextInfo.ToTitleCase($p.Name); break }
    }
    "[$who's $Agent]" }

# ---- State on this computer: <Base>/estado. Never inside a repo, so nothing here is committed by accident. ----

function Get-NasheiStateDir { param([string]$Base)
    if (-not $Base) { $Base = if ($env:NASHEI_BASE) { $env:NASHEI_BASE } else { Join-Path $HOME 'Nashei' } }
    $dir = Join-Path $Base 'estado'
    New-Item -ItemType Directory -Force $dir | Out-Null
    $dir }

function Read-JsonFile { param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable } catch { $null } }

function Write-JsonFile { param([string]$Path, $Value)
    # Write then rename: a hook killed half way never leaves a broken file behind.
    $tmp = "$Path.tmp-$PID"
    $Value | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $tmp -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $Path -Force }

function Add-TouchEntry { param([string]$StateDir, $Entry)
    $line = [ordered]@{ at = [datetime]::UtcNow.ToString('o'); kind = $Entry.kind; tool = $Entry.tool; place = $Entry.place; placeName = $Entry.placeName; detail = $Entry.detail }
    Add-Content -LiteralPath (Join-Path $StateDir 'registro.jsonl') -Value ($line | ConvertTo-Json -Compress) -Encoding utf8 }

function Get-TouchEntries { param([string]$StateDir)
    $file = Join-Path $StateDir 'registro.jsonl'
    if (-not (Test-Path -LiteralPath $file)) { return @() }
    @(Get-Content -LiteralPath $file -Encoding utf8 | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch { } }) }

function Clear-TouchEntries { param([string]$StateDir, [int]$Count = -1)
    <# Drops the first $Count entries (the ones just announced); a hook may have added more meanwhile. #>
    $file = Join-Path $StateDir 'registro.jsonl'
    if ($Count -lt 0 -or -not (Test-Path -LiteralPath $file)) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue; return }
    $rest = @(Get-Content -LiteralPath $file -Encoding utf8 | Where-Object { $_.Trim() } | Select-Object -Skip $Count)
    if ($rest.Count) { Set-Content -LiteralPath $file -Value $rest -Encoding utf8 } else { Remove-Item -LiteralPath $file -Force }
}

function Get-ActiveIssue { param([string]$StateDir) Read-JsonFile (Join-Path $StateDir 'activo.json') }
function Set-ActiveIssue { param([string]$StateDir, [string]$Repo, [int]$Number, [string]$Title)
    Write-JsonFile (Join-Path $StateDir 'activo.json') ([ordered]@{ repo = $Repo; number = $Number; title = $Title; at = [datetime]::UtcNow.ToString('o') }) }
function Clear-ActiveIssue { param([string]$StateDir) Remove-Item -LiteralPath (Join-Path $StateDir 'activo.json') -Force -ErrorAction SilentlyContinue }

function Get-StudioMap { param([string]$StateDir) (Read-JsonFile (Join-Path $StateDir 'studios.json')) ?? @{} }
function Save-StudioMap { param([string]$StateDir, [hashtable]$Map)
    # Keep what was learned before: several Studio windows can be listed at different times.
    $all = Get-StudioMap $StateDir
    foreach ($k in $Map.Keys) { $all[$k] = $Map[$k] }
    Write-JsonFile (Join-Path $StateDir 'studios.json') $all }
