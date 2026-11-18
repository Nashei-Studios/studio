# STYLE.md de Drain for Loot

Estilo único del juego para la skill `momentum-3d-models`. Se escribió una vez y todos los modelos simples lo reutilizan (`.claude/skills/modelo-simple/SKILL.md`). Leon es dueño del arte y lo cambia por PR; cambiarlo cambia todos los modelos futuros, así que se avisa en el tablero.

Qué viene de fuente y qué falta:

- Los seis colores de rareza, el gris de "bloqueado" y la superficie de referencia salen del código: `src/shared/features/rarity/RarityConfig.luau` del repo `drain-for-loot` (`RarityConfig.default`, que el juego usa sin cambios en `Config.default.rarity`).
- "Low poly cartoony" es la dirección que fijó Victor para el juego. Las cifras de bisel, proporción y triángulos son un punto de partida de la plantilla de la skill, no una medida: Leon las ajusta tras el primer modelo.
- Lo que no está acordado dice "por acordar" y se pregunta, no se rellena.

## El estilo en una línea

Low poly cartoony: formas redondeadas y robustas, colores planos, silueta que se lee de un vistazo desde la cámara normal del juego, también en un teléfono.

## Referencias (style/refs/)

Por acordar con Leon: 3 a 6 capturas del look que quiere. Mientras no existan, el cofre por capa de `drain-for-loot#337` es la primera referencia propia y se guarda aquí cuando esté aprobado.

## Reglas de forma

- Silueta primero: debe leerse de un vistazo desde la cámara normal.
- Redondez: muy redondeada. Bisel de unos 5 % del lado más chico de la pieza, 2 segmentos.
- Proporciones: robustas, de juguete (más gruesas que reales).
- Piezas repetidas (tablones, barrotes) regulares, con variación mínima.
- Un prop que muestra su rareza usa el color de esa rareza en el marco o el detalle principal, nunca en todo el cuerpo.

## Paleta (solo estos, o un tono más claro o más oscuro)

| Hex | Trabajo |
|---|---|
| `#9AA5B8` | Común (Common) |
| `#4FD18B` | Poco común (Uncommon) |
| `#4D8DFF` | Rara (Rare) |
| `#B26BFF` | Épica (Epic) |
| `#FF8A3D` | Legendaria (Legendary) |
| `#FF4FB8` | Mítica (Mythic) |
| `#3A4260` | Bloqueado: neutro, sin color de rareza |
| `#171C30` | Superficie oscura de referencia (fondo de tarjetas; no es de modelos) |
| por acordar | Cuerpo principal, madera, metal y plantas: Leon los fija con el primer modelo |

La rareza nunca se carga solo con color: va también con su texto (regla de `docs/design/DESIGN.md` del juego).

## Nivel de detalle

- Props chicos: 3 a 8 piezas. Medianos: 8 a 20. Grandes: 20 a 60.
- El detalle va en los 3 rasgos que lo hacen reconocible; el resto queda simple.

## Presupuesto de triángulos

| Tamaño | Triángulos |
|---|---|
| Chico (en la mano, menos de 3 studs) | 300 a 1.000 |
| Mediano (mueble, menos de 10 studs) | 1.000 a 4.000 |
| Grande (vehículo, edificio) | 4.000 a 15.000 (nunca más de 20.000 por malla) |

## Prohibido

- Texturas fotográficas realistas.
- Detalles diminutos que desaparecen en un teléfono.
- Neón en todo: el brillo se reserva a rarezas altas y energía.
- Mezclar estilos: un modelo que no sigue este archivo se rehace.
