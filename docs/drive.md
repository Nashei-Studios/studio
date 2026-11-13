# Drive: la biblioteca pesada del estudio

Git guarda texto y código. Todo lo que pesa (kits de modelos, UI, audio, investigación con video, material de referencia) vive en una carpeta de Google Drive y cada persona tiene una copia en su computador. Drive es el punto de distribución; la copia local es la que usan Studio, Blender y los agentes.

## Qué es y qué no es

| Es | No es |
|---|---|
| Un zip por paquete más un `manifest.json` por carpeta | Miles de archivos sueltos: Drive los sube y baja muy lento |
| Lo mismo en el computador de los tres, verificado por hash | Un lugar para trabajar en vivo dos personas a la vez |
| Material de apoyo con su licencia anotada | El código o el place del juego (eso es Git y Team Create) |

## Estructura

```
Nashei Studios (Drive)
├── 00-empieza-aqui/     LEEME con este mismo resumen
├── 10-kits/             un zip por kit + manifest.json
├── 20-investigacion/    un zip por tanda de investigación + manifest.json
├── 30-video/            gameplays y material para redes
├── 40-audio/            música y efectos con licencia
├── 50-arte/             fuentes de Blender, texturas, concept
├── 60-legacy/           respaldos de experiencias anteriores
├── 70-redes/            piezas publicadas y por publicar
└── 90-archivo/          lo que ya no se usa
```

El número deja las carpetas en el mismo orden para todos. Cada carpeta que se sincroniza tiene su `manifest.json`: nombre del zip, hash SHA-256, tamaño, cantidad de archivos, licencia, si el material puede ir dentro de un juego (`ships`) y fecha.

## La carpeta

Carpeta raíz: [Nashei Studios](https://drive.google.com/drive/folders/1YCndwJ7cngvOdpDRa2KiMYBwtRAo6tVQ). Su id (`1YCndwJ7cngvOdpDRa2KiMYBwtRAo6tVQ`) vive en `config/ecosistema.json`, clave `drive.raiz`; los scripts lo leen de ahí. La dueña de la carpeta es Leon, que la comparte con cada persona del estudio. Solo entra quien tiene la carpeta compartida con su cuenta de Google (Editor): la dirección no da acceso por sí sola.

## Usarlo sin instalar nada

Abre el enlace de arriba con la cuenta de Google a la que se le compartió, entra a `10-kits`, descarga el zip que necesitas y descomprímelo. Sirve para un kit suelto.

## Tenerlo todo al día (recomendado)

Una sola vez, y casi todo lo hace el agente:

```powershell
pwsh studio/tools/puesto.ps1 install
```

Si falta el remoto `nashei`, `puesto.ps1 install` lo crea con `rclone config create nashei drive scope=drive root_folder_id=<drive.raiz.id>` y abre el navegador. Lo único que hace la persona es autorizar ahí, con la cuenta de Google a la que se le compartió la carpeta. Después el agente comprueba con `rclone lsf nashei: --dirs-only` que aparezca `10-kits` y baja la biblioteca.

Sin navegador (SSH o Linux sin pantalla): en un equipo que sí tenga navegador corre `rclone authorize "drive"` ([documentación](https://rclone.org/commands/rclone_authorize/)), copia el token que imprime y en el equipo sin navegador corre el comando que `puesto.ps1 check` muestra en la línea PERSONA, agregando `config_token=<token>`. El token es una credencial: no lo pegues en chats, issues ni commits.

### Si da acceso denegado o la lista sale vacía

Tu cuenta aún no ve la carpeta. Pide a Leon, dueño de la carpeta, que la comparta con tu cuenta de Google (Editor), abre el enlace de arriba para confirmar que la ves y vuelve a correr `puesto.ps1 install`. Si venció la sesión de rclone: `rclone config reconnect nashei:`. Leon no necesita pedir acceso: solo verifica que rclone y el MCP de Drive vean la carpeta.

Después, cada vez que quieras ponerte al día:

```powershell
gh repo clone Nashei-Studios/studio      # una vez
pwsh studio/tools/kits.ps1 pull -Path D:\Roblox\kits
pwsh studio/tools/kits.ps1 pull -Path D:\Roblox\research -Folder 20-investigacion
```

`pull` baja solo los paquetes cuyo hash cambió, verifica el hash antes de descomprimir y deja cada paquete en su carpeta. `-Path` es donde quieres la copia; elige una ruta y úsala siempre.

| Comando | Qué hace |
|---|---|
| `kits.ps1 status -Path <ruta>` | Compara tu copia con Drive. No cambia nada |
| `kits.ps1 pull -Path <ruta>` | Baja y descomprime lo que cambió |
| `kits.ps1 pull -Path <ruta> -Only kenney-food-kit,icons-pack` | Solo esos paquetes |
| `kits.ps1 push -Path <ruta>` | Sube lo que cambió en tu copia y actualiza el manifiesto |
| `-Folder 20-investigacion` | Trabaja sobre otra carpeta de Drive (por defecto `10-kits`) |

## Subir tu material: qué va en cada carpeta

| Material | Carpeta |
|---|---|
| Arte: fuentes de Blender, texturas, concept, modelos propios | `50-arte` |
| Beta testing: sesiones de tu persona y de juegos de referencia | `35-beta-testing` (`<juego>/<versión>/`, referentes en `referentes/`) |
| Reuniones: audio y actas | `15-reuniones` |
| Experiencias y trabajo anteriores al sistema | `60-legacy` |

Para subir: deja el material en una carpeta de tu copia local y corre `pwsh studio/tools/kits.ps1 push -Path <tu copia> -Folder 50-arte` (cambia `-Folder` por la carpeta de la tabla). El agente pide tu aprobación antes de subir cualquier archivo tuyo.

## Agregar o cambiar un paquete

1. Deja el material en una carpeta nueva dentro de tu copia local, con nombre en minúsculas y guiones (`mi-kit-nuevo`).
2. Anota su origen y licencia en `roblox-vault/kits/<nombre>.md`. Sin licencia conocida, `ships` es `no`: sirve de referencia, no entra a un juego.
3. `pwsh studio/tools/kits.ps1 push -Path <tu copia>`.
4. Avisa en el Agent Board: los demás corren `pull`.

Las carpetas que empiezan con `_` o `.` no se suben.

## Límites que conviene saber

- La carpeta es de Leon, y cada archivo cuenta contra la cuota de quien lo subió (15 GB en una cuenta gratis).
- Dos personas que suben el mismo paquete a la vez: gana la última. Se avisa en el tablero antes de subir algo grande.
- `rclone` usa por defecto una credencial compartida que Google está retirando durante 2026. Cuando deje de funcionar, cada persona crea la suya: [instrucciones de rclone](https://rclone.org/drive/#making-your-own-client-id).
- Un paquete borrado de Drive no se borra de tu copia local: se borra a mano.

## Modelo de transcripción de reuniones

`transcripcion.modelo` en `config/ecosistema.json` es una ruta bajo tu carpeta de usuario, igual en Windows, macOS y Linux: `~/Nashei/models/whisper/ggml-small.bin` (`~` es tu carpeta de usuario). `puesto.ps1 check` marca PERSONA si no está y trae el comando exacto de descarga (unos 470 MB, desde el repositorio de whisper.cpp en Hugging Face). Solo lo necesita quien transcribe reuniones.
