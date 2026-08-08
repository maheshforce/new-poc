# Jenkins CI/CD Setup Guide

## Overview

Jenkins is deployed on Kubernetes as a StatefulSet for continuous integration and deployment of your infrastructure and applications.

## Quick Start

### 1. Install Jenkins Helm Chart

```bash
helm install jenkins ./helm/jenkins -n jenkins --create-namespace

# Or upgrade existing installation
helm upgrade --install jenkins ./helm/jenkins -n jenkins --create-namespace
```

### 2. Access Jenkins

#### Option A: Port Forward (Development)
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:80

# Access at http://localhost:8080
```

#### Option B: LoadBalancer (Production)
```bash
# Edit helm/jenkins/values.yaml and set:
# service.type: LoadBalancer

helm upgrade jenkins ./helm/jenkins -n jenkins

# Get LoadBalancer IP
kubectl get svc -n jenkins
```

### 3. Get Initial Admin Password

```bash
kubectl exec -it jenkins-0 -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword
```

## Jenkins Pipelines

Jenkins includes four main pipeline stages:

### 1. **Jenkinsfile** - Main Orchestration Pipeline

**Triggers:** All branches

**Stages:**
1. **Checkout** - Clone repository
2. **Security Scan** - Run security checks
3. **Validate Infrastructure** - Parallel validation
   - Terraform validation
   - Helm chart validation
4. **Plan Infrastructure** - Generate terraform plans (develop branch)
5. **Approval** - Manual approval required (main branch)
6. **Deploy Infrastructure** - Apply terraform changes
7. **Deploy Kubernetes Applications** - Deploy Helm charts
8. **Verify Deployments** - Check deployment status
9. **Post-Deployment Tests** - Validation checks
10. **Generate Report** - Create deployment summary

**Usage:**
```bash
# Trigger main pipeline
git push origin main

# View logs
curl http://localhost:8080/job/Infrastructure/lastBuild/consoleText
```

### 2. **Jenkinsfile.helm** - Helm Chart Pipeline

**Triggers:** Push/PR to `helm/` directory

**Stages:**
1. Checkout
2. Lint Helm Charts
3. Template Validation
4. YAML Validation
5. Build Helm Packages (main branch)
6. Deploy to EKS (main branch)
7. Verify Deployments

**Usage:**
```bash
# Modify helm charts and push
git add helm/
git commit -m "Update helm charts"
git push origin feature-branch

# Jenkins automatically runs Jenkinsfile.helm
```

### 3. **Jenkinsfile.terraform** - Terraform Pipeline

**Triggers:** Push/PR to `terraform/` directory

**Stages:**
1. Checkout
2. Format Check
3. Terraform Init (VPC)
4. Validate (VPC)
5. Plan (VPC)
6. Terraform Init (EKS)
7. Validate (EKS)
8. Plan (EKS)
9. TFLint Analysis
10. Approval (main branch only)
11. Apply (main branch only)
12. Update kubeconfig

**Usage:**
```bash
# Modify terraform and push
git add terraform/
git commit -m "Update infrastructure"
git push origin feature-branch

# Jenkins automatically runs Jenkinsfile.terraform
```

### 4. **Jenkinsfile.security** - Security Scanning Pipeline

**Triggers:** Manual trigger or branch push

**Stages:**
1. Helm Security Scan
2. Terraform Security Scan
3. Container Image Scan
4. Dependency Check
5. SAST Analysis
6. Generate Report
7. Archive Results

**Usage:**
```bash
# Manual trigger in Jenkins UI or via CLI
curl -X POST http://localhost:8080/job/Security-Scan/build \
  -u admin:$ADMIN_TOKEN
```

## Jenkins Configuration

### Pre-installed Plugins

- **kubernetes** - Kubernetes integration
- **docker** - Docker support
- **pipeline-stage-view** - Visual pipeline display
- **blueocean** - Blue Ocean UI
- **git/github/gitlab** - SCM integration
- **terraform** - Terraform support
- **aws-credentials** - AWS credential management
- **credentials-binding** - Secret injection
- **pipeline-model-definition** - Declarative pipelines
- **junit** - Test reporting
- **cobertura** - Code coverage
- **warnings-ng** - Build analysis
- **slack** - Slack notifications
- **email-ext** - Email notifications

### Pod Templates for Agents

Jenkins is configured with pod templates for different workload types:

#### Docker Pod
```groovy
node('docker') {
    container('docker') {
        sh 'docker build .'
    }
}
```

#### Helm Pod
```groovy
node('helm') {
    container('helm') {
        sh 'helm lint ./helm/argocd'
    }
}
```

#### Terraform Pod
```groovy
node('terraform') {
    container('terraform') {
        sh 'terraform validate'
    }
}
```

## Configuration as Code (CasC)

Jenkins uses Configuration as Code (JCasC) for declarative configuration:

**File:** `helm/jenkins/values.yaml` section `controller.JCasC`

### Updating Configuration

1. Edit `helm/jenkins/values.yaml`
2. Update the `controller.JCasC` section
3. Upgrade Helm chart:

```bash
helm upgrade jenkins ./helm/jenkins -n jenkins
```

### Example: Add Slack Notifications

```yaml
controller:
  JCasC:
    configScripts:
      slack: |
        unclassified:
          slackNotifier:
            teamDomain: your-workspace
            tokenCredentialId: slack-token
            botUser: true
```

## Managing Credentials

### AWS Credentials

```bash
# Create AWS secret
kubectl create secret generic aws-credentials \
  -n jenkins \
  --from-literal=AWS_ACCESS_KEY_ID=<key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret>

# Reference in Jenkinsfile
withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
    sh 'aws eks list-clusters'
}
```

### GitHub Credentials

1. Generate GitHub Personal Access Token
2. In Jenkins: Manage Jenkins → Manage Credentials → Add Credentials
3. Select "GitHub App" or "Username with password"
4. Enter credentials
5. Use in Jenkinsfile:

```groovy
withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
    sh 'gh api repos/$REPO/contents/file'
}
```

## Troubleshooting

### Jenkins Pod Won't Start

```bash
# Check pod status
kubectl describe pod jenkins-0 -n jenkins

# Check logs
kubectl logs jenkins-0 -n jenkins

# Check PVC
kubectl get pvc -n jenkins
```

### Out of Storage

```bash
# Check disk usage
kubectl exec jenkins-0 -n jenkins -- du -sh /var/jenkins_home

# Increase storage
helm upgrade jenkins ./helm/jenkins -n jenkins \
  --set persistence.size=50Gi
```

### Can't Connect to Kubernetes

```bash
# Verify service account
kubectl get serviceaccount jenkins -n jenkins
kubectl get clusterrolebinding jenkins -n jenkins

# Check API server connectivity
kubectl exec jenkins-0 -n jenkins -- \
  curl https://kubernetes.default.svc.cluster.local/api/v1/namespaces
```

### Builds Hanging

1. Check agent pods: `kubectl get pods -n jenkins`
2. Check resource limits: `kubectl describe pod -n jenkins`
3. Increase resources in `helm/jenkins/values.yaml`:

```yaml
resources:
  limits:
    cpu: 4000m      # Increase from 2000m
    memory: 4Gi     # Increase from 2Gi
```

## Best Practices

### 1. Pipeline Security
- ✅ Use credentials plugin for secrets
- ✅ Enable job DSL security
- ✅ Use pipeline approval for dangerous operations
- ❌ Don't commit secrets to repositories
- ❌ Don't use hardcoded credentials

### 2. Scalability
- Enable autoscaling for agents
- Use pod templates for different workloads
- Set appropriate resource requests/limits
- Monitor build queue and adjust accordingly

### 3. Maintenance
- Regular Jenkins upgrades: `helm upgrade jenkins`
- Plugin updates: Check for security updates monthly
- PVC backups: Backup Jenkins home directory
- Log rotation: Configured via `buildDiscarder`

### 4. Monitoring
- Set up Prometheus metrics endpoint
- Monitor build success/failure rates
- Track build duration trends
- Alert on resource usage

## Advanced Configuration

### Kubernetes Cloud Plugin

Jenkins is pre-configured with Kubernetes cloud provider:

```groovy
podTemplate(containers: [
    containerTemplate(
        name: 'docker',
        image: 'docker:latest',
        command: 'cat',
        ttyEnabled: true
    )
]) {
    node(POD_LABEL) {
        container('docker') {
            sh 'docker build .'
        }
    }
}
```

### Multi-branch Pipeline

Create jobs that automatically detect branches:

1. New Item → Multibranch Pipeline
2. Select "Git" as source
3. Enter repository URL
4. Jenkins will scan for Jenkinsfiles in all branches

### Webhook Configuration

Auto-trigger builds on GitHub push:

1. GitHub → Repository Settings → Webhooks → Add webhook
2. Payload URL: `http://jenkins.your-domain/github-webhook/`
3. Content type: `application/json`
4. Events: Push events, Pull requests

## Jenkins Persistence

Jenkins uses a StatefulSet with PersistentVolumeClaim:

```bash
# View PVC
kubectl get pvc -n jenkins

# Resize PVC
kubectl patch pvc jenkins-home-jenkins-0 -n jenkins -p \
  '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'

# Backup Jenkins home
kubectl exec jenkins-0 -n jenkins -- tar -czf - /var/jenkins_home | \
  tar -xzf - -C ./backups/
```

## Accessing Jenkins Services

### Jenkins Master
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:80
```

### Jenkins Agents (JNLP)
```bash
# Jenkins uses port 50000 for agent communication
kubectl port-forward -n jenkins svc/jenkins 50000:50000
```

## Cleanup

### Remove Jenkins

```bash
helm uninstall jenkins -n jenkins

# Remove PVC to free storage
kubectl delete pvc -n jenkins --all

# Delete namespace
kubectl delete namespace jenkins
```

## Next Steps

1. Configure GitHub webhooks for auto-triggering
2. Set up Slack notifications
3. Add SonarQube for code quality
4. Implement backup strategy
5. Set up monitoring and alerting
6. Configure OAuth for authentication
7. Add email notifications
8. Implement approval workflows for production

## Support & Documentation

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Jenkins Helm Chart](https://github.com/jenkinsci/helm-charts)
- [BlueOcean Plugin](https://plugins.jenkins.io/blueocean/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)

## Useful Commands

```bash
# Get Jenkins admin password
kubectl get secret -n jenkins jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d

# Restart Jenkins
kubectl rollout restart statefulset/jenkins -n jenkins

# View Jenkins logs
kubectl logs -f jenkins-0 -n jenkins

# Exec into Jenkins container
kubectl exec -it jenkins-0 -n jenkins -- bash

# Check plugin installation
kubectl exec jenkins-0 -n jenkins -- ls /var/jenkins_home/plugins/

# Purge old builds
kubectl exec jenkins-0 -n jenkins -- rm -rf /var/jenkins_home/jobs/*/builds/
```
