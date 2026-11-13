# Semanal: agenda

30 a 45 minutos. Conduce una persona distinta cada semana. Quien conduce no defiende ninguno de los puntos.

| Bloque | Min | Pregunta cerrada | Evidencia que se trae |
|---|---|---|---|
| 1. Cierre de la semana | 5 | ¿Qué issues se cerraron? ¿Cuáles quedaron `en curso` sin avance? | Vista "Esta semana" de la base GitHub en Notion |
| 2. Bloqueos | 10 | ¿Quién lleva más de X horas trabado (X según `docs/acuerdos.md`)? ¿Quién lo destraba y cuándo? | Comentarios `[bloqueo]` del Agent Board |
| 3. Estado de cada juego | 10 | Por juego: ¿en qué etapa está y qué número dice si sigue? | Fila de la base Juegos; PR abiertas |
| 4. Acuerdos abiertos | 10 | Por cada issue `acuerdo`: ¿se cierra hoy (sí o no)? Si no, ¿quién y para cuándo? | Lista `gh issue list --label acuerdo` |
| 5. Foco de la próxima semana | 5 | Tres cosas, con dueño | Texto escrito en la reunión |

Cada decisión sale con dueño y fecha. Lo que no se cierra en 2 minutos pasa a un issue `acuerdo`.

## Acta

Se genera con la skill `reunion` (fase procesar): decisiones, abiertos, dueños.
