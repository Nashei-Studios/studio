# Sistema que escala: qué vive dónde, minutos y visibilidad de repos

Medido el 2026-11-16 con la API de GitHub y con Notion. Es una propuesta: nada de lo que dice la sección 3 está aplicado. Las decisiones que dependen del equipo están en el issue `needs-team` que enlaza este documento.

## 1. Qué vive dónde

Una sola fuente de verdad por cosa. Lo demás son copias de lectura.

| Cosa | Fuente de verdad | Copias | Por qué |
|---|---|---|---|
| Código de juegos y herramientas | Repo de GitHub | Clon local | Historial, PR, pruebas |
| Tareas, dudas, avisos | Issues, Discussions y Agent Board (studio#1) | Notion (solo issues, ADR 0008) | Una tarea, un dueño |
| Estado de todo el estudio | Project v2 de la organización | Ninguna | Un solo tablero |
| Reglas y decisiones del estudio | `docs/` y `docs/adr/` de `studio` | Ninguna | Se revisan por PR |
| Investigación y decisiones de juego | `roblox-vault` (privado) | Ninguna | No debe ser público |
| Arte pesado, kits, audio, video | Drive del estudio (dueña: Leon) | Copia local con `kits.ps1` | Git no versiona bien binarios |
| Entregables para leer (guías, informes) | Drive o `docs/`, según quién los edite | Notion si hace falta | Lectura sin cuenta de GitHub |
| Vista de lectura para el equipo | Notion, base GitHub (espejo) | No se edita ahí | Solo lectura (ADR 0065) |
| Ids de Drive y Notion, lista de repos | `config/ecosistema.json` | Ninguna | Los scripts la leen |

Reglas que salen de la tabla: lo que se edita en Notion se pierde en el próximo evento de GitHub; ningún archivo de más de unos pocos MB entra a Git; el vault y los juegos no se publican.

## 2. Minutos de Actions

### Límites del plan Free

Fuente: [facturación de GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

| Límite | Valor |
|---|---|
| Cómputo incluido en privados | 12 USD al mes, que a 0,006 USD por minuto de Linux son unos 2.000 minutos |
| Tarifa por minuto | Linux 0,006 USD, Windows 0,010 USD (1,67 veces), macOS 0,062 USD (10,3 veces) |
| Repos públicos con runner estándar | Gratis, no descuentan |
| Runner propio (self-hosted) | Gratis, no descuenta |
| Artefactos y Packages (compartidos) | 500 MB |
| Caché | 10 GB por repo, aparte |

La página actual no habla de multiplicador sino de tarifa por minuto: las razones de la tabla son cálculo con esas tarifas. Tampoco dice si cada job se redondea al minuto; Victor lo midió como un minuto entero por job (nota de minutos de Actions de Nashei) y se mantiene como supuesto. La cuota de LFS no se verificó en la documentación y queda pendiente si algún juego la necesita.

### Consumo de noviembre

Fuente: API `organizations/Nashei-Studios/settings/billing/usage`, al 16-11.

| Repo | Visibilidad | Minutos | Descuenta |
|---|---|---|---|
| drain-for-loot | privado | 752 | sí |
| roblox-vault | privado | 73 | sí |
| plus-one-mining | privado | 23 | sí |
| project-template | privado | 14 | sí |
| claude-toolkit | privado | 10 | sí |
| art | privado | 9 | sí |
| 3 legacy | privados | 15 | sí |
| **Total privados** | | **896 de unos 2.000** | |
| studio | público | 648 Linux, 559 Windows, 514 macOS | no |
| roblox-game-template | público | 231 | no |
| .github | público | 42 | no |

El runner propio (`victor-pc`, etiquetas `self-hosted`, `nashei`, `windows-x64`) está en línea a nivel de organización. Dato por verificar: el `ci.yml` de `drain-for-loot` sigue declarando `runs-on: ubuntu-latest` en sus jobs, así que hay que confirmar cómo se enruta el gate al runner propio antes de confiar en la proyección.

### Proyección mensual

Es una estimación, no una medición.

| Escenario | Minutos privados al mes | Contra 2.000 |
|---|---|---|
| Sin runner propio, 1 juego (ritmo del 1 al 14-11: 752 en 14 días) | unos 1.600 | 80 %, pasa el umbral |
| Sin runner propio, 2 juegos por mes | unos 3.200 | no alcanza |
| Con runner propio, 1 juego (los otros repos hicieron 144 en 16 días) | unos 300 | 15 % |
| Con runner propio y 2 juegos nuevos por mes (supuesto: 30 minutos por repo en jobs auxiliares) | unos 400 a 500 | 25 % |

Con el runner propio alcanza con holgura; sin él, un solo juego ya se acerca al tope. El gate en el runner propio es lo que sostiene el plan.

### Quién consume más y cómo bajarlo

| Workflow | Dónde | Consumo | Cómo bajarlo |
|---|---|---|---|
| `ci` (gate del juego) | drain-for-loot | 752 | Runner propio (hecho desde el 15-11) |
| `install-smoke`, matriz Linux, macOS y Windows | studio | 1.721 entre los tres sistemas | Gratis mientras `studio` sea público. Si fuera privado, macOS cuesta 10 veces: se deja Linux, y Windows corre solo de noche |
| Jobs auxiliares por evento (`notion-mirror`, `labels`, `stale`, `analytics`) | cada repo | 1 minuto entero por evento | `notion-mirror` pasa a solo issues (esta PR); `notion-sync` central cubre el resto |
| `release`, `audit-push` | cada repo | pocos | Mantener `timeout-minutes` |

Umbral de aviso al 75 %: 1.500 minutos. Propuesta: un cron semanal en el runner propio que lea el uso de facturación y abra un issue `needs-team` si pasa de 1.500. No existe todavía.

## 3. Visibilidad de cada repo (propuesta, no se aplica)

Qué da y qué quita GitHub Free en privados. Fuentes: [planes de GitHub](https://docs.github.com/en/get-started/learning-about-github/githubs-plans) y [acerca de los rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).

- Privado en Free: repos ilimitados con "conjunto limitado de funciones" y 12 USD de cómputo al mes. Los revisores obligatorios y las herramientas avanzadas aparecen solo en Pro y Team. La página de rulesets dice que están disponibles para clientes de Team y Enterprise y no menciona Free.
- Público: Actions gratis con runners estándar, Pages y conjunto completo.
- Pages en privado exige Enterprise Cloud.

Rulesets activos hoy: `studio` tiene `develop` y `production` (reglas: borrar, no avance rápido, PR obligatoria, sin bypass). `roblox-game-template` tiene otros dos con los mismos nombres. Los dos repos son públicos, y eso es lo que permite que se apliquen con Free. Si alguno pasara a privado hay que asumir que dejan de hacerse cumplir; la documentación consultada no lo confirma de forma explícita para Free, así que se prueba en un repo de prueba antes. Lo mismo vale para los repos privados actuales: sus protecciones no son una garantía.

| Repo | Hoy | Recomendación | Se gana | Se pierde |
|---|---|---|---|---|
| studio | público | Público | Rulesets, minutos gratis (1.721 en la matriz), cualquiera del equipo lo clona sin permisos | Todo `docs/` se ve desde fuera, incluidos los ids de Drive y Notion de `config/ecosistema.json` (sin secretos) |
| roblox-game-template | público | Público | Rulesets, template-sync sin token, 231 minutos gratis | Los sistemas reutilizables son visibles; lo que no deba salir no va a la plantilla |
| .github | público | Público | Los workflows reutilizables (`pr-gate`) los llama cualquier repo | Nada relevante |
| drain-for-loot | privado | Privado | El juego no se filtra antes de publicar | Rulesets sin garantía; los minutos descuentan (hoy mitigado por el runner) |
| roblox-vault | privado | Privado | Investigación y decisiones protegidas | Igual que arriba |
| plus-one-mining | privado | Privado, y revisar si sigue vivo (16 issues abiertos, último push el 12-11) | No se filtra | Cuenta en los minutos si tiene CI |
| claude-toolkit | privado | Privado | Herramientas internas | Igual que arriba |
| project-template | privado | Decide el equipo: público permitiría usarlo como plantilla sin token | Plantilla usable por cualquiera | Se publica la forma de trabajo del estudio |
| art | privado | Privado | Arte sin publicar | Igual que arriba |
| legacy-grassgame, legacy-bowl-brawl, legacy-drain-the-sea | privados | Archivar (sin issues abiertos, último push el 12-11) | Menos ruido; un repo archivado es de solo lectura y no consume minutos | No se edita sin desarchivar; es reversible |

## 4. Cómo escala

| Con | Qué pasa | Qué hacer |
|---|---|---|
| 5 juegos | 5 repos privados desde la plantilla, un único Project, template-sync empuja la plantilla a cada uno. Los minutos solo suben si el runner falla | Mantener un Project único (ya es así). Cada repo nuevo nace con el gate apuntando al runner propio |
| 10 juegos | Las ramas `game/*` de la plantilla y los PR de template-sync se multiplican; el espejo de issues crece | Archivar el juego cerrado al terminar su ciclo; podar ramas integradas; vistas del Project por repo |
| Runner propio | Un solo punto de falla: `victor-pc`. Con el equipo apagado los jobs quedan en cola | No hay respaldo documentado. Propuesta: el job lee las etiquetas del runner de una variable de la organización; si el runner está caído se cambia a `ubuntu-latest` (cuenta contra los 2.000) y se avisa al 75 % |
| Notion Free con más de un miembro | Bloques limitados ([precios de Notion](https://www.notion.com/pricing)); la página no da el tope exacto. Al llegar se edita lo existente pero no se agregan bloques. Archivos de hasta 5 MB, historial de 7 días | Ya ocurrió el 16-11 (`restricted_resource`). Espejar solo issues (ADR 0008) y archivar las 536 filas de PR |
| Drive | 15 GB por cuenta gratis, compartidos con Gmail y Fotos, y cuentan contra quien sube el archivo ([ayuda de Google](https://support.google.com/drive/answer/6374270)). Con la cuenta llena no se sube nada | Medir el uso de la cuenta de Leon cada mes; mover a `90-archivo` o a disco local lo que no se use. Si llega al 75 %, decide el equipo |

## 5. Pasos

| N | Paso | Quién | Estado |
|---|---|---|---|
| 1 | Espejo de Notion solo con issues (workflow, script, pruebas, ADR 0008) | Victor y su agente | En la PR que trae este documento |
| 2 | Archivar las 536 filas de PR de la base GitHub de Notion (van a la papelera, 30 días para recuperarlas) | Victor | Pendiente (sección 6) |
| 3 | Mismo cambio en `roblox-game-template/.github/workflows/notion-mirror.yml`: el archivo es idéntico al de `studio` y no se sincroniza solo | Victor y su agente | Pendiente |
| 4 | Confirmar cómo `drain-for-loot` enruta su gate al runner propio | Victor | Pendiente |
| 5 | Cron semanal de minutos con aviso al 75 % | Victor y su agente | Pendiente |
| 6 | Borrar las ramas integradas de la sección 6 | Victor y su agente | Pendiente |
| 7 | Decidir la visibilidad de `project-template` y el destino de `plus-one-mining` | El equipo (2 de 3) | Issue `needs-team` |
| 8 | Archivar los tres repos legacy | El equipo | Issue `needs-team` |
| 9 | Medir el uso del Drive de Leon cada mes | Leon | Propuesto |
| 10 | Probar en un repo de prueba si los rulesets se aplican en privado antes de privatizar algo más | Victor | Propuesto |

Se aplica ya (reversible): 1, 3, 5 y 6. Decide el equipo: 7, 8 y cualquier cambio de visibilidad.

## 6. Limpieza

| Qué sobra | Medido | Acción propuesta |
|---|---|---|
| Filas de PR en la base GitHub de Notion | 536 (460 merged, 61 open, 11 closed, 4 draft); quedan 574 issues | Archivar las filas con `Kind = pull request`. El espejo ya no las vuelve a crear |
| Ramas remotas integradas | `roblox-game-template`: `feat/template-sync`, `feat/tier-model-set`, `fix/place-sync-stable-pwsh-242`. `drain-for-loot`: `dependabot/github_actions/develop/actions/setup-node-7` | Borrarlas |
| Ramas de `drain-for-loot` sin PR integrada | 23 ramas y 18 PR abiertas | No tocar: hay trabajo en curso |
| Artefactos | 0 en `studio`, en la plantilla, en el juego y en el vault | Nada |
| Cachés de `studio` | 34 | Dejarlas: GitHub las expira por antigüedad |
| Repos legacy | 3, sin issues ni actividad desde el 12-11 | Archivar (paso 8) |
| `docs/notion.md` | Marca como "pendiente" la integración que ya funciona | Corregir en una PR aparte |

Nada de esto se borró en esta PR, salvo lo descrito en el paso 1.
