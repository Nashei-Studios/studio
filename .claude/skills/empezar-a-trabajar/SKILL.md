---
name: empezar-a-trabajar
description: Ritual de inicio y cierre de sesión del estudio. Úsalo cuando la persona diga "vamos a trabajar", "abre todo", "empecemos" o similar. Deja clones, puesto, tablero y cola al día y lleva el trabajo de punta a punta (arte en la place compartida; código en rama, copia local de la place, Rojo propio, PR a develop) sin pedirle a la persona pasos técnicos.
---

# Empezar a trabajar

La persona solo dice "vamos a trabajar". Tú haces todo lo técnico; solo le pides lo que nadie más puede hacer (iniciar sesión, un permiso, un clic), con el motivo y sin frenar lo demás. Nadie necesita saber qué es Rojo.

Flujo, piezas y prohibiciones: `docs/como-trabajamos.md`. Detalle de en vivo y ramas: `docs/en-vivo-y-ramas.md`. No se copian aquí. Un hook o permiso que te frene no se rodea: se reporta qué acción, para qué y qué hace falta.

Los ids, puertos y nombres salen de `config/ecosistema.json` (`roblox.places`, `personas`, `github.repos`) o de los scripts del repo del juego. Nada de memoria.

## 1. Clones al día

Para cada clon del estudio que exista en la computadora:

```
git -C <clon> switch develop      # solo si está limpio y en develop; otra rama es trabajo de alguien
git -C <clon> pull --ff-only
pwsh tools/puesto.ps1 check
```

Si `pull --ff-only` falla, no se arregla con merge ni reset: se dice y se sigue. Comprobación: `check` sin filas `FALLA`.

## 2. Lo que depende de la persona

Cada fila `PERSONA` del check, un scope de `gh` faltante (`gh auth refresh -h github.com -s project`) o un acceso se le dice en el momento, con el comando exacto, y se sigue.

## 3. Tablero y cola

```
pwsh tools/board.ps1 unread
pwsh tools/work.ps1 mine
```

Muéstrale sus tareas en lenguaje simple. Cola vacía es normal. Con `modo` `preguntar` o `estricto`, propón el primer issue y espera su sí; con `autonomo`, tómalo.

## 3a. Análisis activo del área (cada sesión, sin cron)

El estudio no espera a que alguien proponga trabajo: cada sesión trae su propio análisis del área de la persona y deja tareas nuevas. No es una tarea programada ni un cron, es parte del arranque. Se hace después del tablero y antes de tomar el issue, y no pasa de unos 15 minutos.

1. **Qué frente toca.** Las áreas salen de `config/ecosistema.json` (`personas.<persona>.areas` y `foco`). Cada área tiene sus frentes y se rotan sesión a sesión:

   | Persona | Frentes que rota |
   |---|---|
   | Código, infra, economía (Victor) | sistemas y loop · datos y guardado · rendimiento y carga · pruebas que rompen · economía y monetización · herramientas del estudio |
   | Arte, UI, audio (Leon) | mundo y mapas · modelos y estilo · UI y sistema de diseño · animación y cámara · audio y música · miniaturas y video |
   | Crecimiento (Nande) | primera sesión del jugador · social y lobby · live ops y eventos · comunidad y redes · programa de beta |

   El frente de hoy es el siguiente al último analizado. Lo encuentras buscando tu último aviso `análisis` en el tablero (`pwsh tools/board.ps1 read`); si no hay, empieza por el primero.

2. **Qué cambió desde la última sesión.** Commits del juego y de la plantilla que tocan el frente, issues abiertos y cerrados, documentos nuevos en `docs/investigacion/` de `studio` y del juego, novedades del vault (`roblox-vault/trends`, `research`) y archivos nuevos en tu carpeta del Drive.

3. **Una mirada a fondo al frente.** Para los frentes de juego, la skill `roblox-analisis-por-frentes`; si tu agente no la tiene, el mismo método en pequeño: un referente con gameplay en video, lo que ya existe (vault, plantilla, kits) y la comparación con el juego. Para las herramientas del estudio, lo nuevo en skills, plugins, MCP y versiones (skill `mejora-continua` si existe). Nunca se juega un referente por el MCP de escritorio.

4. **Hasta 3 propuestas.** Antes de crear, busca duplicados (`gh issue list --repo <repo> --search "<tema>" --state all`). Cada propuesta es un issue con Meta, No rompas, Hecho cuando, Cómo comprobarlo y Contexto (con la evidencia y sus enlaces comprobados), etiquetas `from-research`, `needs-triage`, tu `owner:` y el `area:`, y `--project` del juego o "Nashei Studios". Las de otra persona se proponen con su `owner:` y se le avisa: decide ella. Con `modo` `estricto` le muestras las propuestas a la persona y las creas después de su sí.

5. **Aviso.** Una línea en el tablero: `análisis <área>/<frente>: <qué encontraste en una frase>; propuestas #a, #b`. Ese aviso es el que lee la próxima sesión para seguir la rotación. Comprobación: el aviso existe y cada propuesta está en el Project con `needs-triage`.

## 3b. Investigar antes de construir (todo issue, arte o código)

Nada se construye "a lo loco". Al tomar un issue, antes del primer cambio:

1. **Referentes.** Busca cómo lo resuelven juegos que ya funcionan: notas del vault (`roblox-vault/research/`), gameplays en YouTube de la mecánica concreta (skill `aprender-de-video` o el equivalente de tu agente), y la matriz `docs/referent-features-matrix.md` del repo del juego. Nunca jugándolos por el MCP de escritorio.
2. **Lo que ya existe.** Kits del vault (`roblox-vault/kits/`), módulos de la plantilla, plugins instalados, repos open source con licencia compatible. Si hay un binario o kit que hay que entender por dentro, úsalo con `rea` (ingeniería inversa, solo herramientas y builds propias o con licencia).
3. **Compara y decide.** Dos alternativas reales como mínimo, con qué se pierde en cada una.
4. **Deja constancia** en el issue, como comentario con el encabezado `## Investigación`: fuentes con enlace (comprobado, nunca de memoria), qué se eligió y por qué. Comprobación: el comentario existe antes de la primera PR del issue; el revisor lo pide si falta.

Si el issue ya trae una sección `## Investigación` con pistas, esas son el punto de partida, no el techo. Investigación grande (un frente entero del juego) va con la skill `roblox-analisis-por-frentes` si el agente la tiene; si no, el mismo método en pequeño.

## 4. Arte, mapa, UI a mano, luces o audio

1. Abre la place compartida en Studio (ids en `roblox.places`). Comprobación: el panel de colaboradores en vivo la muestra.
2. Avisa en el tablero la zona que vas a tocar, con el issue (`docs/flujo-arte-y-avisos.md`). Comprobación: el mensaje aparece en `board.ps1 unread` de otra sesión.
3. No edites scripts ahí.

## 5. Código, de punta a punta

Todo en el repo del juego (`roblox.places[].repo`). Sus scripts mandan sobre esta lista si difieren.

1. **Tomar el issue:** `pwsh tools/work.ps1 claim <n>`. Sale con 3 si otro reclamó antes: suelta y avisa. Sale con 2 si el issue no es tuyo ni está marcado `ready-for-agent` en tus áreas: pide que lo asignen, no lo fuerces. Comprobación: la tarjeta queda en "En curso" en el Project (si avisa que falta el permiso: `gh auth refresh -h github.com -s project`).
2. **Rama en worktree:** `git worktree add -b feat/<n>-<tema> <carpeta> origin/develop` (`fix/` para un arreglo). Comprobación: `git branch --show-current` da `feat/<n>-<tema>`.
3. **Copia local de la place, una por juego** (`places/dev.rbxl` del clon principal, gitignored; no dentro del worktree, que se borra al cerrar). Se baja si no existe o si el mundo cambió. Métodos en orden; usa el primero que funcione y anota cuál:
   - **A. Open Cloud.** `GET https://apis.roblox.com/asset-delivery-api/v1/assetId/<place_id>` con una llave de API con el scope `legacy-asset:manage`. Devuelve `{ "location": "<url temporal>" }`; esa URL se baja con `Accept-Encoding: gzip` (`curl --compressed`) a `places/dev.rbxl`. La llave va por variable de entorno, nunca en un archivo ni en pantalla. Comprobación: el archivo existe, pesa más de 0 bytes y empieza con `<roblox`. Con 401 o 403 (llave sin el scope) pasa a C sin insistir.
   - **B. MCP de Studio.** No exporta la place (`save_place` guarda en Roblox). Sirve para probar, no para bajar la copia. `game:GetObjects` de la place tampoco: trae los servicios sin el `Workspace`.
   - **C. MCP de escritorio sobre Studio (respaldo que siempre sirve).** Con la place compartida abierta: menú Archivo, "Descargar una copia" (o "Guardar en archivo como"), escribir la ruta completa de `places/dev.rbxl` en el campo Nombre y Enter. Comprobación: el archivo existe y cambió de hora. Sin MCP de escritorio, pídele a la persona solo ese clic.
4. **Meter tu rama en la copia**, desde tu worktree: `lune run scripts/merge-into-copy <ruta de places/dev.rbxl> places/<rama>.rbxl`. Corre `rojo build` y reemplaza solo los contenedores del proyecto; el mundo de los builders queda intacto. No hace falta Rojo conectado ni ningún clic. Comprobación: imprime `code <contenedor>` por cada uno y `wrote`.
5. **Abrir `places/<rama>.rbxl` en Studio** (nunca la place compartida): Windows `RobloxStudioBeta.exe -task EditFile -localPlaceFile <archivo>`, macOS `open -a RobloxStudio <archivo>`. Comprobación: `list_roblox_studios` del MCP de Studio la muestra.
6. **Probar** con el MCP de Studio (`roblox-studio-mcp`): playtest, consola y el flujo que cambiaste, con entrada real por su herramienta de teclado. Sin DataStore, el juego guarda en memoria. Trampas ya vistas: un ProximityPrompt solo aparece si su objeto está en pantalla (restaura la ventana si estaba minimizada); la cámara que cambies con `execute_luau` vuelve a su estado al terminar la llamada; `InputHoldBegin` desde `execute_luau` no llega al motor. Comprobación: el flujo da lo esperado y la consola no tiene errores nuevos. Deja la tabla de resultados en la PR.
7. **Gate local** del repo del juego, según su `AGENTS.md`. Comprobación por código de salida, no por la última línea.
8. **PR a `develop`** con `Closes #<n>`, qué cambió y cómo se verificó. Si cambia el runtime, ábrela en borrador y márcala lista después del paso 6 (`gh pr ready`). El CI y el automerge hacen el resto, y el Project la pasa a "En revisión" y a "Hecho" solo. Cuando se mergea, avisa en el tablero.
9. **Renovar la copia** cuando el mundo cambió (alguien movió el mapa): repite el paso 3. Tras cambiar código, repite 4 y 5.

## 6. Al cerrar

1. Cierra la Studio de tu copia de prueba (y tu Rojo, si lo levantaste para editar en vivo).
2. Deja el aviso en el tablero: qué quedó hecho, qué sigue.
3. Si la PR ya se mergeó, borra tu worktree y tu rama local.
4. Lo que la sesión aprendió y le sirve a otros (una trampa, una herramienta, un referente, un número medido) va al documento que corresponde (`docs/` del repo o el vault), no solo al chat. Si abre trabajo, va a una tarea con `from-research`, igual que en el paso 3a.

## 7. Prohibido

| Nunca | Por qué |
|---|---|
| Rojo a la place compartida desde otra computadora | Dos Rojo se pisan. Esa conexión es solo de la computadora del juego, sobre `develop` |
| Tu Rojo contra otra cosa que no sea tu copia | Es solo para tu banco de pruebas |
| Editar scripts en Studio | El siguiente sync los borra y no llegan a GitHub |
| Commitear en `develop` o `main` | Todo entra por PR; `main` solo recibe releases |
| Publicar en Roblox o hacer público el juego | Lo decide Victor |
