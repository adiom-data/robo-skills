# Dsync Runner References

## Connection String Formats

### MongoDB
```
mongodb://user:password@host:27017/database?authSource=admin
mongodb://user:password@host1:27017,host2:27017/database?replicaSet=rs0
```

### MongoDB Atlas
```
mongodb+srv://user:password@cluster.mongodb.net/database?retryWrites=true
```

### Azure Cosmos DB (MongoDB API)
```
mongodb://account:primaryKey@account.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retryWrites=false
```

### Azure Cosmos DB (NoSQL API)
```
cosmosnosql://account.documents.azure.com?accountKey=primaryKey&database=dbname
```

### AWS DynamoDB
```
dynamodb://us-east-1?accessKeyId=AKID&secretAccessKey=SECRET
dynamodb://us-west-2?accessKeyId=AKID&secretAccessKey=SECRET&endpoint=http://localhost:8000
```

### PostgreSQL
```
postgres://user:password@host:5432/database?sslmode=require
```

### S3
```
s3://bucket-name?region=us-east-1&accessKeyId=AKID&secretAccessKey=SECRET
```

### SQLBatch (SQL Server)
```yaml
driver: sqlserver
connectionstring: sqlserver://sa:password@host.docker.internal:1433?database=MyDB
```

### SQLBatch (DB2)
```yaml
driver: db2
connectionstring: db2://user:password@host:50000?database=MyDB
```

## Docker Commands

### Basic Sync (Open Source)
```bash
docker run --rm markadiom/dsync \
  --progress \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### With Web Progress UI
```bash
docker run --rm -p 8080:8080 markadiom/dsync \
  --progress \
  "mongodb://host.docker.internal:27017" \
  "mongodb://host.docker.internal:27018"
# Access http://localhost:8080/progress
```

### Enterprise Simple Mode
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -p 8080:8080 \
  -v "$PWD/data:/data" \
  markadiom/dsynct \
  --host-port 0.0.0.0:8080 \
  --otel \
  sync \
  --save-file /data/resume.file \
  "mongodb://host.docker.internal:27017" \
  "mongodb://host.docker.internal:27018"
```

### With Transform Config
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -p 8080:8080 \
  -v "$PWD/transform.yaml:/transform.yaml" \
  markadiom/dsynct \
  --host-port 0.0.0.0:8080 \
  sync \
  --transform \
  "mongodb://host.docker.internal:27017" \
  "mongodb://host.docker.internal:27018" \
  dsync-transform://transform.yaml
```

### Namespace Filtering
```bash
docker run --rm markadiom/dsync \
  --ns "production.users,production.orders" \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### Namespace Remapping
```bash
docker run --rm markadiom/dsync \
  --ns "old_db.old_col:new_db.new_col" \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### CDC Only Mode
```bash
docker run --rm markadiom/dsync \
  --mode CDC \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### Skip Initial Sync (Enterprise)
```bash
docker run --rm -e 'DSYNCT_MODE=simple' markadiom/dsynct \
  sync --skip-initial-sync \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### Skip CDC (Initial Only)
```bash
docker run --rm -e 'DSYNCT_MODE=simple' markadiom/dsynct \
  sync --skip-change-stream \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### Test Connectivity
```bash
# Test with /dev/null destination
docker run --rm markadiom/dsync \
  --ns "test.collection" \
  "mongodb://source:27017" \
  /dev/null

# Test with fake source
docker run --rm markadiom/dsync \
  /dev/fakesource \
  "mongodb://dest:27017"
```

## Enterprise Worker Configuration

### Recommended Settings by VM Size

| VM Size | concurrent-activities | sync-transform-workers | sync-writer-workers | per-stream-workers |
|---------|----------------------|------------------------|--------------------|--------------------|
| 4 CPU / 8GB | 4 | 4 | 8 | 4 |
| 8 CPU / 16GB | 8 | 8 | 16 | 8 |
| 16 CPU / 32GB | 16 | 16 | 32 | 16 |

### Worker Command Template
```bash
docker run --name dsyncworker-$(hostname) \
  -e 'OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz:4317' \
  markadiom/dsynct worker \
  --concurrent-activities 8 \
  --sync-transform-workers 8 \
  --sync-writer-workers 16 \
  --per-stream-workers 8 \
  --queue-name "migration-queue" \
  "mongodb://source:27017" \
  "mongodb://dest:27017" \
  temporal --host-port temporal:7233 \
  app --otel
```

### Multiple Worker Sets (Different Configs)
```bash
# Worker set A (source1 -> dest1)
docker run --name worker-set-a markadiom/dsynct worker \
  --queue-name "queue-a" \
  "mongodb://source1:27017" "mongodb://dest1:27017" \
  temporal --host-port temporal:7233

# Worker set B (source2 -> dest2)
docker run --name worker-set-b markadiom/dsynct worker \
  --queue-name "queue-b" \
  "mongodb://source2:27017" "mongodb://dest2:27017" \
  temporal --host-port temporal:7233

# Must use matching queue names in run commands
```

## Transform Configuration

### Field Mapping
```yaml
mappings:
  - namespace: source.collection
    mapnamespace: dest.collection
    cel:
      full_name: doc.first_name + " " + doc.last_name
      updated_at: now_millis()
    add: ["full_name", "updated_at"]
    delete: ["first_name", "last_name", "legacy_field"]
```

### Type Conversions
```yaml
mappings:
  - namespace: source.collection
    cel:
      price: self * 100
    map:
      price: int32
      uuid: bson_uuid
      created: bson_object_id
```

### ID Transformation
```yaml
mappings:
  - namespace: source.collection
    mapid: "string(id[0])"
    idkeys: ["_id"]
    finalidkeys: ["id"]
    delete: ["_id"]
    add: ["id"]
    cel:
      id: string(parent._id)
```

### Data Anonymization
```yaml
mappings:
  - namespace: users
    cel:
      email: fake_email(self)
      name: fake_name(self)
      phone: fake_phone(self)
      address: fake_address(self)
```

### Conditional Filtering
```yaml
mappings:
  - namespace: source.collection
    filter: 'doc.status == "active" && doc.created_at > timestamp("2024-01-01T00:00:00Z")'
```

## Troubleshooting Commands

### Check Dsync Version
```bash
docker run --rm markadiom/dsync --version
docker run --rm markadiom/dsynct --version
```

### List Available Connectors
```bash
docker run --rm markadiom/dsync --help
```

### Debug Logging
```bash
docker run --rm markadiom/dsync \
  --log-level DEBUG \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### Verify Sync Results
```bash
# Quick count check
docker run --rm markadiom/dsync \
  --verify-quick-count \
  "mongodb://source:27017" \
  "mongodb://dest:27017"

# Full hash verification
docker run --rm markadiom/dsync \
  --verify \
  "mongodb://source:27017" \
  "mongodb://dest:27017"
```

### Test Single Document Transform
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -v "./transform.yaml:/transform.yaml" \
  markadiom/dsynct testsync \
  --namespace source.collection \
  --id "507f1f77bcf86cd799439011" \
  --transform \
  "mongodb://source:27017" \
  "mongodb://dest:27017" \
  dsync-transform://transform.yaml
```

## Monitoring Endpoints

| Component | URL | Description |
|-----------|-----|-------------|
| Dsync Progress | http://localhost:8080/progress | Real-time sync progress |
| Temporal UI | http://localhost:8233 | Workflow monitoring |
| SigNoz | http://localhost:8080 | Logs and metrics |

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `connection refused` | Network unreachable | Use `host.docker.internal` for localhost |
| `authentication failed` | Wrong credentials | Verify connection string credentials |
| `namespace not found` | Missing database/collection | Check source exists and is accessible |
| `oplog not enabled` | Replica set not configured | Enable replica set or use standalone mode |
| `document exceeds max size` | >16MB document | Split large documents or increase limit |
| `change stream not supported` | Cosmos DB limitation | Use `--cosmos-deletes-cdc` flag |
| `rate limit exceeded` | Too many requests | Reduce `--load-level` or add `--write-rate-limit` |
