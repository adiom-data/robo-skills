---
name: dsync-sqlbatch-mapping
description: Generate SQLBatch dsync YAML configuration for mapping SQL database tables to NoSQL document structures. Use when user needs to create dsync config for SQL Server, DB2, or PostgreSQL to CosmosDB/MongoDB sync with CDC support.
---

# SQLBatch Dsync Mapping Config Generator

Generate a dsync SQLBatch YAML configuration file that maps relational SQL tables to NoSQL document structures with support for initial sync and CDC (Change Data Capture).

## Required Inputs

Before generating the config, gather:

1. **Database Type**: `sqlserver`, `db2`, or `postgres`
2. **Connection String**: Server, port, database, credentials
3. **Source Schema**: SQL DDL or table structure (columns, types, primary keys, foreign keys)
4. **Target Document Model**: Description of desired NoSQL structure including:
   - Container/collection names
   - Document types within each container
   - Partition key strategy
   - Which related data to embed vs reference

## Config Structure

```yaml
driver: sqlserver  # or db2, postgres
connectionstring: sqlserver://user:password@host:port?database=DbName
mappings:
  - namespace: ContainerName.documentType  # Unique per mapping
    countquery: "SELECT COUNT(1) FROM Table"
    partitionquery: "SELECT 'prefix_' + CAST(ID AS VARCHAR) AS ID FROM Table TABLESAMPLE (1 PERCENT)"
    query: |
      SELECT 
          'prefix_' + CAST(t.ID AS VARCHAR) AS ID,
          'prefix_' + CAST(t.ID AS VARCHAR) AS partitionKey,
          'doctype' AS type,
          t.Column1 AS field1,
          (SELECT ... FOR JSON PATH) AS embeddedArray
      FROM Table t
    limit: 500
    cols: ["ID"]  # MUST be uppercase
    decodejson: ["embeddedArray"]  # List embedded JSON fields
    changes:
      - query: "SELECT ... FROM CHANGETABLE(CHANGES Table, @p1) AS CT ..."
        initialcursorquery: "SELECT CHANGE_TRACKING_CURRENT_VERSION()"
```

## Critical Rules

### 1. Column Naming
- **ALWAYS use uppercase `ID`** in query aliases and `cols` array
- Example: `CAST(t.TableID AS VARCHAR) AS ID` with `cols: ["ID"]`

### 2. Namespace Naming for Multi-Document Containers
- When multiple document types share a container, use `Container.doctype` format
- Example: `CustomerOrders.customers`, `CustomerOrders.orders`

### 3. Money/Decimal Type Handling
- SQL Server `money` type gets base64 encoded - **CAST to FLOAT**
- Example: `CAST(t.Price AS FLOAT) AS price`

### 4. Embedded JSON
- Use `FOR JSON PATH` for arrays, `FOR JSON PATH, WITHOUT_ARRAY_WRAPPER` for objects
- List all embedded JSON fields in `decodejson` array

### 5. Change Tracking Queries
- Primary table: Use `CT.SYS_CHANGE_OPERATION` directly
- Related tables: Use `'U' AS SYS_CHANGE_OPERATION` (always treat as update)
- **ALWAYS add `WHERE ... IS NOT NULL`** for joins that may not match:
  ```sql
  SELECT 'prefix_' + CAST(t.ID AS VARCHAR) AS ID, 'U' AS SYS_CHANGE_OPERATION, 
         CHANGE_TRACKING_CURRENT_VERSION() 
  FROM CHANGETABLE(CHANGES RelatedTable, @p1) AS CT 
  JOIN MainTable t ON t.RelatedID = CT.RelatedID 
  WHERE t.ID IS NOT NULL  -- Prevents null ID errors
  ```

### 6. Change Tracking Primary Keys
- Join on the **primary key** of the tracked table, not foreign keys
- Example for ProductReview (PK: ProductReviewID, FK: ProductID):
  ```sql
  -- CORRECT: Join on ProductReviewID
  JOIN Production.ProductReview prv ON prv.ProductReviewID = CT.ProductReviewID
  
  -- WRONG: CT doesn't have ProductID
  JOIN Production.Product pr ON pr.ProductID = CT.ProductID
  ```

### 7. Always specify partition query

## Database-Specific Patterns

### SQL Server
```yaml
driver: sqlserver
connectionstring: sqlserver://sa:password@host.docker.internal:1433?database=DbName
```
- JSON: `FOR JSON PATH`, `FOR JSON PATH, WITHOUT_ARRAY_WRAPPER`
- CDC: `CHANGETABLE(CHANGES TableName, @p1)` with `CHANGE_TRACKING_CURRENT_VERSION()`
- Enable change tracking: See `templates/enable-change-tracking.sql`

### DB2
```yaml
driver: db2
connectionstring: db2://user:password@host:50000?database=DbName
```
- JSON: Use `LISTAGG` with manual JSON construction (no native JSON_ARRAYAGG)
- CDC: `ASNCDC.CDC_SCHEMA_TABLE` tables with `IBMSNAP_COMMITSEQ`

## Verification Steps

1. **Test Initial Sync First**
   ```bash
   docker run --rm --entrypoint /simple \
     -v ./config.yaml:/cfg.yml \
     markadiom/dsynct-alx --log-level INFO \
     sync --skip-change-stream --dst-data-type DATA_TYPE_JSON_ID \
     --namespace "Namespace" \
     sqlbatch --config=cfg.yml /dev/null
   ```

2. **Check JSON Output**
   - Verify document structure matches target model
   - Check for base64 encoded values (fix with FLOAT cast)
   - Confirm embedded arrays are properly decoded

3. **Test CDC** (requires change tracking enabled)
   ```bash
   # Full sync with CDC
   docker run --rm --entrypoint /simple \
     -v ./config.yaml:/cfg.yml \
     markadiom/dsynct-alx --log-level INFO \
     sync --dst-data-type DATA_TYPE_JSON_ID \
     --namespace "Namespace" \
     sqlbatch --config=cfg.yml /dev/null
   ```

4. **Test CDC-Only Mode**
   ```bash
   # Skip initial sync, only capture changes
   docker run --rm --entrypoint /simple \
     -v ./config.yaml:/cfg.yml \
     markadiom/dsynct-alx --log-level INFO \
     sync --skip-initial-sync --dst-data-type DATA_TYPE_JSON_ID \
     --namespace "Namespace" \
     sqlbatch --config=cfg.yml /dev/null
   ```

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `query column missing ID` | Lowercase `id` in query | Use `AS ID` (uppercase) |
| `string(null_type)` | Null ID from change query | Add `WHERE t.ID IS NOT NULL` |
| Base64 in numeric fields | SQL money/decimal type | `CAST(col AS FLOAT)` |
| `Change tracking not enabled` | Table not configured | Run enable-change-tracking.sql |
| `Invalid column name` in CDC | Wrong PK in CHANGETABLE join | Join on table's actual primary key |
| `connection refused` | Docker can't reach localhost | Use `host.docker.internal` |
| `no compatible data path` | MongoDB requires BSON, SQLBatch outputs JSON_ID | Use transformer pipeline (see MongoDB section) |
| Nested objects as JSON strings | Nested FOR JSON subqueries | Use `[parent.child]` bracket notation instead |

## MongoDB Destination Requirements

**CRITICAL**: MongoDB connector only accepts BSON data type, not JSON_ID. When using SQLBatch with MongoDB destination, you MUST use a transformer.

### Transformer Pipeline Setup

1. Create a transformer config file (`dsync-transform.yaml`):
```yaml
mappings:
  - namespace: sourceNamespace
    mapnamespace: DatabaseName.collectionName
  - namespace: anotherNamespace
    mapnamespace: DatabaseName.anotherCollection
```

2. Use the `--transform` flag and transformer destination:
```bash
docker run --rm \
  -e 'DSYNCT_MODE=simple' \
  -v ./config.yaml:/cfg.yaml \
  -v ./dsync-transform.yaml:/transform.yaml \
  markadiom/dsynct \
  --log-level INFO \
  sync --transform --skip-change-stream \
  --namespace "myNamespace" \
  sqlbatch --config=/cfg.yaml "mongodb://host:27017" dsync-transform:///transform.yaml
```

**Pipeline flow**: SQLBatch (JSON_ID) → Transformer → MongoDB (BSON)

## Nested JSON Objects in SQL Server

The `decodejson` array only works for top-level JSON fields. Nested JSON strings inside decoded objects remain as strings.

### Problem
```sql
-- This creates a JSON string for parentCategory, not a nested object
(
    SELECT
        pc.ProductCategoryID AS productCategoryId,
        pc.Name AS name,
        (
            SELECT ppc.ProductCategoryID AS productCategoryId, ppc.Name AS name
            FROM ProductCategory ppc
            WHERE ppc.ProductCategoryID = pc.ParentProductCategoryID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS parentCategory  -- This becomes a JSON string!
    FROM ProductCategory pc
    WHERE pc.ProductCategoryID = p.ProductCategoryID
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
) AS category
```

### Solution: Use SQL Server Bracket Notation
```sql
-- Use [dotted.path] notation to create proper nested objects
(
    SELECT
        pc.ProductCategoryID AS productCategoryId,
        pc.Name AS name,
        ppc.ProductCategoryID AS [parentCategory.productCategoryId],
        ppc.Name AS [parentCategory.name]
    FROM ProductCategory pc
    LEFT JOIN ProductCategory ppc ON ppc.ProductCategoryID = pc.ParentProductCategoryID
    WHERE pc.ProductCategoryID = p.ProductCategoryID
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
) AS category
```

This produces properly nested objects without needing nested `decodejson`.

### Array Items with Nested Objects
Same pattern works for arrays:
```sql
-- For lineItems with embedded product
(
    SELECT
        sod.OrderQty AS orderQty,
        sod.UnitPrice AS unitPrice,
        p.ProductID AS [product.productId],
        p.Name AS [product.name],
        p.Color AS [product.color]
    FROM SalesOrderDetail sod
    JOIN Product p ON p.ProductID = sod.ProductID
    WHERE sod.SalesOrderID = soh.SalesOrderID
    FOR JSON PATH
) AS lineItems
```

## Output

Generate the complete YAML config file with:
1. All namespace mappings
2. Proper query structure with embedded JSON
3. Change tracking queries for all related tables
4. Comments explaining partition key strategy
