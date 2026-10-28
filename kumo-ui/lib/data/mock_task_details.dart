import 'mock_tasks.dart';
import 'models.dart';
import 'tasks_source.dart';

/// The design's ticket details (docs/design/tasks, `ticketData()` of
/// Tasks.dc.html), for [MockTasksSource.getTask]. Tasks without one get
/// [basic].
///
/// The board's entries ([MockTasks.tasks], [MockTasks.offBoard]) are the
/// cards; this adds what only the detail has: description, acceptance
/// criteria, subtasks, links, attachments, comments, time tracking.
final class MockTaskDetails {
  MockTaskDetails._();

  /// Details by task id, built over the board's [tasks] and the tickets
  /// that aren't on it (epics, other sub-tasks).
  static Map<String, TaskDetail> of(List<TaskEntry> tasks) {
    final known = <TaskEntry>[...tasks, ...MockTasks.offBoard()];
    final now = DateTime.now();
    TaskEntry? entryOf(_Ticket t) => known.where((e) => e.sourceId == 'mock-${t.src}' && (t.matchTitle ? e.title == t.title : e.key == t.key)).firstOrNull ??
        known.where((e) => t.matchTitle ? e.title == t.title : e.key == t.key).firstOrNull;
    final byKey = {for (final t in _tickets) t.key: t};

    TaskRef ref(String key) {
      final t = byKey[key]!;
      final e = entryOf(t);
      return TaskRef(
        id: e?.id ?? '',
        key: key,
        title: e?.title ?? t.title,
        type: e?.type ?? t.type,
        sourceStatus: e == null ? t.status : (e.sourceStatus.isEmpty ? t.status : e.sourceStatus),
        column: e?.column ?? t.column,
        assignee: e == null ? _person(t.assignee) : e.assignee,
        color: t.color,
      );
    }

    final out = <String, TaskDetail>{};
    for (final t in _tickets) {
      final task = entryOf(t) ?? (t.board ? null : _synthesize(t, ref));
      if (task == null) continue;
      out[task.id] = TaskDetail(
        task: task,
        reporter: _person(t.reporter),
        created: t.created,
        description: t.desc,
        acceptanceCriteria: t.ac,
        subtasks: [for (final k in t.subs) ref(k)],
        links: [
          for (final (kind, key) in t.links) LinkedTask(kind: kind, relation: _relation(kind), task: ref(key)),
        ],
        attachments: t.attach,
        comments: [
          for (final (who, at, body) in t.comments) TaskComment(author: _person(who)!, created: at.resolve(now), body: body),
        ],
        components: t.components,
        fixVersions: [if (t.fix.isNotEmpty) t.fix],
        timeTracking: t.time,
        fetched: now,
        location: t.location,
      );
    }
    return out;
  }

  /// What a task without a designed detail shows: its card's fields.
  static TaskDetail basic(TaskEntry task) => TaskDetail(task: task, fetched: DateTime.now());

  /// An off-board ticket the board's mocks don't have yet.
  static TaskEntry _synthesize(_Ticket t, TaskRef Function(String) ref) => TaskEntry(
        id: 'mock-${t.src}/${t.key}',
        sourceId: 'mock-${t.src}',
        kind: t.src == 'GH' ? TaskSourceKind.github : TaskSourceKind.jira,
        key: t.key,
        title: t.title,
        column: t.column,
        priority: t.priority,
        type: t.type,
        typeName: _typeName(t.type),
        sourceStatus: t.status,
        assignee: _person(t.assignee),
        mine: t.assignee == 'me',
        context: 'Pricing',
        parent: t.parent.isEmpty ? null : ref(t.parent),
        subtasksTotal: t.subs.length,
        commentCount: t.comments.length,
        updated: DateTime.now().subtract(const Duration(hours: 5)),
        url: t.src == 'JI' ? 'https://pricing.atlassian.net/browse/${t.key}' : '',
      );

  static String _typeName(TaskType t) => switch (t) {
        TaskType.story => 'Story',
        TaskType.bug => 'Bug',
        TaskType.subtask => 'Sub-task',
        TaskType.epic => 'Epic',
        TaskType.issue => 'Issue',
        _ => 'Task',
      };

  static String _relation(LinkKind k) => switch (k) {
        LinkKind.blocks => 'blocks',
        LinkKind.blockedBy => 'is blocked by',
        LinkKind.relates => 'relates to',
        LinkKind.duplicates => 'duplicates',
        LinkKind.duplicatedBy => 'is duplicated by',
        LinkKind.other => 'links to',
      };

  static const _people = {
    'me': TaskPerson(id: 'me', name: 'Mauri', initials: 'M', you: true),
    'ana': TaskPerson(id: 'ana', name: 'Ana Gómez', initials: 'AG'),
    'lucia': TaskPerson(id: 'lucia', name: 'Lucía', initials: 'L'),
    'tomas': TaskPerson(id: 'tomas', name: 'Tomás', initials: 'T'),
    'valentina': TaskPerson(id: 'valentina', name: 'Valentina', initials: 'V'),
    'nico': TaskPerson(id: 'nico', name: 'Nico', initials: 'N'),
  };

  static TaskPerson? _person(String id) => _people[id];

  static const _kb = 1024;
  static const _h = 3600;

  static final _tickets = <_Ticket>[
    // To do
    _Ticket(
      'PRC-10599', TaskType.bug, 'Generación automática de precios para los canales (Hijas)', TaskColumn.todo, 'To Do',
      priority: TaskPriority.high, reporter: 'valentina', created: DateTime(2026, 10, 9), components: const ['price-engine'], fix: '2026.11',
      desc: _d10599,
      ac: '- [ ] Las 12 hijas reciben precio en la corrida de las 6 h\n- [ ] Alerta si una hija queda más de 24 h sin precio',
      links: const [(LinkKind.relates, 'PRC-11340'), (LinkKind.duplicates, 'PRC-10577')],
      attach: const [
        TaskAttachment(name: 'precios-hijas-2026-10-25.log', kind: 'Log', sizeBytes: 2516582),
        TaskAttachment(name: 'canales-afectados.csv', kind: 'CSV', sizeBytes: 3 * _kb),
      ],
      comments: _c10599,
    ),
    _Ticket(
      'PRC-11354', TaskType.subtask, 'Migracion a Graviton (Parte 4/4)', TaskColumn.todo, 'To Do',
      priority: TaskPriority.low, parent: 'PRC-11300', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 14), components: const ['price-reader-v2'],
      desc: 'Último tramo: mover `price-reader-v2` a nodos arm64 cuando terminen las migraciones de PRC-11355.',
      links: const [(LinkKind.blockedBy, 'PRC-11355')],
      comments: [('ana', const _At.day(10, 24), 'Arrancá cuando esté verde staging.')],
    ),
    _Ticket(
      'PRC-11321', TaskType.task, 'Analisis: Migracion a Envoy', TaskColumn.todo, 'Backlog',
      priority: TaskPriority.medium, assignee: 'tomas', reporter: 'ana', created: DateTime(2026, 10, 2),
      desc: 'Evaluar reemplazar el balanceador actual por Envoy en `price-reader-v2`. Comparar latencia p99 y costo.',
      links: const [(LinkKind.relates, 'PRC-11355')],
      comments: [('tomas', const _At.day(10, 20), 'Lo dejo para el próximo sprint.'), ('nico', const _At.day(10, 25), 'Sumo: medir también el retry budget.')],
    ),
    _Ticket(
      'PRC-11371', TaskType.story, 'Precios por zona de envío en checkout', TaskColumn.todo, 'To Do',
      priority: TaskPriority.medium, parent: 'PRC-11250', assignee: 'valentina', reporter: 'ana', created: DateTime(2026, 10, 21),
      desc: 'Mostrar en checkout el precio final según la zona de envío.',
    ),
    _Ticket(
      'zen-engine#42', TaskType.issue, 'Retry on 502 from pricing API', TaskColumn.todo, 'Open',
      src: 'GH', assignee: 'me', reporter: 'nico', created: DateTime(2026, 10, 24),
      desc: 'The pricing client gives up on the first `502 Bad Gateway`. During deploys we see bursts of 502s for about 20 s.\n'
          '### Proposal\n'
          '- Retry idempotent `GET`s up to 3 times with jittered backoff\n'
          '- Respect `Retry-After`\n'
          '- Never retry `POST /prices`',
      comments: [
        ('nico', const _At.day(10, 24), 'Seen again in staging during the 14:00 deploy.'),
        ('me', const _At.day(10, 25), 'Taking it. Will reuse the backoff from `price-reader-v2`.'),
        ('tomas', const _At.ago(Duration(days: 1)), 'Please keep the total budget under 2 s.'),
      ],
    ),
    _Ticket(
      'Weekly.md', TaskType.todo, 'Revisar costos de AWS', TaskColumn.todo, '',
      src: 'OB', matchTitle: true, assignee: 'me', location: 'Weekly.md · line 14',
      desc: '## Semana 44\n- [x] Mandar resumen del sprint\n- [ ] Revisar costos de AWS\n- [ ] Pedir acceso a Cost Explorer para Tomás',
    ),
    _Ticket(
      'Inbox', TaskType.todo, 'Rotate staging Kafka credentials', TaskColumn.todo, '',
      src: 'TD', matchTitle: true, priority: TaskPriority.high, assignee: 'me', location: 'Todoist · Inbox',
      desc: 'Old ones expire on Friday.',
    ),
    // In progress
    _Ticket(
      'PRC-11355', TaskType.story, 'migraciones', TaskColumn.doing, 'In Progress',
      priority: TaskPriority.low, parent: 'PRC-11300', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 14),
      components: const ['price-admin', 'price-reader-v2'], fix: '2026.11',
      time: const TimeTracking(estimate: '3d', logged: '1d 4h', remaining: '1d 6h', estimateSeconds: 24 * _h, loggedSeconds: 12 * _h, remainingSeconds: 14 * _h),
      subs: const ['PRC-11356', 'PRC-11357', 'PRC-11358', 'PRC-11359'],
      links: const [(LinkKind.blockedBy, 'PRC-11340'), (LinkKind.relates, 'PRC-11321')],
      attach: const [
        TaskAttachment(name: 'graviton-rollout.png', kind: 'PNG image', sizeBytes: 412 * _kb),
        TaskAttachment(name: 'price_history_counts.csv', kind: 'CSV', sizeBytes: 88 * _kb),
        TaskAttachment(name: 'migracion-graviton.pdf', kind: 'PDF', sizeBytes: 1258291),
      ],
      desc: _d11355,
      ac: _ac11355,
      comments: _c11355,
    ),
    _Ticket(
      'PRC-412', TaskType.story, 'Bulk discounts by category', TaskColumn.doing, 'In Progress',
      priority: TaskPriority.high, parent: 'PRC-11280', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 15),
      desc: 'Admins set a discount for a whole category; `price-admin` publishes one event per affected SKU.',
      ac: '- [x] Discount applies to every SKU in the category\n- [ ] One Kafka event per SKU, in batches',
      comments: [('ana', const _At.day(10, 23), 'Remember the 30% cap.'), ('me', const _At.day(10, 27), 'Consumer done, now the admin API.')],
    ),
    _Ticket(
      'PRC-398', TaskType.bug, 'Rounding error on installment prices', TaskColumn.doing, 'In Progress',
      priority: TaskPriority.high, assignee: 'me', reporter: 'lucia', created: DateTime(2026, 10, 20),
      desc: '12 installments of \$1,000.01 add up to \$12,000.10 instead of \$12,000.12.',
      comments: [('lucia', const _At.day(10, 20), 'Happens only with 12 and 18 installments.'), ('me', const _At.day(10, 26), 'Fixed in the formatter; the migration is waiting on staging.')],
    ),
    _Ticket(
      'PRC-11366', TaskType.task, 'Alertas de margen negativo en Grafana', TaskColumn.doing, 'In Progress',
      priority: TaskPriority.medium, assignee: 'nico', reporter: 'ana', created: DateTime(2026, 10, 21),
      desc: 'Alertar cuando un SKU queda con margen negativo más de 10 minutos.',
      comments: [('nico', const _At.ago(Duration(hours: 4)), 'Dashboard listo, faltan las alertas.')],
    ),
    // In review
    _Ticket(
      'PRC-405', TaskType.story, 'Warm cache on deploy', TaskColumn.review, 'Code Review',
      priority: TaskPriority.medium, assignee: 'me', reporter: 'tomas', created: DateTime(2026, 10, 16),
      desc: 'Preload the 5,000 most read prices before `price-reader-v2` takes traffic.',
      comments: [('tomas', const _At.ago(Duration(days: 1)), 'MR !231 looks good, one nit on the timeout.')],
    ),
    _Ticket(
      'PRC-11338', TaskType.story, 'Validación de márgenes en carga masiva', TaskColumn.review, 'QA',
      priority: TaskPriority.medium, parent: 'PRC-11280', assignee: 'ana', reporter: 'valentina', created: DateTime(2026, 10, 8),
      desc: 'Rechazar filas del CSV que dejan margen por debajo del mínimo de la categoría.',
      comments: [('valentina', const _At.day(10, 27), 'En QA con el archivo de octubre.')],
    ),
    // Done
    _Ticket(
      'PRC-11340', TaskType.task, 'Limpieza de ofertas de canales', TaskColumn.done, 'Done',
      priority: TaskPriority.medium, assignee: 'lucia', reporter: 'ana', created: DateTime(2026, 10, 6),
      desc: 'Borrar ofertas vencidas de los canales antes de la migración.',
      links: const [(LinkKind.blocks, 'PRC-11355')],
      comments: [('lucia', const _At.day(10, 26), 'Listo, 18k ofertas borradas.')],
    ),
    _Ticket(
      'PRC-11356', TaskType.subtask, 'Migrar job de precios', TaskColumn.done, 'Done',
      priority: TaskPriority.low, parent: 'PRC-11355', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 14),
      desc: 'Correr el job de precios en un nodo arm64.',
    ),
    _Ticket(
      'PRC-377', TaskType.bug, 'Fix currency rounding in exports', TaskColumn.done, 'Done',
      priority: TaskPriority.medium, assignee: 'me', reporter: 'lucia', created: DateTime(2026, 10, 1),
      desc: 'PR #518 merged.',
    ),
    _Ticket(
      'Inbox', TaskType.todo, 'Update pricing on-call runbook', TaskColumn.done, '',
      src: 'TD', matchTitle: true, priority: TaskPriority.low, assignee: 'me', location: 'Todoist · Inbox',
      desc: 'Done by Claude, in Notion.',
    ),
    // Not on the board: epics, the rest of the sub-tasks, an old duplicate.
    _Ticket(
      'PRC-11300', TaskType.epic, 'Migración a Graviton', TaskColumn.doing, 'In Progress',
      board: false, color: 'violet', priority: TaskPriority.medium, assignee: 'ana', reporter: 'ana', created: DateTime(2026, 9, 30),
      desc: 'Mover todos los servicios de Pricing a instancias Graviton (arm64) antes de fin de año.',
      subs: const ['PRC-11351', 'PRC-11352', 'PRC-11353', 'PRC-11354', 'PRC-11355'],
    ),
    _Ticket(
      'PRC-11280', TaskType.epic, 'Descuentos por volumen', TaskColumn.doing, 'In Progress',
      board: false, color: 'teal', priority: TaskPriority.medium, assignee: 'ana', reporter: 'ana', created: DateTime(2026, 9, 12),
      desc: 'Descuentos por categoría y por cantidad.',
      subs: const ['PRC-412', 'PRC-11338'],
    ),
    _Ticket(
      'PRC-11250', TaskType.epic, 'Precios regionales', TaskColumn.todo, 'To Do',
      board: false, color: 'amber', priority: TaskPriority.medium, assignee: 'valentina', reporter: 'ana', created: DateTime(2026, 9, 2),
      desc: 'Precio por zona de envío.',
      subs: const ['PRC-11371'],
    ),
    _Ticket('PRC-11351', TaskType.subtask, 'Migracion a Graviton (Parte 1/4)', TaskColumn.done, 'Done',
        board: false, priority: TaskPriority.low, parent: 'PRC-11300', assignee: 'lucia', reporter: 'ana', created: DateTime(2026, 10, 1)),
    _Ticket('PRC-11352', TaskType.subtask, 'Migracion a Graviton (Parte 2/4)', TaskColumn.done, 'Done',
        board: false, priority: TaskPriority.low, parent: 'PRC-11300', assignee: 'tomas', reporter: 'ana', created: DateTime(2026, 10, 1)),
    _Ticket('PRC-11353', TaskType.subtask, 'Migracion a Graviton (Parte 3/4)', TaskColumn.doing, 'In Progress',
        board: false, priority: TaskPriority.low, parent: 'PRC-11300', assignee: 'nico', reporter: 'ana', created: DateTime(2026, 10, 1)),
    _Ticket('PRC-11357', TaskType.subtask, 'Analisis', TaskColumn.doing, 'In Progress',
        board: false, priority: TaskPriority.low, parent: 'PRC-11355', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 14)),
    _Ticket('PRC-11358', TaskType.subtask, 'actualizar planilla', TaskColumn.todo, 'To Do',
        board: false, priority: TaskPriority.low, parent: 'PRC-11355', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 14)),
    _Ticket('PRC-11359', TaskType.subtask, 'verificacion en entornos', TaskColumn.todo, 'To Do',
        board: false, priority: TaskPriority.low, parent: 'PRC-11355', assignee: 'me', reporter: 'ana', created: DateTime(2026, 10, 14)),
    _Ticket('PRC-10577', TaskType.bug, 'Precios duplicados en canal Hijas', TaskColumn.done, 'Done',
        board: false, priority: TaskPriority.medium, assignee: 'tomas', reporter: 'valentina', created: DateTime(2026, 9, 18),
        desc: 'Cerrado: se movió el topic a `prices.v2`.'),
  ];

  static const _d11355 = '## Contexto\n'
      'Como parte de PRC-11300 movemos los servicios de Pricing a instancias Graviton (arm64). Este ticket cubre las **migraciones de base** que hay que correr antes del cambio de nodos. @Ana Gómez confirmó la ventana del jueves 30 a las 22 h.\n'
      '## Pasos\n'
      '1. Congelar las escrituras del job de precios (PRC-11356).\n'
      '2. Correr las migraciones en staging, por lotes de 500k filas.\n'
      '3. Comparar conteos de `price_history` antes y después.\n'
      '4. Actualizar la planilla de seguimiento y verificar en todos los entornos.\n'
      '### Chequeos previos\n'
      '- [x] Backup de `price_history`\n'
      '- [x] Snapshot del RDS de staging\n'
      '- [ ] Avisar en #pricing-oncall antes de empezar\n'
      '### Conteo de control\n'
      '```sql\n'
      '-- precios por canal en la última semana\n'
      'SELECT channel_id, COUNT(*) AS prices\n'
      'FROM price_history\n'
      "WHERE updated_at >= NOW() - INTERVAL '7 days'\n"
      'GROUP BY channel_id\n'
      'ORDER BY prices DESC\n'
      'LIMIT 20;\n'
      '```\n'
      '### Entornos\n'
      '| Entorno | Instancia actual | Destino | Estado |\n'
      '| --- | --- | --- | --- |\n'
      '| dev | m6i.large | m7g.large | Listo |\n'
      '| staging | m6i.large | m7g.large | Hoy |\n'
      '| prod | m6i.xlarge | m7g.xlarge | Pendiente |\n'
      'Detalle del rollout en el [Runbook de migraciones](https://wiki.pricing.local/runbooks/migraciones).\n'
      '![Diagrama del rollout, 1280×720](graviton-rollout.png)';

  static const _d10599 = 'Desde el deploy del lunes 6, las **cuentas hijas** de los canales marketplace no reciben precio nuevo. El job `generar_precios_hijas` termina sin errores pero no publica en `prices.v2`.\n'
      '## Impacto\n'
      '- 12 canales hijas con precio desactualizado\n'
      '- Lucía lo publica a mano cada mañana\n'
      '## Para reproducir\n'
      '1. Correr el job en staging con `--channel=marketplace`\n'
      '2. Mirar el topic: no hay mensajes para las hijas\n'
      '```sql\n'
      'SELECT channel_id, last_price_at\n'
      'FROM channels\n'
      'WHERE parent_channel_id IS NOT NULL\n'
      "  AND last_price_at < NOW() - INTERVAL '1 day';\n"
      '```';

  static const _ac11355 = '- [x] Las migraciones corren en staging sin downtime\n'
      '- [ ] Los conteos de `price_history` coinciden antes y después\n'
      '- [ ] El job de precios corre en arm64 sin errores durante 24 h\n'
      '- [ ] La planilla de seguimiento está actualizada';

  static final _c11355 = <(String, _At, String)>[
    ('ana', const _At.day(10, 22), 'Te lo asigno para este sprint. La ventana de mantenimiento es el **jueves 30 a las 22 h**.'),
    ('tomas', const _At.day(10, 23), 'Ojo que `price_history` tiene unos 40 M de filas en prod, conviene correrlo por lotes.'),
    ('me', const _At.day(10, 24), 'Dale, lo parto en lotes de 500k. Dejo el script en el MR.'),
    ('lucia', const _At.day(10, 26), 'Ya cerré PRC-11340, las ofertas viejas no deberían molestar.'),
    ('ana', const _At.ago(Duration(days: 1)), '@Mauri ¿llegamos con staging antes del jueves?'),
    ('me', const _At.ago(Duration(hours: 3)), 'Sí, staging hoy a la tarde. Queda **verificacion en entornos** (PRC-11359) para mañana.'),
  ];

  static final _c10599 = <(String, _At, String)>[
    ('valentina', const _At.day(10, 9), 'Las hijas no reciben precio nuevo desde el deploy del lunes. Adjunto el log.'),
    ('nico', const _At.day(10, 9), 'Confirmo: `generar_precios_hijas` termina OK pero no publica nada.'),
    ('ana', const _At.day(10, 10), 'Lo subo a High. @Valentina ¿cuántos canales están afectados?'),
    ('valentina', const _At.day(10, 10), '12 canales hijas, todos de marketplace.'),
    ('tomas', const _At.day(10, 13), 'Puede ser el cambio de topic de PRC-10577. El consumer sigue escuchando `prices.v1`.'),
    ('nico', const _At.day(10, 14), 'No es eso, el topic está bien. El problema es el filtro por `parent_channel_id`.'),
    ('lucia', const _At.day(10, 16), 'Mientras tanto lo publico a mano cada mañana.'),
    ('ana', const _At.day(10, 20), 'Queda fuera del sprint 2026.21, lo arrastramos.'),
    ('valentina', const _At.day(10, 22), 'Hoy volvió a fallar: dos canales con el precio de la semana pasada.'),
    ('nico', const _At.day(10, 23), 'Dejé en la descripción el query para detectar las hijas sin precio.'),
    ('tomas', const _At.day(10, 24), 'Sigue sin asignar, ¿alguien lo toma?'),
    ('ana', const _At.day(10, 26), '@Mauri cuando cierres PRC-11355, ¿lo podés mirar?'),
    ('me', const _At.ago(Duration(days: 1)), 'Sí, mañana lo veo. Parece el mismo filtro que tocamos en PRC-11340.'),
    ('lucia', const _At.ago(Duration(hours: 2)), 'Hoy también lo publiqué a mano. Marketplace volvió a preguntar.'),
  ];
}

/// When a comment was written: a day of 2026, or a while before now.
class _At {
  const _At.ago(this.ago)
      : month = 0,
        dayOfMonth = 0;
  const _At.day(this.month, this.dayOfMonth) : ago = Duration.zero;

  final Duration ago;
  final int month;
  final int dayOfMonth;

  DateTime resolve(DateTime now) => month == 0 ? now.subtract(ago) : DateTime(2026, month, dayOfMonth, 11);
}

/// One ticket of the design's data.
class _Ticket {
  _Ticket(
    this.key,
    this.type,
    this.title,
    this.column,
    this.status, {
    this.src = 'JI',
    this.matchTitle = false,
    this.board = true,
    this.color = '',
    this.priority = TaskPriority.none,
    this.parent = '',
    this.assignee = '',
    this.reporter = '',
    this.created,
    this.components = const [],
    this.fix = '',
    this.time,
    this.subs = const [],
    this.links = const [],
    this.attach = const [],
    this.desc = '',
    this.ac = '',
    this.comments = const [],
    this.location = '',
  });

  final String key;
  final TaskType type;
  final String title;
  final TaskColumn column;
  final String status;
  final String src;

  /// Personal tasks share keys ("Inbox"): found by title.
  final bool matchTitle;
  final bool board;
  final String color;
  final TaskPriority priority;
  final String parent;
  final String assignee;
  final String reporter;
  final DateTime? created;
  final List<String> components;
  final String fix;
  final TimeTracking? time;
  final List<String> subs;
  final List<(LinkKind, String)> links;
  final List<TaskAttachment> attach;
  final String desc;
  final String ac;
  final List<(String, _At, String)> comments;
  final String location;
}
