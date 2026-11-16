# Tareas propuestas de studio: explicación para decidir (2026-11-14)

Para Victor, Leon y Nande. Son las 22 tareas abiertas con la etiqueta `needs-triage`. Todas salen de las cuatro investigaciones del épico #109: pruebas (#111), arquitectura de juegos, kits y Drive (#113) y crecimiento fuera de Roblox. Ninguna está decidida. La decisión es del equipo, no de quien la propuso.

Cómo leer los esfuerzos: S es menos de medio día, M es uno a tres días, L es más de tres días o necesita algo que no controlamos. Son estimaciones mías a partir de lo que dice cada issue; ningún issue trae una estimación propia, así que donde pongo una cifra es criterio y no dato.

## Resumen

Hay 22 tareas: 14 de Victor (código, datos, pruebas y kits), 5 de Leon (Drive y arte) y 3 de Nande (Discord, share links y beta).

Mi recomendación en una línea: aceptar ahora las siete que protegen dinero y datos de jugadores o dejan el Drive ordenado a bajo costo, juntar las que se pisan, y dejar para después lo que depende de que exista un juego publicado en privado.

Ordenadas por valor sobre esfuerzo (la primera es la mejor relación):

| # | Tarea | Dueño | Valor | Esfuerzo | Recomendación |
|---|---|---|---|---|---|
| 1 | #122 Pruebas primero y gate único | Victor | Alto | S | Aceptar ahora |
| 2 | #129 Borrado por derecho al olvido | Victor | Alto | S | Aceptar ahora |
| 3 | #130 Respaldo y restauración de datos | Victor | Alto | M | Aceptar ahora |
| 4 | #138 README en carpetas del Drive | Leon | Medio | S | Aceptar ahora |
| 5 | #142 Campo `categoria` en el manifiesto | Victor | Medio | S | Juntar con #141 |
| 6 | #141 ADR de `ships` y licencia desconocida | Victor | Alto | S | Aceptar ahora |
| 7 | #139 Limpiar `_prueba`, renombrar `icons`, mover audio | Leon | Medio | S | Aceptar después de #141 |
| 8 | #123 Capa de pruebas que rompen | Victor | Alto | M | Aceptar ahora (tras #122) |
| 9 | #124 Programa de beta testers | Nande | Alto | M | Aceptar ahora, ronda 0 después |
| 10 | #131 Inventario de stores y presupuesto de requests | Victor | Alto | M | Juntar con #129 y #130 |
| 11 | #118 Share links y calendario de live ops | Nande | Medio | S | Aceptar para después |
| 12 | #133 Spike Wally frente a pesde | Victor | Medio | S | Aceptar para después |
| 13 | #127 Mutación dirigida en módulos de dinero | Victor | Medio | S | Aceptar para después |
| 14 | #117 Montar el Discord | Nande | Medio | M | Aceptar para después |
| 15 | #125 Jugadores sintéticos y carga del lobby | Victor | Medio | M | Aceptar para después |
| 16 | #126 Pruebas de motor con Open Cloud | Victor | Medio | L | Aceptar para después |
| 17 | #132 Partir `Main.server` por feature | Victor | Medio | M | Aceptar para después |
| 18 | #140 Archivar kits contenidos en otros | Leon | Bajo | S | Aceptar para después |
| 19 | #143 Kits CC0 de Kenney al Drive | Victor | Medio | S | Aceptar para después (Leon elige) |
| 20 | #119 Kit visual de comunidad y redes | Leon | Medio | M | Aceptar para después |
| 21 | #120 Plantilla de clip vertical 9:16 | Leon | Medio | M | Aceptar para después |
| 22 | #134 Disparadores para ECS y Parallel Luau | Victor | Bajo | M | Descartar por ahora |

Se pisan entre sí: #129, #130 y #131 (los tres tocan el contrato de datos); #122 y #123 (el gate sostiene a las pruebas que rompen); #138, #139 y #140 (todo el orden del Drive, mismo dueño); #141 y #142 (ambos cambian el manifiesto de kits); #125 y #134 (ambos miden carga y rendimiento, y #125 comparte línea base con drain-for-loot#87); #117, #118, #119 y #120 (todo crecimiento fuera de Roblox, con la misma regla de no gastar nada antes de la decisión 0038).

---

## Pruebas y calidad

### #122 Pruebas primero y gate único

- **Qué es.** Hacer que "primero la prueba" sea un paso real del flujo. La plantilla de PR gana una sección "Prueba que falló primero" (comando y salida en rojo), el CLAUDE.md de `roblox-game-template` lo exige, y se crea `scripts/gate.ps1`, que corre stylua, selene, analyze, tests, cobertura, perf-budget y rojo build, y devuelve un solo código de salida.
- **Para qué sirve.** Hoy esos comandos se corren sueltos y alguien puede olvidar uno, o juzgar el resultado por la última línea (el doc de pruebas ya lo marca como falla conocida). Con un solo código de salida, verde o rojo no se discute.
- **Si no se hace.** El gate sigue dependiendo de la memoria de quien abre la PR. Las demás tareas de pruebas no tienen dónde enchufarse.
- **Dueño y esfuerzo.** Victor. S: el issue dice que solo reúne comandos que ya existen.
- **Depende de / desbloquea.** No depende de nada. Desbloquea #123, #126 y #127, que necesitan un punto único donde correr.
- **Riesgos.** Que el gate local tarde demasiado y la gente lo salte. El issue no dice cuánto demora hoy el conjunto.
- **Recomendación: aceptar ahora.** Es la mejor relación valor/esfuerzo de la lista y no cambia comportamiento del juego.
- **Hay que decidir.** Si el gate se vuelve obligatorio en el template desde ya y si `drain-for-loot` lo recibe por template-sync en la misma tanda.

### #123 Capa de pruebas que rompen

- **Qué es.** Un directorio `tests/chaos/` en la plantilla: cortes inyectados en compra y guardado (se enumera cada punto y se revisan invariantes tras reiniciar), conservación de ítems y monedas con corrutinas que ceden, ráfagas de 1.000 llamadas al `RateLimiter`, entradas aleatorias contra el cargador y migraciones de perfiles, y un DataStore falso que devuelve errores 301 a 306. Hay un modo profundo local por variable de entorno.
- **Para qué sirve.** Un juego con dinero real (Robux) pierde jugadores y confianza si una compra se cobra y no se entrega, o si un corte duplica ítems. Estas pruebas buscan justo esos casos antes de que los encuentre un jugador.
- **Si no se hace.** Los bugs de dinero y datos se descubren en producción.
- **Dueño y esfuerzo.** Victor. M: son varias suites, pero entran en `lune run scripts/test` sin CI nuevo.
- **Depende de / desbloquea.** Conviene después de #122. Se solapa en parte con #127 (mutación en los mismos módulos) y con #126 (ambas prueban los adaptadores de datos, una con fakes y otra contra el motor real).
- **Riesgos.** Pruebas aleatorias que fallan "a veces" y desgastan al equipo. El issue lo cubre con la regla de convertir toda semilla que falla en prueba fija.
- **Recomendación: aceptar ahora.** Protege el dinero, que es lo más caro de arreglar tarde.
- **Hay que decidir.** Si el modo profundo queda solo local (como propone) o si alguien lo corre antes de cada release.

### #127 Mutación dirigida en módulos de dinero

- **Qué es.** Un script de Lune que cambia operadores y condiciones en `ProductGrants`, recibos y economía, corre la suite y cuenta cuántos cambios "sobreviven" (pasa todo aunque el código esté roto).
- **Para qué sirve.** Mide si las pruebas de dinero realmente detectan errores, no solo si el código tiene cobertura. La barra de entrega pide un puntaje de mutación.
- **Si no se hace.** La cobertura de 75 % puede ser alta con pruebas que no verifican nada.
- **Dueño y esfuerzo.** Victor. S: sin dependencias nuevas, corre local.
- **Depende de / desbloquea.** Va bien después de #123, porque las pruebas nuevas bajan el número de mutantes vivos. No desbloquea nada.
- **Riesgos.** Que deje archivos mutados si falla a medias. El issue exige restaurar y dejar `git diff` vacío.
- **Recomendación: aceptar para después.** Primero #123; si se hace antes, medirá un puntaje que va a cambiar.
- **Hay que decidir.** Si el puntaje es meta del equipo o solo información.

### #125 Jugadores sintéticos y carga del lobby de 20

- **Qué es.** Un módulo que simula jugadores llamando a los handlers reales, más una corrida del método de `docs/performance.md` para llenar su tabla y fijar `lobbyCap` con una medición.
- **Para qué sirve.** Hoy el tope del lobby no tiene un número medido.
- **Si no se hace.** El `lobbyCap` queda a ojo.
- **Dueño y esfuerzo.** Victor. M.
- **Depende de / desbloquea.** Un comentario del propio issue dice que drain-for-loot#87 (carga del lobby de 20 en Studio) está en curso y da la línea base; los sintéticos vienen después. Se pisa con #134, que también mide rendimiento.
- **Riesgos.** El issue avisa que solo corre en place de desarrollo o copia local. No dice qué máquina de referencia se usa, solo que la tabla la registra.
- **Recomendación: aceptar para después**, cuando termine #87.
- **Hay que decidir.** Si se espera a #87 antes de empezar.

### #126 Pruebas de motor con Open Cloud

- **Qué es.** Probar adaptadores que hablan con el motor (ProfileStore contra DataStore real, MarketplaceService) con un script `engine-test` por la API de ejecución de Luau de Open Cloud, contra una experiencia de desarrollo separada, y un ADR con alternativas.
- **Para qué sirve.** Lune con fakes no prueba el motor real. Esta es la única forma del issue de ver el comportamiento real de DataStore sin tocar la place del grupo.
- **Si no se hace.** Los adaptadores quedan probados solo contra fakes.
- **Dueño y esfuerzo.** Victor. L: hay que crear la universe de desarrollo, una llave con scope específico y publicar a un place de prueba, y esas partes requieren a Victor.
- **Depende de / desbloquea.** Depende de #122. Comparte necesidad de llave y universe de desarrollo con #130 (probar restauración) y #129; conviene crear esa universe una sola vez.
- **Riesgos.** Manejo de una llave (va a secretos de GitHub y variable local, nunca al repo) y límites de la API (5 creaciones por minuto, 10 tareas concurrentes, 5 minutos por tarea).
- **Recomendación: aceptar para después**, con la universe compartida con #130.
- **Hay que decidir.** Quién crea la llave y cuándo, y si se acepta correr en la PR de release `develop` a `main`.

### #124 Programa de beta testers

- **Qué es.** Poner en marcha el programa de beta con Nande: carril rápido (nota de voz de cuatro frases: versión, qué hice, qué esperaba, qué pasó) y carril completo (`beta-testing.md`, B1 a B13), ambos terminando en el mismo issue; canales por versión y una ronda 0 con una build privada.
- **Para qué sirve.** Convierte lo que prueba Nande en issues ordenados en vez de mensajes sueltos.
- **Si no se hace.** Los reportes de prueba siguen llegando por canales distintos y sin versión.
- **Dueño y esfuerzo.** Nande. M. La parte de definir el proceso es corta; la ronda 0 depende de una build.
- **Depende de / desbloquea.** Prerrequisito (lo dice el issue): una versión publicada en privado por Victor. Falta la skill `beta-testing` del claude-toolkit, que hoy no existe. Se pisa con #117 solo en que los probadores también estarían en Discord.
- **Riesgos.** Que la ronda 0 se haga sin build y quede a medias. Las preguntas `TBD` de `docs/game/beta-testing.md` deben responderse; el issue no dice cuántas son.
- **Recomendación: aceptar ahora** el diseño del proceso; la ronda 0 se hace cuando Victor tenga la build privada.
- **Hay que decidir.** Con Victor: el tiempo de respuesta para fallas S0 y dónde vive la ficha de sesión en Notion.

### #134 Disparadores medidos para ECS, Parallel Luau y estado reactivo

- **Qué es.** Un banco de pruebas con N entidades simuladas por servidor, medido con el Script Profiler en un celular de gama baja, para fijar a partir de cuántas entidades se justifica adoptar ECS (Jecs), Parallel Luau o estado reactivo (Charm, Replica).
- **Para qué sirve.** Evitar adoptar una librería sin evidencia.
- **Si no se hace.** Seguimos sin adoptarlas, que es lo correcto mientras el juego sea un simulador de "+1 por segundo". La investigación fuente dice que no hay razón para ECS hoy.
- **Dueño y esfuerzo.** Victor. M: exige un banco reproducible y un celular de gama baja; el issue no dice si hay uno disponible.
- **Depende de / desbloquea.** Se coordina con #111 (ya cerrado) y se pisa con #125. No desbloquea nada.
- **Riesgos.** Gastar días midiendo algo que no está en el camino del juego. La UI y su estado de cliente son decisión de Leon (ADR 0071), así que la parte reactiva no es de Victor.
- **Recomendación: descartar por ahora.** Se reabre si un juego se acerca al techo de rendimiento medido en #125.
- **Hay que decidir.** Si hay algún juego en el que las entidades crezcan lo bastante como para justificarlo.

---

## Datos de jugador y arquitectura

### #129 Borrado por derecho al olvido

- **Qué es.** Declarar plantillas de borrado (`user_data_templates` con el token `{UserId}`) para los stores de jugador, en el template y en Drain for Loot, en vez del "trabajador externo" que se planeó en #61.
- **Para qué sirve.** Cuando Roblox recibe un pedido de borrado de un usuario, borra solo lo que coincide con las plantillas. Es cumplimiento sin escribir código de borrado.
- **Si no se hace.** No hay ningún procedimiento para un pedido real, y el trabajador externo de #61 (cerrado, con otro título) nunca existió como solución.
- **Dueño y esfuerzo.** Victor. S: es un ADR más configuración. Publicar la config es acción de Victor con una llave que no va al repo.
- **Depende de / desbloquea.** Se apoya en el patrón de llaves de #131. Se pisa con #130 y #131 (mismo contrato de datos).
- **Riesgos.** Máximo 100 plantillas por juego, y el conteo de nombres de tablero distintos por año no está medido; si los tableros generan muchos nombres, el tope se alcanza.
- **Recomendación: aceptar ahora** y hacerla junto con #130 y #131.
- **Hay que decidir.** Si el ADR supersede la parte de borrado del 0028, como propone.

### #130 Respaldo y restauración de datos de jugador

- **Qué es.** Un procedimiento: snapshot por Open Cloud antes de publicar un cambio de datos, y restauración con `ListVersionsAsync` y `GetVersionAsync`, con un runbook para quien no estuvo.
- **Para qué sirve.** Hoy un error de migración no se puede deshacer.
- **Si no se hace.** Un cambio de datos mal hecho pierde progreso de jugadores sin vuelta atrás.
- **Dueño y esfuerzo.** Victor. M: la parte difícil es probar en una place de desarrollo que restaurar respeta el envoltorio de ProfileStore, algo que la investigación declara no medido.
- **Depende de / desbloquea.** Necesita la place de desarrollo, la misma de #126. Los `OrderedDataStore` no tienen versiones, así que se reconstruyen desde perfiles (el issue lo pide documentar). Se pisa con #129 y #131.
- **Riesgos.** Que la restauración rompa el envoltorio y no se sepa hasta una emergencia.
- **Recomendación: aceptar ahora.** Es el único seguro contra un error de datos.
- **Hay que decidir.** Cuándo se crea la place de desarrollo y quién la tiene.

### #131 Inventario de stores y presupuesto de requests

- **Qué es.** Un `docs/data-contract.md` con cada store (tipo, patrón de llave, tamaño estimado, quién escribe, frecuencia, plantilla de borrado) y un presupuesto de requests por servidor (60 + jugadores x 40 por minuto) verificado en CI, que falla si aparece un store sin declarar.
- **Para qué sirve.** Es la lista que usan #129 y #130 para saber qué borrar y qué respaldar, y evita pasarse de los límites de Roblox.
- **Si no se hace.** #129 y #130 trabajan sobre una lista que nadie mantiene.
- **Dueño y esfuerzo.** Victor. M: el chequeo en `perf-budget` es la parte nueva.
- **Depende de / desbloquea.** Alimenta a #129 y #130. Cada número lleva su fuente o dice "chosen, not sourced".
- **Riesgos.** Un chequeo que bloquee PR por falsos positivos.
- **Recomendación: juntarla con #129 y #130** en una sola tanda de datos, en el orden #131, #129, #130, con un ADR por decisión.
- **Hay que decidir.** Si se hacen como una sola entrega o tres PR separadas.

### #132 Partir `Main.server` por feature

- **Qué es.** Dividir `src/server/Main.server.luau` (1355 líneas en Drain for Loot) en módulos de cableado por feature, manteniendo un solo Script por lado.
- **Para qué sirve.** Mantenibilidad para un equipo de tres. Cumple el disparador del ADR 0009.
- **Si no se hace.** El archivo sigue creciendo y cualquier cambio de arranque toca todo.
- **Dueño y esfuerzo.** Victor. M. Es refactor sin cambio de comportamiento, pero toca monetización y datos.
- **Depende de / desbloquea.** Mejor después de #122 y #123, para tener red de seguridad. El issue dice que requiere aprobación de Victor antes de tocar monetización o datos.
- **Riesgos.** Cambiar el orden de arranque sin darse cuenta.
- **Recomendación: aceptar para después**, cuando el gate y las pruebas que rompen estén.
- **Hay que decidir.** Si se hace primero en el template y luego se hereda, como propone.

### #133 Spike Wally 0.4 frente a pesde

- **Qué es.** Instalar una dependencia real (`trove` o `signal`) con Wally 0.4 alpha y con pesde, medir y decidir.
- **Para qué sirve.** Hoy el estudio vendoriza todo. Mientras el único paquete externo sea ProfileStore, eso es correcto; el cambio se justifica cuando entre la primera dependencia de registro.
- **Si no se hace.** Nada se rompe. El ADR 0028 queda aprobando Wally "sin instalar nada". Wally estable es la 0.3.2 de junio de 2023; pesde está activo.
- **Dueño y esfuerzo.** Victor. S.
- **Depende de / desbloquea.** No depende de nada. Desbloquea usar paquetes externos.
- **Riesgos.** Ejecutar código de terceros sin leerlo; el ADR 0028 lo prohíbe y el issue lo repite.
- **Recomendación: aceptar para después**, cuando de verdad vayamos a usar `trove` o `signal`.
- **Hay que decidir.** Si queremos depender de un registro, o seguir vendorizando.

---

## Kits y Drive

### #138 README en las carpetas del Drive

- **Qué es.** Un `LEEME.md` en cada una de las 8 carpetas sin uno (10-kits, 20-investigacion, 30-video, 40-audio, 50-arte, 60-legacy, 70-redes, 90-archivo) y una guía de entrada corregida (sin `INDEX.json` ni `LibreriaRbx`, con 15-reuniones y 35-beta-testing).
- **Para qué sirve.** Que quien llegue al Drive sepa qué va en cada carpeta y cómo se nombra.
- **Si no se hace.** La guía de entrada sigue mencionando archivos que ya no existen.
- **Dueño y esfuerzo.** Leon (el Drive es suyo). S: solo texto, nada se borra.
- **Depende de / desbloquea.** Nada. Conviene hacerla junto con #139 y #140 para no editar los mismos archivos tres veces.
- **Riesgos.** Casi ninguno; el issue prohíbe borrar.
- **Recomendación: aceptar ahora.**
- **Hay que decidir.** Que Leon confirme las reglas de nombre que cada carpeta va a declarar.

### #139 Limpiar `_prueba`, renombrar `icons` y mover audio

- **Qué es.** Mandar `15-reuniones/_prueba` a la papelera, renombrar `icons` a `icons-tabler-phosphor` (con licencia MIT y `ships`), y mover `sfx-roblox-audio-pack`, `kenney-impact-sounds` y `2026-11-08-music` a `40-audio` con su manifiesto.
- **Para qué sirve.** Quita ruido y deja cada cosa donde la guía dice.
- **Si no se hace.** Seguimos con carpetas de prueba y audio en lugares inconsistentes.
- **Dueño y esfuerzo.** Leon. S, pero el renombre cambia el slug: hay que actualizar manifiesto y nota del vault a la vez con `kits.ps1 push`.
- **Depende de / desbloquea.** El valor de `ships` de `icons` depende de la regla de #141. Va bien junto con #138 y #140.
- **Riesgos.** Romper el slug de `icons` en el manifiesto. Solo a la papelera y solo con el sí de Leon.
- **Recomendación: aceptar después de #141.**
- **Hay que decidir.** El sí de Leon para la papelera y el renombre.

### #140 Archivar kits contenidos en otro kit

- **Qué es.** Mover a `90-archivo` los kits duplicados (`ui-icon-pack`, `picture-to-roblox-model`, `roblox-maps`, `studs-icon-pack`, `roblox-art-pipeline`, y de forma opcional `roblox-ui-references`), conservando su manifiesto.
- **Para qué sirve.** Aclarar qué es fuente y qué es copia. El ahorro es de unos 37 MB (200 MB con `roblox-ui-references`); el issue dice que es aclarar, no ahorrar.
- **Si no se hace.** Seguimos con duplicados, con riesgo de editar la copia en vez de la fuente.
- **Dueño y esfuerzo.** Leon. S.
- **Depende de / desbloquea.** Nada. Se agrupa con #138 y #139.
- **Riesgos.** Que alguien use un kit archivado; si se archiva `roblox-ui-references` hay que avisar a quien lo use.
- **Recomendación: aceptar para después.** Ganancia baja.
- **Hay que decidir.** Si entra `roblox-ui-references` en el archivo.

### #141 ADR: regla de `ships` frente a licencia desconocida

- **Qué es.** Reconciliar `docs/drive.md` (sin licencia, `ships: no`) con la decisión 0019 del vault (`ships: yes`) y aplicarlo al manifiesto. La investigación propone tres opciones: A (mantener 0019 y cambiar `drive.md`), B (mantener `drive.md` y reabrir 0019) y C (un tercer valor `prototype`: sirve para probar, no para lanzar). Recomienda C.
- **Para qué sirve.** Hoy dos reglas chocan y `ships: yes` no significa "se puede publicar". Hay casos peores: `lift-rock-models` (672 MiB) trae personajes de otra serie sin licencia y está marcado `yes`.
- **Si no se hace.** Un juego monetizado puede lanzar con material sin permiso y recibir un reclamo.
- **Dueño y esfuerzo.** Victor (la decisión 0019 es suya). S: el ADR. El cambio posterior en `kits.ps1`, `KitManifest.validate` y el manifiesto es más trabajo, y el issue no lo estima.
- **Depende de / desbloquea.** Desbloquea #139 y #143, y se junta con #142 porque ambas editan el manifiesto.
- **Riesgos.** Con la opción B, 20 kits pasan a `no` hasta que alguien lea su licencia, y los que usan los juegos hoy quedan sin permiso. Con C hay que tocar tres piezas.
- **Recomendación: aceptar ahora**, empezando por `lift-rock-models`.
- **Hay que decidir.** A, B o C, y qué hacer con `lift-rock-models`.

### #142 Campo `categoria` en el manifiesto de 10-kits

- **Qué es.** Agregar a cada una de las 36 filas de `10-kits/manifest.json` el campo `categoria` (ui, iconos, audio, modelos3d, animacion, vfx, herramientas, conocimiento, referencia), y que `kits.ps1 status` la muestre.
- **Para qué sirve.** Agrupar los 36 kits por tema sin renombrar nada ni cambiar rutas. Es la opción A de la investigación; las otras (subcarpetas o prefijos) rompían rutas ya usadas.
- **Si no se hace.** Seguimos con una lista plana. Nada se rompe.
- **Dueño y esfuerzo.** Victor. S.
- **Depende de / desbloquea.** Se pisa con #141, porque ambas tocan `manifest.json` y `kits.ps1`. Sirve a #143.
- **Riesgos.** Mínimos; si hay más de unos 60 kits la opción deja de bastar.
- **Recomendación: juntarla con #141** en una sola PR de manifiesto.
- **Hay que decidir.** Si la lista de nueve categorías es la correcta; la define Leon en la práctica porque UI e iconos son suyos.

### #143 Kits CC0 de Kenney al Drive

- **Qué es.** Sumar Nature Kit, Particle Pack e Interface Sounds (y los que Leon elija) a `10-kits` o `40-audio` con `kits.ps1 push`, con licencia CC0 anotada.
- **Para qué sirve.** Material con licencia limpia para el juego de lago o mar.
- **Si no se hace.** El juego usa lo que ya hay, parte con licencia dudosa (ver #141).
- **Dueño y esfuerzo.** Victor (etiqueta `owner:victor`), pero Leon elige qué entra. S. El issue deja pendiente aparte consultar el Creator Store con `search_asset`.
- **Depende de / desbloquea.** Mejor después de #141 y #142, para que los kits nuevos nazcan con regla y categoría.
- **Riesgos.** Abrir un archivo en Studio o Blender antes de leerlo; el issue lo prohíbe.
- **Recomendación: aceptar para después**, cuando el juego de lago o mar tenga fecha.
- **Hay que decidir.** Qué paquetes entran, y Leon decide.

---

## Crecimiento y arte fuera de Roblox

Estas cuatro y #124 comparten una regla: nada pagado ni tráfico comprado durante la cohorte de prueba (decisión 0038 del vault), y ninguna recompensa por unirse hasta confirmar las normas de Roblox.

### #117 Montar el Discord del estudio

- **Qué es.** Un servidor en modo Community con reglas, canal de anuncios, onboarding, roles Probador y Estudio, y una política de invitaciones por escrito.
- **Para qué sirve.** Un lugar donde probadores y jugadores hablan con el estudio, y un enlace para las tres ranuras sociales de la página del juego.
- **Si no se hace.** No hay comunidad propia fuera de Roblox. El issue no dice cuánto daña eso al crecimiento.
- **Dueño y esfuerzo.** Nande. M.
- **Depende de / desbloquea.** Depende de revisar la política de invitaciones de Roblox; el texto de las normas no se pudo leer en la investigación (403). Desbloquea #118 y #119 (el ícono es para el Discord).
- **Riesgos.** Roblox puede moderar chats o descripciones que publiquen invitaciones. La investigación cita una sola fuente sobre las condiciones de Community.
- **Recomendación: aceptar para después**, cuando exista algo que probar con gente.
- **Hay que decidir.** Quién administra el servidor y quién modera.

### #118 Share links por canal y calendario de live ops

- **Qué es.** Una convención para nombrar los enlaces de compartir por canal (clip, creador, Discord) con LaunchData, más una plantilla de calendario de eventos y actualizaciones de 4 semanas.
- **Para qué sirve.** Saber de dónde viene cada visita. El resultado se ve en Acquisition del panel.
- **Si no se hace.** Las visitas llegan sin origen.
- **Dueño y esfuerzo.** Nande. S: es una nota con una convención y una plantilla.
- **Depende de / desbloquea.** Nada fuerte. Se beneficia de #117 y #120, que generan los canales.
- **Riesgos.** Respetar los límites oficiales (máximo 10 eventos en curso o próximos, avisos de 60 caracteres cada 3 días).
- **Recomendación: aceptar para después.**
- **Hay que decidir.** Cuántos canales se miden al inicio.

### #119 Kit visual de comunidad y redes

- **Qué es.** Propuesta de ícono, banner y plantilla de anuncio 16:9 para la comunidad y el Discord, con dos o tres opciones y su razón, en el Drive. Solo propone; decide Leon.
- **Para qué sirve.** Identidad visible en las páginas de comunidad.
- **Si no se hace.** Se usan imágenes provisorias.
- **Dueño y esfuerzo.** Leon. M.
- **Depende de / desbloquea.** Depende de #117 (el Discord pide ícono). El ícono mínimo es 512x512.
- **Riesgos.** Nada copiado de otros estudios (barra de diseño propia).
- **Recomendación: aceptar para después**, junto con #117.
- **Hay que decidir.** Si Leon quiere hacerlo ahora o prefiere esperar al nombre del juego.

### #120 Plantilla de clip vertical 9:16

- **Qué es.** Una plantilla de clip vertical con la acción central en los 3 primeros segundos y el nombre del juego en el texto, con dos ejemplos hechos con captura propia. Solo propone; decide Leon.
- **Para qué sirve.** Clips con gancho para TikTok, Shorts y Reels.
- **Si no se hace.** Cada clip se arma desde cero.
- **Dueño y esfuerzo.** Leon. M: los ejemplos exigen capturas del juego.
- **Depende de / desbloquea.** Necesita gameplay propio grabado. Alimenta los canales de #118. Se revisa contra la barra G6 del vault.
- **Riesgos.** Los clips son gameplay real y se publican a mano; no se automatiza.
- **Recomendación: aceptar para después**, cuando haya una build que grabar.
- **Hay que decidir.** Quién graba y quién publica.

---

## Qué tendría que decidir el equipo primero

1. Victor: A, B o C para `ships` (#141). Bloquea #139 y #143.
2. Victor: si los tres de datos (#131, #129, #130) van juntos y cuándo existe la place de desarrollo (también sirve a #126).
3. Victor y Nande: tiempo de respuesta para fallas S0 y dónde vive la ficha en Notion (#124).
4. Leon: el sí al orden del Drive (#138, #139, #140) y a la lista de categorías (#142).
5. Nande y Leon: si el Discord y el kit visual (#117, #119) esperan a que haya una build jugable.
