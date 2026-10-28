# kumo-ui

UI de escritorio de Kumo en Flutter (macOS + Windows). Es la implementación del diseño del canvas: terminal con agentes, archivos, agentes, tareas, git y docs, con tres looks (Dark, Light, Hybrid) y estilo Liquid Glass.

Hoy es **UI con datos mock**. No habla con el daemon todavía: la terminal está detrás de la interfaz `TerminalSurface` para que el spike de M1 (gRPC + render) se enchufe sin tocar el resto. Ver `kumo.md` §10.

## Correrlo

Requisitos: Flutter estable (3.24 o más nuevo) con soporte desktop, Xcode en macOS y Visual Studio con "Desktop development with C++" en Windows.

```bash
cd kumo/kumo-ui
# Genera los runners nativos (macos/ y windows/). No pisa lib/, test/ ni pubspec.yaml.
flutter create --platforms=macos,windows --org dev.kumo --project-name kumo_ui .
flutter pub get
flutter run -d macos      # o: flutter run -d windows
flutter test
```

**macOS 12 (Monterey) o anterior:** `macos_window_utils` necesita un cambio en `macos/Runner/MainFlutterWindow.swift`. Está documentado en su README, sección "Monterey and earlier". En macOS 13 o más nuevo no hace falta.

Si la ventana aparece opaca o negra en lugar de translúcida, abrí *Appearance* (ícono de ajustes abajo a la izquierda) y activá **Demo wallpaper**: pinta el fondo del canvas. Contame qué macOS tenés y lo revisamos.

## Atajos

| Atajo | Acción |
|---|---|
| ⌘1 … ⌘6 | Terminal, Files, Agents, Tasks, Git, Docs |
| ⇧⌘L | Rotar theme: Dark → Light → Hybrid |
| ⇧⌘N | Popover "New worktree" |
| ⌥⌘S | Mostrar/ocultar sidebar |
| ⌘↩ | Crear (dentro del popover / modal de namespace) |
| ⌘D / ⇧⌘D | Terminal: dividir el panel activo a la derecha / abajo |
| ⌘W | Terminal: cerrar el panel activo (el agente pide confirmación) |
| ⌘T | Terminal: nueva terminal |
| Click derecho | Menú de namespace (sidebar) y de worktree (Delete worktree) |
| ⌥⌘B | Terminal: mostrar/ocultar el side-nav (Files · Widgets · Source control) |
| ⌘↩ | Source control: commit con el mensaje escrito |

En Windows es igual, con Ctrl en lugar de ⌘ (salvo ⌘D/⇧⌘D/⌘W/⌘T de la terminal, que por ahora son solo macOS: Ctrl+D es EOF en una shell).

## Decisiones de diseño

- **Translucidez nativa + paneles livianos.** La ventana usa la translucidez del sistema: NSVisualEffectView en macOS y Mica en Windows 11, vía `flutter_acrylic`. Los paneles son rellenos semitransparentes con brillo arriba y borde fino, **sin `BackdropFilter`**, para que la terminal pueda repintar a 60 fps sin re-difuminar en cada frame. Solo los popovers usan blur real (`GlassOverlay`).
- **No es el "Liquid Glass" real de macOS 26.** El plugin expone NSVisualEffectView, no NSGlassEffectView. El look se logra con los rellenos y brillos de `lib/widgets/glass.dart`.
- **Tokens 1:1 con el canvas.** Están en `lib/theme/palette.dart`. Hybrid usa la paleta Light para la ventana y `KumoPalette.hybridTerminal` (vidrio oscuro ahumado) para el área de terminal.
- **Render por frame.** `TerminalCanvas` es un `CustomPainter` que repinta desde un `ValueListenable<TermBuffer>`: un paint por frame, ningún rebuild por mensaje (kumo.md §5.6).
- **UI optimista.** Aprobar o rechazar un agente, crear un worktree, mover una tarea o commitear cambian la UI en el mismo frame. Cuando exista el daemon, confirma o revierte por evento.
- **Sin dependencias pesadas.** Solo `flutter_acrylic`. Los íconos son Material (vienen con Flutter) y las fuentes Geist y Geist Mono están empaquetadas en `assets/fonts` (licencia OFL en `Geist-OFL.txt`).

## Estructura

```
lib/
  main.dart                 init de la ventana nativa y runApp
  app/                      AppState (theme, vista, sidebar, worktree activo) y KumoApp
  theme/                    palette.dart (tokens) y kumo_theme.dart (InheritedWidget + estilos de texto)
  platform/window_effects   flutter_acrylic: vibrancy, toolbar unificada, semáforos nativos
  widgets/                  glass (paneles), controls (botones, segmented, selects, switch), popover anclado
  shell/                    app_shell (layout + atajos), sidebar, screen_chrome (toolbar/status)
  terminal/                 TerminalSurface (interfaz), mock y CustomPainter
  editor/                   syntax (tokenizers), code_editor (TextField resaltado), working_copy (estado git)
  views/                    terminal, files, agents, tasks, git, docs
  overlays/                 New worktree, Appearance
  data/                     modelos y datos mock
test/                       tokenizers, lógica de git y smoke test de la app
```

## Qué falta para conectarlo al core

1. **M1:** implementar `TerminalSurface` sobre `Terminals.Attach` (bidi stream) y medir eco p99 ≤ 16 ms. Si el painter por líneas no alcanza, reemplazarlo por una grilla de glifos sin cambiar la API del widget.
2. **M2:** `TermBuffer` pasa a ser el estado de pantalla que manda el emulador del daemon (diffs de líneas sucias).
3. **M3/M4:** reemplazar `Mock.*` por streams de eventos (agentes, worktrees, tareas) y `WorkingCopy` por el estado git real.
4. **Resaltado de código:** hoy son tokenizers chicos en Dart (`editor/syntax.dart`). Para el producto conviene tree-sitter en el core, mandando rangos ya resueltos.

## Sin verificar todavía

El código se escribió sin poder compilarlo: en el entorno donde lo armé no había SDK de Flutter. Chequeé a mano el balance de paréntesis, los imports y las APIs de `flutter_acrylic` contra su código fuente. Lo primero que hay que confirmar al correrlo:

- `flutter analyze` y `flutter test` limpios.
- La translucidez en macOS (Sonoma/Sequoia/26) y en Windows 10 y 11.
- Que los botones de la toolbar respondan aunque estén en la franja del título (`fullSizeContentView`), y que la ventana se pueda arrastrar desde el espacio vacío de la toolbar.
