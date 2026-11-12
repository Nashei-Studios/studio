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

## Usarlo sin instalar nada

Abre la carpeta en el navegador, entra a `10-kits`, descarga el zip que necesitas y descomprímelo. Sirve para un kit suelto.

## Tenerlo todo al día (recomendado)

Una sola vez:

```powershell
scoop install rclone
rclone config          # n (nuevo), nombre: nashei, tipo: drive, todo por defecto, y autoriza en el navegador
```

Al terminar `rclone config`, edita el remoto para que apunte a la carpeta del estudio: en "root_folder_id" pega el id que aparece en la URL de la carpeta compartida. Comprueba con `rclone lsf nashei:`; debe listar `00-empieza-aqui/` y `10-kits/`.

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

## Agregar o cambiar un paquete

1. Deja el material en una carpeta nueva dentro de tu copia local, con nombre en minúsculas y guiones (`mi-kit-nuevo`).
2. Anota su origen y licencia en `roblox-vault/kits/<nombre>.md`. Sin licencia conocida, `ships` es `no`: sirve de referencia, no entra a un juego.
3. `pwsh studio/tools/kits.ps1 push -Path <tu copia>`.
4. Avisa en el Agent Board: los demás corren `pull`.

Las carpetas que empiezan con `_` o `.` no se suben.

## Límites que conviene saber

- La carpeta es de Leon, pero cada archivo cuenta contra la cuota de quien lo subió (15 GB en una cuenta gratis).
- Dos personas que suben el mismo paquete a la vez: gana la última. Se avisa en el tablero antes de subir algo grande.
- `rclone` usa por defecto una credencial compartida que Google está retirando durante 2026. Cuando deje de funcionar, cada persona crea la suya: [instrucciones de rclone](https://rclone.org/drive/#making-your-own-client-id).
- Un paquete borrado de Drive no se borra de tu copia local: se borra a mano.
