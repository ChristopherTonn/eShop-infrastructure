# 🏗️ eShop Infrastructure – DevOps & Cloud Architecture Project

This directory contains the **Infrastructure-as-Code (IaC)** and deployment automation for the **Microsoft eShop** microservices application — part of the _DevOps & Cloud Architecture_ training project.

The infrastructure implements a **cloud-native multi-environment deployment** on **AWS**, managed via Terraform, Helm, and GitHub Actions under the "Everything as Code" paradigm.

---

## 🌐 Overview

The goal of this infrastructure is to provide a **scalable, secure, and maintainable AWS environment** for the eShop microservices application.

It supports three environments:

- **Development**
- **Staging**
- **Production**

### Core Technologies

| Purpose                 | Tool / Service                           |
| ----------------------- | ---------------------------------------- |
| Infrastructure as Code  | Terraform                                |
| Container Orchestration | Amazon EKS (Kubernetes)                  |
| Configuration as Code   | Ansible (optional)                       |
| CI/CD Automation        | GitHub Actions with OIDC → AWS IAM       |
| Monitoring              | Prometheus + Grafana + CloudWatch        |
| Secrets Management      | AWS Secrets Manager (CSI driver for EKS) |
| Messaging               | RabbitMQ (Helm chart)                    |
| Caching                 | Redis (ElastiCache)                      |
| Database                | PostgreSQL (Amazon RDS)                  |
| Networking              | VPC, ALB, Route 53                       |

---

## 🧱 Directory Structure

```bash
infra/
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   ├── elasticache/
│   │   ├── ecr/
│   │   └── iam-github-oidc/
│   └── envs/
│       ├── dev/
│       ├── stage/
│       └── prod/
├── k8s/
│   ├── helm/
│   │   ├── eshop-app/        # umbrella chart for microservices
│   │   └── dependencies/     # third-party charts (RabbitMQ, Redis)
│   └── manifests/            # cluster-level configs (Ingress, Issuers, etc.)
├── ansible/                  # optional config automation
└── README.md                 # this file
```

---

## ⚙️ Deployment Flow

### 1. Provision Infrastructure (Terraform)

Initialize and deploy resources to the desired environment:

```bash
cd infra/terraform/envs/dev
terraform init
terraform plan -var="project=eshop" -var="region=eu-central-1"
terraform apply -auto-approve
```

This creates:

- VPC with public/private subnets
- EKS cluster (managed node groups)
- RDS PostgreSQL instance
- ElastiCache Redis cluster
- RabbitMQ Helm deployment
- ECR repositories
- IAM roles with OIDC trust for GitHub Actions

---

### 2. Deploy Application (Helm)

After provisioning, deploy the application to the EKS cluster:

```bash
make kube-login ENV=dev
make helm-deploy ENV=dev
```

Helm uses environment-specific values files located in:

```bash
infra/k8s/helm/eshop-app/values-{env}.yaml
```

---

### 3. CI/CD Integration (GitHub Actions)

- **CI workflow (`ci.yml`)** → restores, builds, tests and scans .NET services.
- **CD workflow (`cd.yml`)** → assumes AWS role via OIDC, builds & pushes images to ECR, then deploys via Helm to the correct environment.

The pipeline stages:

1. Code pushed → build & test (.NET)
2. Trivy scan for vulnerabilities
3. Push image to ECR
4. Helm deploy → EKS (dev → stage → prod)

---

## 🔐 AWS IAM User Setup (Security Best Practice)

⚠️ **IMPORTANT**: Never use the AWS Root User for deployments. This project uses an **IAM User with Least Privilege** permissions.

### Quick Setup

1. **Create IAM User** (AWS Console):

   - User name: `eshop-terraform-user`
   - Grant `Programmatic Access` (Access Key + Secret)
   - Attach policy from [`iam-policy-eshop-terraform.json`](./iam-policy-eshop-terraform.json)

2. **Configure Local Credentials**:

   ```bash
   # Edit ~/.aws/credentials
   [eshop-terraform]
   aws_access_key_id = AKIA...
   aws_secret_access_key = ...
   region = eu-central-1
   ```

3. **Verify Setup**:

   ```bash
   aws sts get-caller-identity --profile eshop-terraform
   ```

4. **Use in Scripts**:

   ```bash
   # Automatic (uses AWS_PROFILE env var)
   export AWS_PROFILE=eshop-terraform
   ./deploy.sh

   # Or explicit
   AWS_PROFILE=eshop-terraform ./infra/deploy.sh
   ```

### Security Best Practices

✅ Use IAM User instead of Root (this project)  
✅ Least Privilege - only required permissions  
✅ Credentials in `~/.aws/credentials` (NOT in repo)  
✅ Rotate Access Keys every 90 days  
✅ Enable MFA for Root Account  
✅ Use Terraform State with encryption (S3 + DynamoDB)

**For detailed setup, see**: [`IAM_SETUP_GUIDE.md`](./IAM_SETUP_GUIDE.md)

---

## 🔒 Security

- AWS IAM roles follow **least privilege** principles
- GitHub → AWS via **OIDC** (no long-lived credentials)
- Kubernetes RBAC per namespace
- Secrets stored in **AWS Secrets Manager** (mounted via CSI driver)
- Enforced **TLS / HTTPS** for all ingress traffic

---

## 📊 Observability & Logging

- **Prometheus** for metrics collection
- **Grafana** for dashboards (golden signals)
- **Alertmanager** for notifications (Slack/Email)
- **CloudWatch** for centralized AWS logs

Dashboards and alert rules are stored in the `k8s/helm/monitoring` subchart (Week 5 deliverable).

---

## 🧩 Maintenance & Recovery

- Automated **RDS snapshots** + S3 backups
- Documented **restore procedures** in `/docs/runbooks/`
- Backup verification scheduled weekly via GitHub Actions

---

## ✅ Quickstart Summary

| Step | Command                    | Description                           |
| ---- | -------------------------- | ------------------------------------- |
| 1    | `terraform apply`          | Provision AWS infrastructure          |
| 2    | `make helm-deploy ENV=dev` | Deploy services to EKS                |
| 3    | `terraform destroy`        | Tear down infrastructure (with care!) |

---

## 📚 Additional Resources

- Architecture Diagrams → [`/docs/architecture/`](../docs/architecture/)
- Runbooks & DR Procedures → [`/docs/runbooks/`](../docs/runbooks/)
- CI/CD Workflows → [`.github/workflows/`](../../.github/workflows/)

---

**Author:** DevOps & Cloud Architecture Project Team  
**Last Updated:** October 2025
