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
}
