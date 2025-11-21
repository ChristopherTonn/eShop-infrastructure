# Monitoring Stack - Quick Start & Checklist

## Quick Start (5 Minuten)

### 1. Variablen konfigurieren
```bash
cd infra/terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars

# Minimal anpassen (optional, defaults sind ok):
# monitoring_enabled = true
# grafana_admin_password = ""  # auto-generated
```

### 2. Deployieren
```bash
terraform plan -target=module.monitoring
terraform apply -target=module.monitoring
```

Warte 2-5 Minuten für Deployment.

### 3. Zugriff einrichten
```bash
# Terminal 1
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090

# Terminal 2
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Passwords abrufen
terraform output grafana_admin_password
```

### 4. Dashboards öffnen
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin / <password>)

**Das war's!** Stack ist einsatzbereit.

---

## Pre-Deployment Checklist

- [ ] EKS Cluster läuft und ist erreichbar (`kubectl cluster-info`)
- [ ] kubectl konfiguriert (`kubectl get nodes`)
- [ ] Terraform initialized (`terraform init` in `infra/terraform/envs/dev`)
- [ ] Ausreichend Storage verfügbar (`kubectl get storageclass`)
- [ ] RabbitMQ Module erfolgreich deployed (`kubectl get pods -n rabbitmq`)
- [ ] tfvars Datei vorbereitet (kopiert aus example)

## Deployment Checklist

```bash
# 1. Prüfe Terraform Plan
terraform plan -target=module.monitoring | head -50

# 2. Führe Deployment durch
terraform apply -target=module.monitoring

# 3. Beobachte Deployment
watch kubectl get pods -n monitoring

# 4. Warte auf Ready Status
kubectl rollout status statefulset/kube-prometheus-stack-prometheus -n monitoring --timeout=5m

# 5. Verifiziere Services
kubectl get svc -n monitoring
```

## Post-Deployment Checklist

```bash
# Namespace vorhanden
[ ] kubectl get ns | grep monitoring

# Alle Pods Running
[ ] kubectl get pods -n monitoring
    - kube-prometheus-stack-prometheus-0 (1/1 Running)
    - kube-prometheus-stack-grafana-xxx (1/1 Running)
    - kube-prometheus-stack-alertmanager-0 (1/1 Running)
    - node-exporter-xxx (1/1 Running - auf jedem Node)
    - kube-state-metrics-xxx (1/1 Running)

# PVCs gebunden
[ ] kubectl get pvc -n monitoring
    - kube-prometheus-stack-prometheus-db-xxx (Bound)
    - kube-prometheus-stack-alertmanager-db-xxx (Bound)

# Services erreichbar
[ ] kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
    http://localhost:9090/graph → "Server"

[ ] kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
    http://localhost:3000 → Login Screen

[ ] kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
    http://localhost:9093 → Alertmanager UI

# PrometheusRule registriert
[ ] kubectl get prometheusrules -n monitoring
    eshop-alerts (3 groups, 7 rules)

# Prometheus Targets aktiv
[ ] kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
    http://localhost:9090/targets
    - Prometheus (1/1 up)
    - kubelet (nodes/1 up)
    - rabbitmq (1/1 up) ← sollte grün sein
```

## Erste Metriken prüfen

```bash
# 1. Port-Forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090

# 2. Browser: http://localhost:9090/graph

# 3. Teste PromQL Queries:

# Prometheus selbst läuft
up{job="prometheus"}

# Node Metriken
node_cpu_seconds_total

# RabbitMQ Metriken (wenn RabbitMQ deployed)
rabbitmq_up

# Kubernetes Metriken
kube_pod_info
```

## Grafana Setup

```bash
# 1. Port-Forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# 2. Browser: http://localhost:3000

# 3. Login
Username: admin
Password: (terraform output grafana_admin_password)

# 4. DataSource prüfen
Dashboards → DataSources → Prometheus (should be green)

# 5. Vordefinierte Dashboards nutzen
Dashboards → Browse
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Cluster Monitoring
- Prometheus / Prometheus Stats
```

## Häufige Fehler & Lösungen

### Fehler: Pods bleiben in Pending
```bash
# Prüfe Storage
kubectl get pvc -n monitoring
kubectl describe pvc kube-prometheus-stack-prometheus-db-xxx -n monitoring

# Wenn StorageClass nicht vorhanden
kubectl get storageclass
# Sollte mindestens eine geben (z.B., gp2)
```

### Fehler: Prometheus erreichbar, aber keine Metriken
```bash
# Prometheus braucht 30-60 Sekunden zum Start
kubectl logs kube-prometheus-stack-prometheus-0 -n monitoring --tail=50

# ServiceMonitor prüfen
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor prometheus-operator -n monitoring
```

### Fehler: Grafana lässt sich nicht anmelden
```bash
# Admin Password reset
kubectl patch secret grafana -n monitoring \
  -p '{"data":{"admin-password":"'$(echo -n 'admin' | base64)'"}}'

# Pod neustarten
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana
```

### Fehler: RabbitMQ Metriken fehlen
```bash
# RabbitMQ muss mit prometheus Plugin laufen
kubectl logs -n rabbitmq <pod> | grep prometheus

# RabbitMQ Port 15692 prüfen
kubectl port-forward -n rabbitmq svc/rabbitmq-headless 15692:15692
curl http://localhost:15692/metrics | head -20

# Prometheus scrape config prüfen
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
# http://localhost:9090/targets?search=rabbitmq
```

## Daily Operations

### Metriken Live-Abfragen
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
# http://localhost:9090/graph
```

### Dashboards ansehen
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000
```

### Logs prüfen
```bash
# Prometheus Logs
kubectl logs -f -n monitoring statefulset/kube-prometheus-stack-prometheus

# Grafana Logs
kubectl logs -f -n monitoring deploy/kube-prometheus-stack-grafana

# Alertmanager Logs
kubectl logs -f -n monitoring statefulset/kube-prometheus-stack-alertmanager
```

### Storage prüfen
```bash
# PVC Status
kubectl get pvc -n monitoring

# Storage-Nutzung
kubectl exec -it -n monitoring kube-prometheus-stack-prometheus-0 -- du -sh /prometheus
```

## Nächste Schritte

1. **Alertmanager Notifications** konfigurieren (Slack, Email, etc.)
   → `DEPLOYMENT_GUIDE.md` → Kapitel 6

2. **Custom Dashboards** erstellen
   → Grafana UI → Create → Dashboard

3. **Custom Alert Rules** hinzufügen
   → Bearbeite `main.tf` → Redeploy

4. **RabbitMQ Dashboard** importieren
   → `grafana-dashboard-rabbitmq.json`

5. **Backup Strategy** implementieren
   → `DEPLOYMENT_GUIDE.md` → Kapitel 11

## Wichtige Befehle (Spickzettel)

```bash
# Status prüfen
kubectl get all -n monitoring
kubectl get pvc -n monitoring

# Logs anschauen
kubectl logs -f -n monitoring <pod-name>
kubectl logs -f -n monitoring kube-prometheus-stack-prometheus-0

# Port-Forwarding
kubectl port-forward -n monitoring svc/kube-prometheus-stack 9090:9090
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus restarten
kubectl rollout restart statefulset/kube-prometheus-stack-prometheus -n monitoring

# Grafana restarten
kubectl rollout restart deploy/kube-prometheus-stack-grafana -n monitoring

# Secrets prüfen
kubectl get secret -n monitoring

# Alert Status
kubectl get prometheusrules -n monitoring
kubectl describe prometheusrule eshop-alerts -n monitoring

# Terraform Status
terraform output monitoring_deployment_info
```

## Support & Resources

- **README**: `infra/terraform/modules/monitoring/prometheus/README.md`
- **Deployment Guide**: `DEPLOYMENT_GUIDE.md` (dieses Dokument)
- **Prometheus Docs**: https://prometheus.io/docs/
- **Grafana Docs**: https://grafana.com/docs/
- **Kubernetes Cluster Monitoring**: https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/
