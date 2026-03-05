# Dsync Runner Checklists

## Pre-Migration Checklist

### Source Database
- [ ] Connection string tested and verified
- [ ] Read permissions granted for migration user
- [ ] Change streams / oplog / CDC enabled (for continuous replication)
- [ ] Network connectivity from dsync host to source
- [ ] Estimated data size known

### Destination Database
- [ ] Connection string tested and verified
- [ ] Write permissions granted for migration user
- [ ] Sufficient storage capacity provisioned
- [ ] Network connectivity from dsync host to destination
- [ ] Target databases/collections created (if required)

### Dsync Environment
- [ ] Docker installed and running
- [ ] Correct dsync image pulled (`markadiom/dsync` or `markadiom/dsynct`)
- [ ] Sufficient CPU/memory for workload
- [ ] Persistent volume for resume state (enterprise)

## Distribution Selection Checklist

### Use dsync (Open Source) when:
- [ ] Data size < 100 GB
- [ ] Single-node deployment sufficient
- [ ] Basic progress monitoring acceptable
- [ ] AGPL v3 license compatible

### Use dsynct (Enterprise) when:
- [ ] Data size > 100 GB
- [ ] Horizontal scaling required
- [ ] Advanced observability needed (SigNoz)
- [ ] Production SLA requirements
- [ ] Workflow durability critical (Temporal)

## Sync Configuration Checklist

- [ ] Source connection string correct
- [ ] Destination connection string correct
- [ ] Namespace filtering configured (if needed)
- [ ] Namespace remapping configured (if needed)
- [ ] Load level appropriate for infrastructure
- [ ] Rate limiting set (if destination has limits)
- [ ] Transform config tested (if using transformations)

## Initial Sync Validation

### During Sync
- [ ] Progress visible (web UI or CLI)
- [ ] No error messages in logs
- [ ] Throughput within expected range
- [ ] Resource usage acceptable (CPU, memory, network)

### After Initial Sync
- [ ] Quick count verification passed
  ```bash
  ./dsync --verify-quick-count $SOURCE $DESTINATION
  ```
- [ ] Document counts match source
- [ ] Sample documents spot-checked
- [ ] Embedded/nested data correct
- [ ] Data types preserved correctly

## CDC Validation Checklist

### Setup
- [ ] Change streams enabled on source (MongoDB replica set)
- [ ] CDC mode started successfully
- [ ] Resume token saved (for restarts)

### Validation
- [ ] Insert changes replicated
  ```bash
  # Insert test document on source
  # Verify appears on destination within seconds
  ```
- [ ] Update changes replicated
  ```bash
  # Update document on source
  # Verify change on destination
  ```
- [ ] Delete changes replicated (if supported)
  ```bash
  # Delete document on source
  # Verify removed from destination
  ```
- [ ] Lag within acceptable range

## Transform Validation Checklist

- [ ] Transform config syntax valid (YAML)
- [ ] CEL expressions tested in Transform Studio
- [ ] Field mappings produce expected output
- [ ] Type conversions correct
- [ ] ID transformation working
- [ ] Added fields present
- [ ] Deleted fields removed
- [ ] Filter expressions tested

### Test with Single Document
```bash
docker run -e 'DSYNCT_MODE=simple' \
  -v "./transform.yaml:/transform.yaml" \
  markadiom/dsynct testsync \
  --namespace source.collection \
  --id "test_doc_id" \
  --transform \
  $SOURCE $DESTINATION dsync-transform://transform.yaml
```

## Enterprise Deployment Checklist

### Temporal
- [ ] Temporal server running
- [ ] Database file on persistent storage
- [ ] Dynamic config values set
- [ ] Web UI accessible (port 8233)

### SigNoz (Optional)
- [ ] SigNoz containers running
- [ ] Web UI accessible (port 8080)
- [ ] Account created
- [ ] Dashboards imported

### Workers
- [ ] Worker containers running
- [ ] Connected to Temporal
- [ ] OTEL endpoint configured
- [ ] Correct queue name set
- [ ] Appropriate parallelism settings

### Runner
- [ ] Runner container started
- [ ] Connected to Temporal
- [ ] Progress UI accessible
- [ ] Workflow registered

## Production Cutover Checklist

### Pre-Cutover
- [ ] Initial sync completed
- [ ] CDC running and caught up
- [ ] Verification passed
- [ ] Rollback plan documented
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified

### During Cutover
- [ ] Stop application writes to source
- [ ] Wait for CDC to fully catch up
- [ ] Final verification
  ```bash
  ./dsync --verify-quick-count $SOURCE $DESTINATION
  ```
- [ ] Switch application connection strings
- [ ] Verify application connectivity

### Post-Cutover
- [ ] Application functioning correctly
- [ ] Monitor for errors
- [ ] Keep CDC running (optional, for rollback)
- [ ] Document completion

## Troubleshooting Checklist

### Connection Issues
- [ ] Network connectivity verified (ping, telnet)
- [ ] Firewall rules allow traffic
- [ ] Credentials correct
- [ ] SSL/TLS configured properly
- [ ] `host.docker.internal` used for localhost

### Performance Issues
- [ ] Load level appropriate
- [ ] Rate limiting not too aggressive
- [ ] Source/destination not overloaded
- [ ] Network bandwidth sufficient
- [ ] Worker count adequate (enterprise)

### Data Issues
- [ ] Source data valid
- [ ] Document sizes within limits
- [ ] Transform config correct
- [ ] Namespace mapping correct
- [ ] Type conversions appropriate

### CDC Issues
- [ ] Replica set configured (MongoDB)
- [ ] Change tracking enabled (SQL Server)
- [ ] Resume token valid
- [ ] No gaps in change stream
