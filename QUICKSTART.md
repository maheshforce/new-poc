# Quick Start Guide - Deploy Jenkins & Full Stack

## Prerequisites

- AWS EKS cluster configured (or create via Terraform)
- kubectl configured to access cluster
- Helm 3.0+
- Git repository with this code

## Step 1: Deploy Infrastructure (VPC + EKS)

### Option A: Via Jenkins Pipeline (Recommended)
```bash
# Push to main branch to trigger deployment
git push origin main

# Jenkins will:
# 1. Validate Terraform
# 2. Request approval
# 3. Deploy VPC
# 4. Deploy EKS cluster
# 5. Update kubeconfig
```

### Option B: Manual Terraform Deployment
```bash
# Deploy VPC
cd terraform/vpc
terraform init
terraform plan
terraform apply

# Deploy EKS
cd ../eks
terraform init
terraform plan
terraform apply

# Update kubeconfig
aws eks update-kubeconfig --name $(cd . && terraform output -raw cluster_name)
```

## Step 2: Deploy Jenkins

```bash
# Create Jenkins namespace and deploy
helm install jenkins ./helm/jenkins -n jenkins --create-namespace

# Wait for StatefulSet to be ready
kubectl rollout status statefulset/jenkins -n jenkins

# Get initial admin password
ADMIN_PASSWORD=$(kubectl exec jenkins-0 -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Admin password: $ADMIN_PASSWORD"
```

## Step 3: Access Jenkins

```bash
# Port-forward Jenkins to localhost:8080
kubectl port-forward -n jenkins svc/jenkins 8080:80 &

# Access Jenkins
open http://localhost:8080

# Or use curl
curl http://localhost:8080
```

## Step 4: Configure Jenkins

### 1. Initial Setup
- Login with admin and password from Step 2
- Install suggested plugins (takes 5-10 minutes)
- Create admin user (optional)

### 2. Add Credentials

**AWS Credentials:**
```
Manage Jenkins → Manage Credentials → Add Credentials
- Kind: AWS Credentials
- Access Key: <your-aws-key>
- Secret Key: <your-aws-secret>
- ID: aws-credentials
```

**GitHub Credentials:**
```
- Kind: Username with password (or GitHub App)
- Username: github-username
- Password: personal-access-token
- ID: github-credentials
```

### 3. Configure Git Plugin
```
Manage Jenkins → Configure System → Git
- Git executable: git
```

### 4. Configure Kubernetes Cloud
```
Manage Jenkins → Configure System → Cloud
Should be pre-configured by JCasC
```

## Step 5: Deploy Other Applications

### Option A: Automatic (via Jenkins)
```bash
# Jenkins main pipeline deploys all:
# 1. Karpenter
# 2. KEDA
# 3. ArgoCD
```

### Option B: Manual Helm Deployment
```bash
# Create namespaces
kubectl create namespace karpenter
kubectl create namespace keda
kubectl create namespace argocd

# Deploy Karpenter
helm install karpenter ./helm/karpenter -n karpenter --wait

# Deploy KEDA
helm install keda ./helm/keda -n keda --wait

# Deploy ArgoCD
helm install argocd ./helm/argocd -n argocd --wait
```

## Step 6: Verify Everything

```bash
# Check all namespaces
kubectl get namespaces

# Check deployments
kubectl get deployments --all-namespaces

# Check pods
kubectl get pods --all-namespaces

# Check services
kubectl get services --all-namespaces

# Verify Jenkins
kubectl logs jenkins-0 -n jenkins | tail -50
```

## Step 7: Create Jenkins Jobs

### Method 1: Pipeline from SCM (Recommended)
```bash
# In Jenkins UI:
# 1. New Item → Pipeline
# 2. Name: Infrastructure
# 3. Pipeline → Pipeline script from SCM
# 4. SCM: Git
# 5. Repository URL: https://github.com/your-org/your-repo
# 6. Script path: Jenkinsfile
# 7. Save → Build Now
```

### Method 2: Manual Configuration
```bash
# In Jenkins UI:
# 1. New Item → Pipeline
# 2. Name: Helm Deployment
# 3. Pipeline → Pipeline script from SCM
# 4. SCM: Git
# 5. Repository URL: https://github.com/your-org/your-repo
# 6. Script path: Jenkinsfile.helm
# 7. Save
```

## Step 8: Test Pipeline

```bash
# Trigger manual build
curl -X POST http://localhost:8080/job/Infrastructure/build \
  -u admin:$ADMIN_PASSWORD

# Or in Jenkins UI:
# Click job → Build Now
```

## Access Applications

### Jenkins
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:80
# http://localhost:8080
```

### ArgoCD
```bash
kubectl port-forward -n argocd svc/argocd 8081:80
# http://localhost:8081

# Get ArgoCD password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Kubernetes Dashboard
```bash
# Install metrics-server first
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Port-forward to dashboard
kubectl proxy
# http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Common Commands

### View Logs
```bash
# Jenkins logs
kubectl logs -f jenkins-0 -n jenkins

# Application logs
kubectl logs -f deployment/argocd-server -n argocd
kubectl logs -f deployment/karpenter -n karpenter
kubectl logs -f deployment/keda -n keda
```

### Check Resources
```bash
# CPU/Memory usage
kubectl top nodes
kubectl top pods --all-namespaces

# PVC usage
kubectl get pvc --all-namespaces
df -h /var/jenkins_home  # Inside pod
```

### Debug Issues
```bash
# Describe pods
kubectl describe pod jenkins-0 -n jenkins

# Get events
kubectl get events -n jenkins

# Exec into pod
kubectl exec -it jenkins-0 -n jenkins -- bash
```

## Troubleshooting

### Jenkins Pod Not Starting
```bash
# Check PVC
kubectl get pvc -n jenkins

# Check events
kubectl describe statefulset jenkins -n jenkins

# Check logs
kubectl logs jenkins-0 -n jenkins

# Check resources
kubectl describe node
```

### Build Fails
```bash
# Check Jenkins logs
curl http://localhost:8080/job/Infrastructure/1/consoleText

# Check pod logs
kubectl logs -n jenkins pod/jenkins-0

# SSH into pod
kubectl exec -it jenkins-0 -n jenkins -- bash
```

### Can't Connect to AWS
```bash
# Verify credentials
kubectl get secret -n jenkins aws-credentials

# Test AWS CLI
kubectl exec -it jenkins-0 -n jenkins -- \
  aws sts get-caller-identity
```

## Optional: GitHub Webhook Setup

```bash
# 1. In GitHub repository
Settings → Webhooks → Add webhook

# 2. Payload URL
http://your-jenkins-domain/github-webhook/

# 3. Content type
application/json

# 4. Events
- Push events
- Pull request events

# 5. Save
```

## Cleanup (Danger! Deletes everything)

```bash
# Delete all Helm charts
helm uninstall jenkins -n jenkins
helm uninstall argocd -n argocd
helm uninstall keda -n keda
helm uninstall karpenter -n karpenter

# Delete namespaces
kubectl delete namespace jenkins argocd keda karpenter

# Destroy AWS infrastructure (via Terraform)
cd terraform/eks && terraform destroy
cd ../vpc && terraform destroy
```

## Next Steps

1. ✅ Deploy Jenkins
2. ✅ Configure credentials
3. Setup GitHub webhooks
4. Configure Slack notifications
5. Setup email alerts
6. Backup Jenkins configuration
7. Monitor cluster health
8. Setup cost tracking
9. Implement disaster recovery
10. Scale to production

## Support

- See **JENKINS-SETUP.md** for detailed configuration
- See **CI-CD-README.md** for pipeline documentation
- See **helm/README.md** for Helm chart details
- Check build logs in Jenkins UI for errors

## Time Estimates

- VPC + EKS deployment: 15-20 minutes
- Jenkins deployment: 5 minutes
- Jenkins initial setup: 10 minutes
- Other apps (Karpenter, KEDA, ArgoCD): 10 minutes
- **Total: ~45 minutes**

## Useful Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

---

**Status**: Ready to deploy
**Last Updated**: 2026-08-08
**Tested**: Yes
