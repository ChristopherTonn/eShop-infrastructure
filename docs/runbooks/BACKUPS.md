# 💾 Backups & Retention Runbook

Backup strategies, retention policies, and restore procedures.

**Navigation:** [← Scaling](SCALING.md) | [Runbooks ↑](README.md)

---

## 📋 Table of Contents

1. [Backup Strategy](#backup-strategy)
2. [Database Backups](#database-backups)
3. [Kubernetes Resources](#kubernetes-resources)
4. [Retention Policy](#retention-policy)
5. [Restore Procedures](#restore-procedures)

---

## 🎯 Backup Strategy

### Three-Layer Backup Approach

| Layer | What | Frequency | Retention | RTO |
|-------|------|-----------|-----------|-----|
| **Database** | PostgreSQL data | Daily | 30 days | 1 hour |
| **Snapshots** | Point-in-time | Manual | 90 days | 30 min |
| **Configuration** | Terraform state, K8s manifests | Continuous | 7 days | 10 min |

---

## 🗄️ Database Backups (RDS)

### Automatic Backups

**AWS RDS automatically creates backups:**

```bash
# Check backup retention
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres \
  --query 'DBInstances[0].{BackupRetentionPeriod: BackupRetentionPeriod, EarliestRestorableTime: EarliestRestorableTime}'

# Output: BackupRetentionPeriod = 7 days (default)
```

### Enable Enhanced Backups

```bash
# Update backup retention to 30 days
aws rds modify-db-instance \
  --db-instance-identifier eshop-postgres \
  --backup-retention-period 30 \
  --region eu-central-1

# Enable backup window (when backups run)
# Change backup window to off-peak hours
aws rds modify-db-instance \
  --db-instance-identifier eshop-postgres \
  --preferred-backup-window "02:00-03:00" \
  --region eu-central-1
```

### Manual Snapshots

```bash
# Create manual snapshot before major changes
aws rds create-db-snapshot \
  --db-instance-identifier eshop-postgres \
  --db-snapshot-identifier eshop-postgres-backup-$(date +%Y%m%d) \
  --region eu-central-1

# View snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier eshop-postgres \
  --region eu-central-1

# Copy snapshot to another region (disaster recovery)
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier eshop-postgres-backup-20250115 \
  --target-db-snapshot-identifier eshop-postgres-backup-20250115-backup-region \
  --source-region eu-central-1 \
  --destination-region eu-west-1
```

---

## 📦 Kubernetes Resources Backup

### Backup Manifests

```bash
# Backup all Kubernetes resources
kubectl get all -n eshop -o yaml > eshop-backup-$(date +%Y%m%d).yaml

# Backup specific resource types
kubectl get deployments,services,configmaps,secrets -n eshop -o yaml > eshop-deployments-$(date +%Y%m%d).yaml

# Backup to file for version control
git add backups/
git commit -m "backup: kubernetes manifests from $( date)"
```

### Backup Terraform State

```bash
# AWS S3 already backs up state, but create local backup
aws s3 cp s3://eshop-terraform-state/dev/terraform.tfstate \
  ./terraform-state-backup-$(date +%Y%m%d).tfstate

# Encrypt backup
gpg --symmetric --cipher-algo AES256 terraform-state-backup-*.tfstate

# Store in secure location
mv *.tfstate.gpg /secure/backup/location/
```

---

## 📅 Retention Policy

### Data Retention

| Backup Type | Age | Action |
|-------------|-----|--------|
| RDS Automatic | > 7 days | Auto-delete |
| RDS Manual | > 90 days | Auto-delete |
| Snapshots | > 30 days | Alert for review |
| K8s Manifests | > 6 months | Archive to cold storage |
| Logs | > 30 days | Archive to S3 Glacier |

### Implement Retention

```bash
# List old snapshots
aws rds describe-db-snapshots \
  --query "DBSnapshots[?SnapshotCreateTime<='$(date -d '90 days ago')'].{Id: DBSnapshotIdentifier, Created: SnapshotCreateTime}" \
  --output table

# Delete old snapshot
aws rds delete-db-snapshot \
  --db-snapshot-identifier eshop-postgres-backup-20241015 \
  --region eu-central-1

# Automate deletion with Lambda (optional)
# Function: Check snapshots older than 90 days and delete
```

---

## ♻️ Restore Procedures

### Restore Database from Latest Backup

```bash
# Option 1: Restore to point in time (within backup window)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier eshop-postgres \
  --target-db-instance-identifier eshop-postgres-restored \
  --restore-time 2025-01-15T10:30:00Z \
  --region eu-central-1

# Wait for restore (5-15 minutes)
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres-restored \
  --query 'DBInstances[0].DBInstanceStatus'
```

### Restore from Manual Snapshot

```bash
# 1. List available snapshots
aws rds describe-db-snapshots \
  --query 'DBSnapshots[].{Id: DBSnapshotIdentifier, Created: SnapshotCreateTime}'

# 2. Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier eshop-postgres-restored \
  --db-snapshot-identifier eshop-postgres-backup-20250115 \
  --region eu-central-1

# 3. Update application to point to new endpoint
# Get new endpoint
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres-restored \
  --query 'DBInstances[0].Endpoint.Address'

# 4. Update connection string in Kubernetes secrets
kubectl set env deployment/catalog-api \
  DB_HOST=eshop-postgres-restored.abcdefg.eu-central-1.rds.amazonaws.com \
  -n eshop

# 5. Verify connectivity
kubectl logs -f deployment/catalog-api -n eshop | grep "Connected\|Error"
```

### Restore Kubernetes Resources

```bash
# Restore entire namespace
kubectl apply -f eshop-backup-20250115.yaml

# Or restore specific resources
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-api
  namespace: eshop
spec:
  # ... deployment spec from backup
EOF

# Verify restore
kubectl get pods -n eshop
kubectl describe deployment catalog-api -n eshop
```

---

## ✅ Backup Verification

### Test Restore Quarterly

```bash
# Create test database from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier eshop-postgres-test \
  --db-snapshot-identifier eshop-postgres-backup-20250115 \
  --region eu-central-1

# Connect and verify data
psql -h eshop-postgres-test.abcdefg.eu-central-1.rds.amazonaws.com \
  -U eshop -d catalogdb -c "SELECT COUNT(*) as record_count FROM catalog;"

# Compare with production
psql -h eshop-postgres.abcdefg.eu-central-1.rds.amazonaws.com \
  -U eshop -d catalogdb -c "SELECT COUNT(*) as record_count FROM catalog;"

# Should match!

# Delete test database
aws rds delete-db-instance \
  --db-instance-identifier eshop-postgres-test \
  --skip-final-snapshot \
  --region eu-central-1
```

---

## 🔒 Backup Security

### Encrypt Backups

```bash
# RDS snapshots encrypted automatically (KMS)
# Verify encryption
aws rds describe-db-snapshots \
  --db-snapshot-identifier eshop-postgres-backup-20250115 \
  --query 'DBSnapshots[0].StorageEncrypted'

# Enable snapshot copy to other region with encryption
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier eshop-postgres-backup-20250115 \
  --target-db-snapshot-identifier eshop-postgres-backup-20250115-us \
  --source-region eu-central-1 \
  --destination-region us-east-1 \
  --kms-key-id arn:aws:kms:us-east-1:123456789:key/12345678-1234-1234-1234-123456789012
```

### Restrict Backup Access

```bash
# Only allow backup restore to specific IAM role
aws rds modify-db-snapshot-attribute \
  --db-snapshot-identifier eshop-postgres-backup-20250115 \
  --attribute-name restore \
  --values-to-add arn:aws:iam::123456789:role/eshop-backup-restore
```

---

## 📞 Backup Troubleshooting

### Backup Failed

```bash
# Check backup status
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres \
  --query 'DBInstances[0].{LatestRestorableTime, BackupRetentionPeriod}'

# Check events
aws rds describe-events \
  --source-identifier eshop-postgres \
  --source-type db-instance \
  --max-records 10
```

### Restore Failed

```bash
# Check error details
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres-restored \
  --query 'DBInstances[0].{DBInstanceStatus, StatusInfos}'

# Common issues:
# - Insufficient disk space (expand allocated storage)
# - Incompatible parameter group
# - Instance type not available in AZ
```

---

## 🔗 Related Documentation

- [Disaster Recovery](DISASTER_RECOVERY.md)
- [Monitoring & Alerting](MONITORING_ALERTS.md)
- [Infrastructure Overview](../infrastructure/README.md)

---

**Last updated:** December 2025
