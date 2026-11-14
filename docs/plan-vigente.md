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

1. **La espera del tablero no muere (studio#161, ley de Victor).**
   - Va primero, porque sostiene todo lo demás: con un `/goal` activo, el aviso de que alguien respondió en el tablero sobrevive a la falta de memoria, a los cortes de sesión, al límite de 5 h y a la noche.
   - Lleva investigación con al menos dos opciones, un ADR y una prueba que mata la sesión y comprueba que el aviso igual llega.
   - Mientras no exista, el tablero se revisa a mano en cada turno.
2. **Cerrar lo abierto:**
   - **studio#160:** ronda 11 de la guardia de rama, en la rama `fix/160-guard-round11`. Mergear con el CI en verde y limpiar su worktree.
   - **Dependabot pendientes:**
     - drain-for-loot#1 apunta a `main`: hay que cerrarla y dejar que Dependabot la rehaga sobre `develop`.
     - La #180 de la plantilla tiene el mirror de Notion en rojo: revisar su registro.
3. **Lo que no depende de una decisión:**
   - **drain-for-loot:**
     - #141: el build pisa la copia `places/dev.rbxl`.
     - #72: PumpRules.
     - #77 y #59: avisos viejos de `template-sync`. Si ya entraron, se cierran con la prueba.
   - **studio:**
     - #85: `Test-AgentLoopClone`.
     - #91: el install-smoke se pasa del tiempo y gasta minutos.
   - **plantilla:**
     - #242: ruta de pwsh en place-sync.
     - #233: pruebas de PowerShell en cada PR.
     - #201 a #203: gate de rendimiento, presupuesto de carga y la lista de la prueba privada. Preparan #87 y #89 sin publicar.
4. **Frentes de Victor (studio#162, dentro de la épica #109):**
   - Son los reels R-115 a R-123 y la historia R-124 (producto que se mejora solo con métricas y errores).
   - Por cada uno: el contenido real con `aprender-de-video`, las afirmaciones verificadas en fuentes primarias y la aplicación a Drain for Loot.
   - Sale una propuesta `needs-team` por frente, explicada a Victor y a Leon.
   - Trabajadores Sonnet, como máximo 3 a la vez, midiendo antes la memoria libre.
5. **Decisiones `needs-team` (publicadas el 14-11 en studio#1; esperan la respuesta de Leon y de Victor):**
   - **#37:** opciones 1 + 2. Va primero #156, un solo `ProcessReceipt`.
   - **La versión privada en una experiencia aparte:** destraba #87, #33 y #89.
   - **Las 45 tareas de los dos triages.**

   Cuando respondan los dos, se ejecuta lo aprobado en el orden del triage.
6. **Releases del lunes 16-11** (studio y plantilla). Después, `tools/puesto.ps1 install` en el equipo de Victor y un aviso a Leon para que corra `install` tras su `pull`.

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
