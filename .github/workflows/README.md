# CI/CD Pipelines

This directory contains GitHub Actions workflows for automated testing, building, and deployment.

## Workflows Overview

### 1. helm-lint.yaml
**Triggers:** Push/PR to main/develop branches when `helm/` changes

Performs:
- Helm chart linting for all three charts
- Helm template validation
- Detects syntax errors and best practice violations

```bash
# Manual run
gh workflow run helm-lint.yaml
```

### 2. terraform-lint.yaml
**Triggers:** Push/PR to main/develop branches when `terraform/` changes

Performs:
- Terraform format checking
- Terraform validation (VPC and EKS)
- TFLint static analysis

```bash
# Manual run
gh workflow run terraform-lint.yaml
```

### 3. terraform-apply.yaml
**Triggers:** Push to main branch (applies) or PR (plans)

Performs:
- **On PR:** Creates terraform plans for VPC and EKS
- **On Main:** Applies infrastructure changes automatically
- AWS credential authentication
- Plan artifacts uploaded for review

```bash
# Manual run with inputs
gh workflow run terraform-apply.yaml -f environment=prod
```

### 4. deploy-eks.yaml
**Triggers:** Push to main branch when `helm/` changes

Performs:
- AWS EKS cluster authentication
- Creates Kubernetes namespaces
- Deploys Karpenter → KEDA → ArgoCD (in order)
- Verifies deployments and outputs service info

**Required Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `EKS_CLUSTER_NAME`

```bash
# Manual run
gh workflow run deploy-eks.yaml
```

### 5. build-images.yaml
**Triggers:** Push to main or tags starting with `v*`

Performs:
- Builds container images
- Pushes to GitHub Container Registry (ghcr.io)
- Creates semantic versioning tags

**Required Secrets:**
- `GITHUB_TOKEN` (auto-available)

```bash
# Manual run
gh workflow run build-images.yaml
```

### 6. security-scan.yaml
**Triggers:** Push/PR or scheduled weekly

Performs:
- **Helm:** Strict linting and security validation
- **Terraform:** Trivy filesystem scanning
- **Containers:** Grype vulnerability scanning
- Uploads SARIF reports to GitHub Security

```bash
# Manual run
gh workflow run security-scan.yaml
```

## Setup Instructions

### 1. Add Required Secrets

Go to **Settings → Secrets and variables → Actions** and add:

```
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
EKS_CLUSTER_NAME=<your-eks-cluster-name>
```

### 2. Verify Workflow Permissions

Go to **Settings → Actions → General** and ensure:
- "Read and write permissions" is selected
- "Allow GitHub Actions to create and approve pull requests" is enabled

### 3. Test Locally (Optional)

Install act to run workflows locally:

```bash
# Install act
brew install act  # macOS
choco install act  # Windows

# Run a workflow
act -j helm-lint
act -j terraform-lint
act -j deploy-eks --secret-file .env.local
```

## Workflow Status

View workflow runs:

```bash
# List all workflows
gh workflow list

# View specific workflow runs
gh run list --workflow=helm-lint.yaml

# Watch workflow in real-time
gh run watch <run-id>

# View workflow logs
gh run view <run-id> --log
```

## Local Development

### Before Pushing

Validate locally before triggering workflows:

```bash
# Helm validation
helm lint helm/argocd
helm lint helm/karpenter
helm lint helm/keda
helm template test helm/argocd

# Terraform validation
cd terraform/vpc && terraform validate
cd terraform/eks && terraform validate
```

## Pipeline Order

Recommended push order to avoid failures:

1. **Feature branch**: Push to `develop` → triggers `helm-lint` & `terraform-lint`
2. **Code review**: Create PR to `main` → triggers plan workflows
3. **Merge to main**: Automatically triggers `deploy-eks` + `build-images`

## Troubleshooting

### Workflow not triggering

- Check workflow is enabled in `.github/workflows/`
- Verify branch protection rules
- Ensure file paths match trigger conditions

### Deployment fails

```bash
# Check EKS cluster
aws eks describe-cluster --name <cluster-name>

# Check kubeconfig
aws eks update-kubeconfig --name <cluster-name>
kubectl get nodes

# Check pod status
kubectl get pods -n argocd -n karpenter -n keda
```

### Terraform plan conflicts

```bash
# Check current state
cd terraform/vpc && terraform show
cd terraform/eks && terraform show

# Refresh state
terraform refresh
```

## Best Practices

✅ **Do:**
- Always create PRs before merging to main
- Review terraform plans before applying
- Use workflow_dispatch for manual deployments
- Monitor workflow logs for errors
- Keep secrets in GitHub Secrets, never in code

❌ **Don't:**
- Commit terraform.tfstate files
- Hardcode credentials in workflows
- Skip security scanning
- Force push to main
- Merge without workflow approval

## Access ArgoCD Without Domain

Since no domain is configured, access ArgoCD via port-forward:

```bash
# Port-forward to local machine
kubectl port-forward -n argocd svc/argocd 8080:80

# Access via browser
# http://localhost:8080

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Monitoring

### GitHub Actions Dashboard

- Go to **Actions** tab in repository
- View workflow runs and logs
- See deployment history and status

### Cloud Watch Integration

View logs in AWS CloudWatch:

```bash
# View deployment logs
aws logs tail /aws/eks/<cluster-name> --follow

# View controller logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n karpenter deployment/karpenter
kubectl logs -n keda deployment/keda
```

## Next Steps

1. Add more deployment environments (staging, prod)
2. Implement approval requirements for prod deployments
3. Add Slack notifications for workflow status
4. Set up automatic rollbacks on deployment failure
5. Implement cost optimization workflows

## Support

For workflow issues:
- Check GitHub Actions logs
- Review workflow YAML syntax
- Verify AWS credentials and permissions
- Check Kubernetes cluster connectivity
