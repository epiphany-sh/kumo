# Tasks: "Mine" by default, rich cards, ticket detail — approved design

Spec: `../tareas-detalle-y-mios.md`. This folder is the approved result.

- `Tasks.dc.html` — the design board (HTML prototype). The template is between `<x-dc>` and `</x-dc>`; the sample data, states and interactions are in `renderVals()` of the script at the bottom. Copy texts verbatim from it.
- `screens/` — renders of every state:
  - `mine.png` board, Mine (default) · `everyone.png` Everyone with assignees
  - `cards.png` card variants (Story, overdue Bug, Sub-task, GitHub issue, Obsidian task; Mine and Everyone)
  - `detail.png` panel top · `detailScrolled.png` panel scrolled · `formOpen.png` "Start in a worktree" open
  - `loading.png` skeletons · `offline.png` cached data + notice
  - `expanded.png` large two-column view (⤢) · `comments.png` all comments
  - `emptyMine.png` nothing assigned · `emptyFilter.png` filter without matches
  - `light.png` light theme sample

Decisions (answers to the spec's open questions):
1. Mine = assigned to me by default. The segmented can later get Assigned · Reported · Watching without layout changes.
2. Both: 440 px side panel for going through tickets with ↑/↓, and ⤢ expands to a two-column view inside Tasks (no new navigation); Esc steps back.
3. Move to, Start in a worktree, linked worktrees and "What the agent gets" live in a footer pinned to the panel; in the expanded view, at the top of the right column.
