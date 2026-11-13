# 0001. Una sola fuente para el grill de juego

Estado: aceptada, 2026-11-12. Issue: #46.

## Contexto

Había tres documentos que se solapaban:

- `plantillas/grill-de-juego.md` de este repo: 12 secciones de preguntas abiertas, con la columna "Lo que dice la investigación".
- `docs/game/grill.md` de `roblox-game-template`: agenda por bloques (0 a 14) con minutos, preguntas cerradas, evidencia, pre-mortem, criterio de abandono y rendimiento. Ya lo copió `drain-for-loot` y lo usa la rama `grill/2026-11-12`.
- `plantillas/grill-inicial.md`: elegir entre candidatos antes de tener juego.

Dos plantillas del mismo grill se desincronizan. La skill `grill-de-juego` apuntaba a la vieja y su fase 3 mapeaba "secciones 1, 2, 11 y 12", que ya no existen en la nueva.

## Opciones evaluadas

| Opción | Fricción | Versionado | Se copia a cada juego | Riesgo |
|---|---|---|---|---|
| A. Dejar las dos y avisar | nula | dos fuentes | una sí, otra no | se desincronizan, como ya pasó |
| B. Molde de la plantilla como única fuente; la de `studio` queda como puntero | baja | una fuente, junto al resto de `docs/game/` | sí, ya viaja con el juego | hay que reescribir la fase 3 de la skill |
| C. Molde en `studio` y que cada juego lo traiga por copia manual | media | una fuente, lejos de los demás moldes | no | se olvida copiar |

## Decisión

Opción B. `docs/game/grill.md` de `roblox-game-template` es la única fuente del grill de juego. `plantillas/grill-de-juego.md` queda como un puntero marcado "reemplazada" que explica el cambio y no tiene preguntas. `grill-inicial.md` se conserva: responde otra pregunta (¿qué juego?) y es otro tipo de reunión; se declara así en `config/ecosistema.json`. El grill de sesión no cambia.

La skill `grill-de-juego` mapea de los bloques del molde a los artefactos (tabla en la skill), y la agenda de cada tipo de reunión se declara en el config, no en el texto de las skills.

## Consecuencias

- Positivas: un cambio al grill se hace una vez, en la plantilla, y los juegos nuevos lo heredan.
- Positivas: la skill y la guía dejan de citar números de sección que cambian.
- Negativas: se pierde la columna "Lo que dice la investigación" por pregunta; ahora la evidencia va por bloque. Si el grupo la echa de menos, se propone en la plantilla, no aquí.
- Negativas: los grills ya respondidos con el formato viejo (si existen) no se migran.

Qué la haría cambiar: que el molde de la plantilla deje de ser el punto de partida de los juegos (por ejemplo, si se migra a otra plantilla).
