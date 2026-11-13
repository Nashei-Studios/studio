# Reuniones del estudio

Una guía para que cualquiera de las tres personas (o alguien nuevo) prepare, conduzca y cierre una reunión y obtenga el mismo resultado. Sirve para cualquier reunión: grill de juego, grill inicial, semanal, acuerdos y revisión de juego.

## Qué es y qué no es

| Es | No es |
|---|---|
| Un camino fijo: preparar, conducir, procesar, generar | Un programa de videollamadas |
| Audio en Drive, acta en Git, resumen en Notion, pendientes como issues | Un lugar para guardar la transcripción completa en GitHub |
| Todo se lee de `config/ecosistema.json` | Una lista de ids escrita en cada documento |

## Tipos de reunión

Se declaran en `config/ecosistema.json`, sección `reuniones.tipos`. Agregar un tipo es editar ese archivo y escribir su agenda en `plantillas/reuniones/`.

| Tipo | Cuándo | Duración | Agenda |
|---|---|---|---|
| Grill inicial | No se sabe qué juego hacer | 90 a 120 min | [grill-inicial.md](../plantillas/grill-inicial.md) |
| Grill de juego | Juego elegido, antes de construir | 60 a 90 min | `docs/game/grill.md` de `roblox-game-template` ([ADR 0001](adr/0001-una-sola-fuente-para-el-grill.md)) |
| Semanal | Una vez por semana | 30 a 45 min | [semanal.md](../plantillas/reuniones/semanal.md) |
| Acuerdos | Hay issues `acuerdo` abiertos | 30 a 60 min | [acuerdos.md](../plantillas/reuniones/acuerdos.md) |
| Revisión de juego | Al cerrar una versión o una ronda de testeo | 45 a 60 min | [revision-juego.md](../plantillas/reuniones/revision-juego.md) |

## Material

- Un celular con la app de notas de voz, sobre la mesa, con batería y espacio. Respaldo: un segundo celular o la grabadora del PC.
- Acceso a la carpeta `15-reuniones` de Drive (remoto `nashei` si se sube con `rclone`; si no, desde el navegador).
- Un computador con `rclone`, `ffmpeg`, `whisper-cli` y el modelo (`config/ecosistema.json`, sección `transcripcion`), Node 20 o más, `gh` autenticado.
- El agente (Claude Code con la skill `reunion` de `claude-toolkit`).

## Roles

| Rol | Quién | Hace |
|---|---|---|
| Quien conduce | Una persona que no defiende la idea; rota | Lleva la agenda y el reloj, repregunta lo vago |
| Secretario (el agente) | El agente de quien conduce | Prepara, anota decisiones en vivo, procesa |
| Quien graba | Cualquiera | Pulsa grabar al empezar y sube el audio al terminar |

## Paso a paso

Cada paso dice cuándo está bien, qué hacer si falla y dónde queda registrado.

### 0. Comprobar la configuración (30 segundos)

```
node scripts/ecosistema.mjs validate
node scripts/ecosistema.mjs discover
```

- Bien: `valida` y `sin cambios` en Drive. Notion dice `omitido` si no hay `NOTION_TOKEN`; la skill lo resuelve con el MCP.
- Si dice `changed` o `missing`: algo se renombró. Corre `discover --write`, revisa el diff y abre una PR al config.
- Queda en: la PR del config.

### 1. Preparar (el día antes)

Pide al agente: "prepara la reunión semanal de mañana" (o el tipo que sea). El agente:

1. Crea la fila en la base Reuniones de Notion (tipo, fecha, presentes).
2. Crea la carpeta en Drive: `15-reuniones/<fecha>_<tipo>_<slug>/`.
3. Para un grill de juego: abre la rama `grill/<fecha>` del repo del juego y rellena la evidencia de cada bloque. Para los otros tipos: copia la agenda y trae los datos que pide (issues `acuerdo`, vista "Esta semana", hallazgos).
4. Avisa en el Agent Board con mención a los tres.

- Bien: el aviso trae la agenda, el enlace a Notion y el de Drive.
- Si falla: falta un id o un permiso. El agente dice cuál; no inventa carpetas.
- Queda en: Notion (fila), Drive (carpeta), repo del juego (rama).

### 2. Conducir

Reglas de facilitación (resumen del grill; valen para todas):

1. Quien conduce no defiende la idea.
2. Una pregunta a la vez, en el orden de la agenda, con el reloj a la vista.
3. Una respuesta vaga no cuenta ("que sea divertido", "lo vemos"). Se repregunta hasta tener un verbo, un número con unidad o un nombre.
4. Dato antes que opinión. El gusto es válido y se anota como gusto.
5. Si no hay acuerdo en 2 minutos: se anota `abierto`, quién lo cierra y cuándo, y se sigue.
6. En el grill, el pre-mortem se hace en silencio: cada persona escribe 3 razones por las que fracasó, y recién después se leen en voz alta. Así habla primero la evidencia y no la persona más segura.
7. Al cerrar, se lee en voz alta lo decidido y los abiertos, y se pide un sí explícito.

Grabar: pulsar grabar al empezar, decir en voz alta la fecha y el tipo ("semanal, 12 de noviembre"), dejar el celular entre las personas y grabar toda la reunión sin pausas.

- Bien: una nota de voz de duración similar a la reunión.
- Si falla (no grabó): se reconstruye el acta de memoria con las tres personas y se marca `Grabación: ninguna` en el acta. No se inventa el audio.

### 3. Procesar (el mismo día)

1. Subir el audio: `rclone copy <archivo> "nashei:15-reuniones/<carpeta>/"` (el nombre del remoto y de la carpeta están en el config). Sin `rclone`, se arrastra desde el navegador.
2. Pedir al agente "procesa la reunión <carpeta>". El agente:
   - baja el audio a un directorio temporal y comprueba que `ffprobe` lo lea;
   - mide la memoria libre y no corre whisper bajo el mínimo del config (cierra Roblox Studio si hace falta);
   - transcribe en local; con grabación estéreo separa hablantes (`-di`);
   - escribe el acta desde la plantilla, con minuto y confianza por decisión;
   - decisiones técnicas: ADR por PR; acuerdos: PR a `docs/acuerdos.md`;
   - cada abierto: un issue `acuerdo` con quién lo cierra y cuándo;
   - sube `acta.md` y `transcript/` a la carpeta de Drive;
   - actualiza la fila de Notion (decisiones, pendientes, enlace).
3. Una persona revisa el acta (5 minutos) y corrige lo que el audio dejó mal.

- Bien: el acta tiene decisiones con minuto, ningún nombre de hablante inventado, y los abiertos tienen issue.
- Si falla: whisper devuelve una línea tipo "gracias por ver" sobre silencio: es un artefacto, se descarta. Hablantes sin separar: se nombran a mano. Memoria insuficiente: se procesa por trozos o con otro computador.
- Queda en: Drive (audio, transcripción, acta), Git (ADR o `docs/`), issues, Notion.

### 4. Generar (solo el grill de juego)

Con el `grill.md` respondido y mergeado, el agente sigue la fase 3 de la skill `grill-de-juego`: spec, épicas, historias, issues, Project, fila de Juegos, contexto del vault.

## Qué hacer si algo falla

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `discover` dice `changed` | Alguien movió o recreó una base o carpeta | `discover --write`, revisar el diff, PR |
| Notion `omitido` | Sin `NOTION_TOKEN` o token de otro workspace | Usar el MCP desde el agente; el token no es obligatorio |
| `rclone` no lista `nashei:` | Remoto sin configurar o credencial retirada | [drive.md](drive.md), sección de configuración |
| La transcripción repite una frase | Silencio largo | Cortar el silencio con `ffmpeg` y repetir |
| Dos hablantes mezclados | Grabación mono | Nombrarlos a mano; `[GAP]` en el acta |

## Qué está prohibido

- Subir la transcripción completa o el audio a GitHub. A Git solo van citas cortas, el minuto y el enlace a Drive.
- Servicios de transcripción de terceros sin acuerdo de las tres personas (el audio tiene voces).
- Escribir ids de Notion o Drive en un documento o skill: se leen del config.
- Rellenar con un valor plausible lo que no se dijo o no se oyó: va como `[GAP]`.
- Cerrar un grill sin riesgo del pre-mortem con dueño, o sin criterio de abandono por número.

## Dónde queda registrado

| Qué | Dónde |
|---|---|
| Audio, transcripción, acta | Drive, `15-reuniones/<fecha>_<tipo>_<slug>/` |
| Resumen, decisiones y pendientes | Notion, base Reuniones |
| Decisiones técnicas | ADR en el repo que corresponde |
| Acuerdos del equipo | `docs/acuerdos.md` por PR |
| Lo abierto | Issue con etiqueta `acuerdo` |
| Un ejemplo completo | [acta-prueba-2026-11-12.md](ejemplos/acta-prueba-2026-11-12.md) |

## Reuniones de prueba

Una prueba usa la subcarpeta `_prueba` de `15-reuniones`, su fila lleva `[prueba]` en el título y sus issues y PR llevan la etiqueta `hold`. Al terminar se borran o se marcan como prueba.
