# 0002. Pila de grabación, transcripción y acta de las reuniones

Estado: aceptada, 2026-11-12. Issue: #46.

## Contexto

Tres personas, presupuesto cero, reuniones en persona (grill: todos sentados con un celular sobre la mesa) o por llamada. Las grabaciones tienen voces de personas, así que la privacidad pesa. El estudio ya tiene Drive (`15-reuniones/`), Notion (base Reuniones), GitHub (issues `acuerdo`) y whisper local (`aprender-de-video`, `beta-testing`).

Criterios (NFR): fricción, costo cero o bajo, privacidad, Windows/macOS/Linux y celular, versionado, automatización.

## Opciones evaluadas

Fecha de la consulta: 2026-11-12. Los precios y límites de servicios de terceros vienen de comparativas y páginas de ayuda; están sujetos a cambio y se verifican en la página del proveedor antes de contratar.

### Grabar y transcribir

| Opción | Fricción | Costo | Privacidad | Plataformas | Automatizable | Veredicto |
|---|---|---|---|---|---|---|
| **A. Nota de voz del celular + whisper local** | baja: un botón; subir a Drive | 0 | el audio no sale de Drive del estudio ni de la máquina | todas, celular incluido | sí (CLI) | **elegida** |
| B. Notion AI Meeting Notes | baja | requiere plan Business o Enterprise según la ayuda de Notion; el plan del workspace no está verificado `[GAP]` | el audio pasa por Notion | web y móvil | parcial (MCP `notion-create-meeting-note`) | descartada por costo; reevaluar si el plan lo incluye |
| C. Grabación de Google Meet | media: solo en llamadas | requiere Workspace Business Standard o superior, o plan equivalente; cuenta personal gratis no graba | queda en Drive del organizador | web | difícil | descartada: el grill es presencial |
| D. Otter, Fireflies, tl;dv, Granola | baja | planes gratis con tope (minutos o número de reuniones, cifras que varían según la fuente) | el audio y el texto van a un tercero | mixtas, varios exigen bot o app de escritorio | por API, de pago | descartadas por privacidad y tope |
| E. OBS o grabadora de PC | media | 0 | local | PC | sí | sirve de respaldo, no de camino principal |

### Transcribir y separar hablantes

| Opción | Costo de instalar | Hablantes | Memoria y tiempo medidos | Veredicto |
|---|---|---|---|---|
| **whisper.cpp (`whisper-cli`), ya instalado** | ninguno | `-di`: diarización estéreo (compara el canal izquierdo y el derecho); `-tdrz` pide un modelo especial | 63 s de audio en 33 s de CPU con `ggml-small.bin` | **elegida**; hablantes solo si hay un canal por persona |
| faster-whisper | pip, sin diarización | no | más rápido que whisper.cpp en CPU según el proyecto, sin medir aquí | alternativa de velocidad, sin ganancia en este caso |
| WhisperX + pyannote | torch, token de Hugging Face y aceptar la licencia del modelo gated | sí, en mono | sin medir `[GAP]`: pesado para 16 GB con Studio abierto | **fase 2**, solo si el grill necesita nombres por voz |

### Acta y decisiones

| Opción | Veredicto |
|---|---|
| Acta en `plantillas/reuniones/acta.md`, decisiones en ADR (técnicas) o PR a `docs/` (acuerdos), abiertos como issues `acuerdo`, resumen en la fila de Notion | **elegida**: cada cosa va donde ya se versiona o se ve |
| Todo en la página de Notion | descartada: Notion no se versiona ni se revisa por PR |
| Un registro de decisiones aparte | descartada: el ADR por decisión ya existe |

## Decisión

Nota de voz del celular (o la que cada persona prefiera) subida a Drive, transcripción local con `whisper-cli`, acta desde la plantilla, decisiones por ADR o PR, abiertos como issues `acuerdo`, resumen en Notion. Los hablantes se separan con `-di` solo cuando hay grabación estéreo (una persona por canal, por ejemplo una llamada grabada con cada voz en su canal); en una mesa con un solo celular los hablantes quedan sin nombre y los pone quien condujo.

## Consecuencias

- Positivas: costo 0, el audio no sale del estudio, todo funciona en los tres sistemas operativos con whisper.cpp, sin cuentas de terceros.
- Negativas: sin diarización automática en mono; la transcripción es de calidad "small" (se vieron errores como "testars"); alguien revisa el acta.
- Riesgo: la memoria. Se mide la memoria libre antes de correr whisper (mínimo en el config) y se cierra Studio si no alcanza.

Qué la haría cambiar: que el plan de Notion incluya Meeting Notes sin costo extra, o que el grupo necesite nombres por voz en mesa (entonces WhisperX).

## Fuentes

- Ayuda de Notion, AI Meeting Notes: <https://www.notion.com/help/ai-meeting-notes>
- Disponibilidad de grabación de Meet: comparativas de terceros (Granola, tl;dv); verificar en la ayuda de Google.
- WhisperX (requisitos de pyannote): <https://github.com/m-bain/whisperX>
- Prueba de punta a punta: `docs/ejemplos/acta-prueba-2026-11-12.md`.
