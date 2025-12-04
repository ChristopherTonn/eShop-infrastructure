# 🔄 GitHub Actions Workflows

Automated CI/CD pipelines for building, testing, and deploying eShop microservices.

**Navigation:** [← CI/CD Documentation](../../docs/CI-CD.md) | [Infrastructure →](../../docs/infrastructure/README.md)

---

## ✅ Continuous Integration (`ci.yml`)

### Triggers

- Push to `feature/**` branches (wildcard support)
- Pull requests to `develop`, `staging`, `main` branches

### Jobs Overview

#### 🏗️ Build & Test .NET Services

- **Code Location**: `codebase/src/` and `codebase/tests/`
- **Framework**: .NET 9.0 (LTS)
- **Services Covered**:
  - eShop.AppHost (Aspire orchestrator)
  - Basket.API, Catalog.API, Identity.API, Ordering.API
  - OrderProcessor, PaymentProcessor, Webhooks.API
  - WebApp, WebhookClient, eShop.ServiceDefaults
  - WebAppComponents
- **Strategy**: Matrix build for parallel execution
- **Tests**: Unit tests from `codebase/tests/`

#### 🔒 Security Scan

- **Tool**: Trivy vulnerability scanner
- **Scope**: File system scan for security vulnerabilities
- **Severities**: CRITICAL, HIGH, MEDIUM
- **Output**: SARIF format uploaded to GitHub Security tab

#### 🏢 Complete Solution Build

- **Purpose**: Final solution-wide build and artifact creation
- **Artifacts**: Published .NET applications ready for containerization
- **Retention**: 30 days

### Features

- ✅ **NuGet Package Caching** for faster builds
- ✅ **.NET 9.0 LTS** - Latest stable version
- ✅ **Parallel Execution** via matrix strategy
- ✅ **Test Result Collection** with TRX format
- ✅ **Security Integration** (Trivy) with GitHub Security tab
- ✅ **Build Artifacts** uploaded for debugging
- ✅ **Comprehensive Logging** and summary reports
- ✅ **Resilient Jobs** - Security scan and build complete even if tests fail

## 🚀 Continuous Deployment (`cd.yml`)

### Status: ✅ **Active & Enabled**

Automatically builds and deploys container images to AWS EKS.

### Triggers

- Successful completion of CI workflow
- Branches: `develop`, `staging`, `main`

### Environment Mapping

| Branch    | Environment | EKS Cluster |
| --------- | ----------- | ----------- |
| `develop` | development | eks-dev     |
| `staging` | staging     | eks-staging |
| `main`    | production  | eks-prod    |

### Future Jobs (When Infrastructure is Ready)

#### 🐳 Build & Push Container Images

- **Registry**: Amazon ECR
- **Authentication**: AWS OIDC (no long-lived credentials)
- **Tags**: Git commit SHA for traceability

#### ☸️ Deploy to Kubernetes

- **Orchestrator**: Helm charts
- **Target**: Amazon EKS clusters
- **Strategy**: Rolling deployments with health checks

#### 🧪 Integration Tests

- **Scope**: End-to-end testing against deployed services
- **Tools**: TBD (Playwright, Postman/Newman, custom test suite)

## 🔧 Configuration

### Environment Variables

```yaml
DOTNET_VERSION: "9.0.x" # .NET SDK version (LTS)
DOTNET_CONFIGURATION: "Release" # Build configuration
AWS_REGION: "eu-central-1" # Target AWS region
```

### Required Secrets (For CD Pipeline)

```bash
AWS_ROLE_ARN  # AWS IAM Role ARN for OIDC authentication
```

### GitHub Environments

- `development` - Auto-deploy from develop branch
- `staging` - Auto-deploy from staging branch
- `production` - Manual approval required

## 📊 Workflow Outputs

### Build Artifacts

- **Path**: `artifacts/`
- **Contents**: Published .NET applications
- **Format**: Ready for Docker containerization
- **Retention**: 30 days

### Test Results

- **Format**: TRX (Visual Studio Test Results)
- **Location**: `TestResults/`
- **Retention**: 7 days

### Security Reports

- **Format**: SARIF (Static Analysis Results Interchange Format)
- **Integration**: GitHub Security & Dependabot
- **Visibility**: GitHub Security tab

## 🚀 Getting Started

### Prerequisites

1. ✅ .NET 9 SDK installed (handled by workflow)
2. ✅ AWS Infrastructure provisioned (Terraform)
3. ✅ Container Registry (ECR) configured
4. ✅ Kubernetes Cluster (EKS) running

### Current Status

- ✅ **CI Pipeline**: Fully functional and tested
- ✅ **CD Pipeline**: Active and deploying to EKS
- ✅ **Security Scanning**: Trivy integrated with GitHub
- 📋 **Next Steps**:
  1. Monitor deployment metrics in CloudWatch
  2. Set up alerts for failed deployments
  3. Configure auto-scaling policies

## 🔍 Monitoring & Observability

### GitHub Actions Insights

- **Build Times**: Tracked per service
- **Success Rates**: Monitored across environments
- **Artifact Sizes**: Optimized for deployment speed

### Security Monitoring

- **Vulnerability Tracking**: Automated via Trivy
- **Dependency Updates**: Dependabot integration
- **Security Advisories**: GitHub Security tab

## 🔗 Related Documentation

- [CI/CD Overview](../../docs/CI-CD.md) - Pipeline architecture and concepts
- [Deployment Guide](../../docs/deployment/KUBERNETES_DEPLOYMENT.md) - Kubernetes deployment
- [Environment Configuration](../../docs/deployment/ENVIRONMENTS_AND_SECRETS.md) - Secrets management
- [AWS Setup](../../docs/infrastructure/AWS_SETUP.md) - OIDC provider setup

---

**Last updated:** December 2025

**Next Phase**: Week 3 - Infrastructure provisioning will enable the full CD pipeline.
