# Cómo trabajamos

Esta es la página que se lee primero. Si solo lees una, que sea esta.

## En tres frases

1. **El trabajo de todos se ve en la place compartida del juego.** Es el mismo Studio para los tres, en vivo: lo que hace uno, el otro lo ve al instante. Ahí van el mapa, los modelos, la interfaz hecha a mano, las luces y el audio.
2. **Tu código lo pruebas en tu banco de pruebas**: una copia tuya de esa place, en tu computadora. Nadie más se conecta a ella, así que no puedes romper nada de nadie.
3. **Tu código llega a la place compartida por GitHub**: lo subes en una rama, se revisa solo, entra a `develop`, y la computadora que mantiene la place compartida lo lleva ahí.

Tu agente hace todos los pasos técnicos. Tú dices "vamos a trabajar".

## El flujo

```mermaid
flowchart TD
  P[Tú: "vamos a trabajar"] --> A[Tu agente actualiza, revisa tu puesto y lee el tablero]
  A --> T{Qué tarea tienes}
  T -->|Arte, mapa, UI a mano, luces, audio| S[Abre la place compartida y avisa en el tablero la zona que vas a tocar]
  S --> V[Todos ven tu trabajo en vivo]
  T -->|Código| R[Crea tu rama feat/n-tema y renueva tu copia local: places/dev.rbxl]
  R --> B[Mete tu rama en la copia con merge-into-copy y la abre en Studio]
  B --> X[Prueba en Studio y corre las revisiones]
  X --> PR[Abre la PR a develop]
  PR --> D[Se mergea sola al pasar las revisiones]
  D --> C[La computadora de Rojo del juego lleva develop a la place compartida]
  C --> V
  D --> REL[Cuando se junta trabajo: release a main]
  REL --> PUB[Publicar en Roblox y hacer público el juego: lo decide Victor]
```

## Las tres piezas

| Pieza | Qué es | Quién la toca |
|---|---|---|
| **Place compartida** | El Studio del juego en Team Create. Los ids están en `roblox.places` de `config/ecosistema.json`. | Todos, al mismo tiempo, solo arte y mundo. Código: nunca. |
| **Tu banco de pruebas** | Un archivo `places/dev.rbxl` en tu copia del repo del juego (no se sube a GitHub). Es el mundo real, copiado. Sin guardado en servidor: el juego guarda en memoria. | Solo tú y tu agente. |
| **GitHub (`develop`)** | Donde vive el código. Cada tarea es una rama que entra por PR. | Todos, por PR. |

Rojo es el programa que lleva el código de GitHub a Studio. No tienes que usarlo: lo maneja tu agente. Hay dos usos, que nunca se mezclan:

- El de la place compartida lo corre **una sola computadora** (la del juego, con `tools/place-sync.ps1` del repo del juego). Sirve siempre `develop`, nunca la rama de nadie.
- El tuyo no necesita conexión: tu agente corre `lune run scripts/merge-into-copy`, que construye **tu rama** con Rojo y la mete en **tu copia** sin conectar nada ni dar clics.

## Qué hace tu agente por ti

Cuando dices "vamos a trabajar":

- Actualiza tus carpetas, revisa que tu computador esté listo, lee el tablero y te muestra tus tareas.
- Si tu tarea es de **arte**: abre la place compartida y avisa en el tablero la zona que vas a tocar.
- Si es de **código**: toma el issue, crea tu rama en una carpeta propia, baja o renueva tu copia de la place, mete tu rama en ella con `merge-into-copy` y la abre en Studio. Después prueba, corre las revisiones, abre la PR y avisa cuando se mergea.
- Si ve un paso que solo puedes hacer tú (iniciar sesión, un permiso, un clic que no puede dar), te dice cuál es y por qué, y sigue con lo demás.
- Al cerrar: cierra la copia de prueba y deja el aviso en el tablero.

Los pasos exactos están en la skill [`empezar-a-trabajar`](../.claude/skills/empezar-a-trabajar/SKILL.md).

## Qué no se hace nunca

| Nunca | Por qué |
|---|---|
| Conectar Rojo a la place compartida desde otra computadora | Dos Rojo contra la misma place se pisan. |
| Editar scripts en Studio | El siguiente sync los borra y no llegan a GitHub. |
| Commitear en `develop` o `main` | Todo entra por PR. `main` solo recibe releases. |
| Conectar tu Rojo a la place compartida | Tu Rojo es solo para tu copia. |
| Publicar en Roblox o hacer público el juego | Lo decide Victor. |

## Más detalle

- [Plan vigente](plan-vigente.md): el comando para arrancar una sesión y el orden de trabajo de cada persona.
- [En vivo y por ramas](en-vivo-y-ramas.md): qué se ve en vivo y qué no.
- [Arte y avisos](flujo-arte-y-avisos.md): cómo se avisa una zona y se entrega un asset.
- [Primera vez](primera-vez.md): dejar tu computador listo.
