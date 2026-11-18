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

8. **Órdenes de Victor del 16-11 (en curso).** Una sesión que retoma sigue esta cola en orden y marca cada línea al cerrarla:
   - [ ] **Candidata a primera versión privada.** La rama `integ/drafts-16-11` de drain-for-loot fusiona todos los borradores y está jugada entera en copia. Falta sumarle las correcciones de las PR #232 y #233 y la #190, volver a correr el gate y dejar el archivo de place listo. Publicar lo hace Victor, con el paso a paso de `docs/planning/publicar-privado.md` de drain-for-loot (por escribir, verificado contra la documentación de Roblox). Después Nande la juega y de sus notas salen tareas.
   - [ ] **Menú de propuestas para Leon.** Alrededor de 40 propuestas de arte, mundo, UI y audio sacadas de lo ya investigado (embudo, fichas de referentes, auditorías, issues). Cada una como issue con `from-research` y `needs-triage`, más un índice en una sola página con qué cambia, qué aporta y sí o no, para que Leon acepte en bloque, itere o descarte. También tareas para Nande y Victor.
   - [ ] **Sistema que escala (GitHub, Drive, Notion).** Un documento con datos reales: qué vive dónde, minutos de Actions por repo (al 16-11 los privados llevan 896 de 2.000; 752 son de drain-for-loot antes de pasar su gate al runner propio), qué repos conviene dejar públicos o privados, y los pasos. Cambiar la visibilidad de un repo es decisión del equipo: se propone, no se aplica. Lo reversible sí se aplica.
   - [ ] **Notion, opción A (studio#181).** El espejo deja de crear filas por PR y espeja solo issues; las filas de PR se archivan. Se mide cuántos bloques quedan libres.
   - [ ] **Economía.** Análisis de la curva de ingreso contra los premios (`docs/investigacion/economia-curva-2026-11-16.md` de drain-for-loot) y propuesta de valores.
   - [ ] **Herramientas de los reels R-134 a R-141.** Auditar e instalar lo recomendado: rembg, Upscayl y la skill `roblox-simulator-economy`.
   - **Estado al cierre de la sesión del 16-11 (noche):** los cinco primeros puntos de esta cola están hechos (candidata, menú con 58 issues #239 a #296, `docs/sistema-que-escala.md`, Notion solo con issues y economía con valores aplicados). Falta el de herramientas de reels.

9. **Órdenes de Victor del 16-11 por la noche. La sesión siguiente parte aquí.**
   - **Decisión de Victor:** desde hoy su voto basta para aceptar features y decisiones del equipo. Todo lo recomendado quedó aceptado.
   - [x] **Las 18 features entraron a `develop`** de drain-for-loot en la PR #299 (gate en verde, 1143 tests). Los 18 borradores se cerraron y sus ramas se borraron. La guía `docs/planning/publicar-privado.md` está en `develop` (PR #298).
   - [ ] **Primera versión privada, martes 17-11.** Hecho: release v0.3.0 de drain-for-loot con las 18 features; `develop` jugado en la copia `places/rc-17-11.rbxl` sin errores de script (hitos del mar pagan 20K, 1,5M y 30M; `leaderstats` y aviso de jefe responden). Falta: que Victor publique con `docs/planning/publicar-privado.md` y que Nande haga el segundo playtest con el guion de 15 pasos de `docs/planning/backlog-1000/jugador-y-crecimiento.md`.
   - [x] **Backlog de 1.105 features** en `docs/planning/backlog-1000/` de drain-for-loot (365 de arte, 388 de sistemas, 352 de jugador y 30 ideas de juegos), con índice `README.md`. Las 20 primeras de cada persona están en drain-for-loot#306 (Leon), #307 (Victor) y #309 (Nande). Sigue: cada quien toma las suyas en orden; cuando queden menos de 5, se sacan las 20 siguientes.
   - [x] **Material del 16-11 integrado.** Los 27 archivos están en `D:\Victor\Roblox\kits` con nota por kit en roblox-vault (`develop`, PR #309) y copia en el Drive (`10-kits/2026-11-16-material-victor`, con el resumen). Skills instaladas: `roblox-thumbnail`, `roblox-sfx`, `lihfolk-stud-voxel`, `roblox-vfx`, `roblox-3d-model`, `roblox-map`, `roblox-texture-gen`, `roblox-animation`, `folk-stud-ui` y el plugin `lihfolk` 2.5.0. La copia local de iCloud quedó solo en la nube. Falta: auditar el Emote Menu (asset 127426970365786) en un place de prueba, revisar el MCP del Magnus Vault antes de habilitarlo y plantar `.githooks` en el clon del vault (hoy la guardia no deja empujar desde ahí; la PR #307 entró a `main` por eso mismo y se trajo a `develop`).
   - [ ] **CI, minutos y visibilidad.** Hecho: `docs/plan-ci-y-visibilidad.md` y ADR 0009 (PR #190); rebase merge apagado en todos los repos; los tres `legacy-*` archivados el 16-11. Falta, en este orden: job semanal de poda de ramas en el runner `victor-pc`; dejar el lint de roblox-vault solo en PR y `develop`; comprobar que cada `ci.yml` lee la variable `CI_RUNNER` (fallback a `ubuntu-latest`); avisar al equipo y exigir verificación en dos pasos en la organización; cerrar studio#187 y studio#168.
   - [x] **Ramas: solo `main` y `develop`.** El 16-11 las 12 ramas con trabajo fuera de la principal se guardaron como etiqueta `archive/<rama>` en su mismo commit y se borraron (se recuperan con `git switch -c <rama> archive/<rama>`). Solo quedan ramas con PR abierta: en roblox-vault dos de dependabot y `jarvis/youtube-shorts-2026-11-09`; en roblox-game-template `ci/notion-mirror-issues-only` y `feat/ui-motion-kit`; en project-template una de dependabot. La poda semanal (`branch-prune.yml`, PR #193) informa cada lunes y borra sola cuando exista el secreto `GH_PRUNE_TOKEN`.
   - [ ] **Limpieza de C:.** De 16,8 a 19,6 GB libres el 16-11 (chats de más de 3 días indexados en `D:\Victor\Brain\40-archivo\sesiones-claude\2026-11-16.md`, Temp y versiones viejas de Claude Code). Para pasar de 20 falta `limpieza-elevada.ps1`, que pide el UAC de Victor.
   - [x] **Pendientes chicos del juego:** drain-for-loot#303 y #304 cerrados en la PR #311 (1.147 tests). Sale en el próximo release del juego.
   - [x] **Copia del mundo al día.** `places/dev.rbxl` es la del 16-11 a las 21:31, bajada con Archivo, Descargar una copia por el MCP de escritorio (Victor lo autorizó; el menú queda lejos de Publicar). La anterior está en `places/dev-2026-11-13.bak.rbxl`. El scope `legacy-asset:manage` sigue sin concederse, así que la próxima vez se repite por el menú. v0.4.0 fusionada sobre esa copia arranca sin errores de script.
   - [x] **Reparto por rol (orden de Victor del 16-11).** Victor es scripter y Leon builder: entre los dos cubren el desarrollo completo; Nande lleva lo de fuera del juego, en etapas posteriores. Hay una vista por persona en `docs/planning/backlog-1000/por-rol/` de drain-for-loot (Leon 445 filas, Victor 534, Nande 126; PR #315), también en el Drive.
   - Regla de Victor del 16-11: se investiga y se contrasta antes de construir, se propone sin esperar y se sigue con lo recomendado en lo reversible. Bucear a una capa sin drenarla (#185) es parte de la mecánica.

10. **Sesión del 16-11, última parte. La sesión siguiente parte aquí.**
   - [x] **Las 20 primeras tareas de Victor (drain-for-loot#307)** entraron en las PR #316 a #320 y salieron en el release **v0.4.0** (1.210 tests): tolerancia de ping en recogida, puerta de la capa 3, manguera a presión, arrastre del pago del jefe, velocidad al 6 %, tope de multiplicadores, ventana sin ofertas, guarda de azar pagado, banderas de contenido, migración de guardados, embudo de onboarding, primera venta con mínimo, favoritos y regalos que no se pierden. Nada de esto está jugado a fondo: solo el arranque en copia.
   - [ ] **En curso al cierre:** apagar el oxígeno con interruptor en Config (decisión de Victor: frena la idea de seguir bajando); conectar ofertas y banderas en `Main.server` (hoy nadie las consume); perfil `ligero` de hooks en studio.
   - [ ] **Sistema de Leon lento.** Medido: cada modo de `board-hook.ps1` tarda 0,7 a 0,95 s y por comando de shell corren cinco. El perfil `ligero` deja inicio, cierre y una sola revisión de git. Cuando entre: release de studio y pasos a Leon por el tablero. Leon instala solo las skills de builder, no las 67.
   - [x] **Ecosistema para los tres.** `claude-toolkit` tiene las 67 skills de Roblox y los pasos de instalación (PR #20). El Vault LihFolk V2 está en el Drive `10-kits`. Regla: toda ficha de Roblox lleva el comando del Vault y la PR una sección "Vault consultado".
   - [x] **Ramas archivadas revisadas.** Ninguna de las 12 trae algo que le falte a `develop`: cuatro ya habían entrado, una nota quedó superada, dos se cerraron por tema descartado, una era simulacro, tres son prototipos y la de plus-one-mining es del juego 1 cerrado.
   - [x] **Reels R-137 a R-141** como notas en roblox-vault (`research/sources/reels-2026-11-16`, PR #312).
   - [ ] **Leon quiere rehacer íconos, UI y UX.** Es suyo. Se le pidió en studio#1 la lista de lo primero que cambia para abrirla como issues; el código solo pide conservar las acciones de `GameUiBridge`. Además le esperan drain-for-loot#321 (modelo de la manguera a presión) y el botón de favorito.
   - [ ] **Siguen siendo de Victor:** publicar la versión privada (`docs/planning/publicar-privado.md`) y luego el playtest de Nande; secreto `GH_PRUNE_TOKEN`; rotar el token de `~/.rokit/auth.toml`; verificación en dos pasos de la organización (espera a Leon); público del juego (8 a 13 o 16+).
   - Sigue después: las 20 tareas siguientes de Victor del catálogo de sistemas, y jugar v0.4.0 entera en copia (capa 3 con y sin manguera, herramienta nueva, favoritos, regalo pendiente al reentrar).

11. **Sesión del 17-11 (madrugada). La sesión siguiente parte aquí.**
   - [x] **Cerrado del punto 10:** oxígeno apagado (drain-for-loot#325, probado en copia: 20 s bajo el agua sin perder aire), ofertas y eventos conectados (#327), perfil `ligero` de hooks (studio PR #199, release **v0.9.0**). Los pasos para Leon están en studio#1.
   - [x] **Cinemáticas en `develop`** (drain-for-loot#331): entrada, hito, jefe y mar drenado, con Skip. Sin puntos en `Workspace.CutscenePoints` se saltan solas. **Sin verificar:** que la cámara se mueva y vuelva con puntos puestos; la prueba en copia quedó a medias. Se puede probar con el panel de admin de Leon.
   - [ ] **Segunda tanda de Victor (drain-for-loot#329), tres trabajadores lanzados el 17-11:** grupo A en la rama `feat/329-first-minute-and-pumping`, grupo B (solo servidor) en `feat/329-safe-buying-and-selling`, grupo C en `feat/329-security-and-analytics`. Quien retome: mirar las PR abiertas con `Refs #329`; lo que no esté mergeado se termina desde su worktree en `D:/Victor/jarvis-wt/`.
   - [ ] **Lobby (drain-for-loot PR #330, borrador):** probado con un cliente. Espera de Leon: plataformas en el mundo o panel de UI. Falta la prueba con dos clientes. Su ADR lleva el número 0075, el mismo que el de cinemáticas: renumerar al sacar de borrador.
   - [ ] **PR de Leon en borrador:** #328 (teclas del HUD), #333 (agua en cuatro capas y bajada fluida) y #335 (panel de admin para probar). En la #335 quedó pedido que el remote exija Studio o rango de dueño además de `GameConfig.AdminPanel`, y falta un paso en `release.yml` que corte el release con la bandera encendida. **El panel se quita antes de abrir el juego** (pasos en drain-for-loot#334).
   - [ ] **Release 0.5.0 del juego:** cuando entren las PR de #329. `develop` ya lleva #325, #327 y #331 por delante de `main`. Después: fusionar sobre `places/dev.rbxl` y jugar en copia.
   - [ ] **Tercera tanda de Victor:** sacar las 20 filas P1 siguientes de `docs/planning/backlog-1000/por-rol/victor.md`, sin las de oxígeno, y abrirlas como issue igual que #329. Antes de construir se le avisa a Leon en studio#1 qué necesita de él cada fila.
   - [ ] **Referente Drain the Lake** (video de Victor, informe en el Drive `35-beta-testing/referentes/Drain-The-Lake`). Sin issue todavía: agua en la mano hasta verterla, aviso con número en las mejoras que ya se pueden comprar, cofres grandes al bajar el agua, compra sin animación que haga esperar.
   - [ ] **Drive.** Usado 8,0 de 15 GB (la carpeta del estudio pesa 4,4 GB; 3,05 son `10-kits`). Hay 1,15 GB en la papelera: la vacía Leon, que es el dueño. No se borró `20-investigacion/2026-11-06-research-ui.zip` (1,3 GB, con copia local en `D:\Victor\Roblox\research`) porque Leon va a rehacer la UI; se le preguntó. `rclone` avisa que su `client_id` compartido deja de funcionar durante 2026: hay que crear uno propio (pasos en la documentación de rclone, sección Drive) antes de que se corte la subida de kits.
   - [ ] **Preguntas abiertas a Leon (studio#1):** lobby, objeto que roba el Kraken en la cinemática de entrada, zip de UI, manguera a presión (#321), verificación en dos pasos, público del juego.
   - [ ] **Siguen siendo de Victor:** publicar la versión privada, `GH_PRUNE_TOKEN`, rotar el token de `~/.rokit/auth.toml`, scope `legacy-asset:manage`, verificación en dos pasos de la organización, público del juego.
   - Regla de Victor del 17-11: antes de construir se le propone a Leon por el tablero, y los dos agentes avisan en todo momento qué están haciendo (`empiezo`, `avance`, `cierro`).

12. **Sesión del 17-11 (noche). La sesión siguiente parte aquí.**
   - [x] **Release v0.6.0 del juego en GitHub** (no en Roblox): bloqueo de sesión al entrar (drain-for-loot#347), economía (#348: turbina 15 M, gemas del jefe, reinicio que guarda gemas) y compras seguras para 8 a 13 años (#350, ADR 0078). Antes, v0.5.0 con primer minuto (#340), compras (#341) y seguridad (#336).
   - [x] **Cinemáticas probadas en copia** con el fondo nuevo de Leon (#346): la de jefe y la de mar drenado mueven la cámara y la devuelven. Con puntos que giran de golpe la toma se salta sola (guardia `sharpTurn`). **Sin verificar:** pulsar Skip a mitad de toma y la entrada con el Kraken (falta el actor `Cutscene_Kraken`).
   - [ ] **Tercera tanda (drain-for-loot#339):** A y C hechos. Quedan el grupo B (misiones, premios, analítica) y el D (ajustes y rendimiento en teléfono), que necesitan a Leon, y SIS-010 (punto de venta cercano), que espera dónde va.
   - [ ] **Seguimientos abiertos:** #349 (el hito del 75 % paga 30 M, el doble de la turbina), #351 (oferta de un evento que ya terminó sigue visible), #337 (ideas de Drain the Lake).
   - [ ] **Sin probar en Studio:** avisos de compra reales, respuesta de `PolicyService`, replicación de atributos, cómo se sienten los precios nuevos, dos servidores con un perfil tomado.
   - [ ] **Leon (studio#1):** lobby (#330), objeto que roba el Kraken, puntos de cámara sobre el fondo nuevo, zip de UI del Drive, gating del panel de admin (#335), vaciar la papelera del Drive.
   - [ ] **Victor:** publicar la versión privada, rotar el token de `~/.rokit/auth.toml`, `GH_PRUNE_TOKEN`, verificación en dos pasos de la organización, `client_id` propio de rclone.

13. **Sesión del 18-11 (madrugada). La sesión siguiente parte aquí; reemplaza los pendientes del punto 12.**
   - [x] **Releases v0.7.0 y v0.8.0 en GitHub** (no en Roblox): hito del 75 % a 7,5 M (drain-for-loot#355), ofertas de evento terminado ocultas (#356), misiones con progreso guardado y analítica (#357, esquema 8), ajustes de música, efectos y destellos guardados más topes de partículas (#360, esquema 9).
   - [x] **Probado en copia local:** misiones (la de bienvenida se completa, paga sola, pasa a la siguiente y sobrevive a salir y entrar); atributos de misión e índice llegan al cliente; ajustes por remote cambian el atributo y silencian la música, y una clave inventada se rechaza; cinemáticas de jefe y mar drenado mueven la cámara y la devuelven; Skip con Espacio corta la toma (margen corto, falta confirmarlo a mano).
   - [x] **Tercera tanda (drain-for-loot#339):** grupos A, B, C y D hechos en lo que no necesita a Leon.
   - [ ] **Espera a Leon (studio#1):** botón de reclamar misiones (SIS-229), balde del grupo (JUG-257), dónde va el punto de venta cercano (SIS-010), streaming probado con su mapa (ART-353), puntos de cámara y actor `Cutscene_Kraken`, lobby (#330), tabla de partículas de #360, unificar `Set_reduceMotion` (#361), zip de UI del Drive, gating del panel de admin (#335), vaciar la papelera del Drive.
   - [ ] **Espera la versión privada publicada (Victor):** compras reales, dos servidores con un perfil tomado, guardado real de misiones y ajustes, partículas en teléfono (#362), eventos de analítica.
   - [ ] **Victor:** publicar la versión privada, rotar el token de `~/.rokit/auth.toml`, `GH_PRUNE_TOKEN`, verificación en dos pasos de la organización, `client_id` propio de rclone.

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
