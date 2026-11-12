# Cómo se versiona en el estudio

Es igual en los 12 repos. No hay que memorizarlo: si falta algo, el chequeo de la PR te dice qué.

## Lo que haces tú (o tu agente)

1. **Un issue por trabajo.** Si no existe, lo abres con el formulario.
2. **Una rama desde `develop`**: `git switch -c feat/lo-que-sea origin/develop`.
3. **Una PR a `develop`** (`gh pr create --base develop`):
   - título en inglés con formato `tipo(área): qué hace`, por ejemplo `feat(shop): add the daily offer`;
   - en el cuerpo, `Closes #12` (o `Refs #12` si no lo cierra).
4. Nada más. Si los chequeos pasan, la PR se mergea sola, se borra la rama y se cierra el issue.

Para frenar una PR: déjala como borrador o ponle la etiqueta `hold`.

## Lo que pasa solo

| Qué | Cuándo |
|---|---|
| Merge con squash a `develop` | Al quedar la PR en verde |
| Release: `develop` pasa a `main`, tag `vX.Y.Z`, `CHANGELOG.md` y GitHub Release | Los lunes si hubo cambios, o a pedido con `gh workflow run release.yml` |
| Cierre de PR abandonadas | Con conflicto 14 días o sin actividad 30 (la etiqueta `keep` la salva) |
| Aviso si alguien empuja directo a `main` o `develop` | En el momento, como issue |

## Lo que no se hace

- Empujar directo a `main` o a `develop`. En los repos públicos GitHub lo impide; en los privados el
  plan gratis no lo impide, pero el hook local lo frena y queda un issue de aviso.
- Mergear a mano `develop` a `main`. Eso lo hace el release.

## Dónde vive

La lógica está una sola vez en [`Nashei-Studios/.github`](https://github.com/Nashei-Studios/.github);
cada repo solo la llama. Ahí está también la comparación con otros sistemas y por qué se eligió este
(`docs/adr/0001`). Un repo nuevo se deja igual con `sync/plant.ps1` de ese repo.

Publicar un juego en Roblox no es parte de esto: se hace desde Studio y lo decide Victor.
