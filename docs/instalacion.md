# Qué instalar

Todo es gratis. Hay dos perfiles: quien hace arte, mapa, ideas y pruebas, y quien además toca código. Cada paso dice cómo saber que quedó bien.

## Perfil 1: arte, mapa, ideas y pruebas (30 minutos)

| # | Qué | Dónde | Listo cuando |
|---|---|---|---|
| 1 | Cuenta de GitHub | github.com/signup | Le pasaste tu usuario a Victor |
| 2 | Aceptar la invitación a `Nashei-Studios` | Llega por correo, o en github.com/Nashei-Studios | Ves los repos privados |
| 3 | Roblox Studio | create.roblox.com | Abre y entras con tu cuenta |
| 4 | Verificación en dos pasos en Roblox | Configuración de la cuenta, Seguridad | Te pide el código al entrar |
| 5 | Unirte al grupo de Roblox del estudio | Enlace que pasa quien lo creó | Apareces como miembro |
| 6 | Abrir el place del juego con Team Create | Studio, Archivo, Abrir desde Roblox, pestaña del grupo | Ves a los demás conectados |
| 7 | Notion | notion.com, aceptar la invitación al workspace | Ves la portada del estudio |
| 8 | Google Drive | Aceptar la carpeta compartida `Nashei Studios` | Ves `kits/` |
| 9 | Leer [guia-10-min.md](guia-10-min.md) y dejar un mensaje en el Agent Board | Issue fijado de `studio` | Tu comentario está ahí |

Opcional y recomendado: **Blender** (blender.org) para modelar low poly, y **Obsidian** (obsidian.md) para leer la investigación de `roblox-vault` con sus enlaces.

Si falla el paso 6: el dueño del place tiene que darte permiso de edición en el grupo. Avisa en el Agent Board con `[bloqueo]`.

## Perfil 2: además, código (1 hora más)

Windows. Los comandos van en PowerShell.

| # | Qué | Comando o lugar | Listo cuando |
|---|---|---|---|
| 1 | Git | `winget install Git.Git` | `git --version` responde |
| 2 | GitHub CLI | `winget install GitHub.cli`, luego `gh auth login` | `gh auth status` dice Logged in |
| 3 | VS Code | `winget install Microsoft.VisualStudioCode` | Abre |
| 4 | Rokit (instala Rojo, Lune, StyLua, Selene y el resto con la versión exacta) | `winget install Rojo.Rokit` | `rokit --version` responde |
| 5 | Clonar el juego | `gh repo clone Nashei-Studios/drain-for-loot` | Existe la carpeta |
| 6 | Preparar el repo | Dentro de la carpeta: `pwsh scripts/bootstrap.ps1` | Imprime OK en cada paso |
| 7 | Plugin de Rojo en Studio | Lo instala el paso 6 (`rojo plugin install`) | En Studio aparece la pestaña Rojo |
| 8 | Claude Code (si usas IA para programar) | claude.com/claude-code | `claude` abre en la carpeta del juego |
| 9 | Pasar la puerta local antes de escribir código | `stylua --check .`, `selene .`, `lune run scripts/test` | Las tres terminan sin error |

Regla de Rojo: al place compartido lo conecta **una sola computadora** (la del juego). Tu Rojo es solo para tu copia local. Si dos lo conectan a la misma place, se pisan los scripts. Ver [como-trabajamos.md](como-trabajamos.md).

## Para que la IA controle más cosas (quien orquesta agentes)

Son servidores MCP: programas que le dan a Claude Code acceso a una aplicación. Todos son de código abierto o los entrega el propio fabricante.

| Qué controla | Herramienta | Estado en el equipo de Victor |
|---|---|---|
| Roblox Studio (editar, probar, capturar, generar modelos) | MCP integrado de Studio: Assistant, Manage MCP Servers, Enable Studio as MCP server | Instalado |
| Navegador con tu sesión (leer redes, páginas con cuenta) | Extensión Claude in Chrome | Instalado |
| Escritorio de Windows | MCP de escritorio | Instalado |
| Documentación al día de librerías | context7 | Instalado |
| Notion | MCP oficial: `claude mcp add --transport http notion-studio https://mcp.notion.com/mcp`, luego `/mcp` y autenticar con el workspace del estudio | Instalado |
| Google Drive, Docs, Gmail | workspace-mcp | Instalado |
| Diagramas | drawio | Instalado |
| Blender (modelar y exportar desde un pedido en texto) | `mcp-for-blender` más su addon dentro de Blender. Pasos en el repo `art`, `docs/blender.md` | Instalado |
| Drive como disco para lo pesado | `rclone` con un remoto llamado `nashei` ([drive.md](drive.md)) | Instalado |
| Subir imágenes y audio a Roblox desde archivos | `asphalt` (por Rokit) | **Falta**: pide una llave de Open Cloud |
| Video: bajar, transcribir, cortar | `yt-dlp`, `ffmpeg`, Whisper, Remotion, HyperFrames | Instalado |

Lo que falta tiene su issue en este repo con la etiqueta `ecosistema`.
