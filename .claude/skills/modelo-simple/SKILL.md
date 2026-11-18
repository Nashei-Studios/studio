---
name: modelo-simple
description: Carril ligero de arte para un modelo simple (un prop) o un retoque de terreno que no toca código. Úsalo cuando Leon pida "un modelo simple", "un prop", "un cofre", "retocar el terreno" o diga "modo light". Hace el modelo con la skill momentum-3d-models por el camino corto, sin PR ni CI, y lo deja en Team Create y en el Drive.
---

# Modelo simple (carril ligero de arte)

Meta por modelo: **10 minutos y 20 mil tokens**. Si te pasas del doble, para y dilo: probablemente no era un modelo simple.

## Cuándo aplica

Aplica si se cumplen las tres: es un prop o un retoque de terreno; ningún script ni nombre que el código recorra cambia (`Workspace.Map` y las demás zonas de `docs/flujo-arte-y-avisos.md`, sección 2); y se hace en una sesión. Si falla alguna, usa el carril completo (`docs/flujo-arte-y-avisos.md`) o espera a Victor.

## Qué NO cargues

Skills de código, `docs/plan-vigente.md`, el grill de sesión, investigación de mercado, `empezar-a-trabajar` completo. Modelo Haiku o Sonnet con esfuerzo bajo. Lee solo esta skill, `STYLE.md` del juego y la skill `momentum-3d-models`.

## Pasos

1. **Issue y aviso de una línea.** Un issue `area:arte` (regla 1 sigue: sin issue no se empieza) y un solo aviso: `[Leon's Claude] empiezo #N: <qué>. Toca: nada del juego.` Sin avisos de avance.
2. **Estilo ya hecho.** Usa el `STYLE.md` del juego, no lo rehagas: Drain for Loot en `docs/arte/drain-for-loot/STYLE.md`. Salta el paso 1 de `momentum-3d-models`; esa skill busca `STYLE.md` en la raíz del proyecto, así que dale la ruta de arriba. Solo si no existe el de ese juego, créalo una vez desde la plantilla de la skill y guárdalo en `docs/arte/<juego>/STYLE.md`.
3. **Brief de cuatro líneas** (qué es, tamaño en studs, tres rasgos que lo hacen legible, presupuesto de triángulos del `STYLE.md`). Sin preguntas salvo tamaño o uso si faltan.
4. **Referencias opcionales.** Un objeto simple (cofre, barril, roca) no las necesita: ve directo al bloqueo con el script de Blender. Pídelas solo si el objeto tiene forma rara.
5. **Construye con el script** de la skill, en lotes: `blender -b --factory-startup --python-exit-code 1 --python <build.py> -- <carpeta>`. Sin abrir la ventana de Blender.
6. **Una ronda de crítica**, no tres: mira los renders contra `STYLE.md` y corrige lo que falle. Si aún falla, entrégalo con la lista de lo que falta.
7. **Entrega directa.** Importa a la place compartida por Team Create (paso 6 de la skill), sin PR ni CI. Sube el `.blend` y el `.fbx` al Drive con el paso único de `docs/drive.md`, sección "Leon: lo mínimo".
8. **Cierre.** `gh issue close N --comment "<id del asset, carpeta del Drive>"` y un aviso de cierre de una línea con minutos y tokens gastados.

## Reglas que siguen

- Colores solo del `STYLE.md`; un color "por acordar" se pregunta a Victor, no se inventa.
- Un asset que toca código o zonas compartidas deja de ser simple: se avisa y se espera.
- Antes de subir al Drive, la persona aprueba el envío del archivo.
- Sin Drive o sin Blender instalado: dilo en una línea con el comando de `pwsh tools/puesto.ps1 check`.
