# Plan de CI, visibilidad y control de versiones de la organización

Estado: borrador parcial del 2026-11-16. Las secciones marcadas "pendiente" se completan en commits siguientes. Refs studio#187 y studio#168.

## 1. Qué es y qué no es

Es el plan por etapas para tres cosas: qué repos son públicos o privados, cómo los 2.000 minutos de Actions del plan Free alcanzan todo el mes, y cómo todos los repos heredan el mismo control de versiones. No cambia visibilidades, no archiva repos, no toca secretos ni facturación y no borra ramas: eso queda como paso con su comando en la sección 7.

## 2. Medido el 2026-11-16

Fuente de minutos: `gh api "/organizations/Nashei-Studios/settings/billing/usage?year=2026&month=11"` (la API solo devuelve desde el 11-11, 57 filas agregadas).

| Repo | Visibilidad | Minutos Linux | Descuenta de los 2.000 |
|---|---|---|---|
| drain-for-loot | privado | 762 | sí |
| roblox-vault | privado | 78 | sí |
| plus-one-mining | privado | 24 | sí |
| project-template | privado | 15 | sí |
| claude-toolkit | privado | 11 | sí |
| art | privado | 10 | sí |
| 3 legacy | privados | 6 cada uno, 18 en total | sí |
| **Total privados** | | **918 de 2.000 (46 %)** | |
| studio | público | 673 Linux, 570 Windows, 523 macOS | no |
| roblox-game-template | público | 233 | no |
| .github | público | 43 | no |

Dato: el neto facturado es 0 USD en todas las filas; el descuento lo absorbe el plan.

### Ajustes de merge antes de aplicar (`gh api repos/Nashei-Studios/<repo>`)

| Repo | Visib. | delete_branch_on_merge | squash | merge commit | rebase | Ramas |
|---|---|---|---|---|---|---|
| roblox-game-template | público | true | true | true | true | 11 |
| roblox-vault | privado | false | true | true | true | 10 |
| plus-one-mining | privado | false | true | true | true | 3 |
| studio | público | true | true | true | true | 2 |
| .github | público | true | true | true | true | 2 |
| drain-for-loot | privado | false | true | true | false | 11 (hoy 3, ver sección 6) |
| claude-toolkit | privado | false | true | true | false | 2 |
| legacy-grassgame | privado | false | true | true | false | 2 |
| legacy-bowl-brawl | privado | false | true | true | false | 2 |
| legacy-drain-the-sea | privado | false | true | true | false | 2 |
| project-template | privado | false | true | true | false | 3 |
| art | privado | false | true | true | false | 2 |

Organización: plan `free`, verificación en dos pasos NO exigida (`two_factor_requirement_enabled=false`), pendiente de decidir con Victor.

## 3. Visibilidad repo por repo

Pendiente: tabla final con lo que se gana y se pierde. Base: `docs/sistema-que-escala.md` sección 3 y #168. [POR VERIFICAR] si los rulesets se aplican en privados Free (la API respondió 403 según la skill `github-integrado`).

## 4. Presupuesto de minutos y proyección

Pendiente: desglose por workflow (la medición de `gh run list` corre en segundo plano). Base: tabla de la sección 2 y proyección de `docs/sistema-que-escala.md`.

## 5. Qué corre dónde y fallback

Pendiente. Regla de partida: privados al runner propio `victor-pc`; públicos en runners estándar gratis; con el PC apagado, cambiar la variable de organización a `ubuntu-latest` con aviso al 75 %. Riesgo: un runner propio en repo público ejecuta código de PR de forks, por eso solo se usa en privados.

## 6. Por qué se acumulan ramas

Pendiente. Hipótesis a confirmar: el merge con `GITHUB_TOKEN` no dispara `delete_branch_on_merge`, los repos privados lo tienen apagado a propósito (incidente del 2026-11-12 con `develop`), y los worktrees y borradores dejan ramas.

## 7. Etapas

Pendiente: etapas 1 a 4 con criterio de aceptación y comando por paso.

## 8. Lo aplicado hoy

Pendiente.
