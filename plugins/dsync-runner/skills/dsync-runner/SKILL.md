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

> **Note**: Connector availability changes frequently. Always check the official README for the latest:
> https://github.com/adiom-data/dsync/blob/main/README.md

### NoSQL Databases
- **MongoDB**: Standard URI format `mongodb://...`
- **MongoDB Atlas**: SRV format `mongodb+srv://...` (URL-encode special chars)
- **AWS DocumentDB**: Use MongoDB connector (4.0, 5.0 supported)
- **Cosmos DB MongoDB API**: Standard MongoDB URI with `?ssl=true`
- **Cosmos DB NoSQL**: Not a URI connector — runs as a separate gRPC sidecar (`markadiom/cosmosnosqlconnector`), referenced as `grpc://cosmosnosqlconnector:8089 --insecure`. See [Cosmos DB NoSQL Migrations](#cosmos-db-nosql-migrations).
- **DynamoDB**: `dynamodb://...?accessKeyId=...&secretAccessKey=...`
- **HBase** (1.x, 2.x): Private Preview - includes CDC support

### SQL Databases
- **PostgreSQL**: Standard URI format `postgres://...`
- **SQLBatch** (SQL Server, DB2, PostgreSQL, Oracle): `sqlbatch --config=config.yaml`

### Vector Databases
- **Weaviate**: Sink only (Public Preview)
- **Qdrant**: Sink only (In Development)
- **S3 Vector Index**: Sink only (Public Preview)

### File & Storage
- **CSV Files**: `file://path/to/file.csv` (Source & Sink)
- **S3**: `s3://bucket?region=...&accessKeyId=...&secretAccessKey=...`

### Testing
- **/dev/null**: Discard output
- **/dev/random**: Generate random test data

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

## SigNoz Setup (For OTEL Observability)

SigNoz provides dashboards for dsynct traces and metrics. **Note: SigNoz uses port 8080 by default.**

```bash
# Clone and start SigNoz
git clone --depth 1 -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy/docker
docker compose up -d --remove-orphans

# Verify it's running
docker ps --filter "name=signoz"

# Access SigNoz UI at http://localhost:8080
# OTLP endpoint: localhost:4317 (gRPC), localhost:4318 (HTTP)
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

### Simple Mode - Basic (No Temporal)
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -p 8080:8080 \
  markadiom/dsynct \
  --host-port 0.0.0.0:8080 \
  sync \
  $SOURCE $DESTINATION
```

### Simple Mode - With OTEL Observability (Recommended)

**Important:** Use port 8081 for dsynct when SigNoz is running on 8080.

```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317' \
  -p 8081:8081 \
  markadiom/dsynct \
  --host-port 0.0.0.0:8081 \
  --otel \
  sync \
  $SOURCE $DESTINATION
```

### Simple Mode - Resumable with Named Container (Production)

For production use, create a named container with persistent state:

```bash
# Create state directory
mkdir -p ./dsynct_state

# Run named container (no --rm, use -d for background)
docker run -d \
  --name dsynct-sync \
  -e 'DSYNCT_MODE=simple' \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317' \
  -p 8081:8081 \
  -v $(pwd)/dsynct_state:/data \
  markadiom/dsynct \
  --host-port 0.0.0.0:8081 \
  --otel \
  sync \
  --save-file /data/resume.state \
  $SOURCE $DESTINATION

# Container management
docker logs -f dsynct-sync    # View logs
docker stop dsynct-sync       # Pause sync
docker start dsynct-sync      # Resume from saved state
docker rm dsynct-sync         # Remove container
```

### Simple Mode - Debug Logging
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  markadiom/dsynct \
  --log-level DEBUG \
  sync \
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
git clone --depth 1 -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy/docker && docker compose up -d
```

#### 3. Start Workers
```bash
docker run --name dsyncworker \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317' \
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
  -p 8081:8081 \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317' \
  markadiom/dsynct run \
  temporal --host-port temporal:7233 \
  app --otel --host-port 0.0.0.0:8081
```

### Temporal Tools (Pause/Unpause)
```bash
# Pause workflow
docker run -e 'DSYNCT_MODE=temporaltools' markadiom/dsynct pause --workflow-id=<id>

# Unpause workflow
docker run -e 'DSYNCT_MODE=temporaltools' markadiom/dsynct unpause --workflow-id=<id>
```

## Cosmos DB NoSQL Migrations

Cosmos DB NoSQL is **not** a URI connector. There is no `cosmosnosql://` string. Instead it runs as a separate **gRPC sidecar container** — `markadiom/cosmosnosqlconnector` — and dsync/dsynct connects to it as a connector address: `grpc://cosmosnosqlconnector:8089 --insecure`.

> Docs: [DynamoDB → Cosmos NoSQL (OSS)](https://docs.adiom.io/getting-started/quickstart/dynamo-cosmos) · [Cosmos NoSQL → MongoDB (OSS)](https://docs.adiom.io/getting-started/quickstart/from-cosmos-db-nosql-to-mongodb-api) · [DynamoDB → Cosmos NoSQL (Enterprise)](https://docs.adiom.io/enterprise/running-dsynct/dynamodb-to-cosmos-db-nosql) · [Cosmos NoSQL → MongoDB (Enterprise)](https://docs.adiom.io/enterprise/running-dsynct/cosmos-db-nosql-to-mongo)

### Connector Sidecar

- Java connector; requires JDK 21+ (use the published image as-is). Uses **dynamic ports** for Cosmos SDK connections.
- Must run on a **user-defined docker network** so dsync/dsynct can reach it by container name.
- Launch form: `markadiom/cosmosnosqlconnector <PORT> $COSMOS_URI $COSMOS_KEY` (port `8089` by convention).
- `$COSMOS_URI` is the account URL (`https://<account>.documents.azure.com:443/`); `$COSMOS_KEY` is the Read-Write / Primary Key from Azure Portal → Keys.

```bash
# Create the shared network once
docker network create mynet

# Connector — open source (telemetry disabled)
docker run -d --network mynet --name cosmosnosqlconnector \
  -e OTEL_SDK_DISABLED=true \
  markadiom/cosmosnosqlconnector 8089 "$COSMOS_URI" "$COSMOS_KEY"

# Connector — enterprise (telemetry to SigNoz)
docker run -d --network mynet --name cosmosnosqlconnector \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  markadiom/cosmosnosqlconnector 8089 "$COSMOS_URI" "$COSMOS_KEY"
```

### Namespace Syntax

The `--namespace` format differs by direction:

| Direction | Format | Example |
|-----------|--------|---------|
| DynamoDB → Cosmos | `TABLE:DB.CONTAINER` | `--namespace "users:appdb.users"` |
| Cosmos → MongoDB | `DB.CONTAINER` | `--namespace "appdb.users"` |
| Cosmos → MongoDB (Enterprise worker) | `--namespace-mapping "cosmos_db.container:mongo_db.collection"` | |

### OSS: DynamoDB → Cosmos DB NoSQL

Prerequisites: DynamoDB Streams enabled (at least **New image**); Cosmos DB account with destination database + container pre-created; AWS credentials.

```bash
docker network create mynet

docker run -d --network mynet --name cosmosnosqlconnector \
  -e OTEL_SDK_DISABLED=true \
  markadiom/cosmosnosqlconnector 8089 "$COSMOS_URI" "$COSMOS_KEY"

docker run --network mynet --name dsync -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_REGION=$AWS_REGION \
  markadiom/dsync --web-host 0.0.0.0 \
  --namespace "<TABLE>:<DB>.<CONTAINER>" \
  dynamodb grpc://cosmosnosqlconnector:8089 --insecure
```

- `--load-level [Low|Medium|High]` — controls Cosmos RU / read capacity consumption.
- `--parallel-copiers N` — reader thread count for the initial copy.
- Tip: disabling Cosmos container indexes during migration gives a 100–150% throughput boost; recreate indexes and configure global distribution afterward.

### OSS: Cosmos DB NoSQL → MongoDB

Prerequisites: Cosmos URI + Primary Key; MongoDB destination URI; **"All Versions and Deletes"** change feed mode enabled on the Cosmos container (or set `COSMOS_DISABLE_ALL_VERSIONS_AND_DELETES=true`, which disables delete replication).

Cosmos IDs combine the shard key + `id`; MongoDB uses a single `_id`. Map them with a transformer sidecar (see [Change Feed & ID Mapping](#change-feed--id-mapping)).

```bash
docker network create mynet

# Source connector
docker run -d --network mynet --name cosmosnosqlconnector \
  -e OTEL_SDK_DISABLED=true \
  markadiom/cosmosnosqlconnector 8089 "$COSMOS_URI" "$COSMOS_KEY"

# Transformer sidecar (for id -> _id mapping)
docker run -d --network mynet --name dsync-transform \
  -v "./config.yml:/config.yml" \
  -e 'DSYNCT_MODE=simple' \
  markadiom/dsynct --host-port=0.0.0.0:8085 transformer

# Migration
docker run --network mynet --name dsync -p 8080:8080 \
  markadiom/dsync --web-host 0.0.0.0 \
  --namespace "<DB>.<CONTAINER>" \
  grpc://cosmosnosqlconnector:8089 --insecure \
  "$MONGODB_URI" \
  grpc://dsync-transform:8085 --insecure
```

- Use `--mode InitialSync` for a one-time copy with no change feed.
- OSS supports CDC for a **single namespace only** — multiple namespaces require separate processes or the Enterprise edition.

### Enterprise: DynamoDB → Cosmos DB NoSQL

Requires Temporal + SigNoz (or compatible OTEL collector). Environment: `SIGNOZ=http://<HOST>:4317`, `TEMPORAL=<HOST>:7233`, AWS credentials, `COSMOS_URI`, `COSMOS_KEY`.

```bash
docker network create mynet

# Connector
docker run -d --network mynet --name cosmosnosqlconnector \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  markadiom/cosmosnosqlconnector 8089 "$COSMOS_URI" "$COSMOS_KEY"

# Worker
docker run -d --network mynet --name dsyncworker \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_REGION=$AWS_REGION \
  markadiom/dsynct worker \
  --namespace-mapping "<TABLE>:<DB>.<CONTAINER>" \
  --concurrent-activities 4 --sync-writer-workers 8 \
  dynamodb grpc://cosmosnosqlconnector:8089 --insecure \
  temporal --host-port $TEMPORAL app --otel

# Runner
docker run --network mynet --name dsyncrunner -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  markadiom/dsynct run \
  --namespace "<TABLE>:<DB>.<CONTAINER>" \
  temporal --host-port $TEMPORAL app --otel --host-port 0.0.0.0:8080
```

### Enterprise: Cosmos DB NoSQL → MongoDB

Same prerequisites as the OSS Cosmos → MongoDB flow, plus Temporal + SigNoz. ID mapping is done by the worker's embedded transformer (`--transform` + a volume-mounted `transform.yaml`).

```bash
docker network create mynet

# Connector
docker run -d --network mynet --name cosmosnosqlconnector \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  markadiom/cosmosnosqlconnector 8089 "$COSMOS_URI" "$COSMOS_KEY"

# Worker (with id -> _id transformation)
docker run -d --network mynet --name dsyncworker \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  -v "./transform.yaml:/transform.yaml" \
  markadiom/dsynct worker \
  --namespace-mapping "cosmos_db.container:mongo_db.collection" \
  --concurrent-activities 4 --sync-writer-workers 8 \
  --transform grpc://cosmosnosqlconnector:8089 --insecure \
  "$MONGODB_URI" dsync-transform:///transform.yaml \
  temporal --host-port $TEMPORAL app --otel

# Runner
docker run --network mynet --name dsyncrunner -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=$SIGNOZ \
  markadiom/dsynct run \
  --namespace "cosmos_db.container" \
  temporal --host-port $TEMPORAL app --otel --host-port 0.0.0.0:8080
```

> Omit `--transform`, the volume mount, and `dsync-transform:///transform.yaml` if no ID / data-type changes are needed.

### Change Feed & ID Mapping

- **Change feed**: the Cosmos container must have **"All Versions and Deletes"** mode enabled (Azure Portal → container settings) for delete events to replicate. If it cannot be enabled, set `COSMOS_DISABLE_ALL_VERSIONS_AND_DELETES=true` on the connector — deletes will not replicate.
- **ID mapping**: Cosmos `id` (plus shard key) → MongoDB `_id`. Use a transform config — see `templates/cosmos-nosql-id-mapping.yaml`:
  - Simple case (shard key `/id`): `delete: [id]`, `add: [_id]`, `mapid: id`, `cel: {_id: id}`.
  - Shard-key prefix (e.g. `/region`): `idlist: true`, `idkeys: [region, id]`, `mapid: id[1]`, `cel: {_id: id[1]}`.
- **Data types**: Cosmos uses JSON, MongoDB uses BSON. Consider converting timestamp strings to Dates, and carry the internal `_ts` field if you need TTL behavior.

### Limitations

- DynamoDB → Cosmos NoSQL flows are currently **not resumable**; embedded verification checks may not function.
- OSS supports CDC for a **single namespace only** (multiple namespaces → separate processes or Enterprise).
- The connector requires JDK 21+ and dynamic ports — keep it on a shared docker network rather than publishing fixed ports.

## Data Transformations

> **Note**: Transformations config and available CEL functions change frequently. Always check offical docs for the latest:
> https://docs.adiom.io/enterprise/running-dsynct/data-transformations
> https://docs.adiom.io/enterprise/running-dsynct/data-types
> https://docs.adiom.io/enterprise/running-dsynct/cel-reference

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

### dsync (Open Source)
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

### dsynct (Enterprise) Global Options
| Option | Description |
|--------|-------------|
| `--otel` | Enable OTEL export (requires OTEL_EXPORTER_OTLP_ENDPOINT env) |
| `--log-level` | DEBUG/INFO/WARN/ERROR (default: INFO) |
| `--host-port` | Web server address (default: localhost:8080) |
| `--otel-service-name` | Service name for OTEL (default: dsynct) |

### dsynct sync Subcommand Options
| Option | Description |
|--------|-------------|
| `--save-file` | Path to save/resume state file |

## Monitoring

| Service | Default Port | URL |
|---------|--------------|-----|
| dsynct Progress UI | 8080 (or 8081 with SigNoz) | `http://localhost:8081/` |
| SigNoz Dashboard | 8080 | `http://localhost:8080` |
| SigNoz OTLP (gRPC) | 4317 | - |
| SigNoz OTLP (HTTP) | 4318 | - |
| Temporal UI | 8233 | `http://localhost:8233` |

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

### Full Stack: dsynct + SigNoz on macOS
```bash
# 1. Start SigNoz (port 8080)
cd signoz/deploy/docker && docker compose up -d

# 2. Create state directory
mkdir -p ./dsynct_state

# 3. Start dsynct with OTEL (port 8081)
docker run -d \
  --name dsynct-sync \
  -e 'DSYNCT_MODE=simple' \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317' \
  -p 8081:8081 \
  -v $(pwd)/dsynct_state:/data \
  markadiom/dsynct \
  --host-port 0.0.0.0:8081 \
  --otel \
  sync \
  --save-file /data/resume.state \
  'mongodb+srv://user:pass%40word@cluster.mongodb.net' \
  'mongodb://host.docker.internal:27017'

# Monitor at:
# - dsynct: http://localhost:8081
# - SigNoz: http://localhost:8080
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused to localhost | Use `host.docker.internal` instead of `localhost` on macOS/Windows |
| `--network host` not working | macOS/Windows don't support host networking; use `host.docker.internal` |
| Port 8080 conflict with SigNoz | Use `--host-port 0.0.0.0:8081` and `-p 8081:8081` for dsynct |
| OTEL not sending data | Ensure `--otel` flag is set AND `OTEL_EXPORTER_OTLP_ENDPOINT` env var |
| `--verbosity` not recognized | Use `--log-level DEBUG` instead (dsynct uses different flag) |
| Slow performance | Increase `--load-level` or reduce `--write-rate-limit` |
| CDC not capturing | Check source database oplog/change streams enabled |
| Document too large | Check 16MB BSON limit for MongoDB |
| Transform errors | Test with Transform Studio first |
| Special chars in password | URL-encode: `&` → `%26`, `@` → `%40`, etc. |
| State not persisting | Mount volume: `-v $(pwd)/state:/data` with `--save-file /data/resume.state` |
| Cosmos NoSQL connector unreachable | Run the connector and dsync/dsynct on the same docker network (`--network mynet`); reference it by name (`grpc://cosmosnosqlconnector:8089`) with `--insecure` for plaintext gRPC |
| Cosmos NoSQL deletes not replicating | Enable "All Versions and Deletes" change feed on the container, or accept loss of deletes with `COSMOS_DISABLE_ALL_VERSIONS_AND_DELETES=true` |
| Cosmos `id` vs Mongo `_id` mismatch | Add an ID-mapping transform (`templates/cosmos-nosql-id-mapping.yaml`) via a transformer sidecar or worker `--transform` |
| Slow Cosmos NoSQL writes | Disable container indexes during migration (100–150% boost); recreate them afterward |

## Resources

- Documentation: https://docs.adiom.io/
- GitHub (dsync): https://github.com/adiom-data/dsync
- GitHub (enterprise): https://github.com/adiom-data/public
- SigNoz: https://signoz.io/docs/install/docker/
- Support: info@adiom.io
