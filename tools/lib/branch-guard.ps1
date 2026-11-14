#requires -Version 7
# Branch guard: nobody edits code straight on develop or main of an organization clone (docs/en-vivo-y-ramas.md).
# Used by `board-hook.ps1 rama` (PreToolUse for Edit, Write, MultiEdit and NotebookEdit, and for `git commit` and
# `git push` in Bash and PowerShell, issue 108) and tested by
# tools/tests/board-hooks.test.ps1. Which branches are protected and which organization counts both come from
# config/ecosistema.json, never from a name written here. Needs touch-log.ps1 (Test-OrgRemote) loaded.

function Get-ProtectedBranches { param($Ecosystem)
    <# github.ramas_protegidas; without it, the integration branch plus every rama_base. #>
    $listed = @($Ecosystem.github.ramas_protegidas | Where-Object { $_ })
    if ($listed.Count) { return $listed }
    $bases = @($Ecosystem.github.repos.PSObject.Properties | ForEach-Object { $_.Value.rama_base })
    @(@($Ecosystem.github.rama_integracion) + $bases | Where-Object { $_ } | Select-Object -Unique) }

function Get-EditTarget { param($ToolInput, [string]$Cwd)
    <# The file an edit tool is about to change, absolute; $null when the call names none. #>
    $path = "$($ToolInput.file_path)"
    if (-not $path) { $path = "$($ToolInput.notebook_path)" }
    if (-not $path) { return $null }
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path ($Cwd ? $Cwd : (Get-Location).Path) $path }
    $path }

function Get-OrgCloneTop { param([string]$Dir, $Ecosystem)
    <# The top folder of the organization clone that holds $Dir (an existing folder); $null otherwise. #>
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir -PathType Container)) { return $null }
    $top = (& git -C $Dir rev-parse --show-toplevel 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $top) { return $null }
    if (-not (Test-OrgRemote $top 'origin' "$($Ecosystem.github.organizacion)")) { return $null }
    $top }

function Get-CurrentBranch { param([string]$Top) (& git -C $Top branch --show-current 2>$null | Out-String).Trim() }

function Get-BranchViolation { param([string]$Path, $Ecosystem)
    <# $null unless $Path sits inside a clone of an organization repo whose current branch is protected. #>
    $dir = Split-Path $Path -Parent
    while ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        $up = Split-Path $dir -Parent
        if ($up -eq $dir) { return $null }
        $dir = $up
    }
    $top = Get-OrgCloneTop $dir $Ecosystem
    if (-not $top) { return $null }
    $branch = Get-CurrentBranch $top
    if (-not $branch -or $branch -notin (Get-ProtectedBranches $Ecosystem)) { return $null }
    [pscustomobject]@{ top = ($top -replace '\\', '/'); name = (Split-Path $top -Leaf); branch = $branch } }

function ConvertFrom-ShellWord { param([string]$Word)
    <# A word with its surrounding quotes removed; $null when it still needs the shell to expand it ($VAR,
       `cmd`, $(...), a quote left inside), so the caller can fail closed on it. #>
    $w = $Word
    if ($w.Length -ge 2 -and (($w[0] -eq '"' -and $w[-1] -eq '"') -or ($w[0] -eq "'" -and $w[-1] -eq "'"))) { $w = $w.Substring(1, $w.Length - 2) }
    if ($w -match '[$`"''(){}\\]') { return $null }
    $w }

function Get-ShellGitOps { param([string]$Command, [string]$Cwd)
    <# Each `git commit` and `git push` of a Bash or PowerShell command (issue 108, finding 3), in order:
         dir      where it runs: git -C <dir>, else the last cd / pushd / Set-Location / Push-Location before it,
                  else the hook's cwd
         moves    every earlier `git switch` / `git checkout` of the same command, newest first: branch, kind
                  (create for -c -C -b -B, switch, or checkout: a word that may be a file), dir, and chained
                  (joined to this op only by &&, so the op ran only if the switch worked)
         targets  for a push, the branches its refspecs name ('*' for --all, --mirror or --branches; empty =
                  the branch it is on)
         unclear  the target cannot be read (GIT_DIR / GIT_WORK_TREE, --git-dir / --work-tree, symbolic-ref or
                  update-ref in the same command, or a branch name that needs the shell to expand it): the guard
                  fails closed on it
       git can carry a path (/usr/bin/git, "C:\...\git.exe"). A `git ... commit|push` the parser cannot place gets an
       unclear op of its own, so it fails closed. Aliases and scripts are not followed. #>
    $quoted = '"[^"]+"|''[^'']+''|[^\s;&|]+'
    $global = "\s+-C\s+(?:$quoted)|\s+-c\s+\S+|\s+--[\w-]+(?:=\S+)?|\s+-[pPh]"
    # git starts a word: after a separator, a quote, a backtick, a brace, = ! or @ (bash -c "git ...", `git ...`,
    # {git ...}, $x=git ...), with an optional path in front (/usr/bin/git, "C:\...\git.exe").
    $start = '(?:^|(?<=[\s;&|(`''"{=!@]))'
    $rx = "(?i)$start(?:`"[^`"]*[/\\]|[^\s;&|`"']*[/\\])?git(?:\.exe)?[`"'``]?(?<opts>(?:$global)*)\s+(?<sub>[a-z][\w-]*)(?<rest>[^;&|\n``}]*)"
    # Safety net: any `git ... commit|push` whose first non-option word is the subcommand. When it finds more than
    # the parser placed, the extra ones fail closed instead of slipping through.
    $rawRx = '(?i)(?<![\w-])git(?:\.exe)?["''`]?(?:\s+-\S+(?:\s+(?!-)\S+)?)*?\s+(?:commit|push)(?![\w-])'
    $envUnclear = $Command -match '(?i)(?:^|[\s;&|])(?:\$env:)?GIT_(?:DIR|WORK_TREE)\s*='
    # The rule itself lives in .githooks (pre-commit, pre-push), which see the real branch. Anything that would
    # switch those hooks off, or change what a push targets through config, is denied here (issue 108).
    # --no-v... covers every abbreviation git accepts for --no-verify (it takes any unique prefix).
    # --config-env sets config from the environment like -c does, without the key showing: any use fails closed.
    $hookBypass = $Command -match '(?i)--no-v[a-z-]*|--config-env|hooksPath|ALLOW_PROTECTED_|GIT_CONFIG_(?:COUNT|KEY|VALUE|PARAMETERS|GLOBAL|SYSTEM)'
    # Config keys that switch the hooks off, add a command that may hide a commit or push, or redirect a push.
    $riskyKey = '(?i)^(?:core\.hookspath|alias\..+|remote\..+\.push|push\..+|include\..+|includeif\..+)(?:=.*)?$'
    # $( ), backticks and <( ) run text the parser cannot attribute to the call it sits in.
    $expands = $Command -match '\$\(|`|<\('
    $dirOf = { param($Match, [string]$Opts)
        $d = ''
        $c = [regex]::Match($Opts, "-C\s+(?<d>$quoted)")
        if ($c.Success) { $d = $c.Groups['d'].Value.Trim('"', "'") }
        if (-not $d) {
            $before = $Command.Substring(0, $Match.Index)
            $cds = [regex]::Matches($before, "(?i)(?:^|[;&|]\s*)(?:cd|pushd|Set-Location|Push-Location|sl)\s+(?:-(?:Literal)?Path\s+)?(?<d>$quoted)")
            if ($cds.Count) { $d = $cds[$cds.Count - 1].Groups['d'].Value.Trim('"', "'") }
        }
        if ($d -match '^~') { $d = $HOME + $d.Substring(1) }
        if (-not $d) { $d = $Cwd }
        elseif ($Cwd -and -not [IO.Path]::IsPathRooted($d)) { $d = Join-Path $Cwd $d }
        $d -replace '\\', '/' }
    $ops = @(); $refUnclear = $false
    $moves = @()   # every switch / checkout so far: branch, kind, dir, end
    # `continue` inside a PowerShell switch only moves the switch on: the label skips to the next git call.
    $spans = @()
    :calls foreach ($m in [regex]::Matches($Command, $rx)) {
        $spans += , @($m.Index, ($m.Index + $m.Length))
        $sub = $m.Groups['sub'].Value.ToLowerInvariant()
        $opts = $m.Groups['opts'].Value
        $words = @($m.Groups['rest'].Value.Trim() -split '\s+' | Where-Object { $_ })
        $plain = @($words | Where-Object { $_ -notmatch '^-' })
        switch -Regex ($sub) {
            '^(symbolic-ref|update-ref)$' { $refUnclear = $true; continue calls }
            '^(switch|checkout)$' {
                # `checkout -- <file>` and `checkout <ref> -- <file>` touch files, not the branch.
                if ($sub -eq 'checkout' -and $words -contains '--') { continue calls }
                $flags = $sub -eq 'switch' ? @('-c', '-C', '--create', '--force-create') : @('-b', '-B')
                $i = [array]::FindIndex([string[]]$words, [Predicate[string]] { param($x) $x -in $flags })
                $kind = $i -ge 0 ? 'create' : $sub
                $raw = if ($i -ge 0 -and $i + 1 -lt $words.Count) { $words[$i + 1] } elseif ($plain.Count) { $plain[0] } else { '' }
                if ($raw) {
                    $name = ConvertFrom-ShellWord $raw
                    if ($null -eq $name) { $refUnclear = $true; continue calls }
                    $moves += [pscustomobject]@{ branch = $name; kind = $kind; dir = (& $dirOf $m $opts); end = $m.Index + $m.Length }
                }
                continue calls
            }
            '^config$' {
                # Writing a risky key is denied on its own, whatever else the command does: a later command would
                # run with the hooks off or through the alias. Reading (--get, --list) is fine.
                # Words as the shell hands them to git; one that still needs expanding fails closed.
                $unquoted = @($plain | ForEach-Object { $w = ConvertFrom-ShellWord $_; if ($null -eq $w) { '<unclear>' } else { $w } })
                # A write is a risky key followed by a value, or any write verb or flag; a lone key is a read.
                $keyAt = [array]::FindIndex([string[]]$unquoted, [Predicate[string]] { param($x) $x -match $riskyKey -or $x -eq '<unclear>' })
                $writeVerb = @($words | Where-Object { $_ -match '^(set|unset|edit|rename-section|remove-section|--unset(-all)?|--add|--replace-all|--rename-section|--remove-section|-e|--edit)$' }).Count
                # Renaming or removing a whole section (core, alias, include, includeIf, push, remote.*) counts too.
                $riskySection = @($unquoted | Where-Object { $_ -match '(?i)^(core|alias|include|includeif|push|remote(\..+)?)$' }).Count
                $writes = ($keyAt -ge 0 -and ($writeVerb -or $keyAt + 1 -lt $unquoted.Count -or $unquoted[$keyAt] -match '=' -or $unquoted[$keyAt] -eq '<unclear>')) -or
                    ($riskySection -and @($words | Where-Object { $_ -match '^(--)?(rename|remove)-section$' }).Count)
                if ($writes) {
                    $global = @($words | Where-Object { $_ -match '^--(global|system|file)$|^-f$' }).Count -gt 0
                    $ops += [pscustomobject]@{ op = 'config'; dir = (& $dirOf $m $opts); moves = @(); targets = @(); unclear = $true; global = $global; start = -1 }
                }
                continue calls
            }
            '^(commit|push)$' { }
            default {
                # Any other subcommand may be an alias (aliases cannot shadow built-ins, so a real command is safe):
                # Get-ShellBranchViolation looks it up in the repo's config.
                # It carries the same red flags as a commit or push: hooks off, a hidden target, an alias or a push
                # redirect set through -c for this one call.
                $callUnclear = $envUnclear -or $hookBypass -or ($opts -match '(?i)--(git-dir|work-tree)|-c\s+\S*(?:alias\.|core\.hookspath|remote\.[^\s=]*\.push|push\.|include)')
                $ops += [pscustomobject]@{ op = 'call'; sub = $sub; dir = (& $dirOf $m $opts); moves = @(); targets = @(); unclear = $callUnclear; start = -1 }
                continue calls
            }
        }
        $dir = & $dirOf $m $opts
        $unclear = $envUnclear -or $refUnclear -or $hookBypass -or ($opts -match '(?i)--(git-dir|work-tree)') -or
            ($opts -match '(?i)-c\s+\S*(?:remote\.[^\s=]*\.push|push\.|alias\.)') -or
            # commit -n is --no-verify, also inside a cluster of short flags (-anm)
            ($sub -eq 'commit' -and @($words | Where-Object { $_ -cmatch '^-[a-zA-Z]*n[a-zA-Z]*$' }).Count)
        $targets = @()
        if ($sub -eq 'push') {
            if ($words | Where-Object { $_ -in '--all', '--mirror', '--branches' }) { $targets = @('*') }
            else {
                # The first plain word is the remote; the rest are refspecs (src:dst, +force, refs/heads/x).
                foreach ($ref in @($plain | Select-Object -Skip 1)) {
                    $clean = ConvertFrom-ShellWord $ref
                    if ($null -eq $clean) { $unclear = $true; continue }
                    $dst = (($clean -split ':')[-1]).TrimStart('+') -replace '^refs/heads/', ''
                    # ':' alone (matching branches), an empty destination or a glob reach branches it cannot name.
                    if ($clean -eq ':' -or -not $dst -or $dst -match '[*?\[]') { $unclear = $true; continue }
                    if ($dst -and $dst -ne 'HEAD') { $targets += $dst }
                }
            }
        }
        # Every earlier switch, newest first, with whether only && joins it to this op (then the op ran only if the
        # switch worked). Which of them touch this op's repo is decided by repo, not by folder text, in
        # Get-ShellBranchViolation.
        $before = @(for ($k = $moves.Count - 1; $k -ge 0; $k--) {
                $mv = $moves[$k]
                $between = $Command.Substring($mv.end, [math]::Max(0, $m.Index - $mv.end)) -replace '&&', ''
                [pscustomobject]@{ branch = $mv.branch; kind = $mv.kind; dir = $mv.dir; chained = ($between -notmatch '[;|&\n]') }
            })
        # Where its `git` word sits (after any path or quote in front), to match it with the safety net below.
        $gitAt = $m.Index + $m.Value.Substring(0, $m.Groups['opts'].Index - $m.Index).LastIndexOf('git', [StringComparison]::OrdinalIgnoreCase)
        $ops += [pscustomobject]@{ op = $sub; dir = $dir; moves = $before; targets = $targets; unclear = $unclear; start = $gitAt }
    }
    # A raw match inside a git call the parser already read (a commit message that says "git push", a --grep)
    # is that call's text, not a command of its own.
    foreach ($r in [regex]::Matches($Command, $rawRx)) {
        # Plain text of a parsed call (a commit message) is skipped, unless the command expands text it runs.
        if (-not $expands -and @($spans | Where-Object { $r.Index -ge $_[0] -and $r.Index -lt $_[1] }).Count) { continue }
        if (@($ops | Where-Object { $_.start -eq $r.Index }).Count) { continue }
        $ops += [pscustomobject]@{ op = 'commit/push'; dir = ("$Cwd" -replace '\\', '/'); moves = @(); targets = @(); unclear = $true }
    }
    $ops }

function Get-ShellBranchViolation { param($Op, $Ecosystem)
    <# $null unless the commit lands on, or the push goes to, a protected branch of an organization clone, or the
       command hides where it goes (unclear: fails closed, wherever it runs). An earlier switch only lifts the
       guard when it is chained with && and really names a branch; otherwise both the branch it names and the
       current one count, so a switch that may have failed never opens the way. #>
    $top = Get-OrgCloneTop $Op.dir $Ecosystem
    $unclearAt = { param([string]$Where) [pscustomobject]@{ top = ("$Where" -replace '\\', '/'); name = (Split-Path "$Where" -Leaf); branch = '?'; op = $Op.op; unclear = $true } }
    # A risky config write counts in an organization clone, or anywhere when it goes to the global config.
    if ($Op.op -eq 'config') { return ($top -or $Op.global) ? (& $unclearAt ($top ? $top : $Op.dir)) : $null }
    if ($Op.unclear) { return & $unclearAt ($top ? $top : $Op.dir) }
    if (-not $top) { return $null }
    if ($Op.op -eq 'call') {
        # Any alias (repo or global config) fails closed: an alias can chain to another one, run a shell (!) or
        # carry flags, and following that is not worth the risk in an organization clone. Plain commands pass.
        $alias = (& git -C $top config --get "alias.$($Op.sub)" 2>$null | Out-String).Trim()
        return $alias ? (& $unclearAt $top) : $null
    }
    # The rule lives in .githooks: a clone that has them but does not point core.hooksPath there runs without it.
    if (Test-Path -LiteralPath (Join-Path $top '.githooks') -PathType Container) {
        $hooksPath = (& git -C $top config --get core.hooksPath 2>$null | Out-String).Trim()
        if ($hooksPath -ne '.githooks') { return & $unclearAt $top }
    }
    $protected = @(Get-ProtectedBranches $Ecosystem)
    $current = Get-CurrentBranch $top
    $topKey = ($top -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
    # The newest earlier switch that touches this repo (decided by repo: another folder of the same clone counts,
    # and a folder whose repo cannot be read is treated as this one, to stay on the safe side).
    $on = @($current)
    foreach ($mv in @($Op.moves)) {
        $mvTop = (Test-Path -LiteralPath $mv.dir -PathType Container) ? (& git -C $mv.dir rev-parse --show-toplevel 2>$null | Out-String).Trim() : ''
        if ($mvTop -and ($mvTop -replace '\\', '/').TrimEnd('/').ToLowerInvariant() -ne $topKey) { continue }
        # A bare `checkout <word>` may name a file. It names a branch when the word is protected (checkout creates
        # it from origin), or exists locally or on a remote.
        $isBranch = $mv.kind -ne 'checkout' -or $mv.branch -in $protected
        if (-not $isBranch) {
            & git -C $top rev-parse --verify --quiet "refs/heads/$($mv.branch)" *> $null
            $local = $LASTEXITCODE -eq 0
            # Exact names only: a word with glob or pathspec characters is never taken for a branch.
            $remoteNames = @(& git -C $top for-each-ref --format='%(refname:lstrip=3)' 'refs/remotes/' 2>$null)
            $isBranch = $mv.branch -notmatch '[*?\[\]:]|^[.:]' -and ($local -or $remoteNames -ccontains $mv.branch)
        }
        if ($isBranch) {
            # Joined only by && in a repo it could read: the op ran on that branch. Otherwise both count.
            $on = ($mv.chained -and $mvTop) ? @($mv.branch) : @($mv.branch, $current)
        }
        break
    }
    # A push with no refspec follows remote.<name>.push when the repo sets one: it can reach any branch.
    $configPush = $Op.op -eq 'push' -and -not @($Op.targets).Count -and
        [bool]((& git -C $top config --get-regexp '^remote\..*\.push$' 2>$null | Out-String).Trim())
    $names = if ($Op.op -eq 'push' -and (@($Op.targets) -contains '*' -or $configPush)) { $protected }
             elseif ($Op.op -eq 'push' -and @($Op.targets).Count) { @($Op.targets) }
             else { $on }
    $hit = @($names | Where-Object { $_ -and $_ -in $protected } | Select-Object -First 1)
    if (-not $hit.Count) { return $null }
    [pscustomobject]@{ top = ($top -replace '\\', '/'); name = (Split-Path $top -Leaf); branch = $hit[0]; op = $Op.op; unclear = $false } }

function Format-ShellBranchReason { param($Violation, [string]$Modo)
    $v = $Violation
    $new = "git -C `"$($v.top)`" switch -c feat/<n>-<slug>"
    if ($v.unclear) {
        return "Guardia de rama (modo ${Modo}): este git $($v.op) no pasa: o apaga los hooks de git que hacen cumplir la regla (--no-verify o una abreviatura, commit -n, hooksPath, ALLOW_PROTECTED_*, GIT_CONFIG_*, escribir core.hooksPath, alias.*, remote.*.push o push.* con git config, un clon cuyo core.hooksPath no es .githooks: corre pwsh tools/puesto.ps1 install, o un alias que hace commit o push), o no puedo saber a qué rama va (GIT_DIR, GIT_WORK_TREE, --git-dir, --work-tree, symbolic-ref, update-ref, -c remote.*.push, un refspec ':' o con *, un nombre con variables, o un git dentro de `$( ) o backticks). Córrelo dentro del clon, en tu rama de trabajo, con la rama escrita tal cual y sin esas opciones."
    }
    $what = $v.op -eq 'push' ? "git push a $($v.branch)" : "git commit en $($v.branch)"
    "Guardia de rama (modo ${Modo}): $what de $($v.name). En develop y main no se hace commit ni push directo; todo entra por PR (docs/en-vivo-y-ramas.md). Toma el issue (work.ps1 claim <n>), crea tu rama con $new (o un worktree) y repite el comando ahí." }

function Get-BranchDecision { param([string]$Modo)
    <# estricto and autonomo deny; preguntar asks the person. #>
    $Modo -in 'estricto', 'autonomo' ? 'deny' : 'ask' }

function Format-BranchReason { param($Violation, [string]$Modo)
    $v = $Violation
    $new = "git -C `"$($v.top)`" switch -c feat/<n>-<slug>"
    $tree = "git -C `"$($v.top)`" worktree add -b feat/<n>-<slug> `"<carpeta>`" origin/$($v.branch)"
    "Guardia de rama (modo ${Modo}): $($v.name) está en $($v.branch) y ahí no se edita código; todo entra por PR (docs/en-vivo-y-ramas.md). Toma el issue (work.ps1 claim <n>) y crea tu rama: $new (o fix/ para un arreglo). Si hay otra sesión en este clon, usa un worktree: $tree. Luego repite la edición." }
