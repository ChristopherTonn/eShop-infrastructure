# 🚀 IAM User Quick Start

## ⚡ 5 Minuten Setup

### 1. AWS Console: IAM User erstellen

```text
AWS Console → IAM → Users → Create User
├─ Name: eshop-terraform-user
├─ ✅ Programmatic access
└─ Next → Policy: iam-policy-eshop-terraform.json
```

### 2. Credentials speichern

```bash
# ~/.aws/credentials bearbeiten:
[eshop-terraform]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
region = eu-central-1
```

### 3. Testen

```bash
aws sts get-caller-identity --profile eshop-terraform
# ✅ Sollte User ARN zeigen
```

### 4. Deploy

```bash
export AWS_PROFILE=eshop-terraform
./infra/deploy.sh
```

---

## 📖 Detaillierte Anleitung

→ **`infra/IAM_SETUP_GUIDE.md`**

## 🧪 Testing & Validierung

→ **`infra/IAM_TESTING_GUIDE.md`**

## ✅ Checkliste

→ **`infra/CHECKLIST.md`**

## 🔐 Policy Template

→ **`infra/iam-policy-eshop-terraform.json`**

---

## 💡 Wichtige Commands

```bash
# Teste IAM User
aws sts get-caller-identity --profile eshop-terraform

# Deploy mit Profile
AWS_PROFILE=eshop-terraform ./infra/deploy.sh

# Destroy mit Profile
AWS_PROFILE=eshop-terraform ./infra/destroy.sh

# Terraform mit Profile
cd infra/terraform/envs/dev
terraform plan -var="aws_profile=eshop-terraform"
```

---

## ❓ Probleme?

| Problem                         | Lösung                               |
| ------------------------------- | ------------------------------------ |
| "Profile not found"             | ~/.aws/credentials checken           |
| "UnauthorizedOperation"         | Policy neu anhängen, 5 min warten    |
| Credentials funktionieren nicht | Access Key ID/Secret überprüfen      |
| "InvalidParameterValue"         | `export AWS_PROFILE=eshop-terraform` |

→ Mehr Troubleshooting: **`IAM_TESTING_GUIDE.md`**

---

**Status:** ✅ Production-Ready  
**Zeit zum Setup:** 10-15 Minuten
