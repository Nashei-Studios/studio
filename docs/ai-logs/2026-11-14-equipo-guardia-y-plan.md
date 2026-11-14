## Session: 2026-11-14 — decisiones de equipo, guardia de rama y plan de la sesión siguiente

**Prompt:** `/goal Lee docs/plan-vigente.md de Nashei-Studios/studio y trabaja el plan en orden hasta dejar cada punto verificado`. Durante la sesión se sumaron tres pedidos:
- La regla de que ninguna decisión se toma con una sola persona (`needs-team`).
- La explicación a fondo de las tres decisiones abiertas.
- El plan de la sesión siguiente, con los frentes de Victor y la ley de que la espera del tablero sobreviva a todo.

**Output:**
- **Cerrados:** drain-for-loot#36 (luau-lsp en todo el código heredado) y studio#108 (seguridad del puesto: PR #146 a #151, #159 y plantilla #266).
- **Regla `needs-team`:** quedó en la skill `empezar-a-trabajar`, paso 3c (PR #154).
- **Tres decisiones del equipo publicadas en studio#1**, con sus documentos:
  - #37: los dos guardados.
  - Cómo medir antes de publicar.
  - Las 45 tareas de los dos triages.
- **Ronda 11 de la guardia de rama:** studio#160, en la rama `fix/160-guard-round11`.
- **Issues nuevos:** studio#161 (la espera del tablero sobrevive a todo) y studio#162 (los frentes R-115 a R-124).
- **El plan vigente**, reordenado para la sesión siguiente.

**Decisión:**
- La regla de ramas se hace cumplir en los hooks de git (ADR 0006). La guardia de la shell avisa antes y falla cerrada ante lo que esconde un token sensible.
- La espera del tablero pasa a vivir fuera de la sesión (studio#161), porque el sistema la cortó por falta de memoria y las decisiones se quedaron sin aviso.

**Tradeoffs considerados:**
- **Guardia en la shell:** se descartó normalizar las palabras quitando las barras en todo el comando, porque rompe las rutas de Windows antes de `git.exe`. Se eligió comparar los tokens sensibles antes y después de quitar comillas y escapes, sin tocar el texto que lee el parser. Lo que se pierde: una variable armada en otra sentencia sigue sin seguirse.
- **Espera del tablero:** las opciones quedan para el ADR de studio#161.

**Archivos modificados:**
- `docs/plan-vigente.md`
- `docs/ai-logs/2026-11-14-equipo-guardia-y-plan.md`
- En la rama de #160: `tools/lib/branch-guard.ps1` y `tools/tests/board-hooks.test.ps1`

**Tests agregados/modificados:**
- `tools/tests/board-hooks.test.ps1`: casos de la ronda 11. Sin el cambio fallan 3; con el cambio pasan todos.
