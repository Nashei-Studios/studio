# Sumar a una persona al estudio

Lo hace un dueño de la organización. Criterio de listo al final de cada paso.

| # | Paso | Listo cuando |
|---|---|---|
| 1 | Pedirle su usuario de GitHub | Está escrito en el issue "Pedido de acceso" |
| 2 | Invitarla: github.com/orgs/Nashei-Studios/people, Invite member, rol Member | Aparece en People después de aceptar |
| 3 | Agregarla al equipo que corresponda (`dev` o `arte`) | Sale en la lista del equipo |
| 4 | Reemplazar su marcador (`<NANDE_GH>`, `<LEON_GH>`) en `AGENTS.md` y `.github/CODEOWNERS` de cada juego, por PR | La PR está mergeada |
| 5 | Crear su etiqueta `owner:<nombre>` si no existe | La etiqueta aparece en el repo del juego |
| 6 | Darle acceso al Team Create del juego en Studio | Puede abrir el place |
| 7 | Invitarla al workspace de Notion y a la carpeta de Drive | Ve la portada y la carpeta |
| 8 | Que cree sus llaves de Roblox (una por persona, de usuario, nunca de grupo: Creator Hub las desaconseja) en create.roblox.com/credentials, con acceso solo a la experiencia del juego, y las guarde ella misma con los comandos de `docs/primera-vez.md`, sección 4b. El agente nunca ve el valor | `puesto.ps1 check` marca PASA en `ROBLOX_API_KEY` y `ROBLOX_MONETIZATION_API_KEY` |
| 9 | Que se una a https://www.roblox.com/communities/405835365 y un admin le dé rol | Aparece en los miembros de la comunidad con su rol |
| 10 | Que lea `docs/guia-10-min.md` y deje un mensaje en el Agent Board | Hay un comentario suyo en el tablero |

Si falla el paso 2 (no llega la invitación): revisa que el usuario esté bien escrito y reenvíala desde People, Pending invitations.

Permisos: por defecto los miembros tienen escritura en todos los repos de la organización. Nadie fuera del estudio ve los repos privados.
