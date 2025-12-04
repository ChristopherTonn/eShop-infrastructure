# 🚨 Disaster Recovery Runbook

Procedures for recovering from various disaster scenarios.

**Navigation:** [← Runbooks Index](README.md) | [Next: Monitoring →](MONITORING_ALERTS.md)

---

## 📋 Table of Contents

1. [RTO/RPO Targets](#rtorpo-targets)
2. [Database Failure](#database-failure)
3. [EKS Cluster Failure](#eks-cluster-failure)
4. [Complete Region Failure](#complete-region-failure)
5. [Data Corruption](#data-corruption)

---

## 🎯 RTO/RPO Targets

| Scenario           | RTO     | RPO      | Impact                           |
| ------------------ | ------- | -------- | -------------------------------- |
| Single Pod Failure | 5 min   | 0 min    | Automatic (Kubernetes)           |
| Node Failure       | 10 min  | 0 min    | Automatic (node replacement)     |
| RDS Failure        | 15 min  | < 1 min  | Automatic failover               |
| Region Failure     | 1 hour  | < 1 hour | Manual failover to backup region |
| Complete Outage    | 4 hours | 24 hours | Full infrastructure rebuild      |

---

## 💾 Database Failure

### RDS Automatic Failover (Multi-AZ)

**Trigger:** RDS Multi-AZ automatic failover (happens automatically)

**Timeline:**

- Detection: < 2 minutes
- Failover: ~1-2 minutes
- Application restart: ~5 minutes
- Total RTO: ~10 minutes

**Verification:**

```bash
# Check database status
aws rds describe-db-instances \
  --db-instance-identifier eshop-postgres \
  --region eu-central-1 \
  --query 'DBInstances[0].{Status: DBInstanceStatus, Engine: Engine, MultiAZ: MultiAZEnabled}'

# Verify application can connect
kubectl logs -n eshop deployment/catalog-api | grep "Connected\|Connection"

# Run connectivity test
kubectl run -it db-test --image=postgres:15 --rm --restart=Never -- \
  psql -h RDS_ENDPOINT -U eshop -d catalogdb -c "SELECT 1"
```

### RDS Manual Recovery

**Trigger:** Manual recovery needed

**Steps:**

```bash
# 1. Take snapshot of current database
aws rds create-db-snapshot \
  --db-instance-identifier eshop-postgres \
  --db-snapshot-identifier eshop-postgres-manual-backup \
  --region eu-central-1

# Wait for snapshot
aws rds describe-db-snapshots \
  --db-snapshot-identifier eshop-postgres-manual-backup \
  --region eu-central-1 \
  --query 'DBSnapshots[0].Status'

# 2. Restore from snapshot (creates new instance)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier eshop-postgres-restored \
  --db-snapshot-identifier eshop-postgres-manual-backup \
  --region eu-central-1

# 3. Update application connection string
# Points to new RDS endpoint

# 4. Verify data integrity
psql -h NEW_RDS_ENDPOINT -U eshop -d catalogdb -c "SELECT COUNT(*) FROM catalog"

# 5. Delete old RDS instance when ready
aws rds delete-db-instance \
  --db-instance-identifier eshop-postgres \
  --skip-final-snapshot \
  --region eu-central-1
```

---

## ⚙️ EKS Cluster Failure

### Node Failure (Automatic Recovery)

**Trigger:** Node becomes unreachable

**Kubernetes auto-recovery:**

```bash
# Monitor node status
kubectl get nodes -w

# Expect:
# 1. Node marked NotReady (~5 min)
# 2. Pods evicted to other nodes (~10 min)
# 3. ASG replaces node automatically (~15 min)
```

**Manual verification:**

```bash
# Check node status
kubectl describe node <NODE_NAME>

# Check evicted pods
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Force pod rescheduling if needed
kubectl delete pod POD_NAME -n eshop
```

### EKS Control Plane Failure

**Trigger:** EKS control plane unavailable

**AWS manages control plane**, but if regional outage:

```bash
# 1. Failover to backup region (manual)
cd infra/terraform/envs/prod-backup-region
terraform apply

# 2. Point DNS to backup cluster
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch file://dns-failover.json

# 3. Verify services running
kubectl get services -A
kubectl get pods -A
```

---

## 🌍 Complete Region Failure

### Scenario: eu-central-1 Down

**Steps:**

```bash
# 1. Verify region is actually down (not just connectivity)
aws ec2 describe-instances --region eu-central-1 \
  --query 'Reservations[].Instances[].InstanceId'
# If times out, region is down

# 2. Trigger failover to backup region
cd infra/terraform/envs/prod-backup-region  # e.g., eu-west-1
terraform apply

# 3. Restore database from backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier eshop-postgres \
  --db-snapshot-identifier eshop-postgres-backup-20250115 \
  --region eu-west-1

# 4. Update application URLs in DNS
# Old: api.eshop.com → eu-central-1 ALB
# New: api.eshop.com → eu-west-1 ALB

aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.eshop.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z987654321ZYX",
          "DNSName": "eu-west-1-alb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# 5. Verify traffic flows to backup region
curl -I https://api.eshop.com/health

# 6. Monitor backup region metrics
kubectl top nodes -A
kubectl top pods -n eshop
```

---

## 🔄 Data Corruption

### Detect Corruption

```bash
# Run data integrity checks
kubectl exec -it -n eshop POD_NAME -- \
  dotnet YourApp.exe --check-integrity

# Query logs for errors
kubectl logs -n eshop deployment/catalog-api | grep -i "corrupt\|invalid\|error"

# Check database constraints
psql -h RDS_ENDPOINT -U eshop -d catalogdb << EOF
  SELECT table_name FROM information_schema.tables WHERE table_schema='public';

  -- Run constraint checks
  ALTER TABLE catalog VALIDATE CONSTRAINT fk_category;
EOF
```

### Recover from Backup

```bash
# 1. Stop affected services
kubectl scale deployment catalog-api --replicas=0 -n eshop

# 2. Restore from latest clean backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier eshop-postgres-restored \
  --db-snapshot-identifier eshop-postgres-backup-20250114 \
  --region eu-central-1

# 3. Verify data integrity
psql -h NEW_ENDPOINT -U eshop -d catalogdb -c "SELECT COUNT(*) FROM catalog"

# 4. Update connection string to point to restored database

# 5. Restart services
kubectl scale deployment catalog-api --replicas=3 -n eshop

# 6. Monitor logs for errors
kubectl logs -f -n eshop deployment/catalog-api
```

---

## 📞 Escalation

### Level 1: Automated Response

- Kubernetes auto-healing
- RDS multi-AZ failover
- CloudWatch alarms

### Level 2: Manual Intervention (15-30 min)

- Contact: Platform Team
- Actions: Node replacement, pod recovery
- Tools: kubectl, AWS CLI

### Level 3: Disaster Recovery (1-4 hours)

- Contact: Director of Engineering
- Actions: Regional failover, data restore
- Approval: Required for destructive operations

---

## 🔗 Related Documentation

- [Monitoring & Alerting](MONITORING_ALERTS.md)
- [Backups & Retention](BACKUPS.md)
- [Infrastructure Overview](../infrastructure/README.md)

---

**Last updated:** December 2025
