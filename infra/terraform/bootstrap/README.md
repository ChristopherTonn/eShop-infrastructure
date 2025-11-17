# 🚀 Terraform Bootstrap

Diese Bootstrap-Konfiguration erstellt die erforderliche Infrastruktur für Terraform State Management.

## 📋 Was wird erstellt

### S3 Buckets (Terraform State Storage)

- `eshop-terraform-state-dev`
- `eshop-terraform-state-staging`
- `eshop-terraform-state-prod`

**Features:**

- ✅ Versioning aktiviert
- ✅ Server-side Encryption (AES256)
- ✅ Public Access blockiert
- ✅ Environment-spezifische Trennung

### DynamoDB Tables (State Locking)

- `eshop-terraform-lock-dev`
- `eshop-terraform-lock-staging`
- `eshop-terraform-lock-prod`

**Features:**

- ✅ Pay-per-request Billing
- ✅ Automatic State Locking
- ✅ Conflict Prevention

## 🛠️ Setup Instructions

### 1️⃣ Bootstrap ausführen

```bash
# In das Bootstrap-Verzeichnis wechseln
cd infra/terraform/bootstrap

# AWS-Credentials konfigurieren
aws configure

# Terraform initialisieren
terraform init

# Plan anzeigen
terraform plan

# Bootstrap-Infrastruktur erstellen
terraform apply
```

### 2️⃣ Backend-Konfigurationen aktivieren

Nach dem Bootstrap, die Backend-Konfigurationen in den Environment-Dateien aktivieren:

**`envs/dev/main.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "eshop-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eshop-terraform-lock-dev"
    encrypt        = true
  }
}
```

**`envs/staging/main.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "eshop-terraform-state-staging"
    key            = "staging/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eshop-terraform-lock-staging"
    encrypt        = true
  }
}
```

**`envs/prod/main.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "eshop-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eshop-terraform-lock-prod"
    encrypt        = true
  }
}
```

### 3️⃣ State Migration durchführen

Für jede Environment:

```bash
# Development
cd ../envs/dev
terraform init

# Staging
cd ../staging
terraform init

# Production
cd ../prod
terraform init
```

## ⚠️ Wichtige Hinweise

### Bootstrap State Management

- **Bootstrap läuft lokal:** Keine Remote-State für Bootstrap selbst
- **Backup Bootstrap State:** `terraform.tfstate` sollte versioniert werden
- **Team-Zugriff:** Bootstrap sollte nur von einem Administrator ausgeführt werden

### Security Considerations

- ✅ S3 Buckets sind privat und verschlüsselt
- ✅ DynamoDB-Tabellen haben IAM-Zugriffskontrollen
- ✅ State-Dateien enthalten sensible Daten → Zugriff beschränken

### Cost Optimization

- **S3:** Standard-Tier für häufigen Zugriff
- **DynamoDB:** Pay-per-request für kosteneffiziente Nutzung
- **Monitoring:** CloudWatch-Metriken aktiviert

## 🔄 Reihenfolge der Terraform-Operationen

1. **Bootstrap** 🥾 ← **Sie sind hier**
2. **Development Environment** 🟢
3. **Staging Environment** 🟡
4. **Production Environment** 🔴

## 🧹 Cleanup

⚠️ **ACHTUNG:** Das Löschen der Bootstrap-Infrastruktur löscht alle Terraform-States!

```bash
# Nur in Notfällen!
terraform destroy
```

## 🤝 Team Workflow

1. **Administrator:** Führt Bootstrap einmalig aus
2. **Team:** Verwendet Remote-State für kollaborative Entwicklung
3. **CI/CD:** Nutzt State-Backend für automatische Deployments

---

**📝 Nach erfolgreichem Bootstrap:** Aktiviere Backend-Konfigurationen in Environment-Files!
