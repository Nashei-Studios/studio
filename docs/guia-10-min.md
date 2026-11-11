# Cómo se trabaja, en 10 minutos

Para quien llega al estudio y no usa GitHub a diario.

## Lo mínimo que necesitas

1. Una cuenta de GitHub y aceptar la invitación a la organización `Nashei-Studios`.
2. Roblox Studio con acceso al Team Create del juego.
3. Si usas IA: pásale siempre [`CONTEXT.md`](../CONTEXT.md) primero.

No necesitas saber Git para aportar arte, ideas o pruebas. Sí lo necesitas para tocar código.

## Tres lugares, tres usos

| Quiero... | Voy a... |
|---|---|
| Decir "esto hay que hacerlo" | **Issues** del repo del juego. Botón New issue, elige la plantilla |
| Preguntar "¿esto está bien?" o tirar una idea | **Discussions** |
| Avisar que terminé, que estoy trabado o pasarle algo a alguien | **Agent Board**, el issue fijado arriba de la lista |

Regla corta: si la pregunta es "¿quién hace esto?", es un issue. Si es "¿qué les parece?", es una discusión.

## Tomar una tarea

1. Abre los Issues del juego y busca uno sin dueño.
2. Comenta "lo tomo" y ponte tu etiqueta `owner:tu-nombre`.
3. Una tarea, un dueño. Si te trabas, dilo en el Agent Board; no te quedes solo con el problema.
4. Al terminar, la PR la cierra sola. Si fue arte, la cierras tú cuando el modelo esté publicado.

## Escribir en el Agent Board

Un comentario por cosa, corto:

```
[avance] #12 terminé el modelo de la bomba, está publicado como Package.
Siguiente: @usuario lo conecta al script.
```

Las tres palabras son `[avance]`, `[bloqueo]` y `[handoff]`. Sin la mención con `@`, nadie recibe el aviso.

## En Studio

- El arte y el mapa se hacen en Studio, con Team Create.
- Los scripts **no** se editan en Studio: se sobrescriben solos. Si necesitas un cambio de código, abre un issue.
- Publicar el juego lo hace una sola persona, desde Studio.

## Dónde mirar cómo va todo

- El Project de la organización: tablero con todas las tareas por estado.
- Notion: la misma información, para leer cómodo.

El detalle está en `docs/team-workflow.md` de cada juego.
