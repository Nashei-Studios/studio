# Studio: el centro de Nashei Studios

Este repo no tiene código de juego. Es la puerta de entrada del estudio: aquí están las reglas comunes, el mapa de dónde vive cada cosa, las conversaciones de toda la organización (Discussions) y el tablero de avisos (Agent Board).

Si eres nuevo, lee en este orden:

1. [docs/guia-10-min.md](docs/guia-10-min.md): cómo se trabaja, en 10 minutos.
2. [CONTEXT.md](CONTEXT.md): el documento de contexto. Se le pasa a la IA antes de pedirle cualquier cosa.
3. [docs/acuerdos.md](docs/acuerdos.md): los acuerdos del equipo (horas, bloqueos, cuándo se cierra un juego).
4. [docs/ecosistema.md](docs/ecosistema.md): qué repo, qué carpeta de Drive y qué página de Notion sirve para qué.

## Qué es y qué no es

| Es | No es |
|---|---|
| Reglas y acuerdos que valen para todos los juegos | El código de un juego (cada juego tiene su repo) |
| Discussions de toda la organización | El lugar de las tareas de un juego (van en los Issues de ese juego) |
| El tablero de avisos entre personas y agentes del estudio | Un almacén de arte o videos (van en Drive, ver el mapa) |
| La guía para conectar Notion y sumar a una persona nueva | La investigación de mercado (vive en `roblox-vault`) |

## Repos de la organización

| Repo | Para qué | Quién lo toca |
|---|---|---|
| [`studio`](https://github.com/Nashei-Studios/studio) | Reglas, acuerdos, Discussions, Agent Board | Todos |
| [`roblox-game-template`](https://github.com/Nashei-Studios/roblox-game-template) | La plantilla de la que nace cada juego: guardado, tienda, UI, pruebas, CI | Victor y sus agentes; cualquiera propone por PR |
| [`roblox-vault`](https://github.com/Nashei-Studios/roblox-vault) | Investigación, decisiones, referentes medidos y la nota de cada juego | Todos leen; se escribe por PR |
| [`drain-for-loot`](https://github.com/Nashei-Studios/drain-for-loot) | El juego en curso | El equipo, según los dueños por carpeta |
| [`plus-one-mining`](https://github.com/Nashei-Studios/plus-one-mining) | Juego 1, cerrado. Queda como referencia de código y de errores | Solo lectura |
| [`.github`](https://github.com/Nashei-Studios/.github) | El perfil público de la organización | Victor |

## Árbol de este repo

```
studio/
├── README.md            esta página
├── CONTEXT.md           documento de contexto para las IA de todos
├── AGENTS.md            reglas para agentes que trabajen en este repo
├── docs/
│   ├── guia-10-min.md   cómo se trabaja, para quien llega
│   ├── acuerdos.md      acuerdos del equipo y los que faltan por cerrar
│   ├── ecosistema.md    mapa: GitHub, Notion, Drive, Roblox
│   ├── notion.md        cómo conectar Notion y qué estructura lleva
│   ├── sumar-persona.md pasos para agregar a alguien al estudio
│   └── hackathon.md     el mismo sistema en un solo repo, para un proyecto corto
└── .github/
    └── ISSUE_TEMPLATE/  acuerdo por cerrar, pedido de acceso, tablero
```

## Cómo se agrega algo

- Una regla nueva para todos: PR a `CONTEXT.md` o a `docs/acuerdos.md`, y se avisa en el Agent Board.
- Una duda o una idea que no es de un juego en particular: Discussions de este repo.
- Una tarea de un juego: Issue en el repo de ese juego, no aquí.

## Prohibido en este repo

- Secretos de cualquier tipo: tokens, claves, contraseñas. Tampoco capturas donde se vean.
- Código de juego, modelos, texturas, audio o video.
- Decisiones de dinero (Robux, anuncios) sin que quede escrito quién las aprobó.
