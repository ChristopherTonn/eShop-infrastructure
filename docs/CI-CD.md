# 🔄 CI/CD & DevOps Automation

Complete overview of continuous integration and continuous deployment pipelines for eShop.

**Navigation:** [← Back](INDEX.md) | [Up ↑](INDEX.md) | [Next: Architecture →](ARCHITECTURE.md)

## 📋 Quick Links

- [GitHub Workflows Details](../.github/workflows/README.md)
- [Deployment Guide](deployment/KUBERNETES_DEPLOYMENT.md)
- [Environment Setup](deployment/ENVIRONMENTS_AND_SECRETS.md)

---

## 🔄 Pipeline Overview

eShop uses **GitHub Actions** for automated:
1. **Build & Test** - Compile, unit tests, security scanning
2. **Container Build** - Docker images, push to ECR
3. **Kubernetes Deploy** - Helm charts to EKS
4. **Monitoring** - Automated health checks

### Workflow Files

| File | Trigger | Purpose |
|------|---------|---------|
| `ci.yml` | Push/PR to feature/* | Build & test all services |
| `cd.yml` | Merge to develop/main | Build images & deploy |
| `client-app-tests.yml` | Changes to ClientApp | E2E tests (Playwright) |
| `markdownlint.yml` | Changes to *.md | Documentation validation |
| `playwright.yml` | Scheduled + manual | E2E tests in CI |

### Branch Strategy

| Branch | Environment | Deploy | Approval |
|--------|-------------|--------|----------|
| `develop` | Dev | ✅ Automatic | None |
| `staging` | Staging | ✅ Automatic | None |
| `main` | Production | ⏸️ Manual | Required |
| `feature/*` | None | ✅ Build only | - |

---

## 🏗️ Build Pipeline

```
Code Push
    ↓
Build & Test (ci.yml)
    ├─ Checkout code
    ├─ Setup .NET 9
    ├─ Restore NuGet packages
    ├─ Build solution
    ├─ Run unit tests
    ├─ Security scan (Trivy)
    └─ Upload artifacts
    ↓
(if merged to develop/staging/main)
    ↓
Deploy Pipeline (cd.yml)
    ├─ Build Docker images
    ├─ Push to ECR
    ├─ Deploy to EKS (Helm)
    └─ Verify deployment
    ↓
Smoke Tests
    ├─ Check service health
    ├─ Run integration tests
    └─ Notify team
```

---

## 🔐 Secrets & Credentials

### GitHub Secrets (Required)

```
AWS_ROLE_ARN              ← IAM role for OIDC
AWS_REGION                ← eu-central-1
DOCKER_REGISTRY           ← ECR registry URL
HELM_VALUES_DEV           ← Helm values for dev environment
SLACK_WEBHOOK_URL         ← For notifications (optional)
```

### OIDC Configuration

eShop uses **GitHub OIDC** instead of long-lived AWS credentials:

```yaml
# In GitHub Actions:
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: eu-central-1
```

**Benefits:**
✅ No credential rotation needed  
✅ Short-lived tokens (15 minutes)  
✅ Better security posture  
✅ Audit trail in AWS CloudTrail  

Setup: [AWS IAM OIDC Provider](infrastructure/AWS_SETUP.md#github-actions-oidc)

---

## 📦 Container Registry (ECR)

All Docker images are pushed to **Amazon ECR** (Elastic Container Registry):

### Image Naming Convention

```
{AWS_ACCOUNT}.dkr.ecr.eu-central-1.amazonaws.com/{service-name}:{git-sha}
```

**Examples:**
```
123456789.dkr.ecr.eu-central-1.amazonaws.com/basket-api:abc1234
123456789.dkr.ecr.eu-central-1.amazonaws.com/catalog-api:def5678
```

### Image Cleanup

Old images are automatically cleaned up based on policy:
- **Keep latest 10 images** per service
- **Delete untagged images** older than 7 days

---

## 🚀 Deployment Process

### Step 1: Code Merge
```bash
# Create feature branch
git checkout -b feature/my-feature
git push origin feature/my-feature

# Create PR, get approval
# Merge to develop
```

### Step 2: Automatic Deployment (CD Workflow)
```
1. Trigger: Code merged to develop
2. Actions:
   - Checkout code
   - Build Docker images
   - Push to ECR
   - Deploy via Helm to EKS
3. Notifications: Slack, GitHub status
```

### Step 3: Verify Deployment
```bash
# Check rollout status
kubectl rollout status deployment/basket-api -n default

# Check pod logs
kubectl logs -f deployment/basket-api

# Run health checks
curl http://basket-api/health
```

---

## 🧪 Testing Strategy

### Unit Tests
```bash
cd codebase
dotnet test
```

### Integration Tests
```bash
# Runs after deployment
dotnet test --filter Category=Integration
```

### End-to-End Tests (E2E)
```bash
# Playwright tests in CI
cd codebase/e2e
npx playwright test
```

**Test Results:**
- Logs uploaded to GitHub Artifacts
- Coverage reports in pull requests
- Failures block deployment to main

---

## 📊 Monitoring Deployments

### Deployment Status

After deployment, monitor:

```bash
# Watch rollout
kubectl rollout status deployment/basket-api

# Check logs
kubectl logs -f deployment/basket-api

# View events
kubectl describe deployment basket-api
```

### Metrics Dashboard

Access Grafana during/after deployment:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# http://localhost:3000 (admin/PASSWORD)
```

Monitor key metrics:
- ✅ Pod restart count (should be 0)
- ✅ Request latency (p99 < 200ms)
- ✅ Error rate (< 0.1%)
- ✅ CPU/Memory usage (normal levels)

---

## 🔧 Common Tasks

### Trigger a Deployment Manually

```bash
# Via GitHub CLI
gh workflow run cd.yml -f environment=dev

# Or via GitHub UI:
# Actions → CD Workflow → Run workflow
```

### View Workflow Logs

```bash
# Show recent runs
gh run list --workflow=ci.yml

# View specific run logs
gh run view RUN_ID --log
```

### Rollback to Previous Version

```bash
# Find previous deployment
kubectl rollout history deployment/basket-api

# Rollback
kubectl rollout undo deployment/basket-api
```

### Disable Auto-Deployment

```bash
# Edit .github/workflows/cd.yml
# Comment out the 'on.push.branches' trigger
```

---

## 🚨 Troubleshooting

### Build Fails

**Check:**
```bash
cd codebase
dotnet build
dotnet test
```

**Common causes:**
- .NET version mismatch → Check `global.json`
- Missing NuGet packages → Run `dotnet restore`
- Failing tests → Check test logs in GitHub

### Deployment Fails

**Check:**
```bash
kubectl get pods -n default
kubectl logs POD_NAME
kubectl describe pod POD_NAME
```

**Common causes:**
- Image not found in ECR → Check push logs
- Secret not mounted → Check ENVIRONMENTS_AND_SECRETS.md
- Resource limits exceeded → Check pod requests/limits

### E2E Tests Fail

**Check:**
```bash
cd codebase/e2e
npx playwright test --debug
```

**Common causes:**
- Page load timeout → Check service health
- Element not found → Check page selectors
- Network issues → Check security groups

---

## 📈 Performance

### Build Time Targets

| Stage | Target | Current |
|-------|--------|---------|
| Build | < 5 min | ~4 min |
| Tests | < 5 min | ~3 min |
| Push to ECR | < 2 min | ~1 min |
| Helm Deploy | < 3 min | ~2 min |
| **Total** | **< 15 min** | **~10 min** |

### Optimization Tips

1. **Cache NuGet packages** (already configured)
2. **Parallel test execution** (enabled)
3. **Multi-stage Docker builds** (enabled)
4. **ECR image layer caching** (enabled)

---

## 🔒 Security Best Practices

✅ **Do:**
- Use OIDC for AWS authentication
- Rotate GitHub tokens regularly
- Keep secrets in GitHub Secrets, not code
- Review PRs before merge
- Sign commits with GPG (recommended)

❌ **Don't:**
- Hardcode credentials in workflows
- Commit .env files
- Store passwords in git history
- Disable branch protection on main

---

## 📚 Related Documentation

- [GitHub Workflows Details](../.github/workflows/README.md)
- [Deployment Guide](deployment/KUBERNETES_DEPLOYMENT.md)
- [Infrastructure Setup](infrastructure/TERRAFORM_GUIDE.md)
- [Environment Configuration](deployment/ENVIRONMENTS_AND_SECRETS.md)

---

**See also:** [Architecture](ARCHITECTURE.md) | [Index](INDEX.md)

**Last updated:** December 2025
