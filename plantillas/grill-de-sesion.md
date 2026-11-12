# Grill de sesión

Cinco a diez minutos al empezar **cada** sesión de trabajo o plan nuevo. El agente pregunta, la persona responde, y el resultado queda como comentario en el issue. Sirve para no construir lo que nadie pidió.

Hay tres tamaños de grill. Se usa el más chico que alcance:

| Grill | Cuándo | Duración | Sale |
|---|---|---|---|
| Inicial | No se sabe qué proyecto o juego hacer | 90 a 120 min, en grupo | Una decisión y un candidato |
| De proyecto o de juego | Proyecto elegido, antes de construir | 60 a 90 min, en grupo | Spec, épicas, historias, issues, tablero |
| **De sesión (este)** | Cada vez que alguien se sienta a trabajar | 5 a 10 min, persona y agente | Plan de la sesión en el issue |

## Preguntas

El agente llega con las columnas "Lo que ya se sabe" llenas: lee el issue, el spec padre, el tablero y el código antes de preguntar. Solo pregunta lo que no pudo responder solo.

| # | Pregunta | Lo que ya se sabe | Respuesta |
|---|---|---|---|
| 1 | ¿Qué issue es y qué dice su criterio de listo? | | |
| 2 | ¿Qué parte se hace en esta sesión y qué queda fuera? | | |
| 3 | ¿Qué carpetas se tocan y quién es su dueño? | | |
| 4 | ¿Qué depende de otra persona o de otro issue? | | |
| 5 | ¿Cómo se va a comprobar que funciona? (prueba, comando, captura) | | |
| 6 | ¿Qué decisión de esta parte no está tomada? | | |
| 7 | ¿Qué haría que paremos y preguntemos al grupo? | | |

## Preguntas extra según la parte

Solo las del área del issue.

| Área | Preguntas |
|---|---|
| Código | ¿Qué contrato o API cambia? ¿Quién escribe las pruebas de aceptación, que no sea quien implementa? |
| UI | ¿De qué kit o sistema de diseño sale? ¿En qué tamaños de pantalla se prueba? |
| Arte o 3D | ¿Qué referencia visual manda? ¿Presupuesto de triángulos y formato de entrega? |
| Datos o economía | ¿Qué número se cambia y cómo se mide el efecto? |
| Infra o CI | ¿Qué se rompe si falla y cómo se vuelve atrás? |
| Investigación | ¿Qué pregunta responde y qué decisión cambia con la respuesta? |

## Cómo se deja escrito

Un comentario en el issue:

```
Grill de sesión, <fecha>. <persona> con <agente>.
Alcance: ...
Fuera: ...
Se comprueba con: ...
Depende de: ... (@quien)
Abierto: ... (quién lo cierra y cuándo)
```

Lo que quede "abierto" y sea del grupo se lleva al tablero con mención. El estado del issue en el tablero pasa a "En curso" al publicar este comentario.
