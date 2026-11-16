# 0008: Notion solo refleja issues, no pull requests

- **Estado:** aceptado (decisión de Victor del 16-11-2026, opción A de studio#181)
- **Fecha:** 2026-11-16
- **Relacionados:** studio#181, ADR 0065 (espejo a Notion, no se edita), [sistema-que-escala.md](../sistema-que-escala.md)

## Contexto

Desde el 16-11 00:45 UTC el espejo falla con `restricted_resource: This workspace has used all of its free blocks`. El plan Free de Notion limita los bloques de un espacio con 2 o más miembros ([precios de Notion](https://www.notion.com/pricing)): al llegar al tope se edita lo existente pero no se crean filas. La base GitHub tenía 1.110 filas: 574 issues y 536 PR (460 merged, 61 open, 11 closed, 4 draft). Los PR son casi la mitad y nadie los lee en Notion; el historial completo está en GitHub.

## Opciones evaluadas

| Opción | Qué se pierde |
|---|---|
| A. Espejar solo issues y archivar las filas de PR | El historial de PR en Notion |
| B. Borrar a mano contenido viejo y dejar el espejo igual | Se vuelve a llenar en semanas |
| C. Apagar el espejo | La vista de tareas en Notion |

## Decisión

Opción A. `notion-mirror.yml` deja de escuchar `pull_request`; `notion-mirror.mjs` y `notion-sync.mjs` devuelven `null` para un PR y no escriben nada. Las filas de PR ya creadas se archivan a mano (Notion las manda a la papelera, 30 días para recuperarlas).

## Consecuencias

- Positivas: se libera casi la mitad de los bloques usados, el espejo puede volver a crear filas de issues y hay menos eventos de Actions.
- Negativas: Notion ya no muestra el estado de los PR. El valor `pull request` queda como opción sin uso en la columna Kind.
- Pendiente: `roblox-game-template` tiene su propia copia de `notion-mirror.yml` y no se sincroniza sola; hay que aplicarle el mismo cambio.
