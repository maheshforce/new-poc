# Jenkins & CI/CD Pipeline Documentation

## Overview

This project includes a comprehensive CI/CD infrastructure with:
- **Jenkins** - CI/CD orchestration running on Kubernetes
- **GitHub Actions** - Lightweight automation workflows
- **Jenkinsfiles** - Declarative pipeline definitions
- **Helm Charts** - Infrastructure as Code for Kubernetes

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Git Repository                          │
│  (Push → Webhook → Jenkins/GitHub Actions Trigger)         │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴──────────────┐
                ▼                            ▼
        ┌─────────────────┐        ┌─────────────────┐
        │  Jenkins        │        │ GitHub Actions  │
        │  (on EKS)       │        │ (Cloud-hosted)  │
        └────────┬────────┘        └─────────────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
  Helm       Terraform    Security
  Pipelines  Pipelines    Scans
    │            │            │
    └────────────┴────────────┘
            │
            ▼
    ┌───────────────────┐
    │  AWS EKS Cluster  │
    │ ┌──────────────┐  │
    │ │   ArgoCD     │  │
    │ │   KEDA       │  │
    │ │  Karpenter   │  │
    │ │   Jenkins    │  │
    │ └──────────────┘  │
    └───────────────────┘
```

## Files Created

### Helm Charts

1. **helm/jenkins/**
   - `Chart.yaml` - Jenkins chart metadata
   - `values.yaml` - Jenkins configuration
   - `templates/` - Kubernetes manifests
     - `statefulset.yaml` - Jenkins controller
     - `service.yaml` - Jenkins service
     - `rbac.yaml` - Service account & roles
     - `namespace.yaml` - Kubernetes namespace
     - `_helpers.tpl` - Template helpers

### Jenkinsfiles

1. **Jenkinsfile** - Main orchestration pipeline
   - Triggers on all branches
   - Coordinates all stages
   - Requires approval for main branch
   - Deploys full infrastructure stack

2. **Jenkinsfile.helm** - Helm chart pipeline
   - Triggered by `helm/` directory changes
   - Lints all Helm charts
   - Validates templates
   - Deploys to EKS on main branch

3. **Jenkinsfile.terraform** - Infrastructure pipeline
   - Triggered by `terraform/` directory changes
   - Validates Terraform syntax
   - Plans infrastructure changes
   - Applies changes with approval

4. **Jenkinsfile.security** - Security scanning
   - Scans Helm charts
   - Scans Terraform files
   - Container vulnerability scan
   - Dependency checking
   - SAST analysis

### Documentation

1. **JENKINS-SETUP.md** - Complete Jenkins setup guide
   - Installation instructions
   - Pipeline descriptions
   - Configuration guide
   - Troubleshooting tips

2. **CI-CD-README.md** - This file
   - Architecture overview
   - Quick start guide
   - Best practices

## Quick Start

### 1. Deploy Jenkins

```bash
# Create namespace and deploy
helm install jenkins ./helm/jenkins -n jenkins --create-namespace

# Wait for deployment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jenkins -n jenkins --timeout=300s
```

### 2. Access Jenkins

```bash
# Port-forward Jenkins UI
kubectl port-forward -n jenkins svc/jenkins 8080:80

# Get initial admin password
kubectl exec jenkins-0 -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Configure Credentials

```bash
# Add AWS credentials to Jenkins
# Settings → Credentials → Add AWS credentials

# Add GitHub credentials
# Settings → Credentials → Add GitHub token
```

### 4. Create Pipeline Jobs

In Jenkins UI:

1. **New Item** → Pipeline → OK
2. **Pipeline script from SCM** → Git
3. Repository URL: `https://github.com/your-org/your-repo`
4. Branch: `*/main`
5. Script path: `Jenkinsfile`
6. Save

## Pipeline Workflows

### Development Branch Flow

```
git push origin feature-branch
    ↓
Security Scan (parallel)
    ↓
Validate Terraform + Helm (parallel)
    ↓
Generate Plans
    ↓
Report Results
```

### Main Branch Flow

```
git push origin main
    ↓
Security Scan (parallel)
    ↓
Validate Terraform + Helm (parallel)
    ↓
Manual Approval Required
    ↓
Deploy Infrastructure (VPC + EKS)
    ↓
Deploy Applications (Karpenter, KEDA, ArgoCD)
    ↓
Verify & Test
    ↓
Generate Deployment Report
```

## Pipeline Stages

### Jenkinsfile (Main)

| Stage | Trigger | Action |
|-------|---------|--------|
| Checkout | All | Clone repository |
| Security Scan | All | Run security checks |
| Validate | All | Parallel validation |
| Plan | develop | Generate terraform plans |
| Approval | main | Require manual approval |
| Deploy | main | Apply infrastructure |
| Verify | main | Validate deployments |
| Report | main | Generate summary |

### Jenkinsfile.helm

| Stage | Trigger | Action |
|-------|---------|--------|
| Checkout | All | Clone repository |
| Lint | All | Helm lint validation |
| Template | All | Generate templates |
| YAML | All | Validate YAML syntax |
| Build | main | Package charts |
| Deploy | main | Deploy to EKS |
| Verify | main | Check status |

### Jenkinsfile.terraform

| Stage | Trigger | Action |
|-------|---------|--------|
| Checkout | All | Clone repository |
| Format | All | Check formatting |
| Init | All | Initialize Terraform |
| Validate | All | Validate syntax |
| Plan | All | Generate plans |
| Lint | All | TFLint analysis |
| Approval | main | Require approval |
| Apply | main | Apply changes |
| Kubeconfig | main | Update EKS access |

### Jenkinsfile.security

| Stage | Trigger | Action |
|-------|---------|--------|
| Checkout | All | Clone repository |
| Helm Scan | All | Security checks |
| Terraform Scan | All | Trivy/TFSec scan |
| Container Scan | All | Grype vulnerability scan |
| Dependencies | All | Check libraries |
| SAST | All | Code analysis |
| Report | All | Generate findings |

## Environment Variables

### Required (Jenkins Credentials)

```
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
EKS_CLUSTER_NAME=your-cluster-name
GITHUB_TOKEN=your-github-token
```

### Available (Set by Jenkins)

```
GIT_COMMIT_SHORT=abc1234
GIT_BRANCH_NAME=main
WORKSPACE=/var/jenkins_home/workspace/job
BUILD_NUMBER=42
BUILD_URL=http://jenkins:8080/job/name/42/
```

## Best Practices

### 1. Branch Strategy

```
main branch
  ↓ (pull requests)
  ↑ (merge after approval)
develop branch
  ↓ (feature branches)
feature-xyz branch
```

### 2. Commit Messages

```
[helm] Update ArgoCD chart version to 2.8.0
[terraform] Add spot instances to EKS node group
[security] Enable TLS for Jenkins
```

### 3. Pull Request Workflow

1. Create feature branch: `git checkout -b feature-name`
2. Make changes and commit
3. Push branch: `git push origin feature-name`
4. Create pull request on GitHub
5. Jenkins runs validation automatically
6. Review and merge after approval

### 4. Secrets Management

✅ **Do:**
- Store secrets in Jenkins Credentials
- Use `withCredentials()` in pipelines
- Rotate secrets regularly
- Audit credential access

❌ **Don't:**
- Commit secrets to git
- Hardcode credentials in Jenkinsfiles
- Share credentials via email
- Use production secrets in dev

### 5. Monitoring

```bash
# View build logs
kubectl logs -f jenkins-0 -n jenkins

# Monitor builds
curl http://localhost:8080/api/json

# Check agent status
kubectl get pods -n jenkins
```

## Troubleshooting

### Jenkins Pod Not Starting

```bash
# Check pod status
kubectl describe pod jenkins-0 -n jenkins

# Check logs
kubectl logs jenkins-0 -n jenkins

# Check PVC binding
kubectl get pvc -n jenkins
```

### Build Stuck/Hanging

```bash
# Check executor status
curl http://localhost:8080/queue/api/json

# Force kill a build
kubectl exec -it jenkins-0 -n jenkins -- kill -9 <pid>

# Restart Jenkins
kubectl rollout restart statefulset/jenkins -n jenkins
```

### Can't Connect to AWS

```bash
# Test AWS credentials
kubectl exec -it jenkins-0 -n jenkins -- \
  aws sts get-caller-identity

# Check IAM permissions
aws iam get-user
aws eks list-clusters
```

### Terraform State Issues

```bash
# View state
cd terraform/vpc && terraform show

# Refresh state
terraform refresh

# Fix lock
terraform force-unlock <LOCK_ID>
```

## Accessing Applications

Without a domain, use port-forward:

```bash
# Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:80

# ArgoCD
kubectl port-forward -n argocd svc/argocd 8080:80

# Metrics (if available)
kubectl port-forward -n keda svc/keda 8080:8080
```

## Pipeline Execution Examples

### Deploy new Helm chart version

```bash
git checkout -b release/v1.1.0
# Edit helm/argocd/Chart.yaml version: 1.1.0
git add helm/
git commit -m "[helm] Release ArgoCD v1.1.0"
git push origin release/v1.1.0
# Create PR → Jenkins runs validation → Merge → Auto-deploy
```

### Add new Terraform resource

```bash
git checkout -b feature/add-vpc-endpoint
# Edit terraform/vpc/main.tf
git add terraform/
git commit -m "[terraform] Add VPC endpoint for S3"
git push origin feature/add-vpc-endpoint
# Create PR → Jenkins plans changes → Review plan → Merge → Auto-apply
```

### Emergency security update

```bash
git checkout main
git pull
# Edit security configs
git commit -m "[security] Update TLS cert rotation"
git push origin main
# Jenkins automatically deploys after approval
```

## Integration Points

### GitHub Webhook

```bash
Settings → Webhooks → Add webhook
Payload URL: http://jenkins.your-domain/github-webhook/
Events: Push, Pull requests
```

### Slack Notifications

```groovy
post {
    failure {
        slackSend(color: 'danger', message: "Build failed: ${env.BUILD_URL}")
    }
    success {
        slackSend(color: 'good', message: "Build success: ${env.BUILD_URL}")
    }
}
```

### Email Notifications

```groovy
post {
    failure {
        emailext(
            subject: "Build failed: ${env.BUILD_NUMBER}",
            body: "See ${env.BUILD_URL}",
            to: "team@example.com"
        )
    }
}
```

## Next Steps

1. ✅ Deploy Jenkins
2. ✅ Configure AWS credentials
3. ✅ Setup GitHub webhooks
4. ✅ Create pipeline jobs
5. Add Slack notifications
6. Configure email alerts
7. Setup backup strategy
8. Implement approval workflows
9. Add cost monitoring
10. Setup disaster recovery

## Support Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Useful Commands

```bash
# Jenkins management
helm upgrade jenkins ./helm/jenkins -n jenkins
helm uninstall jenkins -n jenkins
kubectl restart statefulset/jenkins -n jenkins

# View resources
kubectl get all -n jenkins
kubectl describe statefulset jenkins -n jenkins
kubectl logs -f jenkins-0 -n jenkins

# Jenkins CLI
kubectl exec jenkins-0 -n jenkins -- jenkins-cli -s http://jenkins:8080 list-jobs
```

## Contact & Support

For issues or questions:
1. Check JENKINS-SETUP.md for detailed troubleshooting
2. Review build logs in Jenkins UI
3. Check Kubernetes pod logs
4. Review pipeline definitions
