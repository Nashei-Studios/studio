# Mapa del ecosistema

Qué vive dónde. La regla: **GitHub es la fuente de verdad, Notion la muestra, Drive guarda lo pesado.** Nada importante vive solo en el computador de una persona.

```mermaid
flowchart TD
  subgraph GitHub[GitHub: Nashei-Studios, fuente de verdad]
    S[studio: reglas, Discussions, Agent Board]
    T[roblox-game-template: la plantilla]
    V[roblox-vault: investigación y decisiones]
    G[drain-for-loot y los juegos siguientes]
    P[Project: tablero de todo el estudio]
  end
  subgraph Notion[Notion: vista para leer]
    N1[Portada del estudio]
    N2[Base Juegos]
    N3[Base Tareas, espejo de los Issues]
  end
  subgraph Drive[Google Drive: lo pesado]
    D1[kits y assets]
    D2[videos y capturas]
    D3[audio]
  end
  subgraph Roblox
    R1[Comunidad del estudio]
    R2[Experiencias]
    R3[Team Create: arte y mapa]
  end
  T -->|se estampa| G
  V -->|referentes y barras| G
  G -->|Issues| P
  G -->|espejo automático| N3
  V -->|una nota por kit, con su ruta| D1
  G -->|Rojo| R3
  R3 --> R2
```

## Qué va en cada lugar

| Cosa | Dónde | Por qué |
|---|---|---|
| Código de un juego | Repo del juego | Historial, revisión por PR, pruebas automáticas |
| Tareas | Issues del repo del juego | Una tarea, un dueño, se cierra con la PR |
| Ideas, dudas, gustos | Discussions (`studio` para todo el estudio, el repo del juego para ese juego) | No todo es una tarea |
| Avisos entre personas y agentes | Agent Board (issue fijado) | Un solo buzón; la mención dispara la notificación |
| Estado de todo | Project de la organización | Un solo tablero |
| Investigación, referentes, decisiones | `roblox-vault` | Se lee antes de opinar sobre un juego |
| Sistemas reutilizables | `roblox-game-template` | Lo que un juego resuelve vuelve a la plantilla |
| Arte y mapa | Studio con Team Create, modelos como Package | No se versiona bien en Git |
| Kits, modelos, texturas, audio, video (archivos grandes) | Google Drive del estudio | Git no sirve para gigas; el vault guarda la nota y la ruta |
| Vista cómoda para leer | Notion | Para quien no vive en GitHub |

## Lo pesado: Drive

Hoy la biblioteca de kits está en el computador de Victor (`D:\Victor\Roblox\kits`, con su `INDEX.json`). Para que el equipo la tenga:

1. Carpeta compartida `Nashei Studios` en Google Drive con `kits/`, `video/`, `audio/` y `capturas/`.
2. La estructura de `kits/` replica el `INDEX.json`: una carpeta por kit, mismo nombre que la nota en `roblox-vault/kits/`.
3. Cada nota de kit en el vault lleva la ruta de Drive, la licencia y el hash del archivo.
4. Se sincroniza con `rclone` (libre) desde el computador que tiene la biblioteca. Nadie sube archivos sueltos sin su nota.

Estado: **pendiente**. Falta que Victor cree la carpeta compartida y autorice `rclone` una vez. Issue en este repo.

## Automatizaciones

| Qué | Cómo | Estado |
|---|---|---|
| Merge al verde, cierre de issues, borrado de ramas | Workflows de la plantilla (`ci.yml`, automerge) | Funciona en los repos estampados |
| Release con changelog | `release.yml` de la plantilla | Funciona |
| Issues hacia Notion | `notion-mirror.yml` de la plantilla | Apagado hasta tener el token y la base (ver [notion.md](notion.md)) |
| Aviso de mensajes nuevos al abrir Claude Code | Hooks de `tools/board-hooks/` | Lo activa cada persona en su copia |
| Radar de mercado diario | Colector del vault (corre en el computador de Victor) | Funciona |

## Skills y herramientas de IA compartidas

Las skills de Roblox que usa Victor (análisis por frentes, UI, monetización, publicación, Studio por MCP) viven hoy en su configuración personal. Para que los tres tengan las mismas, el plan es publicarlas como un marketplace de plugins de Claude Code en un repo de esta organización, que cada persona instala con un comando. Estado: **pendiente**, issue en este repo.

## El mismo sistema en todos los repos

| Pieza | Cómo queda igual en todos | Estado |
|---|---|---|
| Ramas | `develop` por defecto con squash; `main` solo recibe releases | Plantado en `drain-for-loot`, `roblox-game-template` y `plus-one-mining` |
| CI, automerge y release | Workflows de la plantilla; cada juego los hereda al estamparse | Funciona; Actions ya puede crear PR en toda la organización |
| Project | Uno global y uno por repo, con el mismo ciclo (Backlog, Listo, En curso, En revisión, Verificación, Hecho), campos (Prioridad, Carril, Tamaño, Puntos, Iteración, Inicio, Objetivo) y diez vistas | Plantado en los cuatro con `plant-project.mjs` |
| Equipos | `todos` (escritura en todos los repos), `dev`, `arte` | Creados |
| Tablero de agentes | Issue fijado más `tools/board` y sus hooks | En `studio` y `drain-for-loot` |
| Etiquetas | `owner:*`, `agent`, `handoff`, `art`, `hold`, `board`, `acuerdo` | En `drain-for-loot`; falta copiarlas al resto |

### Protección de `main`: qué se puede y qué no

GitHub no permite reglas de protección de ramas ni rulesets en repos **privados** de una organización gratis. Se probó el 2026-11-11: la API responde que hay que pagar o hacer público el repo. En el único repo público (`.github`) la regla sí quedó activa.

Lo que protege `main` en los repos privados:

- Nadie trabaja en `main`: la rama por defecto es `develop` y `main` solo la toca el workflow de release.
- Todo entra por PR con CI; el merge lo hace el automerge, no una persona.
- CODEOWNERS pide la revisión del dueño de cada carpeta.

Lo que **no** se puede garantizar: que alguien con permiso de escritura no empuje directo a `main`. Opciones: dejarlo así (recomendado mientras son tres), o hacer públicos los repos que no tengan nada privado, donde la regla sí aplica. Los tres miembros son hoy Owner de la organización; con ese rol cualquier regla se puede saltar.

### Pasos que solo existen en la interfaz

En cada Project, una vez: columna del tablero por Status (y por Carril en "Por carril"), fechas del roadmap con Inicio y Objetivo, límite de trabajo en "En curso", y los workflows integrados (ítem agregado a Backlog, PR enlazada a En revisión, cerrado a Hecho, auto-archivo, auto-agregar issues del repo).
