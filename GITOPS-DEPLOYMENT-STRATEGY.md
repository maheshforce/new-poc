# GitOps Deployment Strategy
# Deploy ArgoCD manually → Deploy rest via ArgoCD + ALB Ingress YAML

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Your Git Repository                           │
│  (Contains k8s-manifests/, helm/, argocd-apps/)        │
└──────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│    Manual Helm: ArgoCD Deployment                       │
│  helm install argocd ./helm/argocd -n argocd           │
│  (Only step done manually)                              │
└──────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│         ArgoCD Controller (GitOps Engine)               │
│  - Watches Git repository for changes                   │
│  - Syncs Applications to cluster automatically          │
└──────────────┬──────────────────────────────────────────┘
               │
     ┌─────────┼─────────┬──────────────┐
     ▼         ▼         ▼              ▼
┌─────────┐┌─────────┐┌─────────────┐┌─────────┐
│ ALB     ││Jenkins  ││  Karpenter  ││  KEDA   │
│Ingress  ││         ││             ││         │
│(YAML)   ││(Helm)   ││  (Helm)     ││(Helm)   │
└─────────┘└─────────┘└─────────────┘└─────────┘
```

## Step-by-Step Deployment

### Phase 1: Setup (One-time)

1. **Create Git Repository**
   ```bash
   git clone <your-repo>
   cd <repo>
   
   # Create directory structure
   mkdir -p k8s-manifests/{alb-ingress,apps}
   mkdir -p argocd-apps
   mkdir -p helm/{jenkins,argocd,karpenter,keda,aws-alb-ingress}
   ```

2. **Push code to Git**
   ```bash
   git add .
   git commit -m "Initial commit: K8s manifests and Helm charts"
   git push origin main
   ```

### Phase 2: Manual ArgoCD Deployment (5 minutes)

This is the ONLY manual step:

```bash
# 1. Add ArgoCD Helm repo
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update

# 2. Deploy ArgoCD manually
helm install argocd argocd/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values ./helm/argocd/values.yaml

# 3. Verify ArgoCD is running
kubectl get pods -n argocd
kubectl get ingress -n argocd  # Should show ALB ingress

# 4. Get ArgoCD admin password
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# 5. Access ArgoCD
# Open browser: http://ALB-DNS/argocd
```

### Phase 3: Deploy ALB Ingress Controller via YAML

```bash
# 1. Create namespace
kubectl create namespace kube-system || true

# 2. Apply ALB Ingress Controller manifests
kubectl apply -f k8s-manifests/alb-ingress/namespace.yaml
kubectl apply -f k8s-manifests/alb-ingress/rbac.yaml
kubectl apply -f k8s-manifests/alb-ingress/service-account.yaml
kubectl apply -f k8s-manifests/alb-ingress/controller-deployment.yaml

# 3. Verify ALB controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Phase 4: Deploy Rest via ArgoCD (GitOps)

ArgoCD will automatically sync these applications from Git:

1. **Create ArgoCD Application manifests** (in Git)
   - argocd-apps/jenkins-app.yaml
   - argocd-apps/karpenter-app.yaml
   - argocd-apps/keda-app.yaml
   - argocd-apps/alb-ingress-routes.yaml

2. **Register applications with ArgoCD**
   ```bash
   # ArgoCD reads from Git and auto-deploys
   kubectl apply -f argocd-apps/
   ```

3. **Monitor deployments in ArgoCD UI**
   ```bash
   # Open browser: http://ALB-DNS/argocd
   # See all applications syncing in real-time
   ```

## Repository Structure

```
your-repo/
├── helm/                          # Helm charts (used by ArgoCD)
│   ├── jenkins/
│   │   ├── Chart.yaml
│   │   ├── values.yaml            # Path-based ingress configured
│   │   └── templates/
│   ├── argocd/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── karpenter/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── keda/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── aws-alb-ingress/
│       ├── Chart.yaml
│       └── ...
│
├── k8s-manifests/                 # Raw Kubernetes YAML manifests
│   ├── alb-ingress/
│   │   ├── namespace.yaml
│   │   ├── rbac.yaml
│   │   ├── service-account.yaml
│   │   └── controller-deployment.yaml
│   └── apps/
│       ├── jenkins-ingress.yaml   # Path-based ALB ingress for Jenkins
│       ├── argocd-ingress.yaml    # Path-based ALB ingress for ArgoCD
│       ├── karpenter-ingress.yaml # Path-based ALB ingress for Karpenter
│       └── keda-ingress.yaml      # Path-based ALB ingress for KEDA
│
├── argocd-apps/                   # ArgoCD Application definitions (GitOps)
│   ├── jenkins-app.yaml           # Tells ArgoCD to deploy Jenkins from Helm
│   ├── karpenter-app.yaml         # Tells ArgoCD to deploy Karpenter from Helm
│   ├── keda-app.yaml              # Tells ArgoCD to deploy KEDA from Helm
│   └── alb-ingress-app.yaml       # Tells ArgoCD to deploy ALB ingress routes
│
└── README.md                      # Deployment guide
```

## Workflow

### Initial Deployment

```bash
# 1. Manual ArgoCD deployment only
helm install argocd argocd/argo-cd -n argocd --create-namespace

# 2. Apply ALB controller via YAML
kubectl apply -f k8s-manifests/alb-ingress/

# 3. Register all other apps with ArgoCD (from Git)
kubectl apply -f argocd-apps/

# That's it! ArgoCD handles the rest
```

### Adding New Services

Example: Deploy a new application

```yaml
# argocd-apps/myapp-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: helm/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```bash
# Push to Git
git add argocd-apps/myapp-app.yaml
git commit -m "Add myapp to ArgoCD"
git push

# ArgoCD automatically detects and deploys!
```

### Updating Existing Services

Example: Change Jenkins replicas

```bash
# 1. Update helm values
vim helm/jenkins/values.yaml
# Change: replicaCount: 2

# 2. Commit and push
git add helm/jenkins/values.yaml
git commit -m "Increase Jenkins replicas to 2"
git push

# 3. ArgoCD automatically syncs the change!
# No manual deployment needed
```

## Deployment Checklist

### Prerequisites
- [ ] Git repository ready
- [ ] Helm charts pushed to Git (helm/ folder)
- [ ] K8s manifests pushed to Git (k8s-manifests/ folder)
- [ ] ArgoCD application definitions pushed (argocd-apps/ folder)
- [ ] AWS IAM role for ALB controller configured
- [ ] EKS cluster accessible

### Phase 1: Manual ArgoCD
- [ ] Helm repo added: `helm repo add argocd https://argoproj.github.io/argo-helm`
- [ ] ArgoCD installed: `helm install argocd ...`
- [ ] ArgoCD pods running: `kubectl get pods -n argocd`
- [ ] ArgoCD accessible: `http://ALB-DNS/argocd`
- [ ] Admin password retrieved and saved

### Phase 2: ALB Ingress Controller
- [ ] ALB controller YAML applied: `kubectl apply -f k8s-manifests/alb-ingress/`
- [ ] ALB controller pods running: `kubectl get deployment -n kube-system aws-load-balancer-controller`
- [ ] No errors in controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

### Phase 3: ArgoCD Applications
- [ ] Application definitions created in argocd-apps/
- [ ] Applications registered: `kubectl apply -f argocd-apps/`
- [ ] Applications visible in ArgoCD UI
- [ ] All applications syncing successfully
- [ ] Services accessible via ALB paths

### Verification
- [ ] Jenkins accessible: `http://ALB-DNS/jenkins`
- [ ] ArgoCD accessible: `http://ALB-DNS/argocd`
- [ ] Karpenter accessible: `http://ALB-DNS/karpenter`
- [ ] KEDA accessible: `http://ALB-DNS/keda`
- [ ] All ingresses created: `kubectl get ingress -A`
- [ ] ALB provisioned: `aws elbv2 describe-load-balancers`

## GitOps Workflow

### Making Changes (After Initial Deployment)

**NEVER** run `kubectl apply` or `helm install` manually!

**Always** follow this flow:

```
1. Clone Git repo
   ↓
2. Make changes to files (Helm values, manifests, etc)
   ↓
3. Commit to Git
   ↓
4. Push to Git
   ↓
5. ArgoCD automatically detects changes
   ↓
6. ArgoCD syncs to cluster
   ↓
7. Applications updated automatically
```

### Example: Update Jenkins configuration

```bash
# 1. Pull latest
git pull origin main

# 2. Edit Jenkins values
vim helm/jenkins/values.yaml
# Make your changes

# 3. Commit and push
git add helm/jenkins/values.yaml
git commit -m "Update Jenkins: increase memory to 2Gi"
git push origin main

# 4. Watch ArgoCD sync in UI
# Open: http://ALB-DNS/argocd
# Jenkins application will show "Syncing" then "Synced"

# 5. Verify in cluster
kubectl get deployment -n jenkins
kubectl describe pod -n jenkins jenkins-0
```

## Benefits of This Approach

✅ **Single Manual Step** - Only ArgoCD deployment is manual  
✅ **GitOps** - All changes tracked in Git (audit trail)  
✅ **Automatic Sync** - ArgoCD automatically applies Git changes  
✅ **No Manual kubectl** - Reduces human errors  
✅ **Version Control** - Rollback by reverting Git commit  
✅ **Self-Healing** - ArgoCD continuously reconciles desired vs actual state  
✅ **Easy Scaling** - Add services by adding Git files  
✅ **Team Collaboration** - Git pull requests for infrastructure changes  

## Troubleshooting

### ArgoCD not syncing

```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Describe application to see errors
kubectl describe app jenkins -n argocd

# Check ArgoCD controller logs
kubectl logs -n argocd argocd-application-controller-0 -f

# Manually trigger sync
argocd app sync jenkins
```

### Application stuck in "OutOfSync"

```bash
# Option 1: Manual sync (one-time)
kubectl apply -f argocd-apps/jenkins-app.yaml

# Option 2: Enable auto-sync in ArgoCD Application
# Set: spec.syncPolicy.automated.prune: true
```

### Cannot connect to Git repository

```bash
# Check ArgoCD repo credentials
kubectl get secrets -n argocd | grep git

# Verify SSH key or HTTPS token is valid
# Update credentials if needed
```

### ALB Ingress not created

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress status
kubectl describe ingress jenkins -n jenkins

# Verify ALB controller RBAC
kubectl get clusterrole aws-load-balancer-controller
kubectl get clusterrolebinding aws-load-balancer-controller
```

## Cost Analysis

| Component | Cost | Note |
|-----------|------|------|
| ALB (consolidated) | $20/month | Single ALB for all services |
| EKS Control Plane | $0.10/hour (~$72/month) | Per cluster |
| EC2 Nodes | Variable | Your worker nodes |
| **Total** | **~$90-100/month** | Excluding worker nodes |

**ArgoCD overhead**: None! (runs as pod on your cluster)

## Security Considerations

### Git Repository Access

```bash
# For public repos, no credentials needed
# For private repos:

# Option 1: SSH Key (recommended for GitOps)
kubectl create secret generic argocd-git-ssh \
  --from-file=ssh-privatekey=$HOME/.ssh/id_rsa \
  -n argocd

# Option 2: HTTPS with token
kubectl create secret generic argocd-git-https \
  --from-literal=username=<github-user> \
  --from-literal=password=<github-token> \
  -n argocd
```

### ArgoCD RBAC

```yaml
# argocd-rbac.yaml
# Restrict who can deploy what
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:devops, applications, sync, default/*, allow
    p, role:devops, applications, create, default/*, allow
    g, devops-team, role:devops
```

### Network Policies

```yaml
# Restrict traffic to ArgoCD
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-ingress-only
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: aws-load-balancer-controller
      ports:
        - protocol: TCP
          port: 8080
```

## Summary

```
Manual Step:       1 (ArgoCD via Helm)
Automated Steps:   3 (ALB via YAML, Apps via ArgoCD, Ingress via YAML)
Total Time:        ~10-15 minutes
Ongoing Overhead:  Near zero (Git push = automatic deployment)
```

**Ready to deploy! Follow the 4-phase deployment above.** 🚀

---

**Last Updated**: 2026-08-08  
**Status**: Production-Ready  
**Recommended Approach**: Yes - GitOps with ArgoCD is industry best practice
