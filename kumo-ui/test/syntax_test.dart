import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/editor/syntax.dart';

void main() {
  test('go: keywords, strings, calls and types', () {
    final segs = Syntax.line(Lang.go, 'func (r *Repository) UpsertMany(ctx context.Context) error {');
    expect(segs.first, ('func', Tok.kw));
    expect(segs.contains(('Repository', Tok.type)), isTrue);
    expect(segs.contains(('UpsertMany', Tok.fn)), isTrue);
    expect(segs.contains(('error', Tok.type)), isTrue);
    expect(Syntax.line(Lang.go, '// comment').single, ('// comment', Tok.com));
    expect(Syntax.line(Lang.go, '    "fmt"').last, ('"fmt"', Tok.str));
  });

  test('yaml: keys, values, comments and list items', () {
    final kv = Syntax.line(Lang.yaml, '  port: 8080');
    expect(kv.contains(('port', Tok.key)), isTrue);
    expect(kv.last, ('8080', Tok.num));
    final withComment = Syntax.line(Lang.yaml, '    bulk: price.discounts.bulk.v1   # new consumer');
    expect(withComment.last.$2, Tok.com);
    final item = Syntax.line(Lang.yaml, '    - kafka-0.pricing.svc:9092');
    expect(item.any((s) => s.$2 == Tok.key), isFalse, reason: 'host:port in a list item is a value, not a key');
    expect(Syntax.line(Lang.yaml, r'  dsn: ${POSTGRES_DSN}').last, (r'${POSTGRES_DSN}', Tok.type));
  });

  test('json: keys vs string values', () {
    final segs = Syntax.line(Lang.json, '  "percent": 15,');
    expect(segs.contains(('"percent"', Tok.key)), isTrue);
    expect(segs.contains(('15', Tok.num)), isTrue);
    expect(Syntax.line(Lang.json, '    "TV-55-QLED-4K",').contains(('"TV-55-QLED-4K"', Tok.str)), isTrue);
  });

  test('segments always rebuild the original line exactly', () {
    const samples = {
      Lang.go: '        rows = append(rows, []any{d.SKU, d.Percent})',
      Lang.yaml: '<<<<<<< HEAD (feat/PRC-412-bulk-discounts)',
      Lang.json: '  "endsAt": null,',
      Lang.makefile: '    migrate -path ./migrations -database \$(POSTGRES_DSN) up',
      Lang.markdown: 'Start Postgres with `docker compose up`, then `make test`.',
    };
    samples.forEach((lang, line) {
      expect(Syntax.line(lang, line).map((s) => s.$1).join(), line, reason: '$lang');
    });
  });

  test('langOf maps files to languages', () {
    expect(langOf('internal/discount/bulk.go').lang, Lang.go);
    expect(langOf('deploy/k8s/values.yaml').lang, Lang.yaml);
    expect(langOf('testdata/bulk_discount.json').lang, Lang.json);
    expect(langOf('README.md').lang, Lang.markdown);
    expect(langOf('Makefile').lang, Lang.makefile);
    expect(langOf('go.mod').badge, 'MOD');
  });

  test('rust: keywords, macros, attributes, lifetimes and types', () {
    final f = Syntax.line(Lang.rust, 'pub fn tasks_update_to<\'a>(board: &\'a TaskBoard, sent: &mut u64) -> Option<String> {');
    expect(f.first, ('pub', Tok.kw));
    expect(f, contains(('fn', Tok.kw)));
    expect(f.any((s) => s.$1.contains('tasks_update_to') && s.$2 == Tok.text), isTrue, reason: 'followed by <, not (');
    expect(f, contains(("'a", Tok.type)));
    expect(f, contains(('TaskBoard', Tok.type)));
    expect(f, contains(('u64', Tok.type)));
    expect(f, contains(('mut', Tok.kw)));

    final m = Syntax.line(Lang.rust, '    println!("{} tasks", tasks.len()); // done');
    expect(m, contains(('println', Tok.fn)));
    expect(m, contains(('"{} tasks"', Tok.str)));
    expect(m, contains(('len', Tok.fn)));
    expect(m.last, ('// done', Tok.com));

    expect(Syntax.line(Lang.rust, '#[derive(Debug, Clone)]').single, ('#[derive(Debug, Clone)]', Tok.key));
    expect(Syntax.line(Lang.rust, "    let c = '\\n';"), contains(("'\\n'", Tok.str)));
    expect(Syntax.line(Lang.rust, r"let q = '\'';"), contains((r"'\''", Tok.str)));
    expect(Syntax.line(Lang.rust, r'    let s = r#"say "hi""#;'), contains((r'r#"say "hi""#', Tok.str)));
    expect(Syntax.line(Lang.rust, '/// Docs for the item.').single.$2, Tok.com);
    expect(Syntax.line(Lang.rust, ' * inside a block comment').single.$2, Tok.com);
    expect(Syntax.line(Lang.rust, 'let n = 1_000u32;'), contains(('1_000u32', Tok.num)));
  });

  test('toml: sections, keys, strings and numbers', () {
    expect(Syntax.line(Lang.toml, '[workspace.dependencies]').single, ('[workspace.dependencies]', Tok.head));
    final dep = Syntax.line(Lang.toml, 'tokio = { version = "1.48", features = ["full"] } # runtime');
    expect(dep.first, ('tokio', Tok.key));
    expect(dep, contains(('"1.48"', Tok.str)));
    expect(dep.last, ('# runtime', Tok.com));
    expect(Syntax.line(Lang.toml, 'edition = 2024').last, ('2024', Tok.num));
  });

  test('other languages: comments, strings and keywords per language', () {
    expect(Syntax.line(Lang.python, 'def run(self):  # go').first, ('def', Tok.kw));
    expect(Syntax.line(Lang.python, 'def run(self):  # go').last, ('# go', Tok.com));
    expect(Syntax.line(Lang.shell, r'echo "$HOME" && cd ${DIR}'), contains((r'${DIR}', Tok.type)));
    expect(Syntax.line(Lang.sql, 'SELECT id FROM tasks -- all').first, ('SELECT', Tok.kw));
    expect(Syntax.line(Lang.sql, 'SELECT id FROM tasks -- all').last, ('-- all', Tok.com));
    expect(Syntax.line(Lang.ts, r'const x = `id: ${id}`;'), contains((r'`id: ${id}`', Tok.str)));
    expect(Syntax.line(Lang.dart, '@override'), [('@override', Tok.type)]);
    expect(Syntax.line(Lang.c, '#include <stdio.h>').first, ('#include', Tok.kw));
  });

  test('every language rebuilds the original line exactly', () {
    const line = r'''  let x = foo("a\"b", 'c', `d`) + 0x1F; /* c */ // end # $Y -- z #[a] 'b''';
    for (final lang in Lang.values) {
      expect(Syntax.line(lang, line).map((s) => s.$1).join(), line, reason: '$lang');
    }
  });

  test('langOf knows Rust, TOML and friends', () {
    expect(langOf('crates/domain/src/lib.rs').lang, Lang.rust);
    expect(langOf('crates/domain/src/lib.rs').badge, 'RS');
    expect(langOf('Cargo.toml').lang, Lang.toml);
    expect(langOf('Cargo.lock').lang, Lang.toml);
    expect(langOf('lib/main.dart').lang, Lang.dart);
    expect(langOf('web/app.tsx').lang, Lang.ts);
    expect(langOf('scripts/run.sh').lang, Lang.shell);
    expect(langOf('Dockerfile').lang, Lang.shell);
    expect(langOf('NOTES').lang, Lang.plain);
  });
}
