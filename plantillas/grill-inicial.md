# Grill inicial: qué juego hacemos

Va **antes** del grill de juego (`docs/game/grill.md` del juego, ver [ADR 0001](../docs/adr/0001-una-sola-fuente-para-el-grill.md)). Aquí el grupo elige tema, gimmick y juego entre varios candidatos, y fija la dirección de cada frente. El grill de juego viene después y baja el candidato elegido a spec, épicas e historias.

| | Grill inicial (este) | Grill de juego |
|---|---|---|
| Pregunta | ¿Cuál hacemos y con qué dirección? | ¿Qué entra exactamente en el primer build? |
| Entrada | Mercado, legacy, ideas del vault, kits | El candidato elegido |
| Salida | Una decisión en el vault y un candidato | Spec, épicas, historias, issues, Project |
| Duración | 90 a 120 minutos | 60 a 90 minutos |

## Cómo se usa

1. **Antes de la reunión**, un agente copia esta plantilla a `roblox-vault/research/<aaaa-mm-dd>-grill-inicial-<tema>.md` y rellena todo lo que dice "investigación" con la skill `roblox-analisis-por-frentes`: foto de mercado del día, referentes por frente, legacy e ideas. Cada cifra lleva fuente y fecha. Lo que no está medido se escribe `sin medir`; nunca un valor plausible.
2. **En la reunión**, el grupo recorre las partes en orden y llena las columnas "Decisión". El agente que conduce repregunta lo vago. Lo que no cierra queda `abierto`, con quién lo cierra y cuándo.
3. **Después**, el agente escribe la decisión en `roblox-vault/decisions/`, actualiza la fila en Notion y deja prellenado el grill de juego del candidato elegido.

Reglas: una respuesta por celda; un número siempre con su unidad; el gusto del equipo es un criterio válido y se anota como gusto, no como dato.

| Campo | Valor |
|---|---|
| Fecha de la reunión | |
| Presentes | |
| Quién condujo (persona y agente) | |
| Foto de mercado usada (fecha y hora UTC) | |

## Parte A. Punto de partida

| # | Pregunta | Investigación | Decisión |
|---|---|---|---|
| A.1 | ¿Cuántas horas por semana pone cada persona este mes? | | |
| A.2 | ¿Qué fecha jugable y qué fecha de veredicto nos ponemos? | | |
| A.3 | ¿Qué número nos dice que valió la pena? (jugadores concurrentes, tiempo de juego) | | |
| A.4 | ¿Cuánto Robux hay y quién aprueba gastarlo? | | |
| A.5 | ¿Qué no hacemos, aunque el mercado lo pida? (temas, mecánicas, estilos) | | |

## Parte B. Mercado hoy

La llena el agente; el grupo solo la lee y pregunta.

| # | Qué se mira | Investigación |
|---|---|---|
| B.1 | Géneros por jugadores, cantidad de juegos y parte del primero | |
| B.2 | Juegos de menos de 45 días con más de 250 jugadores (los que rompieron) | |
| B.3 | Familias de nombre que se repiten entre los que rompieron | |
| B.4 | Los que más crecieron entre las dos últimas fotos | |
| B.5 | Qué se está viendo en videos cortos (TikTok, Shorts, Reels) | |
| B.6 | Límites de la muestra | |

## Parte C. Candidatos

Un candidato por fila: los legacy, las ideas del vault, las familias que salen de la Parte B y lo que proponga cualquiera en la reunión. Mínimo cinco, máximo doce.

| # | Candidato | Origen (legacy, vault, mercado, propuesta) | Una frase que entienda alguien de 10 años |
|---|---|---|---|
| C.1 | | | |

### Matriz de comparación

Cada celda es dato con fecha o `sin medir`. La nota de 1 a 5 la pone el grupo en la reunión, no el agente.

| Criterio | Qué se mide | C.1 | C.2 | C.3 | C.4 | C.5 |
|---|---|---|---|---|---|---|
| ¿El tipo crece? | Juegos jóvenes sobre 250 jugadores en su familia | | | | | |
| ¿Queda espacio? | Parte de los jugadores que tiene el primero | | | | | |
| Gancho de video | Qué se ve en 3 segundos; ¿alguien lo grabaría solo? | | | | | |
| Servidor vacío | ¿Se disfruta con un solo jugador? | | | | | |
| Cabe en 7 a 10 días | Qué trae la plantilla y qué hay que construir | | | | | |
| Lo que ya tenemos | Legacy, kits y moldes que sirven tal cual | | | | | |
| Gusto del equipo | Quién lo quiere hacer | | | | | |
| Riesgo principal | Lo que más probablemente lo mata | | | | | |
| **Nota del grupo (1 a 5)** | | | | | | |

| # | Pregunta | Decisión |
|---|---|---|
| C.a | ¿Qué candidatos se descartan hoy y por qué? | |
| C.b | ¿Cuál es el elegido y cuál el segundo, por si el primero falla? | |
| C.c | ¿Qué dato nos haría cambiar al segundo antes de construir? | |

## Parte D. Dirección por frente

Para el candidato elegido. En cada frente: qué hacen los referentes, las opciones y la decisión. Si un frente no se alcanza a decidir, queda `abierto` con dueño.

### D.1 Tema y gimmick

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.1.1 | ¿Cuál es el gimmick? La única cosa que lo distingue del que va ganando | | | |
| D.1.2 | ¿El gimmick se ve en una imagen quieta? | | | |
| D.1.3 | ¿Qué referente lo hace parecido y cómo le va? | | | |

### D.2 Loop y estructura

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.2.1 | ¿Continuo, por rondas o mixto? | | | |
| D.2.2 | El loop en cinco verbos | | | |
| D.2.3 | ¿Qué se queda para siempre y qué se pierde? | | | |
| D.2.4 | ¿Tiene techo? ¿Qué pasa al llegar? | | | |

### D.3 Primer minuto

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.3.1 | ¿Qué hace el jugador en los primeros 10 segundos sin leer? | | | |
| D.3.2 | ¿En qué segundo llega la primera recompensa? | | | |
| D.3.3 | ¿Qué ve de otro jugador antes del segundo 30? | | | |

### D.4 Dirección artística

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.4.1 | Estilo en una frase y tres imágenes de referencia | | | |
| D.4.2 | Paleta (5 colores) e iluminación | | | |
| D.4.3 | ¿Qué sale de kits y qué se modela? | | | |
| D.4.4 | ¿Quién tiene la última palabra en arte? | | | |

### D.5 Mundo y mapa

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.5.1 | ¿Cuántas zonas tiene el primer build y de qué tamaño? | | | |
| D.5.2 | ¿Hay lobby? ¿Qué se ve al aparecer? | | | |
| D.5.3 | ¿Cada cuánto llega una zona nueva después del lanzamiento? | | | |

### D.6 Personaje, animación y movimiento

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.6.1 | Velocidad y forma de moverse (correr, nadar, vehículo) | | | |
| D.6.2 | ¿Qué animaciones propias necesita el primer build? | | | |
| D.6.3 | ¿Qué efecto se ve al hacer la acción principal? | | | |

### D.7 UI y controles

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.7.1 | Botones del HUD (máximo 6 en PC y 4 en celular) | | | |
| D.7.2 | ¿De qué kit sale la UI? | | | |
| D.7.3 | Controles: ¿algo fuera del estándar de los referentes? | | | |

### D.8 Música y sonido

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.8.1 | Estilo de música y de dónde sale, con licencia | | | |
| D.8.2 | Los tres sonidos que más se van a oír | | | |

### D.9 Economía y monetización

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.9.1 | Monedas y en qué se gastan | | | |
| D.9.2 | ¿Hay rareza o azar? Las probabilidades se muestran | | | |
| D.9.3 | Pases y productos del primer build y su precio de partida | | | |
| D.9.4 | ¿Qué se vende que no rompa el juego para quien no paga? | | | |

### D.10 Social

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.10.1 | Jugadores por servidor | | | |
| D.10.2 | ¿Qué razón hay para entrar con un amigo? | | | |
| D.10.3 | ¿Qué se puede mostrar a los demás? | | | |

### D.11 Crecimiento y video

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.11.1 | ¿De dónde vienen los primeros 250 jugadores, sin pagar? | | | |
| D.11.2 | ¿Qué momento del juego se graba solo? | | | |
| D.11.3 | ¿Quién graba y publica, en qué red y cada cuánto? | | | |
| D.11.4 | ¿De dónde saca su tráfico el referente que va ganando? | | | |

### D.12 Nombre y página

| # | Pregunta | Investigación | Opciones | Decisión |
|---|---|---|---|---|
| D.12.1 | Título de trabajo y tres alternativas (el final sale de `roblox-naming`) | | | |
| D.12.2 | ¿Qué muestra el ícono y la miniatura? | | | |

## Parte E. Legacy: qué se rescata

Una fila por experiencia anterior del equipo. No se rescata por cariño: se rescata lo que ahorra días.

| Experiencia | Qué tiene hecho | Estado del archivo | Qué se reutiliza en el elegido | Qué se archiva |
|---|---|---|---|---|
| | | | | |

## Parte F. Equipo y calendario

| # | Pregunta | Decisión |
|---|---|---|
| F.1 | Dueño de cada frente (código, UI, arte, mundo, audio, crecimiento) | |
| F.2 | Fecha del grill de juego | |
| F.3 | Fecha de inicio de construcción y fecha jugable | |
| F.4 | Fecha y umbral del veredicto | |
| F.5 | ¿Cada cuánto nos juntamos y por dónde? | |

## Qué se genera de este documento

| De la parte | Sale | Dónde |
|---|---|---|
| C y D.1 | Decisión numerada: candidato elegido, segundo y qué los cambiaría | `roblox-vault/decisions/` |
| C (descartados) | Notas de idea con el motivo, para no repetir la discusión | `roblox-vault/ideas/` |
| D | Grill de juego prellenado con estas decisiones | `roblox-vault/games/<slug>/grill.md` |
| E | Un issue por cosa que se rescata | Repo del juego |
| A, F | Fila del juego con fechas y dueño | Base Proyectos de Notion |
| Cada `abierto` | Issue de acuerdo con quién lo cierra y cuándo | `studio`, etiqueta `acuerdo` |
| B | Foto de mercado y referentes | Base Referentes de Notion y `roblox-vault/research/` |
