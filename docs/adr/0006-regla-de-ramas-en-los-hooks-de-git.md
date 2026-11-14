# 0006. La regla de ramas la hace cumplir git; el hook del agente solo avisa antes

- Estado: aceptado 2026-11-14
- Fecha: 2026-11-14
- Decide: Victor (pedido del plan vigente, punto 7: seguridad del puesto)
- Amplía: los ADR [0066](https://github.com/Nashei-Studios/roblox-game-template/blob/develop/docs/adr/0066-branch-guard-without-server-rules.md) y [0070](https://github.com/Nashei-Studios/roblox-game-template/blob/develop/docs/adr/0070-no-direct-push-to-develop.md) de la plantilla. El 0070 ya rechazaba el push directo a `develop` en la plantilla y los juegos; el `pre-push` de studio había quedado atrás y aquí se alinea
- Refs: studio#108, PR studio#147, #149 y la de este ADR

## Contexto
"Nunca commitear en `develop` ni en `main`" era una regla escrita, y desde studio#108 también un hook de Claude Code: la guardia de rama lee cada `git commit` y `git push` del comando de Bash o PowerShell. Cuatro rondas de la revisión de seguridad automática encontraron, cada una, otra forma de escribir el mismo commit o push que el parser no veía: `bash -c "git commit"`, un alias, `$( )`, backticks, `remote.origin.push` en la config, un refspec `:`, un escape de PowerShell. Un parser de la shell siempre deja otra forma. Git, en cambio, sabe en qué rama está el commit y qué refs actualiza el push, se haya escrito como se haya escrito el comando. El plan gratis no da reglas de rama del servidor en los repos privados (ADR 0066).

## Opciones consideradas
1. **Seguir endureciendo el parser.** A favor: un solo lugar, mensaje temprano con el comando para crear la rama. En contra: no termina nunca; cada forma nueva de la shell es un hueco hasta la próxima revisión.
2. **La regla en los hooks de git (`pre-commit` y `pre-push`), y el hook del agente solo como aviso temprano que además niega lo que apaga esos hooks.** A favor: git ve la rama y los refs reales, sin depender de cómo se escribió el comando; vale también para personas y otras herramientas. En contra: solo existe donde `core.hooksPath` apunta a `.githooks` (lo instala `puesto.ps1 install` y lo verifica `check`), y `--no-verify`, `commit -n` o `core.hooksPath` lo apagan: eso es justo lo que el hook del agente niega.
3. **Hacer públicos los repos para tener reglas del servidor.** Descartada en el ADR 0066: expone el código de los juegos.

## Decisión
Opción 2.
- `.githooks/pre-commit` rechaza un commit con `HEAD` en `develop` o `main`. Un `HEAD` sin rama (el worktree fijado de los hooks) pasa. Salida de emergencia, dicha antes al equipo: `ALLOW_PROTECTED_COMMIT=1`.
- `.githooks/pre-push` de studio también rechaza un push directo a `develop`, además de `main` y los borrados, como ya hacía la plantilla desde el ADR 0070: `develop` solo avanza por una PR mergeada. Salida de emergencia, la misma de antes: `ALLOW_PROTECTED_PUSH=1`.
- La guardia de rama del agente (`board-hook.ps1 rama`) sigue dando el mensaje temprano con el comando para crear la rama, y además niega en cualquier rama lo que apagaría los hooks de git: `--no-verify`, `commit -n`, `hooksPath`, `ALLOW_PROTECTED_*`, `GIT_CONFIG_*`. También niega lo que no puede leer.
- La plantilla y los juegos reciben el `pre-commit` por `roblox-game-template#265` y `template-sync`. El `pre-push` ya lo tienen.

## Consecuencias
- Positivas: la regla deja de depender de leer la shell; un alias o un script no la saltan. Lo que el agente no puede leer falla cerrado, y lo que sí puede leer recibe un mensaje útil antes de llegar a git.
- Negativas: un repo sin `core.hooksPath` no tiene la regla (la fila `hooks` de `check` lo marca FALLA, y la guardia del agente niega commit y push ahí hasta que corra `install`). Los scripts de `.githooks` corren desde el árbol de trabajo del clon, no desde la copia fijada: cambiarlos exige un commit en una rama de trabajo, que la revisión de la PR ve. La guardia del agente niega algunos comandos legítimos en ramas de trabajo: `--no-verify`, y un `git` dentro de `$( )` o backticks. Hay que escribirlos de otra forma.
- Qué haría revisar esta decisión: reglas de rama del servidor en privados del plan gratis, o un caso que los hooks de git no detengan.
