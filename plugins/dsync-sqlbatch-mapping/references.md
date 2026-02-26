# Dsync SQLBatch Mapping References

## Working Examples

### SQL Server - AdventureWorks
Location: `/Users/alexander/tmp/adventureworks/dsync_nosql_adventureworks.yaml`

Features demonstrated:
- Multi-document containers (`CustomerOrders.customers`, `CustomerOrders.orders`)
- Embedded JSON arrays (`FOR JSON PATH`)
- Embedded JSON objects (`FOR JSON PATH, WITHOUT_ARRAY_WRAPPER`)
- Money type handling (`CAST(... AS FLOAT)`)
- Multi-table change tracking with null guards
- Aggregated documents with GROUP BY (ShoppingCarts)
- Denormalized fields from related tables

### DB2 - Insurance Policies
Location: `/Users/alexander/tmp/dsync_db2/dsync_db2.yaml`

Features demonstrated:
- DB2 connection string format
- Manual JSON construction with LISTAGG
- ASNCDC change data capture tables
- IBMSNAP_COMMITSEQ cursor tracking

## Dsync Transform Configuration

For ID transformation (lowercase to application format):

```yaml
# dsync-transform.yml
defaultmapping: default
mappings:
  - namespace: default
    delete: ["ID"]
    add: ["id"]
    mapid: "string(id[0])"
    cel:
      id: string(parent.ID)
```

## Docker Commands

### Basic Sync Test
```bash
docker run --rm --entrypoint /simple \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO \
  sync --skip-change-stream --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Namespace" \
  sqlbatch --config=cfg.yml /dev/null
```

### With Transform
```bash
docker run --rm --entrypoint /simple \
  -v ./dsync-transform.yml:/transform.yml \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO \
  sync --transform --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Namespace" \
  sqlbatch --config=cfg.yml /dev/null --log-json dsync-transform://transform.yml
```

### With Web UI
```bash
docker run --rm --entrypoint /simple -p 8080:8080 \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO --host-port 0.0.0.0:8080 \
  sync --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Namespace" \
  sqlbatch --config=cfg.yml /dev/null
# Access progress at http://localhost:8080
```

### Multiple Namespaces
```bash
docker run --rm --entrypoint /simple \
  -v ./config.yaml:/cfg.yml \
  markadiom/dsynct-alx --log-level INFO \
  sync --dst-data-type DATA_TYPE_JSON_ID \
  --namespace "Container.type1" \
  --namespace "Container.type2" \
  --namespace "OtherContainer" \
  sqlbatch --config=cfg.yml /dev/null
```

## SQL Server Change Tracking

### Enable Database-Level
```sql
ALTER DATABASE MyDatabase
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
```

### Enable Table-Level
```sql
ALTER TABLE Schema.TableName
ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
```

### Query Current Version
```sql
SELECT CHANGE_TRACKING_CURRENT_VERSION();
```

### Query Changes
```sql
SELECT CT.*, t.*
FROM CHANGETABLE(CHANGES Schema.TableName, @version) AS CT
JOIN Schema.TableName t ON t.PrimaryKey = CT.PrimaryKey;
```

## DB2 CDC (ASNCDC)

### CDC Table Naming
CDC tables: `ASNCDC.CDC_<SCHEMA>_<TABLE>`

### Query Changes
```sql
SELECT cdc.*, t.*
FROM ASNCDC.CDC_SCHEMA_TABLE cdc
JOIN SCHEMA.TABLE t ON t.PK = cdc.PK
WHERE cdc.IBMSNAP_COMMITSEQ > ?;
```

### Get Current Cursor
```sql
SELECT MAX(SYNCHPOINT) FROM (
  SELECT CD_NEW_SYNCHPOINT AS SYNCHPOINT FROM ASNCDC.IBMSNAP_REGISTER
  UNION ALL
  SELECT SYNCHPOINT AS SYNCHPOINT FROM ASNCDC.IBMSNAP_REGISTER
);
```

## Cosmos DB Data Model Considerations

When designing the target document model:

1. **Partition Key Selection**
   - High cardinality (many unique values)
   - Even distribution of data
   - Commonly used in queries

2. **Embedding vs Referencing**
   - Embed: Data accessed together (>60% correlation)
   - Embed: Bounded growth (won't exceed 2MB document limit)
   - Reference: Unbounded growth
   - Reference: Frequently updated independently

3. **Multi-Document Containers**
   - Use `type` field to distinguish document types
   - Share partition key for related documents
   - Query with `WHERE c.type = 'doctype'`

## Troubleshooting Resources

- Dsync GitHub: https://github.com/adiom-data/dsync
- SQL Server Change Tracking: https://docs.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking
- DB2 CDC: https://www.ibm.com/docs/en/db2/11.5?topic=replication-sql-change-data-capture
