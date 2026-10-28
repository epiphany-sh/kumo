# Prompt de diseño: tareas con más detalle y "mis tareas"

> Pegalo tal cual en la herramienta de diseño. La UI de Kumo está en inglés,
> así que los textos de pantalla van en inglés; el resto del prompt, en español.

---

## Contexto

Kumo es una app de escritorio (macOS primero, Windows después) para trabajar con agentes de IA que programan. El usuario organiza sus repos en *namespaces*, trabaja cada cosa en su propio *worktree* y lanza agentes ahí. La vista **Tasks** trae los tickets de las herramientas que ya usa (Jira, GitHub Issues, Todoist, Obsidian, Bear) a un tablero, y desde un ticket arranca un worktree con un agente que recibe el ticket como contexto.

Lenguaje visual existente (respetalo):
- Ventana con sidebar izquierda (namespaces, repos, worktrees), barra superior con breadcrumb y buscador ⌘K, y contenido en paneles de vidrio ahumado (*smoked glass*) con bordes suaves y radios de 14 a 22 px.
- Tema oscuro y claro. Acento azul lavanda. Estados: ok verde, warn ámbar, err rojo.
- Tipografía sans para texto y monoespaciada para keys, ramas y paths.
- Badges de dos letras por fuente (`JI` Jira, `GH` GitHub, `TD` Todoist, `OB` Obsidian, `BE` Bear) y pills para estados.
- Tamaño típico de ventana 1440×960; mínimo 1100×700.

## Qué hay hoy

**Tablero** (ver captura adjunta):
- Header con "Tasks", la fuente y "synced just now", un buscador "Filter tasks" y chips de fuente con conteo (`All 37`, `Jira - Fravega 37`).
- Cuatro columnas: To do, In progress, In review, Done.
- **Card**: badge de fuente, key (`PRC-11355`), prioridad (High/Med/Low) arriba a la derecha, título y el proyecto (`Pricing`). Nada más.

**Panel de detalle** (columna derecha, unos 380 px):
- Key, fuente, título.
- Grilla con Status, Priority, Due e In (proyecto).
- Segmented "Move to" (To do / Doing / Review / Done).
- Bloque "Start in a worktree": repositorio, rama base, rama nueva sugerida (`feat/PRC-11355-migraciones`), switch de agente y botón "Create worktree".
- Abajo, los worktrees ya vinculados al ticket.

**El problema:**
- La card y el panel son muy flacos: no dicen de qué se trata el ticket ni en qué anda.
- El tablero muestra todo lo que trae la consulta, cuando el usuario quiere ver primero lo suyo.

## Objetivo 1: "Mine" por defecto, "Everyone" cuando lo pida

- El tablero arranca mostrando solo **mis tareas**: en Jira, asignadas a mí; en GitHub, `assignee:@me`. Obsidian, Bear y Todoist son personales, así que todo cuenta como mío.
- Un control en el header permite pasar a **Everyone**, que muestra lo que trae la fuente (por ejemplo, todo el proyecto de Jira). Proponé el control (segmented `Mine · Everyone` con conteos, toggle o chip) y dónde va respecto del buscador y los chips de fuente. La elección se recuerda.
- En **Everyone**, cada card muestra a quién está asignada (avatar con iniciales y nombre al pasar el mouse). Las mías se distinguen sutilmente, y las sin asignar dicen "Unassigned".
- Estados vacíos:
  - "Nothing assigned to you in Jira", con el botón "Show everyone".
  - "No tasks match" cuando el filtro de texto deja todo afuera.
- Contemplá que más adelante "mine" pueda incluir "reported by me" o "watching". No hace falta diseñarlo, pero que el control no lo impida.

## Objetivo 2: cards con más información, sin perder escaneabilidad

La card sigue siendo compacta: un tablero de 20 a 40 tickets por columna tiene que leerse de un vistazo. Proponé qué entra y con qué jerarquía. Candidatos:

- **Tipo de issue** con ícono: Story, Bug, Task, Sub-task, Epic.
- **Estado real de Jira** cuando no coincide con el nombre de la columna. Por ejemplo, la columna In review con el estado "Code Review" o "QA".
- **Épica o padre**, como chip con su color.
- **Story points**.
- **Sprint**, solo si no es el actual o si ya cerró.
- **Progreso de subtareas** (`2/5`).
- **Comentarios** (cantidad).
- **Vencimiento**: due date, y overdue en rojo.
- **Asignado**: avatar, solo en Everyone.
- **Labels**: hasta 2, con `+N`.
- **Worktree vinculado** con su agente corriendo: ya existe como concepto; mostrá un indicador.

Pensá variantes de card para un Story de Jira completo, un Bug urgente vencido, un Sub-task, un issue de GitHub con labels y una tarea de Obsidian (que casi no tiene metadatos), para que la card degrade bien cuando faltan datos.

## Objetivo 3: el panel de detalle como "ficha" del ticket

Al abrir un ticket se piden los detalles a la fuente. Llegan en uno o dos segundos y quedan en caché, así que hay que diseñar el estado *loading* (skeleton) y el *offline* (datos básicos de la card y un aviso). Proponé si el panel crece en ancho, si se puede expandir a una vista grande (ya hay un ícono ⤢ en el header del panel) o ambas cosas.

Contenido, en el orden que te parezca mejor:

1. **Header.**
   - Ícono de tipo, key, fuente, pill de estado con el nombre real ("Code Review").
   - Acciones: abrir en Jira, copiar link, cerrar.
   - Título grande.
2. **Gente.** Assignee y reporter, con avatar y nombre.
3. **Metadatos.**
   - Priority, story points, sprint (nombre y fechas), épica o padre (clickeable), due, created, updated.
   - Components, fix version y labels.
   - Time tracking (estimado / registrado / restante) si existe, idealmente como barrita.
4. **Descripción** renderizada desde Markdown: títulos, listas, checklists, bloques de código, tablas, links, menciones (`@Ana`) e imágenes (placeholder o miniatura). Larga: colapsada con "Show more".
5. **Acceptance criteria**, si el proyecto tiene ese campo: destacado, porque es lo que le importa al agente.
6. **Subtasks**: lista con key, título y estado (pill chica); progreso arriba.
7. **Linked issues**, agrupados por relación (blocks, is blocked by, relates to, duplicates), con key, título y estado. Destacar si algo me bloquea.
8. **Attachments**: nombre, tipo y tamaño. No hace falta preview.
9. **Comments**:
   - Los últimos 3, con avatar, nombre, hace cuánto y el cuerpo en Markdown; "Show all N comments" para el resto.
   - Solo lectura en esta versión. Dejá previsto dónde iría "Add a comment", sin diseñarlo a fondo.
10. **Acciones existentes**, que se mantienen y no se pueden perder de vista:
    - "Move to" (las columnas que la fuente permite).
    - "Start in a worktree", que es la acción principal.
    - Los worktrees vinculados.
    Pensá si van fijas abajo o arriba (sticky) mientras se scrollea el contenido largo.
11. Un aviso chico de que **el agente recibe** título, descripción, acceptance criteria y comentarios cuando se arranca desde el ticket. Puede ser un "What the agent gets" desplegable.

## Estados y pantallas a entregar

Todo en tema oscuro y una muestra en claro:

1. Tablero en **Mine** con cards ricas: 3 o 4 columnas con contenido realista.
2. Tablero en **Everyone**, con avatares de asignados y las mías distinguidas.
3. Variantes de **card**: Story completa, Bug vencido, Sub-task, issue de GitHub y tarea de Obsidian.
4. **Panel de detalle completo** con todas las secciones (scrolleado y arriba).
5. Panel de detalle **loading** y **offline**.
6. Panel de detalle **expandido** (vista grande), si lo proponés.
7. **Estados vacíos**: nada asignado a mí, y el filtro sin resultados.
8. **Comentarios expandidos** (más de 10).

Interacciones a anotar:
- ↑ y ↓ cambian de ticket con el panel abierto; Esc cierra.
- ⌘K busca tickets.
- Hover en avatar muestra el nombre.
- Click en épica, padre o linked issue abre ese ticket en el panel, con "back" para volver.

## Datos de ejemplo

Usalos; no inventes empresas reales.

- **PRC-11355 · Story · "migraciones"**
  - Proyecto Pricing, sprint "Pricing 2026.22" (21 oct – 4 nov), 5 pts, prioridad Low, estado Jira "In Progress".
  - Assignee: vos (Mauri). Reporter: Ana Gómez.
  - Épica: PRC-11300 "Migración a Graviton".
  - Subtasks 2/4: PRC-11356 "Migrar job de precios" (Done), PRC-11357 "Analisis" (In Progress), PRC-11358 "actualizar planilla" (To Do), PRC-11359 "verificacion en entornos" (To Do).
  - Linked: is blocked by PRC-11340 "Limpieza de ofertas de canales" (Done); relates to PRC-11321 "Analisis: Migracion a Envoy".
  - 6 comentarios.
  - Descripción con contexto, una lista de pasos, un bloque de código SQL y acceptance criteria en checklist.
- **PRC-10599 · Bug · "Generación automática de precios para los canales (Hijas)"**: High, vencido hace 2 días, sin asignar.
- **PRC-11354 · Sub-task · "Migracion a Graviton (Parte 4/4)"**: padre PRC-11300, Low.
- **Issue de GitHub** `zen-engine#42` "Retry on 502 from pricing API", labels `bug`, `api`, asignado a vos.
- **Tarea de Obsidian** "Revisar costos de AWS" de la nota "Weekly.md", con due date.

## Restricciones

- No agregues navegación nueva: todo vive en la vista Tasks y su panel.
- Mismos componentes del sistema: pills, chips, segmented, botones primario y secundario, glass panels.
- Nada de colores de marca de Jira o GitHub más allá del badge de fuente.
- Accesible: contraste AA, foco visible, nada que se entienda solo por color.

## Preguntas abiertas

Proponé una respuesta para cada una:

- ¿"Mine" debería incluir también "reported by me" por defecto, o solo "assigned to me"?
- ¿El detalle va en el panel lateral más ancho, en una vista expandida, o en los dos?
- ¿Dónde quedan las acciones "Move to" y "Start in a worktree" cuando el detalle es largo?
