# 0009. CI, visibilidad de repos y control de versiones de la organización

Estado: propuesto (2026-11-16). Detalle y mediciones: `docs/plan-ci-y-visibilidad.md`.

## Contexto

Plan Free con 2.000 minutos al mes en privados (918 usados al 16-11), rulesets solo en públicos (la API responde 403 en privados) y un runner propio `victor-pc`. Issues #187 y #168.

## Opciones evaluadas

| Opción | Minutos | Protección de ramas | Costo | Riesgo |
|---|---|---|---|---|
| A. Todo privado | agota el cupo con la matriz de 3 sistemas | sin rulesets | 0 | cupo |
| B. Mixto: públicos studio, plantilla y .github; juegos, vault y arte privados con runner propio | unos 300 a 500 | rulesets donde hay código abierto | 0 | el PC es punto único de falla |
| C. Plan Team | 3.000 | rulesets en privados | 12 USD al mes con 3 personas | contradice la regla de no pagar |

## Decisión

B. Fallback: la variable de organización `CI_RUNNER` pasa a `ubuntu-latest`. Squash a `develop`, merge commit solo en el release, rebase apagado, ramas borradas por `delete_branch_on_merge` en públicos y por un job de poda en privados.

## Consecuencias

Positivas: costo cero, minutos con holgura, historia limpia. Negativas: en privados el push directo se detecta y no se impide; `studio` expone `docs/`; con el PC apagado los gates se frenan o cuestan minutos.
