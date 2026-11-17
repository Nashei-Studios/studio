# 0008. Perfil ligero de hooks para equipos lentos

- Estado: aceptado 2026-11-16
- Fecha: 2026-11-16
- Decide: Victor (ficha del 16-11, queja de Leon)
- Refs: studio#198, ADR [0003](0003-agentes-que-toman-trabajo-solos.md) y [0006](0006-regla-de-ramas-en-los-hooks-de-git.md)

## Contexto
Cada modo de `tools/board-hooks/board-hook.ps1` arranca un `pwsh` nuevo. Medido en el equipo de Victor: `registro` y `rama` tardan 0,8 a 1,0 s cada uno, `prompt` 3,3 s y `session-start` 7 s. Por cada llamada de Bash corre `registro` (siempre) y, si el comando es git, `rama`; por cada mensaje corre `prompt`. En el equipo de Leon, más lento y con un plan pequeño, se nota.

Sobre las tres entradas de `rama`: no son redundantes. Una es para `Edit|Write|MultiEdit|NotebookEdit` y dos comparten el matcher `^Bash$|^PowerShell$`, distinguidas por el campo `if` (`Bash(git *)` y `PowerShell(git *)`). Para una llamada dada solo una coincide, así que ya hay un solo arranque por herramienta; unirlas no ahorra nada y `completo` queda como está.

## Opciones consideradas
1. **Perfil `ligero` elegido en `puesto.json`.** Registra solo `session-start`, `cierre` y un único modo `guardia` que hace en un proceso lo de `candado` y `rama`, y sale antes de cargar nada si el comando de shell no contiene `git`. A favor: cambio pequeño, `completo` es el default y no cambia nada a nadie. En contra: quien lo elige pierde garantías (ver abajo).
2. **Un proceso residente** (servidor local al que los hooks hablan). A favor: el costo por llamada baja a milisegundos y se mantiene todo. En contra: un cliente igual tiene que arrancar para hablarle; hay que gestionar su ciclo de vida, puertos y limpieza, en tres sistemas, y en un equipo lento un demonio también pesa. Mucha más superficie que mantener para un problema que tiene remedio más barato.
3. **Reescribir los hooks en Node.** A favor: arranque de unos 40 a 60 ms contra 700 o más de `pwsh`. En contra: duplicar `touch-log`, `branch-guard` (un parser con doce rondas de revisión de seguridad) y `agent-loop`, y mantener dos implementaciones; las herramientas del estudio son pwsh. Se reevalúa si el perfil ligero no basta.

## Decisión
Opción 1. `puesto.json` admite `"hooks": "completo" | "ligero"` (default `completo`; un valor inválido se informa y cae a `completo`). `puesto.ps1 install` registra el perfil y quita del `settings.json` las entradas del estudio que el perfil no usa; `check` dice el perfil y marca PERSONA si lo instalado no coincide.

`ligero` registra:
- `SessionStart` y `Stop` (`session-start`, `cierre`), igual que `completo`.
- `PreToolUse` con `guardia` en los mismos tres matchers (MCP de Studio, herramientas de edición, shell con `if` de git). `guardia` despacha a la lógica de `candado` si la herramienta es MCP y a la de `rama` en el resto, con las mismas respuestas. Para shell sale de inmediato si el comando no contiene `git` (ni comillas, escapes o expansiones que puedan esconderlo); en ese caso la regla `if` ya evita incluso arrancar `pwsh`.

## Consecuencias
- Positivas: sin `prompt` ni `registro` por herramienta; un comando de shell sin git no arranca ningún proceso; con git, uno solo.
- Negativas, lo que `ligero` deja de garantizar:
  - El aviso al tablero ya no se arma solo con la lista de lo tocado (MCP a places, `git push`, subidas a Drive): sin `registro`, `cierre` no tiene esa lista. El aviso (`aviso.ps1`) sigue disponible a mano.
  - Los mensajes nuevos del tablero ya no llegan en cada mensaje de la persona (sin `prompt`); llegan al inicio de sesión, con la espera del tablero y al cerrar el turno si la espera durable vio algo.
  - Sigue igual: candado de inicio, guardia de rama y la protección de `main` y `develop` por `.githooks` del clon (ADR 0006), que no depende de Claude Code.
- Qué haría revisar esta decisión: que `ligero` siga siendo lento en el equipo de Leon (pasar a la opción 3) o un tercer perfil pedido por otra persona.
