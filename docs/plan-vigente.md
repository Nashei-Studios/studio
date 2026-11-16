# Plan vigente

Qué hacer al abrir una sesión, en qué orden y qué queda para cada persona. El cómo está en [cómo trabajamos](como-trabajamos.md); el estado de cada tarea, en el Project del tablero. Esta página solo ordena y apunta.

## Arranque de una sesión

Una línea basta. Desde la carpeta de `studio` o desde cualquier repo de Nashei:

```text
/goal Lee docs/plan-vigente.md de Nashei-Studios/studio y trabaja el plan en orden hasta dejar cada punto verificado
```

El agente hace lo de la skill [`empezar-a-trabajar`](../.claude/skills/empezar-a-trabajar/SKILL.md): actualiza los repos, corre `tools/puesto.ps1 check`, lee el tablero (studio#1 y el hilo del juego), hace el análisis activo de un frente del área de su persona (paso 3a: hasta 3 tareas nuevas con `from-research` y `needs-triage`, sin cron) y toma el primer issue de su persona con `tools/work.ps1 claim N`, que mueve la tarjeta a "En curso".

La investigación de fondo del estudio vive en la épica studio#109 y sus documentos en [`docs/investigacion/`](investigacion/). Las tareas que salen de ahí entran al Project con `needs-triage` y cada dueño las valida antes de que entren a su orden de trabajo.

## Qué Studio es cuál

Pueden estar abiertos dos Studios a la vez y no es un error: cada uno tiene un trabajo.

| Studio | Qué abre | Para qué | Quién escribe código ahí |
|---|---|---|---|
| **Place compartida** | La place del grupo en Team Create (ids en `roblox.places` de `config/ecosistema.json`) | Mapa, modelos, UI hecha a mano, luces, audio. Todos lo ven en vivo | Nadie a mano. Recibe `develop` sola, por `tools/place-sync.ps1` del juego, desde una sola computadora |
| **Copia de prueba** | `places/<rama>.rbxl` de tu clon del juego | Probar tu rama con el mundo real copiado, sin tocar a nadie | Tu agente, con `lune run scripts/merge-into-copy` |

La copia se arma sin Rojo conectado y sin clics: `merge-into-copy` toma `places/dev.rbxl`, mete el código de tu rama y escribe `places/<rama>.rbxl`. Se abre con `RobloxStudioBeta.exe -task EditFile -localPlaceFile <archivo>` (macOS: `open -a RobloxStudio <archivo>`) y se prueba con el MCP de Studio. Al terminar, esa copia se cierra; la compartida queda abierta.

Lo que **no** se usa: VS Code Live Share, un Baseplate vacío como banco de pruebas, ni un segundo Rojo conectado a la place compartida.

## Orden de trabajo

Primero se cierra lo que está a medio camino, después lo nuevo. Dentro de cada bloque, de arriba hacia abajo.

### Victor y su agente (código, infra, economía)

Hecho al 14-11:
- drain-for-loot #113, #103 y #36.
- Seguridad del puesto (studio#108, más las rondas 8 a 10 de la guardia de rama en #159).
- Investigación de la ola 2: dfl #151, #160, #166 y #167, studio #157 y #158.
- Dependabot de studio, #28 y #29.

1. **La espera del tablero no muere (studio#161, ley de Victor): hecho el 14-11.**
   - `tools/board-watch.ps1` (ADR 0007): una tarea oculta del sistema lee el tablero cada 2 minutos y retoma con la meta la sesión que murió o quedó quieta.
   - Toda sesión con `/goal` corre `arm` y usa `board-watch.ps1 wait` como su espera (skill `empezar-a-trabajar`, paso 3).
   - En el equipo de Victor la tarea ya está registrada. A los demás les llega con el release del lunes y `tools/puesto.ps1 install`.
2. **La sesión de Leon tarda y gasta de más (studio#165, `needs-team`).** Su agente mide el piso de contexto de su equipo; Leon y Victor responden las opciones A a E (carril corto, análisis diario, modelo por tipo de trabajo, MCP por tarea).
3. **Cerrar lo abierto: hecho el 15-11.** studio#160 está cerrado y las dos Dependabot (drain-for-loot#1 y la #180 de la plantilla) están fusionadas.
4. **Lo que no depende de una decisión:**
   - **drain-for-loot: hecho el 15-11.** #141 y #72 arreglados (PR #203 y #204); #77 y #59 cerrados con la prueba de que ya habían entrado.
   - **studio: hecho el 15-11.** #85 cerrado con la prueba (`puesto.ps1 check` da PASA en los cinco clones) y #91 arreglado (PR #174): la instalación en macOS y Windows esperaba un inicio de sesión de Google y ahora termina en 1 y 3 minutos.
   - **plantilla: hecho el 15-11.** #269 (PR #270), #242 (PR #271), #233 (PR #272), #201 (PR #273) y #202 con #203 (PR #274). Las mediciones de la página de presupuesto de carga quedan en `TBD` hasta la prueba privada.

   Regla de Victor del 15-11: las features del juego van antes que esta deuda. Mientras falten votos, se construyen en ramas en borrador, en el orden del backlog del juego (`docs/investigacion/embudo-2026-11-15.md` de drain-for-loot, ola 2). El orden por día hasta el privado del 20-11 está en `docs/planning/plan-al-20-11.md` de drain-for-loot.

   **Features en borrador al 16-11 (drain-for-loot):**
   - Cadena de botín, apilada en este orden: PR #175 (#131), #176 (#132), #208 (#183, #187) y #223 (#196). Probadas en copia local: etiqueta con rareza y precio, recogida, cambio con la mochila llena, gema y aviso por hallazgo nuevo, HUD de capa que sube al drenar y primer botín raro garantizado.
   - PR #221 (#200): paso de venta en el embudo. Con pruebas; el evento real de analítica se ve recién en el privado.
   - Jefe: PR #222 (#152, lógica del Kraken con pruebas) y #225 (#153, la vida se publica solo cuando cambia el porcentaje: 25 escrituras donde antes había 150). Las dos probadas en copia.
   - Premios: PR #226 (#224), el adaptador que lleva los premios de la plantilla al saldo que el jugador ve. Es el plan B de #37 y se borra cuando #37 se decida.
   - En construcción: #194, #195, #186 y #193.
   - Sin probar: el premio por completar la capa de #208, los golpes del Kraken contra el jugador, la compra de prueba de #180 (#156; faltan los ids de producto) y el adaptador de #226 en copia.
   - Ninguna pasa de borrador a lista sin el segundo voto de la decisión 7. El resultado de cada prueba está en un comentario de su PR.
5. **Frentes de Victor (studio#162, dentro de la épica #109):**
   - Son los reels R-115 a R-123 y la historia R-124 (producto que se mejora solo con métricas y errores).
   - Por cada uno: el contenido real con `aprender-de-video`, las afirmaciones verificadas en fuentes primarias y la aplicación a Drain for Loot.
   - Sale una propuesta `needs-team` por frente, explicada a Victor y a Leon.
   - Trabajadores Sonnet, como máximo 3 a la vez, midiendo antes la memoria libre.
   - **Hecho el 15-11:** R-115 a R-133 verificados en el issue y con una nota por reel en el vault (`research/sources/reels/`). #173 sigue abierto solo por los reels anteriores a R-115.
6. **Decisiones `needs-team` (publicadas el 14-11 en studio#1; esperan la respuesta de Leon y de Victor):**
   - **#37:** opciones 1 + 2. Va primero #156, un solo `ProcessReceipt`.
   - **La versión privada en una experiencia aparte:** destraba #87, #33 y #89.
   - **Las 45 tareas de los dos triages.**

   - **Sumadas después:** studio#165, studio#168, studio#171 y las features de la semana.

   Al 15-11 Victor votó la opción recomendada en todas. Falta un voto más, de Leon o de Nande. Cuando llegue, se ejecuta lo aprobado en el orden del triage. El estado completo del equipo, con quién lleva qué, está en `docs/planning/estado-del-equipo-2026-11-15.md` de drain-for-loot y en el Drive.
7. **Releases del lunes 16-11: hecho.** studio v0.7.0 y plantilla v0.8.0. `tools/puesto.ps1 install` en el equipo de Victor da PASA 39, FALLA 0; el aviso a Leon está en studio#1. El release se lanza desde `main` (`gh workflow run release.yml` sin `--ref`): lanzado desde `develop`, el push de la rama de release da 403.

### Leon y su agente (mundo, arte, UI, audio)

1. **Puesto al día**: correr el prompt de studio#1 (comentario 6866076180). Incluye `gh auth refresh -h github.com -s project` para que su agente mueva tarjetas del Project.
2. **#93**: primera capa con los modelos de botín, con las etiquetas `CarryObject`, `CarryDeposit` y `UpgradeStation` que lee el código.
3. **#34**: adelgazar `StarterGui` (1.989 instancias, 1.664 en `Panels`): es la mayor parte del tiempo de entrada que queda.
4. **#92 y #94**: estilo y paleta de la primera capa por escrito; UI móvil primero sobre su UI.
5. **#38**: assets en su cuenta (99 imágenes, 22 sonidos). Se suben con `tools/kits.ps1 push` y solo con su sí explícito.
6. **#97**: miniaturas, video y página del juego (ola 2).

### Nande (beta tester y líder, crecimiento)

Juega la versión privada cuando el equipo decida publicarla, y deja notas de voz cortas; van a Notion.

## Lo que decide el equipo y ejecuta Victor

Ninguna decisión la toma una sola persona: va con la etiqueta `needs-team`, explicada entera a Victor y a Leon (al otro por el tablero), y se registra cuando responden al menos dos (skill `empezar-a-trabajar`, paso 3c). Lo que sigue lo ejecuta solo Victor, después de esa decisión; ningún agente lo hace ni lo rodea.

- Publicar en Roblox, hacer público el juego y gastar Robux.
- Llaves: scope `legacy-asset:manage` en la llave de Roblox (hoy da 403), `TEMPLATE_SYNC_TOKEN`, llave de monetización, llave de Open Cloud (template#241).
- Medir en un teléfono real: #89, #29 y #90 necesitan una versión publicada.

## Cuándo se actualiza esta página

Cuando un punto se cierra o cambia el orden, en la misma PR que lo cierra. Si esta página y el Project no coinciden, manda el Project y se corrige esta página.
