# Dsync SQLBatch Mapping Verification Checklist

## Pre-Generation Checklist

- [ ] **Database schema available** - DDL or table descriptions with columns, types, PKs, FKs
- [ ] **Target document model defined** - Container names, document types, partition keys
- [ ] **Embedding strategy decided** - Which related data to embed vs reference
- [ ] **Connection string ready** - Use `host.docker.internal` for Docker testing

## Config Generation Checklist

- [ ] **Uppercase ID** - All `AS ID` aliases and `cols: ["ID"]` use uppercase
- [ ] **Unique namespaces** - Multi-document containers use `Container.doctype` format
- [ ] **Money types handled** - All `money`/`decimal` columns use `CAST(... AS FLOAT)`
- [ ] **JSON fields listed** - All embedded JSON fields in `decodejson` array
- [ ] **Change queries complete** - One query per table that affects the document
- [ ] **Null guards added** - `WHERE ... IS NOT NULL` on change query joins
- [ ] **Correct PK joins** - Change queries join on tracked table's actual primary key

## Testing Checklist

### 1. Initial Sync Test (without CDC)
```bash
docker run --rm --entrypoint /simple \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO \
  sync --skip-change-stream --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Namespace" \
  sqlbatch --config=cfg.yml /dev/null
```

- [ ] No errors in output
- [ ] Records counted correctly
- [ ] JSON structure matches expected format
- [ ] No base64 encoded numeric values
- [ ] Embedded arrays properly decoded

### 2. Change Tracking Setup (SQL Server)
```bash
# Run enable-change-tracking.sql on database
sqlcmd -S server -d database -i enable-change-tracking.sql
```

- [ ] Database-level change tracking enabled
- [ ] All required tables have change tracking enabled
- [ ] Verify with: `SELECT * FROM sys.change_tracking_tables`

### 3. Full Sync with CDC
```bash
docker run --rm --entrypoint /simple \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO \
  sync --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Namespace" \
  sqlbatch --config=cfg.yml /dev/null
```

- [ ] Initial sync completes
- [ ] CDC phase starts (watching for changes)
- [ ] No `string(null_type)` errors
- [ ] No `Invalid column name` errors

### 4. CDC Validation
```bash
# Terminal 1: Start dsync in CDC-only mode
docker run --rm --entrypoint /simple \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO \
  sync --skip-initial-sync --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Namespace" \
  sqlbatch --config=cfg.yml /dev/null

# Terminal 2: Generate test data changes
# Insert/update/delete records in source database
```

- [ ] `write-updates` messages appear for new inserts
- [ ] `write-updates` messages appear for updates
- [ ] Deletes handled correctly (if applicable)
- [ ] Related table changes trigger parent document updates

## Common Issues Checklist

| Issue | Check | Fix |
|-------|-------|-----|
| `query column missing ID` | Is alias uppercase? | Change to `AS ID` |
| `string(null_type)` | Does change query join produce nulls? | Add `WHERE col IS NOT NULL` |
| Base64 in numbers | Is column money/decimal type? | Add `CAST(col AS FLOAT)` |
| `Change tracking not enabled` | Is table in change tracking? | Run enable script |
| `Invalid column name` | Is CHANGETABLE join on correct PK? | Use table's actual PK |
| `connection refused` | Is connection string correct for Docker? | Use `host.docker.internal` |
| Empty embedded arrays | Is subquery WHERE clause correct? | Check FK/PK relationship |
| Duplicate documents | Is namespace unique per mapping? | Use `Container.doctype` format |

## Production Readiness Checklist

- [ ] All namespaces tested individually
- [ ] Full sync completes without errors
- [ ] CDC captures all change types (insert, update, delete)
- [ ] Performance acceptable (check batch sizes)
- [ ] Connection string uses production credentials
- [ ] Change tracking retention appropriate for sync frequency
- [ ] Monitoring/alerting configured for sync failures
