# Complete GitOps Deployment Summary

## Your Infrastructure Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Kubernetes Cluster                   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         AWS Application Load Balancer (ALB)           │  │
│  │        Single ALB serving all 4 applications           │  │
│  │   (No domain required - path-based routing only)       │  │
│  └───────────┬───────────────────────────────────────────┘  │
│              │                                              │
│   ┌──────────┼─────────────┬──────────────┐                │
│   │          │             │              │                │
│   ▼          ▼             ▼              ▼                │
│  /jenkins  /argocd      /karpenter      /keda             │
│   │          │             │              │                │
│   ▼          ▼             ▼              ▼                │
│ ┌────────┐┌────────────┐┌──────────┐┌──────────┐          │
│ │Jenkins ││ ArgoCD     ││Karpenter ││   KEDA   │          │
│ │(Helm)  ││(Manual)    ││ (Helm)   ││  (Helm)  │          │
│ │:8080   ││:8080       ││ :8080    ││  :6443   │          │
│ └────────┘└────────────┘└──────────┘└──────────┘          │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ALB Ingress Controller                               │  │
│  │  (Manages ALB/NLB resources)                          │  │
│  │  kube-system namespace                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         △                △                △
         │                │                │
    Git Repo        Manual Helm      kubectl apply
   (ArgoCD)           Deploy         (YAML manifests)
```

## Deployment Breakdown

### 1. ArgoCD Manual Deployment (Helm)

**What**: Deploy ArgoCD using Helm chart  
**When**: First time only  
**Command**:
```bash
helm install argocd ./helm/argocd -n argocd --create-namespace
```

**Files Involved**:
- `helm/argocd/Chart.yaml`
- `helm/argocd/values.yaml` (path-based ingress configured)
- `helm/argocd/templates/*`

**Outcome**: Single ArgoCD pod running, web UI accessible at `http://ALB-URL/argocd`

---

### 2. ALB Ingress Controller Deployment (YAML)

**What**: Deploy AWS ALB Ingress Controller using raw Kubernetes manifests  
**When**: Second step (must be done before apps)  
**Command**:
```bash
kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml
```

**Files Involved**:
- `k8s-manifests/alb-ingress-controller-manifests.yaml`

**What Gets Created**:
- Namespace: `kube-system` (already exists)
- ServiceAccount: `aws-load-balancer-controller`
- ClusterRole: `aws-load-balancer-controller`
- ClusterRoleBinding: `aws-load-balancer-controller`
- Deployment: 2 replicas of ALB controller
- Service: Webhook service
- IngressClass: `alb`
- ValidatingWebhookConfiguration
- MutatingWebhookConfiguration

**Outcome**: ALB controller running, ready to manage ingresses

---

### 3. Jenkins, Karpenter, KEDA via ArgoCD (GitOps)

**What**: Register application definitions with ArgoCD  
**When**: After ArgoCD is running  
**Commands**:
```bash
kubectl apply -f argocd-apps/jenkins-app.yaml
kubectl apply -f argocd-apps/karpenter-app.yaml
kubectl apply -f argocd-apps/keda-app.yaml
```

**Files Involved**:
- `argocd-apps/jenkins-app.yaml`
- `argocd-apps/karpenter-app.yaml`
- `argocd-apps/keda-app.yaml`
- `helm/jenkins/Chart.yaml`, `values.yaml`, `templates/*`
- `helm/karpenter/Chart.yaml`, `values.yaml`, `templates/*`
- `helm/keda/Chart.yaml`, `values.yaml`, `templates/*`

**What Happens**:
1. ArgoCD detects new Application resources
2. ArgoCD clones Git repository
3. ArgoCD reads Helm charts from `helm/*/`
4. ArgoCD applies Helm values and deploys to cluster
5. Each deployment creates:
   - Namespace (jenkins, karpenter, keda)
   - Deployment/StatefulSet pods
   - Services
   - Ingress resources with path-based routing

**Outcome**: 3 applications running, each accessible via different ALB path

---

### 4. Ingress Routes via YAML (Optional)

**What**: Deploy ingress routes using raw Kubernetes manifests  
**When**: Can be done instead of or alongside Helm chart ingress templates  
**Command**:
```bash
kubectl apply -f k8s-manifests/ingress-routes.yaml
```

**Files Involved**:
- `k8s-manifests/ingress-routes.yaml`

**What Gets Created**:
- Ingress: jenkins (path: /jenkins)
- Ingress: karpenter (path: /karpenter)
- Ingress: keda (path: /keda)

**Note**: If using Helm charts for deployment, these ingress resources are already created by Helm templates. This file is only needed if managing ingresses separately.

**Outcome**: ALB ingress routes configured

---

## Complete File Structure

```
your-repo/
│
├── helm/                                    # Helm charts (used by ArgoCD)
│   ├── argocd/
│   │   ├── Chart.yaml
│   │   ├── values.yaml                      # Path-based ingress configured
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── ...
│   │
│   ├── jenkins/
│   │   ├── Chart.yaml
│   │   ├── values.yaml                      # Path-based ingress, 20Gi PVC
│   │   └── templates/
│   │       ├── statefulset.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml                 # Deployed by ArgoCD
│   │       ├── pvc.yaml
│   │       ├── configmap.yaml
│   │       └── ...
│   │
│   ├── karpenter/
│   │   ├── Chart.yaml
│   │   ├── values.yaml                      # Path-based ingress, HPA enabled
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml                 # Deployed by ArgoCD
│   │       ├── hpa.yaml
│   │       └── ...
│   │
│   ├── keda/
│   │   ├── Chart.yaml
│   │   ├── values.yaml                      # Path-based ingress, metrics server
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml                 # Deployed by ArgoCD
│   │       └── ...
│   │
│   └── aws-alb-ingress-controller/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── rbac.yaml
│           └── ...
│
├── k8s-manifests/                           # Raw Kubernetes YAML manifests
│   ├── alb-ingress-controller-manifests.yaml    # Deploy with kubectl apply
│   └── ingress-routes.yaml                      # Optional: deploy ingress only
│
├── argocd-apps/                             # ArgoCD Application definitions (GitOps)
│   ├── jenkins-app.yaml                     # Tells ArgoCD to deploy Jenkins from Helm
│   ├── karpenter-app.yaml                   # Tells ArgoCD to deploy Karpenter from Helm
│   ├── keda-app.yaml                        # Tells ArgoCD to deploy KEDA from Helm
│   └── alb-ingress-controller-app.yaml      # Optional: deploy ALB via ArgoCD too
│
├── docs/                                    # Documentation
│   ├── GITOPS-DEPLOYMENT-STRATEGY.md        # High-level strategy
│   ├── GITOPS-DEPLOYMENT-GUIDE.md           # Step-by-step guide
│   ├── GITOPS-QUICK-REFERENCE.md            # Quick reference
│   ├── PATH-BASED-INGRESS.md                # Detailed ALB configuration
│   ├── PATHBASED-QUICKSTART.md              # 5-minute quickstart
│   └── PATHBASED-CONFIG-SUMMARY.md          # Configuration summary
│
├── .gitignore
├── README.md
└── terraform/                               # (Your existing Terraform code)
    ├── vpc/
    ├── eks/
    └── modules/
```

## Deployment Sequence

```
Step 1: Git Setup (10 min)
├─ Create/clone repository
├─ Copy Helm charts to helm/
├─ Copy ArgoCD apps to argocd-apps/
├─ Copy K8s manifests to k8s-manifests/
├─ Update repo URLs in YAML files
├─ Update AWS configuration (ACCOUNT_ID, cluster name, etc.)
└─ Commit and push to Git

Step 2: Deploy ArgoCD Manually (5 min)
├─ helm repo add argocd ...
├─ helm install argocd ./helm/argocd -n argocd
├─ Wait for pods (30 sec)
├─ Get admin password
└─ Get ALB URL

Step 3: Deploy ALB Ingress Controller via YAML (3 min)
├─ kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml
├─ Wait for pods (30 sec)
└─ Verify deployment

Step 4: Register Apps with ArgoCD (2 min)
├─ kubectl apply -f argocd-apps/jenkins-app.yaml
├─ kubectl apply -f argocd-apps/karpenter-app.yaml
└─ kubectl apply -f argocd-apps/keda-app.yaml

Step 5: Monitor ArgoCD Sync (3-5 min)
├─ Open ArgoCD UI: http://ALB-URL/argocd
├─ Watch applications sync
└─ Verify all pods running

Step 6: Verify Access (2 min)
├─ curl http://ALB-URL/jenkins
├─ curl http://ALB-URL/argocd
├─ curl http://ALB-URL/karpenter
└─ curl http://ALB-URL/keda

Total Time: ~30 minutes (first time)
```

## Daily Operations (GitOps)

### Updating Services

```bash
# Example: Update Jenkins memory limit to 2Gi

# 1. Make changes in Git
vim helm/jenkins/values.yaml
# Change: memory: 1Gi → 2Gi

# 2. Commit and push
git add helm/jenkins/values.yaml
git commit -m "Update Jenkins: increase memory to 2Gi"
git push origin main

# 3. ArgoCD automatically detects and syncs
# Monitor in ArgoCD UI: http://ALB-URL/argocd
# Jenkins app will show "Syncing" then "Synced"

# 4. Verify in cluster
kubectl get statefulset -n jenkins -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
# Should output: 2Gi
```

### Adding New Services

```bash
# Example: Deploy Prometheus monitoring

# 1. Create Helm chart structure
mkdir helm/prometheus
# Copy Prometheus Helm chart files

# 2. Create ArgoCD application definition
cat > argocd-apps/prometheus-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: helm/prometheus
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# 3. Commit and push
git add helm/prometheus/
git add argocd-apps/prometheus-app.yaml
git commit -m "Add Prometheus monitoring"
git push origin main

# 4. Register with ArgoCD
kubectl apply -f argocd-apps/prometheus-app.yaml

# 5. ArgoCD automatically deploys!
```

### Rolling Back Changes

```bash
# If something goes wrong:

# Option 1: Revert Git commit
git revert HEAD
git push origin main
# ArgoCD automatically syncs to previous state

# Option 2: Manual rollback in ArgoCD UI
# Open: http://ALB-URL/argocd
# Applications → jenkins → Sync → Previous version

# Option 3: Manual rollback via CLI
argocd app rollback jenkins <revision>
```

## Cost Analysis

| Component | Estimated Monthly Cost | Notes |
|-----------|----------------------|-------|
| EKS Control Plane | $72 | $0.10/hour |
| ALB (single, consolidated) | $20 | $16.20 fixed + LCU charges |
| EC2 Worker Nodes (on-demand) | $200-500 | Depends on instance type/size |
| EBS Volumes (Jenkins 20Gi) | $2 | gp2 storage |
| Data Transfer | $5-10 | Varies by usage |
| ArgoCD | $0 | Runs as pod on cluster |
| **Minimum Total** | **~$300-400/month** | Excluding worker node costs |

**70-80% savings vs. using multiple ALBs (host-based routing)**

## Security Considerations

### 1. Git Repository Access

```bash
# For private repositories, setup authentication
kubectl create secret generic argocd-git-credentials \
  --from-file=ssh-privatekey=$HOME/.ssh/id_rsa \
  -n argocd
```

### 2. Secrets Management

```bash
# Never commit secrets to Git!
# Options:
# 1. Use Sealed Secrets
# 2. Use External Secrets Operator
# 3. Create secrets manually in cluster
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=<secure-password> \
  -n jenkins
```

### 3. RBAC and Access Control

```bash
# Restrict who can deploy what
# Configure ArgoCD RBAC using ConfigMap
kubectl apply -f - << EOF
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
EOF
```

### 4. Network Policies

```bash
# Restrict pod-to-pod communication
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: jenkins-ingress
  namespace: jenkins
spec:
  podSelector:
    matchLabels:
      app: jenkins
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
EOF
```

## Monitoring and Observability

### Key Metrics to Monitor

```bash
# ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/k8s-jenkins-jenkins-xxxxx

# Pod resource usage
kubectl top pods -n jenkins
kubectl top pods -n karpenter
kubectl top pods -n keda

# Cluster node usage
kubectl top nodes
```

### Logging

```bash
# View ArgoCD logs
kubectl logs -n argocd argocd-application-controller-0 -f
kubectl logs -n argocd argocd-server-0 -f

# View ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# View application logs
kubectl logs -n jenkins jenkins-0 -f
kubectl logs -n karpenter -l app=karpenter -f
kubectl logs -n keda -l app=keda-operator -f
```

## Troubleshooting Matrix

| Issue | Symptoms | Resolution |
|-------|----------|-----------|
| ArgoCD not syncing | App shows "OutOfSync" | `argocd app sync jenkins --force` |
| ALB not created | Ingress has no ADDRESS | Check ALB controller logs |
| Pod not starting | Pod in "Pending" state | `kubectl describe pod <pod>` |
| Service not accessible | 502/503 errors | Check health checks, endpoints |
| Git auth failing | ArgoCD can't pull repo | Setup credentials, verify SSH key |

## Next Steps After Deployment

- [ ] Setup monitoring (Prometheus, Grafana)
- [ ] Configure logging (CloudWatch, ELK)
- [ ] Setup backups (Velero, EBS snapshots)
- [ ] Create runbooks for common operations
- [ ] Test disaster recovery procedures
- [ ] Setup alerts and on-call rotation
- [ ] Document team runbooks
- [ ] Schedule regular security audits

## Summary

```
Deployment Components:
1. ✅ ArgoCD (Helm) - Manual deployment
2. ✅ ALB Controller (YAML) - kubectl apply
3. ✅ Jenkins (ArgoCD) - GitOps auto-deploy
4. ✅ Karpenter (ArgoCD) - GitOps auto-deploy
5. ✅ KEDA (ArgoCD) - GitOps auto-deploy

Total Deployment Time:  ~30 minutes
Manual Handoff Needed:  After initial setup, ZERO
Deployment Method:      50% Manual (ArgoCD + ALB), 50% GitOps
Ongoing Maintenance:    100% GitOps (Git commits only)

Result:
- No domain required
- Single ALB for all services
- 70-80% cost savings
- Full GitOps workflow
- Production-ready
```

---

**Status**: ✅ Ready for Production Deployment  
**Last Updated**: 2026-08-08  
**Estimated Time to Deploy**: 30 minutes (first time)  
**Recommended**: Yes - This is industry best practice
