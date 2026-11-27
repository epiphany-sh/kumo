# Performance: que Kumo no caliente la máquina

Kumo corre horas abierto mientras agentes escriben archivos y llenan
terminales sin parar. Cualquier trabajo que se dispare "por evento" o "por
frame" se multiplica por eso, en macOS, Linux y Windows por igual. Estas
reglas salen de un caso real: en macOS los ventiladores se prendían con un
solo agente trabajando.

Antes de dar por terminada una feature, revisá esta lista.

## UI (Flutter)

- **Nada de animaciones infinitas a vsync.** Un `AnimationController` con
  `repeat()` pide un frame en cada refresco de pantalla (60–120 Hz) mientras
  dure. Para indicadores de estado (pulsos, spinners) usá un `Timer` a baja
  frecuencia (~10 fps) o un estado fijo. Siempre:
  - envolvé lo animado en un `RepaintBoundary`;
  - pará la animación si `MediaQuery.disableAnimationsOf`, si
    `TickerMode` está apagado o si el widget no es visible;
  - cancelá timers en `dispose`.
  Ejemplo: `WorktreeDot` en `kumo-ui/lib/shell/sidebar.dart`.
- **Lo que no se ve no se dibuja.** Las pantallas montadas en un
  `IndexedStack` o en pestañas ocultas siguen vivas: no deben generar
  snapshots ni pedir frames (`scheduleFrameCallback` / `setState`). Guardá el
  estado, marcá "sucio" y dibujá una vez al volver a mostrarse. Ejemplo:
  `setVisible` en `kumo-ui/lib/engine/grpc_terminal_surface.dart`.
- **Rebuilds acotados.** No escuches todo `AppState` desde arriba si solo
  cambia una parte. Lo que se deriva de la config (paleta, `ThemeData`) se
  calcula una vez por combinación de valores y tiene `==`/`hashCode`, para
  que `updateShouldNotify` no avise cambios falsos.
- **Trabajo proporcional al cambio, no al tamaño.** Nada de recorrer todo el
  scrollback, la lista entera de archivos o todas las sesiones en cada
  chunk de salida. Mantené índices incrementales.
- **Efectos caros con cuidado.** `BackdropFilter`, blur y ventanas
  translúcidas hacen que cada frame cueste más al compositor del S.O.; con
  pocos frames está bien, con muchos no.

## Daemon (Rust)

- **Eventos del filesystem: debounce + piso entre corridas + single flight.**
  Usá el scheduler de `crates/application/src/workspace/schedule.rs`
  (primera corrida a los 125 ms, después al menos 3 s entre corridas, una
  sola corrida extra si llegan eventos mientras corre). Nunca un
  `sleep` corto en loop ni un segundo watcher sobre las mismas carpetas.
- **Ignorá lo que no importa:** `.git/objects`, `logs`, `*.lock`,
  `node_modules`, `target`, `.dart_tool`, `dist`, `build`, etc.
- **Alcance mínimo.** Un cambio en un worktree refresca ese worktree; lo
  que es de todo el repo se lee solo cuando cambian refs/HEAD/worktrees.
- **Pocos procesos git y cacheados.** Preferí un `git status
  --porcelain=v2 --branch` a varias llamadas sueltas. Cacheá lo que depende
  de oids (merge-base, diffs contra la base) y lo que depende de
  tamaño/mtime (conteos de archivos). Corré git con `GIT_OPTIONAL_LOCKS=0`
  y los diffs con `-c diff.autoRefreshIndex=false`.
- **Respetá la presencia de la ventana.** Con la ventana sin foco el ritmo
  baja; oculta, se pausa y se pone al día al volver
  (`Workspace.SetPresence`). Un trabajo periódico nuevo tiene que mirar esto.
- **Nada de busy loops ni polling corto.** Si necesitás un intervalo,
  justificá el valor y que se pause cuando nadie mira.
- **Streams a la UI: diffs y batching.** No mandes el snapshot completo en
  cada evento ni un mensaje por chunk de salida.

## Cómo verificar

- Dejá un agente trabajando unos minutos y mirá CPU/GPU de Kumo y `kumod`
  (Activity Monitor, `top`, Task Manager) y si aparecen procesos `git`
  seguidos.
- Flutter DevTools → Performance: con la app quieta no debería haber frames.
- Los timers y schedulers se testean con tiempo falso (`tokio::time::pause`,
  `tester.pump(duration)`), no con sleeps reales.
