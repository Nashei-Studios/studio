## Session: 2026-11-14 — la espera del tablero fuera de la sesión y el costo de la sesión de Leon

**Prompt:** `/goal Lee docs/plan-vigente.md de Nashei-Studios/studio y trabaja el plan en orden hasta dejar cada punto verificado`. Durante la sesión Victor sumó un pedido: el agente de Leon tarda 20 minutos y gasta 80 mil tokens en un retoque de terreno; hay que explicarlo a los dos, hablar con su agente y arreglarlo.

**Output:**
- **studio#161, punto 1 del plan:** `tools/board-watch.ps1` y `tools/lib/board-watch.ps1`. Una tarea oculta del sistema lee el tablero cada 2 minutos y retoma con `claude --resume <id> --bg` la sesión que murió o quedó quieta con posts sin leer. ADR 0007.
- **Prueba real en Windows:** sesión de fondo detenida con `claude stop`, comentario en un issue de prueba (studio#166, cerrado), la tarea `Nashei Board Watch` la retomó sin abrir ventanas y la sesión leyó el comentario con `inbox`.
- **studio#165:** diagnóstico del costo de la sesión de Leon, publicado en studio#1 con seis mediciones que su agente tiene que devolver y cinco opciones para decidir entre Leon y Victor.
- **place-sync:** la PR drain-for-loot#170 de Leon llegó a la place compartida (worktree en `945c69e5`).

**Decisión:**
- La espera vive en el programador del sistema, no en la sesión ni en JARVIS, para que sirva igual en el equipo de cada persona (ADR 0007, opción A).
- Una sesión ocupada no se retoma: la lee su propia espera o el hook de cierre de turno. Una sesión quieta más de 10 minutos con posts sin leer se retoma como copia.
- El texto de los posts nunca viaja en el mensaje de retomada.

**Tradeoffs considerados:**
- **Cron de JARVIS:** solo existe en el equipo de Victor. **Workflow de `issue_comment`:** gasta minutos de Actions por cada comentario y no llega a un proceso local. **`Monitor` o cron de la sesión:** mueren con la sesión.
- **Mensaje de retomada:** la primera versión pedía además dejar la espera corriendo. Eso entró en la condición del `/goal`, chocó con la meta de prueba y la sesión quedó dando vueltas. Quedó la meta tal cual más un paso único.
- **Desde dónde corre la tarea:** `puesto.ps1 install` solo la registra desde la copia fijada al release, igual que los hooks. Se pierde tenerla en los otros equipos antes del release del lunes.
- **Costo de la sesión de Leon:** lo que carga el estudio es poco (unos 5.900 tokens entre `AGENTS.md`, `CLAUDE.md` y el aviso de inicio). El tiempo se va en el carril completo de código que hoy recorre cada retoque de terreno. El piso de contexto de su equipo no se puede medir desde acá.

**Archivos modificados:**
- `tools/board-watch.ps1`, `tools/lib/board-watch.ps1`, `tools/board-hooks/run-hidden.vbs` (nuevos)
- `tools/board-hooks/board-hook.ps1`, `tools/puesto.ps1`
- `docs/adr/0007-la-espera-del-tablero-fuera-de-la-sesion.md` (nuevo)
- `.claude/skills/empezar-a-trabajar/SKILL.md`, `docs/plan-vigente.md`

**Tests agregados/modificados:**
- `tools/tests/board-watch.test.ps1` (nuevo): la decisión, lo que `install` registra en cada sistema y el comando de punta a punta con GitHub y Claude Code simulados. Mata el proceso de la espera y comprueba que la pasada retoma la sesión.
- `tools/tests/board-hooks.test.ps1`: el cierre de turno se frena una vez cuando hay posts sin leer.
- `tools/tests/smoke.ps1`: corre las pruebas nuevas en los tres sistemas.
