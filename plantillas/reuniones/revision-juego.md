# Revisión de juego: agenda

45 a 60 minutos. Se hace al cerrar una versión jugable o una ronda de testeo, antes de decidir si el juego sigue.

| Bloque | Min | Pregunta cerrada | Evidencia que se trae |
|---|---|---|---|
| 1. Qué se probó | 5 | ¿Qué versión (SemVer y PlaceVersion) y con cuántos testers? | Fila de "Sesiones de testeo" |
| 2. Números | 10 | ¿Se cumplió el número del criterio de abandono (sí o no)? | `metrics.md` del juego; informe de la ronda |
| 3. Hallazgos S0 y S1 | 15 | ¿Cada uno tiene dueño y fecha? ¿Alguno cambia el alcance? | `hallazgos.csv`; issues |
| 4. Qué se ve en el video | 10 | Los tres momentos donde el tester dudó: ¿qué cambia en el juego? | Clips con minuto |
| 5. Veredicto | 10 | Seguir, ajustar o cerrar (una de las tres) y la fecha de la próxima revisión | Criterio escrito en el grill |

El veredicto se registra en la base Juegos de Notion y, si cierra el juego, en un ADR del repo del juego.
