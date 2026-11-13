---
name: empezar-a-trabajar
description: Ritual de inicio de sesión del estudio. Úsalo cuando la persona diga "vamos a trabajar", "abre todo", "empecemos" o similar, para dejar clones, puesto, tablero, cola y herramientas listos para el flujo oficial (ramas y PR a develop, Studio en vivo para arte).
---

# Empezar a trabajar

Resumen en `AGENTS.md` (sección "Ritual de inicio"). Esta skill lo detalla. Sirve para Claude Code y Codex, en Windows, macOS y Linux, y para cualquier persona del estudio: Leon también programa con su agente.

Qué va en vivo y qué por ramas: `docs/en-vivo-y-ramas.md`. No se copia aquí.

## 1. Clones al día

Para cada clon del estudio (los repos de `github.repos` en `config/ecosistema.json` que existan en la computadora):

```
git -C <clon> switch develop      # solo si está limpio y en develop; otra rama es trabajo de alguien: no se toca
git -C <clon> pull --ff-only
```

Si `pull --ff-only` falla, no se arregla con merge ni reset: se dice y se sigue. Luego:

```
pwsh tools/puesto.ps1 check
```

## 2. Lo que depende de la persona

Cada fila `PERSONA` del check, un permiso de `gh` faltante o un acceso (Drive, Studio, Notion) se le dice **en ese momento**, con el comando exacto, y se sigue con lo demás. Ejemplos:

- Falta el scope de proyectos: `gh auth refresh -h github.com -s project`.
- `puesto.json` o `modo` sin definir: `pwsh tools/puesto.ps1 install`.

Un bloqueo de permisos o un hook no se rodea: se reporta qué acción, para qué y qué hace falta.

## 3. Tablero y cola

```
pwsh tools/board.ps1 unread
pwsh tools/work.ps1 mine
```

La identidad (login, nombre, áreas) sale de `personas` en `config/ecosistema.json`. Cola vacía es normal. Con `modo` `preguntar` o `estricto`, proponle el primer issue a la persona y espera su sí; con `autonomo`, tómalo.

## 4. Abrir según el área del issue

### Arte, mapa, UI hecha a mano o audio dentro de la place

Studio con la place del grupo, en vivo por Team Create (Archivo, Abrir desde Roblox, pestaña del grupo). Los ids salen de `roblox.places` en `config/ecosistema.json`. Antes de tocar una zona compartida: aviso en el tablero (`docs/flujo-arte-y-avisos.md`). Si trabajas por el MCP de Studio, el candado pide un issue empezado.

### Código

```
git switch develop
git pull --ff-only
pwsh tools/work.ps1 claim <n>          # sale con 3 si otro reclamó antes: suelta
git switch -c feat/<n>-<slug>          # fix/<n>-<slug> para un arreglo
```

Si ya hay otra sesión en el clon, worktree propio en vez de cambiar de rama:

```
git worktree add -b feat/<n>-<slug> <carpeta> origin/develop
```

Para probar la rama en Studio (repo de juego, con el candado `.studio.lock` de la plantilla, ver `docs/multi-agent.md` de `roblox-game-template`):

1. `rojo build default.project.json -o places/dev.rbxl`
2. Abrir `places/dev.rbxl` en Studio (nunca la place del grupo).
3. `rojo serve --port <libre>` y Connect en el plugin de Rojo.

Al final: gate local del repo, PR a `develop` con `Closes #<n>`, mensaje en el tablero, CI y automerge. No se mergea a mano ni se borra la rama a mano: lo hace el CI.

## 5. Prohibido, y por qué

| Prohibido | Por qué |
|---|---|
| Conectar Rojo a la place del grupo | Dos Rojo contra la misma place se pisan. Solo conecta la computadora del dueño del código |
| Editar scripts en Studio | Rojo los pisa en la siguiente sincronización y el cambio nunca llega a GitHub |
| Commitear o editar código en `develop` o `main` | Todo entra por PR con CI. `main` solo recibe releases. La guardia de rama lo frena: deniega con `estricto` o `autonomo`, pregunta con `preguntar`, y da el comando para crear la rama |

## 6. Verificar el ritual

`pwsh tools/puesto.ps1 check` sin filas `FALLA`, `git branch --show-current` en una rama `feat/` o `fix/` antes de editar código, y el issue asignado a la persona.
