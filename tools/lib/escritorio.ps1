# Desktop MCP of the workstation (issue 97). Pure functions: the command and its flags come from
# config/ecosistema.json (escritorio.<os>), never from here. Dot-sourced by puesto.ps1 and its tests.

# Returns the { comando, args } block for a system, or $null when the system has none (Linux).
function Get-EscritorioSpec { param($Ecosystem, [string]$Os)
    $block = $Ecosystem.escritorio
    if (-not $block -or -not $block.$Os) { return $null }
    return $block.$Os }

# The claude arguments that register the server at user level: claude <result>.
# CommandPath replaces the bare command (an absolute path survives hosts that do not inherit PATH).
function Get-EscritorioAddArgs { param($Ecosystem, [string]$Os, [string]$CommandPath = '')
    $spec = Get-EscritorioSpec $Ecosystem $Os
    if (-not $spec) { return @() }
    $exe = $CommandPath ? $CommandPath : $spec.comando
    return @('mcp', 'add', $Ecosystem.escritorio.nombre, '-s', 'user', '--', $exe) + @($spec.args) }

# State of the row from the text `claude mcp list` printed. PASA = registered and connected.
function Get-EscritorioState { param([string]$McpList, [string]$Name)
    # `claude mcp list` prints "name: command - state"; the colon keeps "escritorio-otro" from matching "escritorio".
    $line = @($McpList -split "`n" | Where-Object { $_ -match "^$([regex]::Escape($Name)):" })[0]
    if (-not $line) { return 'ausente' }
    return ($line -match 'Connected' -and $line -notmatch 'Failed') ? 'conectado' : 'registrado-sin-conexion' }
