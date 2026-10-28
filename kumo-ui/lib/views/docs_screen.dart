import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../shell/screen_chrome.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kicons.dart';

/// Confluence / Notion / Obsidian in one reader, with "use as agent context".
class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  String _page = 'Discount rules v3';
  bool _attached = false;
  bool _wholePage = true;
  String _session = 'codex';

  static const _sources = [
    ('CF', 'Confluence', 'Pricing', ['Discount rules v3', 'Kafka topics and owners', 'Incident: stale prices']),
    ('NO', 'Notion', 'Eng handbook', ['ADR-014 · Kafka topic naming', 'ADR-009 · Pagination', 'On-call · Pricing runbook']),
    ('OB', 'Obsidian', 'local vault', ['PRC-412 scratchpad', 'pgx CopyFrom notes']),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ScreenFrame(
      toolbar: ScreenToolbar(
        breadcrumb: Breadcrumb(icon: KIcons.docs, parts: ['Confluence', 'Pricing', _page]),
        primary: KButton(label: 'Open in Confluence', icon: KIcons.external, height: 36, onTap: () {}),
      ),
      body: LayoutBuilder(builder: (context, box) {
        final showAside = box.maxWidth >= 980;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 240, child: _tree(context)),
          const SizedBox(width: 10),
          Expanded(child: _reader(context)),
          if (showAside) ...[const SizedBox(width: 10), SizedBox(width: 310, child: _aside(context))],
        ]);
      }),
      status: const [
        Flexible(child: StatusText('Confluence · 214 pages indexed', flexible: true)),
        Flexible(child: StatusText('Notion · 96 pages', flexible: true)),
        Flexible(child: StatusText('Obsidian vault · 41 notes, local', flexible: true)),
        Spacer(),
        StatusText('Read-only unless an agent has write access'),
      ],
    );
  }

  Widget _tree(BuildContext context) {
    final c = context.c;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Icon(KIcons.search, size: 14, color: c.text3),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                style: sans(12.5, color: c.text),
                cursorColor: c.acc,
                decoration: InputDecoration.collapsed(hintText: 'Filter docs', hintStyle: sans(12.5, color: c.text3)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final (k, name, space, pages) in _sources) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(children: [
              SourceTile(k, size: 20),
              const SizedBox(width: 8),
              Text(name, style: sans(12.5, weight: FontWeight.w600, color: c.text)),
              const SizedBox(width: 6),
              Flexible(child: Text(space, overflow: TextOverflow.ellipsis, style: sans(11, color: c.text3))),
            ]),
          ),
          for (final p in pages)
            KPressable(
              onTap: () => setState(() => _page = p),
              selected: p == _page,
              semanticLabel: p,
              builder: (context, hover, focus) => Container(
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.fromLTRB(34, 6, 8, 6),
                decoration: p == _page ? chipDecoration(c, radius: 9, fill: c.navActive) : BoxDecoration(color: hover ? c.tile : null, borderRadius: BorderRadius.circular(9)),
                child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(12.5, weight: p == _page ? FontWeight.w600 : FontWeight.w400, color: p == _page ? c.text : c.text2)),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }

  Widget _reader(BuildContext context) {
    final c = context.c;
    final body = sans(14, color: c.text2, height: 1.65);
    Widget h2(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: sans(16, weight: FontWeight.w600, color: c.text)));
    final isRules = _page == 'Discount rules v3';
    return GlassPanel(
      fill: c.paper,
      child: ListView(padding: const EdgeInsets.fromLTRB(36, 30, 36, 30), children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_page, style: sans(28, weight: FontWeight.w600, color: c.text, letterSpacing: -0.7, height: 1.15)),
            const SizedBox(height: 8),
            Text('Pricing team · edited 3 days ago · read by 2 agents this week', style: sans(12, color: c.text3)),
            if (!isRules) ...[
              const SizedBox(height: 24),
              Text('Pick “Discount rules v3” to see the full page in this mock.', style: body),
            ] else ...[
              h2('Scope'),
              Text(
                'These rules cover list-price discounts stored by price-admin. Installment and financing prices are derived later by price-reader-v2 and are never stored with a discount applied.',
                style: body,
              ),
              h2('Precedence'),
              for (final (i, t) in const [(1, 'SKU discount'), (2, 'Category discount, including bulk'), (3, 'Campaign discount')])
                Padding(padding: const EdgeInsets.only(left: 6, bottom: 2), child: Text('$i.  $t', style: body)),
              const SizedBox(height: 8),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: c.accSoft, borderRadius: BorderRadius.circular(4), border: Border.all(color: c.acc.withAlpha(80))),
                  child: Text('Only the highest-precedence rule applies. Rules never stack.', style: body.copyWith(color: c.text)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(9)),
                  child: Text('sent to Claude · PRC-412', style: sans(11, weight: FontWeight.w600, color: c.acc)),
                ),
              ]),
              h2('Rounding'),
              Text('Round half-up to two decimals after applying the discount, never before.', style: body),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(12)),
                child: Text('final := list.Mul(one.Sub(pct)).Round(2)', style: mono(12.5, color: c.text)),
              ),
              h2('Events'),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Every change publishes '),
                  TextSpan(text: 'price.discounts.v1', style: mono(12.5, color: c.text)),
                  const TextSpan(text: ' with the previous and the new value, keyed by SKU.'),
                ]),
                style: body,
              ),
            ],
          ]),
          ),
        ),
      ]),
    );
  }

  Widget _aside(BuildContext context) {
    final c = context.c;
    final s = AppScope.read(context);
    const refs = [
      ('JI', 'PRC-412 · Bulk discounts', 'Jira · linked by Claude', false),
      ('JI', 'PRC-398 · Installment rounding', 'Jira · linked by you', false),
      ('JI', 'PRC-421 · Price history API', 'Jira · linked doc', false),
      ('GO', 'discount/service.go:42', 'price-admin · code comment', true),
      ('NO', 'ADR-014 · Kafka topic naming', 'Notion · mentions this page', false),
    ];
    return ListView(padding: EdgeInsets.zero, children: [
      Section(
        strong: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(KIcons.agent, size: 16, color: c.acc),
            const SizedBox(width: 8),
            Text('Use with an agent', style: sans(13, weight: FontWeight.w600, color: c.text)),
          ]),
          const SizedBox(height: 12),
          KSelect<String>(
            label: 'Agent session',
            value: _session,
            items: const [('codex', 'Codex · PRC-398 rounding'), ('claude', 'Claude Code · PRC-412 bulk discounts'), ('gemini', 'Gemini CLI · CU-2291 audit log')],
            onChanged: (v) => setState(() {
              _session = v;
              _attached = false;
            }),
          ),
          const SizedBox(height: 10),
          KSegmented<bool>(
            expand: true,
            label: 'What to send',
            value: _wholePage,
            onChanged: (v) => setState(() => _wholePage = v),
            items: const [(true, 'Whole page', null), (false, 'Rounding only', null)],
          ),
          const SizedBox(height: 12),
          if (!_attached)
            KButton.primary(label: 'Attach as context', expand: true, onTap: () => setState(() => _attached = true))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: c.okSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(KIcons.check, size: 14, color: c.ok),
                const SizedBox(width: 8),
                Expanded(child: Text('Attached · stays in sync', style: sans(12.5, weight: FontWeight.w600, color: c.ok))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Section(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PanelHeading('Referenced by', size: 13),
          const SizedBox(height: 8),
          for (final (k, title, note, code) in refs)
            KPressable(
              onTap: () => s.view = code ? KumoView.files : KumoView.tasks,
              semanticLabel: title,
              builder: (context, hover, focus) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SourceTile(k, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: (code ? mono(12, color: c.text) : sans(12.5, color: c.text)).copyWith(color: hover ? c.acc : null)),
                      Text(note, style: sans(11, color: c.text3)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}
