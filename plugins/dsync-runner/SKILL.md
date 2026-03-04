---
name: dsync-runner
description: Run database migrations with dsync (open source) or dsynct (enterprise). Use when user needs to sync data between MongoDB, Cosmos DB, DynamoDB, PostgreSQL, or other supported databases with CDC support.
---

# Dsync/Dsynct Database Migration Runner

Help users run database migrations and continuous replication using Adiom's dsync tools.

## When to Use

- User wants to migrate data between databases (MongoDB, Cosmos DB, DynamoDB, PostgreSQL, etc.)
- User needs to set up continuous CDC replication
- User wants to configure data transformations during sync
- User needs help choosing between dsync (open source) and dsynct (enterprise)

## Distribution Selection

| Feature | dsync (Open Source) | dsynct (Enterprise) |
|---------|---------------------|---------------------|
| Data Size | < 100 GB | 100 GB - 100 TB+ |
| Scalability | Single binary | Horizontal (Temporal workers) |
| Observability | Basic progress | SigNoz dashboards |
| License | AGPL v3 | Commercial (free trial) |
| Docker Image | `markadiom/dsync` | `markadiom/dsynct` |

## Supported Connectors

- **MongoDB**: `mongodb://user:pass@host:27017/db`
- **Cosmos DB MongoDB API**: `mongodb://account:key@account.mongo.cosmos.azure.com:10255/?ssl=true`
- **Cosmos DB NoSQL**: `cosmosnosql://account.documents.azure.com?accountKey=...&database=db`
- **DynamoDB**: `dynamodb://region?accessKeyId=...&secretAccessKey=...`
- **PostgreSQL**: `postgres://user:pass@host:5432/db`
- **SQLBatch** (SQL Server, DB2, PostgreSQL): `sqlbatch --config=config.yaml`
- **S3**: `s3://bucket?region=...&accessKeyId=...&secretAccessKey=...`
- **/dev/null**: Discard output (testing)
- **/dev/fakesource**: Generate test data

## Installation

### Docker (Recommended)
```bash
# Open Source
docker pull markadiom/dsync

# Enterprise
docker pull markadiom/dsynct
```

### Homebrew (macOS)
```bash
brew install adiom-data/homebrew-tap/dsync
```

### Build from Source
```bash
git clone https://github.com/adiom-data/dsync.git
cd dsync && go build
```

## Running dsync (Open Source)

### Basic Sync
```bash
./dsync --progress --logfile dsync.log $SOURCE $DESTINATION
```

### With Namespace Filtering
```bash
# Single namespace
./dsync --ns "database.collection" $SOURCE $DESTINATION

# Multiple namespaces
./dsync --ns "db1,db2.col1" $SOURCE $DESTINATION

# Namespace remapping
./dsync --ns "source_db.source_col:dest_db.dest_col" $SOURCE $DESTINATION
```

### CDC Only Mode
```bash
./dsync --mode CDC $SOURCE $DESTINATION
```

### With Verification
```bash
# Quick count verification
./dsync --verify-quick-count $SOURCE $DESTINATION

# Full hash-based verification
./dsync --verify $SOURCE $DESTINATION
```

### Reverse Flow
```bash
# After initial sync, reverse direction for bidirectional replication
./dsync --reverse $SOURCE $DESTINATION
```

### Load Control
```bash
# Load levels: Low, Medium, High, Beast
./dsync --load-level Medium $SOURCE $DESTINATION

# Rate limiting (ops per second)
./dsync --write-rate-limit 5000 $SOURCE $DESTINATION
```

## Running dsynct (Enterprise)

### Simple Mode (No Temporal)
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -p 8080:8080 \
  markadiom/dsynct \
  --host-port 0.0.0.0:8080 \
  sync \
  --save-file /data/resume.file \
  $SOURCE $DESTINATION
```

### Temporal Mode (Scalable)

#### 1. Start Temporal Server
```bash
temporal server start-dev \
  --db-filename /data/temporal.db \
  --ip 0.0.0.0 \
  --dynamic-config-value limit.numPendingActivities.error=10000 \
  --dynamic-config-value frontend.activityAPIsEnabled=true
```

#### 2. Start SigNoz (Optional)
```bash
git clone -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy/docker && docker compose up -d
```

#### 3. Start Workers
```bash
docker run --name dsyncworker \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz:4317' \
  markadiom/dsynct worker \
  --concurrent-activities 4 \
  --sync-transform-workers 4 \
  --sync-writer-workers 8 \
  --per-stream-workers 4 \
  $SOURCE $DESTINATION \
  temporal --host-port temporal:7233 \
  app --otel
```

#### 4. Start Workflow
```bash
docker run --name dsyncrunner \
  -p 8080:8080 \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz:4317' \
  markadiom/dsynct run \
  temporal --host-port temporal:7233 \
  app --otel --host-port 0.0.0.0:8080
```

### Temporal Tools (Pause/Unpause)
```bash
# Pause workflow
docker run -e 'DSYNCT_MODE=temporaltools' markadiom/dsynct pause --workflow-id=<id>

# Unpause workflow
docker run -e 'DSYNCT_MODE=temporaltools' markadiom/dsynct unpause --workflow-id=<id>
```

## Data Transformations

### Using YAML Config
```bash
# With embedded transformer
docker run \
  -v "./transform.yaml:/transform.yaml" \
  markadiom/dsynct worker \
  --transform \
  $SOURCE $DESTINATION dsync-transform://transform.yaml
```

### Transform Config Example
```yaml
mappings:
  - namespace: source_collection
    mapnamespace: dest_collection
    cel:
      name: self + " (migrated)"
      created_at: now_millis()
    add: ["created_at"]
    delete: ["legacy_field"]
    map:
      price: float
```

### Transform Studio (Interactive Testing)
```bash
docker run -e DSYNCT_MODE=simple -p 8080:8080 \
  markadiom/dsynct --host-port 0.0.0.0:8080 studio
# Open browser to http://localhost:8080
```

### Test Sync (Single Document)
```bash
docker run -e 'DSYNCT_MODE=simple' \
  markadiom/dsynct testsync \
  --namespace source_db.collection \
  --id "document_id" \
  $SOURCE $DESTINATION
```

## Key CLI Options

| Option | Description |
|--------|-------------|
| `--ns "db.col"` | Namespace filtering/remapping |
| `--mode CDC` | CDC-only mode (skip initial sync) |
| `--reverse` | Reverse sync direction |
| `--load-level` | Low/Medium/High/Beast parallelism |
| `--write-rate-limit N` | Throttle to N ops/second |
| `--verify` | Full hash verification |
| `--verify-quick-count` | Quick count verification |
| `--progress --logfile` | CLI progress reporting |
| `--cosmos-deletes-cdc` | Enable Cosmos DB delete emulation |
| `--transform` | Enable data transformation |

## Monitoring

- **Web Progress**: `http://localhost:8080/progress`
- **Temporal UI**: `http://temporal:8233`
- **SigNoz**: `http://signoz:8080`

## Common Patterns

### Migration with Cutover
```bash
# 1. Initial sync + CDC
./dsync $SOURCE $DEST

# 2. Stop application writes to source

# 3. Wait for CDC to catch up (verify counts)
./dsync --verify-quick-count $SOURCE $DEST

# 4. Switch application to destination
```

### Bidirectional Replication
```bash
# Terminal 1: Source -> Dest
./dsync --mode CDC $SOURCE $DEST

# Terminal 2: Dest -> Source (after initial sync)
./dsync --reverse $SOURCE $DEST
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Use `host.docker.internal` for localhost |
| Slow performance | Increase `--load-level` or reduce `--write-rate-limit` |
| CDC not capturing | Check source database oplog/change streams enabled |
| Document too large | Check 16MB limit for MongoDB |
| Transform errors | Test with Transform Studio first |

## Resources

- Documentation: https://docs.adiom.io/
- GitHub (dsync): https://github.com/adiom-data/dsync
- GitHub (enterprise): https://github.com/adiom-data/public
- Support: info@adiom.io
