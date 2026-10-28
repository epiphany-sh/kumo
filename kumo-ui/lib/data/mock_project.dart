/// The price-admin worktree shown in the Files view: tree, contents, git
/// status and changed-line marks. Indentation is stored as spaces (Go tabs
/// rendered as 4 spaces) so the editor's text and spans always line up.
library;

enum GitStatus { modified, added, untracked, deleted, conflict }

extension GitStatusLetter on GitStatus {
  String get letter => switch (this) {
        GitStatus.modified => 'M',
        GitStatus.added => 'A',
        GitStatus.untracked => 'U',
        GitStatus.deleted => 'D',
        GitStatus.conflict => 'C',
      };
  String get label => switch (this) {
        GitStatus.modified => 'modified',
        GitStatus.added => 'added',
        GitStatus.untracked => 'untracked',
        GitStatus.deleted => 'deleted',
        GitStatus.conflict => 'conflict',
      };
}

/// A directory has [children]; a file has none.
class TreeNode {
  const TreeNode(this.name, [this.children]);
  final String name;
  final List<TreeNode>? children;
  bool get isDir => children != null;
}

abstract final class MockProject {
  static const conflictPath = 'deploy/k8s/values.yaml';
  static const deletedPath = 'internal/discount/legacy_v1.go';

  static const List<TreeNode> tree = [
    TreeNode('cmd', [
      TreeNode('server', [TreeNode('main.go')]),
    ]),
    TreeNode('config', [TreeNode('app.yaml')]),
    TreeNode('deploy', [
      TreeNode('k8s', [TreeNode('values.yaml')]),
    ]),
    TreeNode('internal', [
      TreeNode('discount', [TreeNode('bulk.go'), TreeNode('bulk_test.go'), TreeNode('legacy_v1.go'), TreeNode('repository.go'), TreeNode('service.go')]),
      TreeNode('kafka', [TreeNode('bulk_consumer.go')]),
    ]),
    TreeNode('testdata', [TreeNode('bulk_discount.json')]),
    TreeNode('.gitignore'),
    TreeNode('go.mod'),
    TreeNode('go.sum'),
    TreeNode('Makefile'),
    TreeNode('README.md'),
  ];

  static const status = <String, GitStatus>{
    'config/app.yaml': GitStatus.modified,
    'deploy/k8s/values.yaml': GitStatus.conflict,
    'internal/discount/bulk.go': GitStatus.added,
    'internal/discount/bulk_test.go': GitStatus.modified,
    'internal/discount/legacy_v1.go': GitStatus.deleted,
    'internal/discount/repository.go': GitStatus.modified,
    'internal/kafka/bulk_consumer.go': GitStatus.added,
    'testdata/bulk_discount.json': GitStatus.untracked,
    'go.mod': GitStatus.modified,
    'go.sum': GitStatus.modified,
  };

  /// 1-based inclusive line ranges: (from, to, isAdd). isAdd=false → modified.
  static const marks = <String, List<(int, int, bool)>>{
    'internal/discount/repository.go': [(5, 5, true), (7, 7, true), (20, 20, false), (22, 34, true)],
    'config/app.yaml': [(12, 14, true)],
    'internal/discount/bulk_test.go': [(15, 15, false), (16, 16, true)],
    'go.mod': [(8, 8, true)],
    'go.sum': [(3, 4, true)],
    'deploy/k8s/values.yaml': [(5, 5, false)],
  };

  static const files = <String, String>{
    'cmd/server/main.go': r'''package main

import (
    "go.uber.org/fx"

    "github.com/pricing/price-admin/internal/discount"
    "github.com/pricing/price-admin/internal/kafka"
)

func main() {
    fx.New(
        fx.Provide(discount.NewRepository, discount.NewService),
        kafka.Module,
    ).Run()
}''',
    'config/app.yaml': r'''server:
  port: 8080
  readTimeout: 5s
  writeTimeout: 10s

postgres:
  dsn: ${POSTGRES_DSN}
  maxConns: 20

discounts:
  maxPercent: 90
  bulk:
    enabled: true
    batchSize: 500''',
    'deploy/k8s/values.yaml': r'''replicaCount: 3

image:
  repository: gcr.io/pricing/price-admin
<<<<<<< HEAD (feat/PRC-412-bulk-discounts)
  tag: "2026.10.27-prc412"
=======
  tag: "2026.10.24"
>>>>>>> main
  pullPolicy: IfNotPresent

kafka:
  brokers:
    - kafka-0.pricing.svc:9092
    - kafka-1.pricing.svc:9092
  topics:
    discounts: price.discounts.v1
    bulk: price.discounts.bulk.v1   # new consumer

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    memory: 512Mi

featureFlags:
  bulkDiscounts: true
  legacyV1Endpoints: false''',
    'internal/discount/bulk.go': r'''package discount

import (
    "errors"
    "time"

    "github.com/shopspring/decimal"
)

var ErrInvalidPercent = errors.New("discount: percent must be in (0, 90]")

var maxPercent = decimal.NewFromInt(90)

// BulkDiscount applies one percentage to every SKU in a category.
type BulkDiscount struct {
    CategoryID string
    Percent    decimal.Decimal
    StartsAt   time.Time
    EndsAt     *time.Time
}

func (b BulkDiscount) Validate() error {
    if b.Percent.LessThanOrEqual(decimal.Zero) || b.Percent.GreaterThan(maxPercent) {
        return ErrInvalidPercent
    }
    if b.EndsAt != nil && !b.EndsAt.After(b.StartsAt) {
        return errors.New("discount: ends_at must be after starts_at")
    }
    return nil
}''',
    'internal/discount/bulk_test.go': r'''package discount

import (
    "testing"

    "github.com/shopspring/decimal"
)

func TestBulkDiscountValidate(t *testing.T) {
    cases := []struct {
        name    string
        percent int64
        wantErr bool
    }{
        {"zero", 0, true},
        {"ten", 10, false},
        {"over max", 95, true},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            b := BulkDiscount{Percent: decimal.NewFromInt(tc.percent)}
            if err := b.Validate(); (err != nil) != tc.wantErr {
                t.Fatalf("got %v, wantErr %v", err, tc.wantErr)
            }
        })
    }
}''',
    'internal/discount/legacy_v1.go': r'''package discount

import (
    "context"

    "github.com/shopspring/decimal"
)

// Deprecated: v1 endpoints were removed in PRC-370.
func (s *Service) LegacyApply(ctx context.Context, sku string, pct float64) error {
    return s.repo.Upsert(ctx, Discount{SKU: sku, Percent: decimal.NewFromFloat(pct)})
}''',
    'internal/discount/repository.go': r'''package discount

import (
    "context"
    "fmt"

    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"
)

// Repository persists discounts in PostgreSQL.
type Repository struct {
    db *pgxpool.Pool
}

func NewRepository(db *pgxpool.Pool) *Repository {
    return &Repository{db: db}
}

// UpsertMany writes every discount in a single COPY round trip.
func (r *Repository) UpsertMany(ctx context.Context, ds []Discount) error {
    rows := make([][]any, 0, len(ds))
    for _, d := range ds {
        rows = append(rows, []any{d.SKU, d.Percent, d.StartsAt, d.EndsAt})
    }
    _, err := r.db.CopyFrom(ctx,
        pgx.Identifier{"discounts_staging"},
        []string{"sku", "percent", "starts_at", "ends_at"},
        pgx.CopyFromRows(rows),
    )
    if err != nil {
        return fmt.Errorf("copy discounts: %w", err)
    }
    return nil
}''',
    'internal/discount/service.go': r'''package discount

import "context"

type Service struct {
    repo *Repository
}

func NewService(repo *Repository) *Service {
    return &Service{repo: repo}
}

// ApplyBulk expands a category discount into SKU rows (Discount rules v3).
func (s *Service) ApplyBulk(ctx context.Context, b BulkDiscount) error {
    if err := b.Validate(); err != nil {
        return err
    }
    skus, err := s.repo.SKUsInCategory(ctx, b.CategoryID)
    if err != nil {
        return err
    }
    return s.repo.UpsertMany(ctx, expand(b, skus))
}''',
    'internal/kafka/bulk_consumer.go': r'''package kafka

import (
    "context"
    "encoding/json"

    "github.com/pricing/price-admin/internal/discount"
    kafkago "github.com/segmentio/kafka-go"
)

// BulkConsumer reads price.discounts.bulk.v1 and applies each batch.
type BulkConsumer struct {
    reader *kafkago.Reader
    svc    *discount.Service
}

func (c *BulkConsumer) Run(ctx context.Context) error {
    for {
        msg, err := c.reader.FetchMessage(ctx)
        if err != nil {
            return err
        }
        var b discount.BulkDiscount
        if err := json.Unmarshal(msg.Value, &b); err != nil {
            continue
        }
        if err := c.svc.ApplyBulk(ctx, b); err != nil {
            return err
        }
        _ = c.reader.CommitMessages(ctx, msg)
    }
}''',
    'testdata/bulk_discount.json': r'''{
  "categoryId": "tv-and-video",
  "percent": 15,
  "startsAt": "2026-11-01T00:00:00-03:00",
  "endsAt": null,
  "skus": [
    "TV-55-QLED-4K",
    "TV-65-OLED-C4",
    "SB-ATMOS-510"
  ],
  "dryRun": false
}''',
    '.gitignore': r'''/bin
/coverage.out
.env
*.local.yaml''',
    'go.mod': r'''module github.com/pricing/price-admin

go 1.23

require (
    github.com/jackc/pgx/v5 v5.7.1
    github.com/segmentio/kafka-go v0.4.47
    github.com/shopspring/decimal v1.4.0
    go.uber.org/fx v1.23.0
)''',
    'go.sum': r'''github.com/jackc/pgx/v5 v5.7.1 h1:x7SYsPBYDkHDksogeSmZZ5xzThcTgRz++I5E+ePFUcs=
github.com/jackc/pgx/v5 v5.7.1/go.mod h1:e7O26IywZZ+naJtWWos6i6fvWK+29etgITqrqHLfoZA=
github.com/shopspring/decimal v1.4.0 h1:bxl37RwXBklmTi0C79JfXCEBD1cqqHt0bbgBAGFp81k=
github.com/shopspring/decimal v1.4.0/go.mod h1:gawqmDU56v4yIKSwfBSFip1HdCCXN8/+DMd9qYNcwME=''',
    'Makefile': r'''.PHONY: test lint migrate-up

# run with the race detector, like CI
test:
    go test ./... -race

lint:
    golangci-lint run

migrate-up:
    migrate -path ./migrations -database $(POSTGRES_DSN) up''',
    'README.md': r'''# price-admin

Admin API for list prices and discounts.

## Run locally

Start Postgres and Kafka with `docker compose up`, then run `make test`.

## Docs

Discount rules live in Confluence › Pricing › Discount rules v3.''',
  };

  /// Removes conflict markers keeping current, incoming or both sides.
  static String resolveConflict(String text, String keep) {
    final out = <String>[];
    String? zone;
    for (final l in text.split('\n')) {
      if (l.startsWith('<<<<<<<')) {
        zone = 'cur';
        continue;
      }
      if (l.startsWith('=======')) {
        zone = 'inc';
        continue;
      }
      if (l.startsWith('>>>>>>>')) {
        zone = null;
        continue;
      }
      if (zone == 'cur' && keep == 'incoming') continue;
      if (zone == 'inc' && keep == 'current') continue;
      out.add(l);
    }
    return out.join('\n');
  }

  static bool hasConflictMarkers(String text) => text.split('\n').any((l) => l.startsWith('<<<<<<<'));
}
