# 0005. Sin tope de trabajo en curso: cada persona configura su sistema

- Estado: aceptado 2026-11-13
- Fecha: 2026-11-13
- Decide: Victor
- Supersede: la parte de `wip` (1 por defecto) de [0003](0003-agentes-que-toman-trabajo-solos.md)
- Refs: studio#93, roblox-game-template#229

## Contexto
El ADR 0003 dejó `wip = 1` por defecto: un agente no toma un issue nuevo mientras su persona tenga otro abierto. El 13-11 eso frenó a Victor, que orquesta varios trabajadores en paralelo, cada uno en su rama: `work.ps1 claim 28` respondió "no trabajable" porque #64 seguía abierto. Leon trabaja con su propio sistema y su propio ritmo.

## Opciones consideradas
1. **Tope 1 por defecto (0003).** A favor: obliga a terminar antes de empezar otra cosa. En contra: frena al que trabaja en paralelo y fija desde el repo cómo trabaja cada uno.
2. **Tope distinto por persona fijado en el repo.** A favor: se ajusta a cada uno. En contra: igual decide el repo por la persona, y hay que mantenerlo.
3. **Sin tope por defecto; cada uno pone el suyo en su `puesto.json` si quiere.** A favor: cada uno ve su sistema como quiera y la coordinación queda en el tablero. En contra: nada impide tomar demasiado a la vez.

## Decisión
Opción 3, por pedido de Victor: "sin topes ni nada definido para nadie, cada quien ve su sistema como quiera, solo se comunican". `claim` y `list` no aplican tope si `puesto.json` no trae `wip`. Si lo trae, se respeta.

## Consecuencias
- Positivas: el trabajo en paralelo (orquestador con trabajadores) no choca con la herramienta. El repo no decide cómo trabaja cada persona.
- Negativas: alguien puede tener muchos issues tomados a la vez y otro no ver qué está libre. Lo mitigan el lease de 24 h sin PR ni commits, el tablero y el aviso al tomar.
- Qué haría revisar esta decisión: issues tomados que se vencen seguido o que bloquean a otro. En ese caso, cada persona se pone su propio tope.
