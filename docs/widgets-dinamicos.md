# Widgets dinámicos

Evaluación y plan para los widgets del panel lateral (Files · Widgets ·
Source control): qué se hizo, y cómo llevar a cabo que la IA cree widgets
nuevos a pedido, al estilo de los "mods" de Claude.

Estado al 2026-11-14:

| Parte | Estado |
|---|---|
| Resize vertical de cada widget, con scroll interno | Implementado en `feat/dinamic-widgets` (PR #78), sin probar a mano con trackpad |
| Ancho del panel redimensionable | Pendiente (hoy fijo en 300 px) |
| Widgets declarativos (YAML) | Diseño, sin código |
| Creación de widgets por IA | Diseño, sin código |

## 1. Punto de partida

- Los widgets son una lista cerrada en el código: el enum `InspectorWidget`
  (`kumo-ui/lib/app/app_state.dart`) y un `switch` que elige el cuerpo de
  cada uno (`_widgetBody` en `kumo-ui/lib/shell/side_panel.dart`). Hay ocho:
  Agent, Session, Changes, Context, Pipelines, Tests, Pull request, Activity.
- El usuario puede agregarlos, quitarlos y reordenarlos. Esa lista no se
  guarda entre sesiones.
- El panel lateral mide 300 px fijos (`kumo-ui/lib/views/terminal_screen.dart`).
  Lo que sí se redimensiona es el sidebar izquierdo de repos (220–420 px).
- La UI es Flutter compilado (AOT) y el proyecto no usa webviews
  (`kumo-ui/pubspec.yaml`: "No webviews").

## 2. Resize vertical (hecho)

Cómo se comporta:

- **Agarre:** el espacio de 10 px debajo de cada widget arrastra su alto.
  Mismo patrón que el resizer del sidebar: grip al pasar el mouse, ↑ ↓ con
  teclado (⇧ para pasos grandes), doble click para volver al alto del
  contenido. El menú de click derecho suma "Fit height to content".
- **Mínimo:** 120 px (`AppState.minWidgetHeight`).
- **Máximo:** el menor entre el contenido completo del widget, el alto
  visible del panel y un techo de 900 px (`AppState.maxWidgetHeight`). Nunca
  queda espacio vacío ni un widget más alto que el panel.
- **Sin alto fijado:** el widget mide lo que mide su contenido, como antes.
  Si supera el alto del panel, scrollea adentro en vez de crecer sin límite.
- **Scroll:** el contenido scrollea dentro del marco de la card, con
  scrollbar. Al llegar al final, el scroll sigue en la lista de widgets,
  inercia incluida, para que el gesto no se corte en el borde. Un widget
  cuyo contenido entra completo no captura scroll.
- **Persistencia:** los altos se guardan en las preferencias
  (`widgets.heights`). Al quitar un widget se descarta su alto.

Dónde está:

- `kumo-ui/lib/shell/side_panel.dart`: `_WidgetCard` y `_WidgetResizer`.
- `kumo-ui/lib/shell/screen_chrome.dart`: `SectionViewport` y el scroll
  dentro de `Section`.
- `kumo-ui/lib/app/app_state.dart`: altos por widget y su persistencia.
- `kumo-ui/test/side_widgets_test.dart`: grupo "widget heights".

Pendiente de esta parte:

- Probarlo en la app real con trackpad y rueda.
- Tests (6 suites, 5 fallos) y Activity recortan su lista en el código:
  agrandarlos no muestra más filas. Deberían mostrar más cuando hay alto.
- Ancho del panel redimensionable, con el mismo patrón.
- Guardar la lista y el orden de widgets entre sesiones.

## 3. Widgets creados por la IA

### Por qué no se puede copiar el mecanismo de los mods

Los mods de Claude funcionan porque su interfaz puede cargar código en
runtime. Flutter compila AOT y no puede cargar Dart nuevo en una app ya
firmada. Las alternativas:

| Camino | Velocidad | Veredicto |
|---|---|---|
| **Spec declarativa + renderer nativo** | Igual que un widget compilado | Recomendado |
| Scripting embebido (`dart_eval`, Lua, QuickJS) | Interpretado, más lento | Solo si la spec se queda corta |
| WebView por widget | Pesado, look distinto | Descartado: el proyecto no usa webviews |
| Que la IA edite el código de Kumo y recompile | Nativa de verdad | Inviable para distribuir: pide Flutter SDK, rebuild y re-firma |

### El enfoque recomendado

Un widget dinámico es un archivo de texto que describe **qué datos traer** y
**cómo mostrarlos** con piezas que Kumo ya trae compiladas. La IA no escribe
código de interfaz: escribe ese archivo.

Ejemplo ilustrativo (el schema real hay que diseñarlo):

```yaml
version: 1
id: deploy-status
title: Deploys
sources:
  deploys:
    run: ./scripts/deploys.sh --json   # imprime JSON por stdout
    every: 30s
    timeout: 5s
view:
  - heading: "Deploys"
    trailing: "{{ deploys.env }}"
  - list:
      each: deploys.items
      max: 8
      row:
        title: "{{ item.service }}"
        detail: "{{ item.version }} · {{ item.ago }}"
        badge: { text: "{{ item.state }}", tone: "{{ item.state == 'ok' ? 'ok' : 'err' }}" }
        on_tap: { open_url: "{{ item.url }}" }
  - button: { label: "Redeploy", run: ./scripts/redeploy.sh, confirm: true }
```

- **Fuentes (`sources`):** las ejecuta el daemon, no la interfaz, así la UI
  nunca bloquea. Tipos: comando con intervalo, archivo observado, HTTP, y
  los datos que Kumo ya tiene (git, agentes, pipelines, tests). El daemon
  manda snapshots por gRPC.
- **Vista (`view`):** un árbol de primitivas (título, fila, lista, badge,
  medidor, sparkline, botón, texto mono) que un intérprete en Flutter arma
  con los controles reales de `kumo-ui/lib/widgets/`. Por eso rinde y se ve
  como un widget nativo.
- **Expresiones (`{{ }}`):** deliberadamente mínimas: acceso a campos,
  comparaciones, formato. Sin loops ni funciones, para que nunca puedan
  colgar la interfaz.
- **Acciones:** correr un comando, mandar texto a la terminal, abrir un
  archivo o una URL.
- **Dónde viven:** `~/.kumo/widgets/` (personales). `.kumo/widgets/` dentro
  del repo (compartibles) queda para una segunda etapa; ver seguridad.
- **Flujo con IA:** "Add widget → Describe it…" lanza un agente con el schema
  y ejemplos. El agente escribe el YAML y, si hace falta, el script. El
  daemon valida y le devuelve los errores para que corrija; el panel recarga
  solo.

Piezas que ya existen y se reaprovechan: los agentes sobre varios CLIs, el
patrón de `AgentDefs` (archivos + Save/List; el servicio de widgets sería su
hermano), el watcher de archivos del daemon y el paquete `yaml` en la UI.

### El límite real

- **Del lado de los datos casi no hay límite.** El script puede hacer lo que
  quiera, en cualquier lenguaje, mientras devuelva JSON.
- **El límite está en la interfaz.** Solo se combina lo que exista como
  primitiva. No hay dibujo libre, layouts raros, drag and drop propio,
  animaciones a medida ni editores complejos. Si falta una pieza, sale en un
  release de Kumo.
- **Solo afecta al panel de widgets.** Los mods de Claude tocan temas,
  comandos y paneles; acá cada lugar extensible (paleta de comandos, barra de
  estado) hay que abrirlo aparte.
- **La velocidad percibida depende del script.** El render es instantáneo,
  pero si el comando tarda 3 s, el dato llega 3 s tarde.

### Riesgos de seguridad

El riesgo central: **un widget que corre comandos es ejecución de código con
los permisos del usuario**. El daemon no tiene sandbox, y agregarlo en serio
es un proyecto aparte.

| Riesgo | Mitigación |
|---|---|
| Widgets que vienen en un repo: clonar no puede ejecutar nada | Aprobación explícita mostrando los comandos exactos; se vuelve a pedir si el archivo o el script cambian (por hash, como `direnv`) |
| Widgets escritos por la IA: un agente que leyó contenido malicioso puede escribir un comando dañino | La misma aprobación, aunque lo haya generado el agente propio |
| Exfiltración por una fuente HTTP o un `curl` en el script | La aprobación muestra los hosts declarados; dentro del script no se puede garantizar nada |
| Botones que disparan comandos | Solo con click real del usuario, nunca al cargar ni por timer; las destructivas piden confirmación |
| Salida no confiable del script | Se muestra como texto plano; los links se abren solo con click y con la URL visible |
| Abuso de recursos | Intervalo mínimo, timeout, tope de salida y límite de procesos simultáneos, impuestos por el daemon |
| Secretos en la salida de los comandos | Esa salida no va a logs |

### Nativos y primitivas: inmutables

- **Primitivas** (fila, badge, medidor…): inmutables por naturaleza, porque
  son código compilado. Son la garantía de velocidad y de coherencia visual.
- **Widgets nativos** (Agent, Session, Changes…): de solo lectura. Si la IA
  los editara en el lugar, cada actualización de Kumo chocaría con esas
  ediciones, y un widget roto parecería un bug de Kumo.
- **Para personalizar un nativo: duplicar.** "Duplicate & customize" crea una
  copia en YAML del usuario y el original queda intacto. Solo funciona para
  los nativos expresables con las primitivas: los simples (Changes,
  Pipelines) probablemente sí; Agent y Session tienen lógica propia y siguen
  siendo código.

## 4. Plan recomendado

Cada etapa se puede publicar sola.

1. **Cerrar el resize.** Probar a mano, ancho del panel, filas que crecen con
   el alto, guardar lista y orden de widgets.
2. **Registro de widgets.** Pasar el enum cerrado a un registro con ids
   (nativos + dinámicos). Toca orden, agregar/quitar y persistencia. Sin
   cambio visible.
3. **Widgets declarativos escritos a mano.** Schema `version: 1` con unas 10
   primitivas y 3–4 tipos de fuente, validador, intérprete de vista en
   Flutter, y un servicio `Widgets` en el daemon que programe las fuentes
   (timeouts, tope de salida, cancelación). Solo personales, en
   `~/.kumo/widgets/`. Sirve para validar el schema antes de que la IA
   dependa de él.
4. **Creación por IA.** El flujo "Describe it…", con el ciclo de validación y
   corrección, y la pantalla de aprobación de comandos.
5. **Widgets en el repo.** `.kumo/widgets/`, con aprobación por hash.
6. **Duplicate & customize** de los nativos expresables.

Estimación gruesa de las etapas 2 a 4: 1,5–2,5 semanas.

## 5. Decisiones abiertas

- **Versión:** esto es un minor (0.8.0), no un patch. Según `CLAUDE.md` hay
  que confirmarlo antes de abrir la release.
- **Alcance de la primera versión:** solo widgets personales (recomendado) o
  también dentro del repo. Arrancar solo con personales evita el caso más
  peligroso (código ajeno al clonar).
- **Schema:** una vez publicado, `version: 1` hay que soportarlo para
  siempre. Conviene congelarlo recién después de la etapa 3.
- **Sandbox del daemon:** fuera de alcance acá; define cuánto se puede
  confiar en widgets de terceros.
