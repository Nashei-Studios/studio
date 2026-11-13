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

1. **Tomar el issue:** `pwsh tools/work.ps1 claim <n>`. Sale con 3 si otro reclamó antes: suelta y avisa.
2. **Rama en worktree:** `git worktree add -b feat/<n>-<tema> <carpeta> origin/develop` (`fix/` para un arreglo). Comprobación: `git branch --show-current` da `feat/<n>-<tema>`.
3. **Copia local de la place** (`places/dev.rbxl` dentro del worktree, gitignored). Se baja si no existe o si el mundo cambió desde que se bajó. Métodos en orden; usa el primero que funcione y anota cuál:
   - **A. Open Cloud.** `GET https://apis.roblox.com/asset-delivery-api/v1/assetId/<place_id>` con una llave de API con el scope `legacy-asset:manage`. Devuelve `{ "location": "<url temporal>" }`; esa URL se baja con `Accept-Encoding: gzip` (`curl --compressed`) a `places/dev.rbxl`. Sirve `.../version/<n>` para una versión concreta. La llave va por variable de entorno, nunca en un archivo ni en pantalla. Comprobación: el archivo existe, pesa más de 0 bytes y empieza con `<roblox` (xml) o `<roblox!` (binario). Si la respuesta es 401 o 403 (llave sin el scope, o sin acceso a la place), pasa a B sin insistir.
   - **B. MCP de Studio.** Hoy no trae una herramienta para descargar la place: `save_place` guarda de vuelta en Roblox, no exporta. No sirve para bajar la copia; úsalo después, para probar.
   - **C. MCP de escritorio sobre Studio (respaldo que siempre sirve).** Con la place compartida abierta en Studio: menú Archivo, "Guardar en archivo como" (en algunas versiones, "Descargar una copia"), elegir `places/dev.rbxl` del worktree y confirmar. Comprobación: el archivo existe y cambió de hora. Sin MCP de escritorio, pídele a la persona solo esto: "En Studio, con la place del grupo abierta, Archivo, Guardar en archivo como, y guárdala en <ruta de dev.rbxl>. Es un solo clic y deja tu banco de pruebas con el mundo real". Es la única razón por la que hace falta: Roblox no deja a un agente descargar la place sin esa llave o sin la ventana de Studio.
4. **Levantar tu Rojo** sirviendo la rama del worktree, en un puerto libre que descubres tú (no uno fijo): `rojo serve --port <libre>`. Comprobación: la salida dice en qué puerto escucha. Guarda el proceso para apagarlo al cierre.
5. **Abrir la copia en Studio:** abre `places/dev.rbxl` (nunca la place compartida) y conecta: en el aviso de Rojo, clic en "Connect" (MCP de escritorio). Comprobación: el plugin de Rojo muestra "Connected" y el puerto es el tuyo. Sin MCP de escritorio, la persona hace ese único clic.
6. **Probar** con el MCP de Studio (`roblox-studio-mcp`): playtest, consola y el flujo que cambiaste. Sin DataStore, el juego guarda en memoria. Comprobación: consola sin errores nuevos.
7. **Gate local** del repo del juego, según su `AGENTS.md`. Comprobación por código de salida, no por la última línea.
8. **PR a `develop`** con `Closes #<n>`, qué cambió y cómo se verificó. El CI y el automerge hacen el resto. Cuando se mergea, avisa en el tablero.
9. **Renovar la copia** cuando el mundo cambió (alguien movió el mapa): repite el paso 3.

## 6. Al cerrar

1. Apaga tu Rojo (el proceso del paso 4) y cierra la copia en Studio.
2. Deja el aviso en el tablero: qué quedó hecho, qué sigue.
3. Si la PR ya se mergeó, borra tu worktree y tu rama local.

## 7. Prohibido

| Nunca | Por qué |
|---|---|
| Rojo a la place compartida desde otra computadora | Dos Rojo se pisan. Esa conexión es solo de la computadora del juego, sobre `develop` |
| Tu Rojo contra otra cosa que no sea tu copia | Es solo para tu banco de pruebas |
| Editar scripts en Studio | El siguiente sync los borra y no llegan a GitHub |
| Commitear en `develop` o `main` | Todo entra por PR; `main` solo recibe releases |
| Publicar en Roblox o hacer público el juego | Lo decide Victor |
