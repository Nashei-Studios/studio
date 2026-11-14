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

1. **Cerrar lo abierto.** drain-for-loot PR #113 (arranque temprano, `Refs #89`): medir en la copia de prueba contra los 4,85 s de referencia con el probe `[BOOTTIMING]`, comentar el número en #89, sacar de borrador y mergear. Limpiar su worktree.
2. **#103**: reaparecer cuando el mar no carga y tratar como muerto a un humanoide sin raíz.
3. **#87**: prueba de carga con varios clientes (lobby de 20, partidas de 4) en Studio.
4. **#33**: ajuste de streaming, medido antes y después.
5. **#37 y #36**: unificar el `DataService` heredado con el de la plantilla y tiparlo.
6. **Ola 2**: #96 monetización y la parte de código de #95 jefes, cada una con su investigación (`## Investigación` en el issue) antes del primer cambio.
7. **Seguridad del puesto**: los cuatro hallazgos sobre los hooks globales (scripts del clon de `studio` que corren en todas las sesiones, candado que falla abierto, guardia de rama solo en Edit y Write, texto del tablero que entra al contexto) van a un issue de `studio` y se resuelven por PR.

### Leon y su agente (mundo, arte, UI, audio)

1. **Puesto al día**: correr el prompt de studio#1 (comentario 6866076180). Incluye `gh auth refresh -h github.com -s project` para que su agente mueva tarjetas del Project.
2. **#93**: primera capa con los modelos de botín, con las etiquetas `CarryObject`, `CarryDeposit` y `UpgradeStation` que lee el código.
3. **#34**: adelgazar `StarterGui` (1.989 instancias, 1.664 en `Panels`): es la mayor parte del tiempo de entrada que queda.
4. **#92 y #94**: estilo y paleta de la primera capa por escrito; UI móvil primero sobre su UI.
5. **#38**: assets en su cuenta (99 imágenes, 22 sonidos). Se suben con `tools/kits.ps1 push` y solo con su sí explícito.
6. **#97**: miniaturas, video y página del juego (ola 2).

### Nande (beta tester y líder, crecimiento)

Juega la versión privada cuando Victor la publique y deja notas de voz cortas; van a Notion.

## Lo que solo puede hacer Victor

Ningún agente lo hace ni lo rodea.

- Publicar en Roblox, hacer público el juego y gastar Robux.
- Llaves: scope `legacy-asset:manage` en la llave de Roblox (hoy da 403), `TEMPLATE_SYNC_TOKEN`, llave de monetización, llave de Open Cloud (template#241).
- Medir en un teléfono real: #89, #29 y #90 necesitan una versión publicada.

## Cuándo se actualiza esta página

Cuando un punto se cierra o cambia el orden, en la misma PR que lo cierra. Si esta página y el Project no coinciden, manda el Project y se corrige esta página.
