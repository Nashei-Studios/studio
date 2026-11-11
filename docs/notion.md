# Notion: conexión y estructura

Notion es la vista para leer. No se editan tareas ahí: se toman y se cierran en GitHub, y el espejo las copia.

## 1. Conectar la integración (lo hace el dueño del workspace, una vez)

El token de una integración interna sirve para **un solo workspace**. Si el workspace del estudio es nuevo, hay que crear una integración nueva dentro de él; el token de otro workspace da `401 token_invalid`.

1. Entra a <https://www.notion.so/profile/integrations> con la cuenta dueña del workspace del estudio.
2. **New integration**. Nombre: `Nashei Studio Bot`. Associated workspace: el del estudio. Type: **Internal**. Guarda.
3. En **Capabilities** marca Read content, Update content e Insert content. No hace falta información de usuarios.
4. En **Internal Integration Secret** pulsa Show y luego Copy. El token empieza con `ntn_` y tiene unos 50 caracteres. No lo pegues en ningún chat ni archivo.
5. Abre la página raíz del estudio en Notion. Menú `...` arriba a la derecha, **Connections**, busca `Nashei Studio Bot` y agrégala. Con eso la integración ve esa página y todo lo que cuelga de ella. Repite en cualquier otra página suelta que deba ver (por ejemplo la guía del Hackathon Agent Board).
6. Guarda el token como variable de usuario, directo desde el portapapeles, en PowerShell 7:

   ```powershell
   [Environment]::SetEnvironmentVariable('NOTION_TOKEN', (Get-Clipboard -Raw).Trim(), 'User')
   ```

7. Comprueba el largo sin mostrar el valor (debe dar cerca de 50):

   ```powershell
   [Environment]::GetEnvironmentVariable('NOTION_TOKEN','User').Length
   ```

8. Cierra y vuelve a abrir Claude Code. Un programa abierto antes del cambio sigue viendo el valor antiguo.

Si falla: `401` es token de otro workspace o mal copiado (repite 4 a 8); `404` en una página es que falta el paso 5 en esa página.

## 2. Estructura del workspace

Todo cuelga de una página raíz, para que se pueda duplicar entera como plantilla.

```
Nashei Studios (raíz)
├── Empieza aquí        guía de 10 minutos y enlaces a GitHub, Roblox y Drive
├── Juegos (base)       un juego por fila
├── Tareas (base)       espejo de los Issues de GitHub, solo lectura
├── Acuerdos            copia de docs/acuerdos.md
├── Reuniones (base)    fecha, asistentes, decisiones, pendientes
└── Referentes (base)   juegos que se estudian, con su cifra y fecha
```

### Base Juegos

| Propiedad | Tipo | Ejemplo |
|---|---|---|
| Nombre | Título | Drain for Loot |
| Estado | Select: idea, en construcción, en prueba, publicado, cerrado | en construcción |
| Etapa | Número (0 a 13) | 2 |
| Repo | URL | github.com/Nashei-Studios/drain-for-loot |
| Experiencia | URL | por publicar |
| Inicio | Fecha | 2026-11-16 |
| Fecha jugable | Fecha | inicio más 7 a 10 días |
| Veredicto | Select: sin medir, seguir, cerrar | sin medir |

### Base Tareas (la llena el espejo)

| Propiedad | Tipo |
|---|---|
| Título | Título |
| Número | Número |
| Estado | Select: abierta, cerrada |
| Dueño | Select |
| Etiquetas | Multi-select |
| Juego | Relación a Juegos |
| URL | URL |
| Actualizada | Fecha |

## 3. Encender el espejo de un repo

Por cada repo de juego, una vez creado el workspace y la base Tareas:

1. `gh secret set NOTION_TOKEN --repo Nashei-Studios/<repo>` (pega el token cuando lo pida; no lo pases como argumento).
2. `gh variable set NOTION_DATABASE_ID --repo Nashei-Studios/<repo> --body <id de la base Tareas>`.
3. El workflow `notion-mirror.yml` corre con cada cambio de un issue. Sin el secreto y la variable no hace nada.

Mejor: guardar el secreto y la variable **a nivel de organización** para que los hereden todos los repos. Requiere que el token de `gh` tenga el permiso `admin:org` (`gh auth refresh -s admin:org`).

## 4. Usarlo como plantilla para otro proyecto

Para un hackathon o un proyecto corto: en Notion, `...` sobre la página raíz, **Duplicate**, y se renombra. Las bases se copian vacías de relaciones externas. Luego se conecta la integración a la copia (paso 5) y se apunta el espejo del repo nuevo a su base Tareas. El lado de GitHub está en [hackathon.md](hackathon.md).

## Estado

- Integración conectada al workspace del estudio: **pendiente** (pasos 1 a 8).
- Estructura creada: **pendiente**, se crea por API apenas el token funcione.
- Espejo encendido en `drain-for-loot`: **pendiente**.
