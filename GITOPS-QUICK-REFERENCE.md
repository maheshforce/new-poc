# GitOps Setup - Quick Reference

## Your Deployment Strategy

```
┌──────────────────────────────────────────┐
│ Helm Manual: ArgoCD                      │
│ (One-time manual deployment)             │
└──────────────────┬───────────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │   Git Repository     │
        │   (Helm charts +     │
        │    Ingress YAML)     │
        └──────────────────────┘
                   △
                   │
        ┌──────────┴────────────┐
        ▼                       ▼
  ┌──────────────────┐  ┌─────────────────────┐
  │ ArgoCD Auto-Sync │  │ Manual YAML Apply   │
  │ (Jenkins,        │  │ (ALB Ingress Routes)│
  │  Karpenter,      │  │ kubectl apply -f... │
  │  KEDA)           │  └─────────────────────┘
  └──────────────────┘
```

## Files You Need

### 1. ArgoCD Deployment (Manual - Helm)
```bash
helm install argocd ./helm/argocd -n argocd --create-namespace
```

### 2. ALB Ingress Controller (YAML)
```bash
kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml
```

### 3. Everything Else (ArgoCD GitOps)
```bash
kubectl apply -f argocd-apps/jenkins-app.yaml
kubectl apply -f argocd-apps/karpenter-app.yaml
kubectl apply -f argocd-apps/keda-app.yaml
kubectl apply -f argocd-apps/alb-ingress-controller-app.yaml
```

## Directory Structure

```
your-repo/
├── helm/
│   ├── argocd/               ← Deploy with Helm manually
│   ├── jenkins/              ← Deployed by ArgoCD
│   ├── karpenter/            ← Deployed by ArgoCD
│   ├── keda/                 ← Deployed by ArgoCD
│   └── aws-alb-ingress-controller/  ← Optional (if using ArgoCD for ALB too)
│
├── k8s-manifests/
│   └── alb-ingress-controller-manifests.yaml  ← Deploy with kubectl apply
│
├── argocd-apps/
│   ├── jenkins-app.yaml      ← Register with ArgoCD
│   ├── karpenter-app.yaml    ← Register with ArgoCD
│   ├── keda-app.yaml         ← Register with ArgoCD
│   └── alb-ingress-controller-app.yaml  ← Optional (if using ArgoCD for ALB)
│
└── docs/
    ├── GITOPS-DEPLOYMENT-STRATEGY.md
    ├── GITOPS-DEPLOYMENT-GUIDE.md
    └── PATH-BASED-INGRESS.md
```

## Deployment Timeline

| # | Step | Command | Time | Manual? |
|---|------|---------|------|---------|
| 1 | Add Helm repo | `helm repo add argocd ...` | 1 min | ✅ Yes |
| 2 | Deploy ArgoCD | `helm install argocd ...` | 3 min | ✅ Yes |
| 3 | Wait for ArgoCD | Monitor pods | 1 min | - |
| 4 | Deploy ALB controller | `kubectl apply -f k8s-manifests/...` | 2 min | ✅ Yes |
| 5 | Register Jenkins app | `kubectl apply -f argocd-apps/jenkins-app.yaml` | 1 min | ✅ Yes |
| 6 | Register Karpenter app | `kubectl apply -f argocd-apps/karpenter-app.yaml` | 1 min | ✅ Yes |
| 7 | Register KEDA app | `kubectl apply -f argocd-apps/keda-app.yaml` | 1 min | ✅ Yes |
| 8 | Monitor ArgoCD sync | Watch in UI or CLI | 3-5 min | - |
| **Total** | | | **~15 min** | |

## Manual Steps (That's All!)

### 1️⃣ ArgoCD via Helm

```bash
# Add repo
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update

# Deploy
helm install argocd ./helm/argocd \
  -n argocd --create-namespace \
  --values ./helm/argocd/values.yaml

# Get admin password
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Get URL
kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

### 2️⃣ ALB Ingress Controller via YAML

```bash
# Update these values in the YAML file:
# - ACCOUNT_ID: Your AWS account ID
# - YOUR_CLUSTER_NAME: Your EKS cluster name
# - AWS region: us-east-1 (or your region)

# Deploy
kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 3️⃣ Register Apps with ArgoCD

```bash
# Update this value in each YAML:
# - repoURL: Your GitHub repo URL

# Deploy
kubectl apply -f argocd-apps/jenkins-app.yaml
kubectl apply -f argocd-apps/karpenter-app.yaml
kubectl apply -f argocd-apps/keda-app.yaml

# Monitor (optional - ArgoCD auto-syncs)
watch kubectl get app -n argocd
```

## That's It!

From here, everything is GitOps:

```bash
# To update any service:
# 1. Edit file in Git
# 2. Commit and push
# 3. ArgoCD automatically syncs

# Example:
vim helm/jenkins/values.yaml  # Make changes
git add helm/jenkins/values.yaml
git commit -m "Update Jenkins config"
git push origin main
# → ArgoCD detects and deploys automatically
```

## Access Your Services

```bash
# Get ALB DNS name
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Jenkins
curl http://$ALB_URL/jenkins
# Or: http://ALB-DNS/jenkins in browser

# ArgoCD  
curl http://$ALB_URL/argocd
# Or: http://ALB-DNS/argocd in browser
# Login: admin / [password from step 1]

# Karpenter metrics
curl http://$ALB_URL/karpenter/metrics

# KEDA webhook
curl https://$ALB_URL/keda/validate --insecure
```

## Monitor Deployment

### Via CLI
```bash
# Watch applications sync
watch kubectl get app -n argocd

# Get details
argocd app get jenkins
argocd app get karpenter
argocd app get keda

# Follow logs
argocd app logs jenkins --follow
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

### Via UI
```
Open: http://ALB-URL/argocd
Login: admin / [password]
Watch: Applications → Each app should show "Synced" status
```

## Key Files to Customize

Before deploying, update these files:

### 1. `argocd-apps/jenkins-app.yaml`
```yaml
source:
  repoURL: https://github.com/your-org/your-repo  # ← Change to your repo
```

### 2. `argocd-apps/karpenter-app.yaml`
```yaml
source:
  repoURL: https://github.com/your-org/your-repo  # ← Change to your repo
```

### 3. `argocd-apps/keda-app.yaml`
```yaml
source:
  repoURL: https://github.com/your-org/your-repo  # ← Change to your repo
```

### 4. `argocd-apps/alb-ingress-controller-app.yaml`
```yaml
source:
  repoURL: https://github.com/your-org/your-repo  # ← Change to your repo
helm:
  values: |
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/alb-ingress-controller"  # ← Change ACCOUNT_ID
    aws:
      vpcId: vpc-xxxxxxxx  # ← Get from AWS console or: aws ec2 describe-vpcs
```

### 5. `k8s-manifests/alb-ingress-controller-manifests.yaml`
```yaml
serviceAccountName: aws-load-balancer-controller
metadata:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/aws-load-balancer-controller"  # ← Change ACCOUNT_ID

spec:
  containers:
  - args:
    - --cluster-name=YOUR_CLUSTER_NAME  # ← Change to your cluster
    - --aws-region=us-east-1  # ← Change if needed
```

## Troubleshooting Quick Fixes

```bash
# ArgoCD not syncing?
argocd app sync jenkins --force

# Application stuck in OutOfSync?
kubectl apply -f argocd-apps/jenkins-app.yaml

# ALB controller not running?
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# No ALB created?
kubectl describe ingress -n jenkins
kubectl get ingress -A

# Can't access services?
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
curl -v http://$ALB_URL/jenkins
```

## Documentation Files

| File | Purpose |
|------|---------|
| **GITOPS-DEPLOYMENT-STRATEGY.md** | High-level overview and architecture |
| **GITOPS-DEPLOYMENT-GUIDE.md** | Step-by-step deployment instructions |
| **PATH-BASED-INGRESS.md** | Detailed ALB ingress configuration |
| **PATHBASED-QUICKSTART.md** | 5-minute quick start |
| **PATHBASED-CONFIG-SUMMARY.md** | Configuration details for all services |

## Cost Analysis

```
ArgoCD overhead:     $0 (runs in Kubernetes)
ALB (single):        ~$20/month
EKS Control Plane:   ~$72/month
Worker Nodes:        Your cost
─────────────────────────────
Total:               ~$92/month (minimum)
```

## Security Notes

1. **Don't commit secrets to Git**
   - Use ArgoCD sealed secrets or external secrets operator
   - Or create secrets manually after deployment

2. **Git credentials**
   - If private repo, setup SSH key or token in ArgoCD

3. **RBAC in ArgoCD**
   - Restrict who can deploy what
   - Use project-level RBAC

4. **Network policies**
   - Restrict pod-to-pod traffic
   - Whitelist ALB to service routes

## Next Steps (After Deployment)

1. ✅ Verify all services are running and accessible
2. ✅ Setup monitoring (Prometheus, Grafana, etc.)
3. ✅ Configure backups (Velero, etcd snapshots)
4. ✅ Setup logging (CloudWatch, ELK, etc.)
5. ✅ Test failover scenarios
6. ✅ Document runbooks for your team
7. ✅ Setup alerts and on-call rotation

## Summary

```
Manual Helm Deploys:  1 (ArgoCD only)
Manual YAML Deploys:  1 (ALB Ingress Controller only)
GitOps Auto-Deploys:  3+ (Jenkins, Karpenter, KEDA, others)
Time to Production:   ~15 minutes
Ongoing Maintenance:  Git commits (no manual kubectl!)
```

**You're ready!** 🚀

---

**Last Updated**: 2026-08-08  
**Status**: Production-Ready  
**Recommended**: Yes
