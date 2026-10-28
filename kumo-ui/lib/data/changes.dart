/// What the agent changed in the current worktree, line by line. The daemon
/// will stream this from `git diff` (vs. the merge base for committed
/// changes, vs. HEAD for the working tree); the mock mirrors the canvas.
library;

enum DiffKind { context, added, deleted }

class DiffLine {
  const DiffLine(this.kind, this.text);
  final DiffKind kind;
  final String text;
}

class ChangedFile {
  const ChangedFile({required this.path, required this.kind, required this.lines, this.committed = false, this.writing = false});

  final String path;

  /// 'A' added, 'M' modified.
  final String kind;
  final List<DiffLine> lines;

  /// Already in a commit on the branch (not in the working tree).
  final bool committed;

  /// The agent is still writing it.
  final bool writing;

  int get added => lines.where((l) => l.kind == DiffKind.added).length;
  int get deleted => lines.where((l) => l.kind == DiffKind.deleted).length;
  String get name => path.substring(path.lastIndexOf('/') + 1);
  String get dir => path.substring(0, path.lastIndexOf('/') + 1);
}

/// One rendered row of the file viewer.
class DiffRow {
  const DiffRow.line(this.line, this.oldNo, this.newNo, {this.hunk})
      : fold = 0;
  const DiffRow.fold(this.fold)
      : line = null,
        oldNo = null,
        newNo = null,
        hunk = null;

  final DiffLine? line;
  final int? oldNo;
  final int? newNo;

  /// Index of the change this row starts, if it starts one.
  final int? hunk;

  /// Number of hidden unchanged lines (fold rows only).
  final int fold;

  bool get isFold => line == null;
}

/// Rows for [file]: every line with old/new numbers, or (with [changesOnly])
/// only the lines within [context] of a change, the rest folded.
List<DiffRow> diffRows(ChangedFile file, {bool changesOnly = false, int context = 3}) {
  final lines = file.lines;
  final changed = [for (final l in lines) l.kind != DiffKind.context];
  bool near(int i) {
    for (var j = i - context; j <= i + context; j++) {
      if (j >= 0 && j < lines.length && changed[j]) return true;
    }
    return false;
  }

  final rows = <DiffRow>[];
  var o = 1, n = 1, hunk = 0, hidden = 0;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final startsHunk = changed[i] && (i == 0 || !changed[i - 1]);
    final keep = !changesOnly || file.kind == 'A' || near(i);
    if (keep) {
      if (hidden > 0) rows.add(DiffRow.fold(hidden));
      hidden = 0;
      rows.add(DiffRow.line(
        l,
        l.kind == DiffKind.added ? null : o,
        l.kind == DiffKind.deleted ? null : n,
        hunk: startsHunk ? hunk : null,
      ));
    } else {
      hidden++;
    }
    if (startsHunk) hunk++;
    if (l.kind != DiffKind.added) o++;
    if (l.kind != DiffKind.deleted) n++;
  }
  if (hidden > 0) rows.add(DiffRow.fold(hidden));
  return rows;
}

int hunkCount(ChangedFile f) {
  var count = 0;
  for (var i = 0; i < f.lines.length; i++) {
    final c = f.lines[i].kind != DiffKind.context;
    if (c && (i == 0 || f.lines[i - 1].kind == DiffKind.context)) count++;
  }
  return count;
}

List<DiffLine> _all(DiffKind k, List<String> ls) => [for (final l in ls) DiffLine(k, l)];
DiffLine _c(String t) => DiffLine(DiffKind.context, t);
DiffLine _a(String t) => DiffLine(DiffKind.added, t);
DiffLine _d(String t) => DiffLine(DiffKind.deleted, t);

abstract final class MockChanges {
  /// Files of the PRC-412 worktree, as shown by `git ls-files`.
  static const tree = [
    'cmd/price-admin/main.go',
    'internal/discount/bulk.go',
    'internal/discount/bulk_test.go',
    'internal/discount/discount.go',
    'internal/discount/repository.go',
    'internal/discount/service.go',
    'internal/http/handler.go',
    'internal/http/routes.go',
    'internal/kafka/bulk_consumer.go',
    'internal/kafka/consumer.go',
    'internal/store/pg/pool.go',
    'migrations/0041_discounts.sql',
    'migrations/0042_discount_category.sql',
    '.golangci.yml',
    'Makefile',
    'README.md',
    'go.mod',
    'go.sum',
  ];

  static final List<ChangedFile> files = [
    ChangedFile(path: 'internal/discount/bulk.go', kind: 'A', lines: _all(DiffKind.added, const [
      'package discount', '', 'import (', '\t"errors"', '\t"time"', ')', '',
      '// BulkDiscount applies one percentage to every SKU of a category.',
      'type BulkDiscount struct {', '\tCategory string', '\tPercent  float64', '\tStartsAt time.Time', '\tEndsAt   time.Time', '\tSKUs     []string', '}', '',
      'var (',
      '\tErrNoSKUs       = errors.New("bulk discount: category has no SKUs")',
      '\tErrBadPercent   = errors.New("bulk discount: percent must be in (0, 90]")',
      '\tErrBadTimeRange = errors.New("bulk discount: ends before it starts")',
      ')', '',
      'func (b BulkDiscount) Validate() error {', '\tswitch {', '\tcase len(b.SKUs) == 0:', '\t\treturn ErrNoSKUs', '\tcase b.Percent <= 0 || b.Percent > 90:', '\t\treturn ErrBadPercent',
      '\tcase !b.EndsAt.After(b.StartsAt):', '\t\treturn ErrBadTimeRange', '\t}', '\treturn nil', '}', '',
      '// Expand turns the aggregate into one Discount per SKU.', 'func (b BulkDiscount) Expand() []Discount {', '\tout := make([]Discount, 0, len(b.SKUs))', '\tfor _, sku := range b.SKUs {',
      '\t\tout = append(out, Discount{SKU: sku, Percent: b.Percent, StartsAt: b.StartsAt, EndsAt: b.EndsAt})', '\t}', '\treturn out', '}',
    ])),
    ChangedFile(path: 'internal/discount/repository.go', kind: 'M', lines: [
      _c('package discount'), _c(''), _c('import ('), _c('\t"context"'), _a('\t"fmt"'), _c(''), _c('\t"github.com/jackc/pgx/v5"'), _c('\t"github.com/jackc/pgx/v5/pgxpool"'), _c(')'), _c(''),
      _c('// Repository persists discounts in PostgreSQL.'), _c('type Repository struct {'), _c('\tdb *pgxpool.Pool'), _c('}'), _c(''),
      _c('func NewRepository(db *pgxpool.Pool) *Repository {'), _c('\treturn &Repository{db: db}'), _c('}'), _c(''),
      _c('func (r *Repository) Upsert(ctx context.Context, d Discount) error {'), _c('\t_, err := r.db.Exec(ctx, upsertSQL, d.SKU, d.Percent, d.StartsAt, d.EndsAt)'),
      _d('\treturn err'), _a('\tif err != nil {'), _a('\t\treturn fmt.Errorf("upsert discount %s: %w", d.SKU, err)'), _a('\t}'), _a('\treturn nil'), _c('}'), _c(''),
      _c('func (r *Repository) UpsertMany(ctx context.Context, ds []Discount) error {'),
      _d('\tfor _, d := range ds {'), _d('\t\tif err := r.Upsert(ctx, d); err != nil {'), _d('\t\t\treturn err'), _d('\t\t}'), _d('\t}'), _d('\treturn nil'),
      _a('\trows := make([][]any, 0, len(ds))'), _a('\tfor _, d := range ds {'), _a('\t\trows = append(rows, []any{d.SKU, d.Percent, d.StartsAt, d.EndsAt})'), _a('\t}'),
      _a('\t_, err := r.db.CopyFrom(ctx,'), _a('\t\tpgx.Identifier{"discounts_staging"},'), _a('\t\t[]string{"sku", "percent", "starts_at", "ends_at"},'), _a('\t\tpgx.CopyFromRows(rows),'), _a('\t)'),
      _a('\tif err != nil {'), _a('\t\treturn fmt.Errorf("copy %d discounts: %w", len(ds), err)'), _a('\t}'), _a('\t_, err = r.db.Exec(ctx, mergeStagingSQL)'), _a('\treturn err'), _c('}'), _c(''),
      _c('func (r *Repository) ByCategory(ctx context.Context, category string) ([]Discount, error) {'), _c('\trows, err := r.db.Query(ctx, byCategorySQL, category)'), _c('\tif err != nil {'),
      _c('\t\treturn nil, err'), _c('\t}'), _c('\treturn pgx.CollectRows(rows, pgx.RowToStructByName[Discount])'), _c('}'),
    ]),
    ChangedFile(path: 'internal/kafka/bulk_consumer.go', kind: 'A', writing: true, lines: _all(DiffKind.added, const [
      'package kafka', '', 'import (', '\t"context"', '\t"encoding/json"', '', '\t"github.com/segmentio/kafka-go"', '', '\t"price-admin/internal/discount"', ')', '',
      'const TopicBulkDiscounts = "price.discounts.bulk.v1"', '', 'type BulkConsumer struct {', '\treader *kafka.Reader', '\tsvc    *discount.Service', '}', '',
      'func (c *BulkConsumer) Run(ctx context.Context) error {', '\tfor {', '\t\tmsg, err := c.reader.FetchMessage(ctx)', '\t\tif err != nil {', '\t\t\treturn err', '\t\t}',
      '\t\tvar b discount.BulkDiscount', '\t\tif err := json.Unmarshal(msg.Value, &b); err != nil {', '\t\t\tcontinue // poison message: it lands in the DLQ', '\t\t}',
    ])),
    ChangedFile(path: 'internal/discount/discount.go', kind: 'M', committed: true, lines: [
      _c('package discount'), _c(''), _c('import "time"'), _c(''), _c('// Discount is a percentage off one SKU for a time window.'), _c('type Discount struct {'),
      _c('\tSKU      string    `db:"sku"`'), _c('\tPercent  float64   `db:"percent"`'), _c('\tStartsAt time.Time `db:"starts_at"`'), _c('\tEndsAt   time.Time `db:"ends_at"`'),
      _a('\tCategory string    `db:"category"`'), _a('\tSource   string    `db:"source"` // "manual" | "bulk"'), _c('}'), _c(''),
      _d('func (d Discount) Active(now time.Time) bool { return now.After(d.StartsAt) && now.Before(d.EndsAt) }'),
      _a('// Active reports whether now falls inside [StartsAt, EndsAt).'), _a('func (d Discount) Active(now time.Time) bool {'), _a('\treturn !now.Before(d.StartsAt) && now.Before(d.EndsAt)'), _a('}'),
    ]),
    ChangedFile(path: 'internal/discount/service.go', kind: 'M', committed: true, lines: [
      _c('package discount'), _c(''), _c('import "context"'), _c(''), _c('type Service struct {'), _c('\trepo *Repository'), _c('}'), _c(''),
      _a('// ApplyBulk validates a bulk discount and stores one row per SKU.'), _a('func (s *Service) ApplyBulk(ctx context.Context, b BulkDiscount) error {'), _a('\tif err := b.Validate(); err != nil {'),
      _a('\t\treturn err'), _a('\t}'), _a('\treturn s.repo.UpsertMany(ctx, b.Expand())'), _a('}'), _a(''),
      _c('func (s *Service) ByCategory(ctx context.Context, category string) ([]Discount, error) {'), _c('\treturn s.repo.ByCategory(ctx, category)'), _c('}'),
    ]),
    ChangedFile(path: 'internal/discount/bulk_test.go', kind: 'M', lines: [
      _c('package discount'), _c(''), _c('import ('), _a('\t"errors"'), _c('\t"testing"'), _c('\t"time"'), _c(')'), _c(''),
      _c('func TestBulkDiscountValidate(t *testing.T) {'), _c('\tnow := time.Now()'), _c('\ttests := []struct {'), _c('\t\tname string'), _c('\t\tin   BulkDiscount'), _c('\t\twant error'), _c('\t}{'),
      _d('\t\t{"ok", BulkDiscount{SKUs: []string{"a"}, Percent: 10}, nil},'), _d('\t\t{"no skus", BulkDiscount{Percent: 10}, ErrNoSKUs},'),
      _a('\t\t{"ok", BulkDiscount{SKUs: []string{"a"}, Percent: 10, StartsAt: now, EndsAt: now.Add(time.Hour)}, nil},'),
      _a('\t\t{"no skus", BulkDiscount{Percent: 10, StartsAt: now, EndsAt: now.Add(time.Hour)}, ErrNoSKUs},'),
      _a('\t\t{"percent too high", BulkDiscount{SKUs: []string{"a"}, Percent: 95, StartsAt: now, EndsAt: now.Add(time.Hour)}, ErrBadPercent},'),
      _a('\t\t{"ends before start", BulkDiscount{SKUs: []string{"a"}, Percent: 10, StartsAt: now, EndsAt: now.Add(-time.Hour)}, ErrBadTimeRange},'),
      _c('\t}'), _c('\tfor _, tt := range tests {'), _c('\t\tt.Run(tt.name, func(t *testing.T) {'),
      _d('\t\t\tif got := tt.in.Validate(); got != tt.want {'), _a('\t\t\tif got := tt.in.Validate(); !errors.Is(got, tt.want) {'),
      _c('\t\t\t\tt.Fatalf("Validate() = %v, want %v", got, tt.want)'), _c('\t\t\t}'), _c('\t\t})'), _c('\t}'), _c('}'),
    ]),
  ];

  static ChangedFile? byPath(String path) {
    for (final f in files) {
      if (f.path == path) return f;
    }
    return null;
  }
}
