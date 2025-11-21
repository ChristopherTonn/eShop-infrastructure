# 🔄 CI/CD Workflows

This directory contains GitHub Actions workflows for the eShop microservices application.

## 🔨 Continuous Integration (`ci.yml`)

### Triggers

- Push to `develop`, `staging`, `main` branches
- Pull requests to `develop`, `staging`, `main` branches

### Jobs Overview

#### 🏗️ Build & Test .NET Services

- **Strategy**: Matrix build for all microservices
- **Services Covered**:
  - eShop.AppHost (Aspire orchestrator)
  - Basket.API
  - Catalog.API
  - Identity.API
  - Ordering.API
  - OrderProcessor
  - PaymentProcessor
  - Webhooks.API
  - WebApp (Blazor frontend)
  - WebhookClient
  - eShop.ServiceDefaults
  - WebAppComponents

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
- ✅ **.NET 10 Support** with prerelease packages
- ✅ **Parallel Execution** via matrix strategy
- ✅ **Test Result Collection** with TRX format
- ✅ **Security Integration** with GitHub Security tab
- ✅ **Build Artifacts** for deployment pipeline
- ✅ **Comprehensive Logging** and summary reports

## 🚀 Continuous Deployment (`cd.yml`)

### Status: 🚧 **Prepared but Disabled**

_This workflow is ready but disabled until AWS infrastructure is provisioned._

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
DOTNET_VERSION: "10.0.x" # .NET SDK version
DOTNET_CONFIGURATION: "Release" # Build configuration
AWS_REGION: "eu-central-1" # Target AWS region
```

### Required Secrets (For CD Pipeline)

```bash
AWS_DEPLOYMENT_ROLE_ARN    # AWS IAM Role for OIDC authentication
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

1. ✅ .NET 10 SDK installed (handled by workflow)
2. ⏳ AWS Infrastructure (Week 3 deliverable)
3. ⏳ Container Registry (ECR)
4. ⏳ Kubernetes Cluster (EKS)

### Current Status

- ✅ **CI Pipeline**: Fully functional
- 🚧 **CD Pipeline**: Prepared, awaiting infrastructure
- 📋 **Next Steps**:
  1. Create Dockerfiles for each service
  2. Provision AWS infrastructure with Terraform
  3. Enable CD pipeline
  4. Add integration tests

## 🔍 Monitoring & Observability

### GitHub Actions Insights

- **Build Times**: Tracked per service
- **Success Rates**: Monitored across environments
- **Artifact Sizes**: Optimized for deployment speed

### Security Monitoring

- **Vulnerability Tracking**: Automated via Trivy
- **Dependency Updates**: Dependabot integration
- **Security Advisories**: GitHub Security tab

---

**Next Phase**: Week 3 - Infrastructure provisioning will enable the full CD pipeline.
