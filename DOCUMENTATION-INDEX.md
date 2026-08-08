# Complete GitOps Infrastructure Documentation Index

## 🎯 Start Here

**New to this setup?** Read in this order:

1. **[GITOPS-QUICK-REFERENCE.md](GITOPS-QUICK-REFERENCE.md)** ← START HERE (5 min read)
   - Overview of your deployment strategy
   - Directory structure
   - Key files to customize
   - Quick troubleshooting

2. **[DEPLOYMENT-COMMANDS.md](DEPLOYMENT-COMMANDS.md)** ← RUN THIS NEXT (30 min deployment)
   - Copy-paste commands for deployment
   - Step-by-step with explanations
   - Complete automation script included
   - Troubleshooting commands

3. **[GITOPS-DEPLOYMENT-GUIDE.md](GITOPS-DEPLOYMENT-GUIDE.md)** ← READ DURING DEPLOYMENT
   - Detailed step-by-step guide
   - What happens at each phase
   - Verification procedures
   - Common issues and fixes

4. **[PATH-BASED-INGRESS.md](PATH-BASED-INGRESS.md)** ← READ AFTER DEPLOYMENT
   - Complete ALB ingress configuration guide
   - Path-based routing explanation
   - Cost analysis and optimization
   - Advanced configuration options

---

## 📚 Complete Documentation

### Strategic Documents
| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[GITOPS-DEPLOYMENT-STRATEGY.md](GITOPS-DEPLOYMENT-STRATEGY.md)** | High-level strategy, GitOps workflow, benefits | 10 min |
| **[GITOPS-COMPLETE-SUMMARY.md](GITOPS-COMPLETE-SUMMARY.md)** | Comprehensive summary of entire infrastructure | 15 min |
| **[GITOPS-QUICK-REFERENCE.md](GITOPS-QUICK-REFERENCE.md)** | Quick facts, commands, troubleshooting | 5 min |

### Deployment Documents
| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[DEPLOYMENT-COMMANDS.md](DEPLOYMENT-COMMANDS.md)** | Copy-paste commands, automation script | 15 min |
| **[GITOPS-DEPLOYMENT-GUIDE.md](GITOPS-DEPLOYMENT-GUIDE.md)** | Step-by-step deployment guide | 20 min |
| **[PATHBASED-QUICKSTART.md](PATHBASED-QUICKSTART.md)** | 5-minute quick start deployment | 5 min |

### Configuration Documents
| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[PATH-BASED-INGRESS.md](PATH-BASED-INGRESS.md)** | Complete ALB ingress guide | 20 min |
| **[PATHBASED-CONFIG-SUMMARY.md](PATHBASED-CONFIG-SUMMARY.md)** | Configuration changes summary | 10 min |
| **[ALB-INGRESS-SETUP.md](ALB-INGRESS-SETUP.md)** | Detailed ALB setup guide | 25 min |

### Reference Documents
| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md)** | File organization and resource summary | 10 min |
| **[JENKINS-SETUP.md](JENKINS-SETUP.md)** | Jenkins configuration and plugins | 15 min |
| **[CI-CD-README.md](CI-CD-README.md)** | CI/CD pipeline workflows | 15 min |
| **[QUICKSTART.md](QUICKSTART.md)** | 45-minute full deployment walkthrough | 45 min |
| **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)** | Pre/post deployment verification | 5 min |

---

## 📁 File Structure

```
your-repo/
│
├── 📄 Documentation (Start here!)
│   ├── GITOPS-QUICK-REFERENCE.md ⭐ START HERE
│   ├── DEPLOYMENT-COMMANDS.md ⭐ DEPLOYMENT SCRIPT
│   ├── GITOPS-DEPLOYMENT-GUIDE.md
│   ├── GITOPS-DEPLOYMENT-STRATEGY.md
│   ├── GITOPS-COMPLETE-SUMMARY.md
│   ├── PATH-BASED-INGRESS.md
│   ├── PATHBASED-QUICKSTART.md
│   ├── PATHBASED-CONFIG-SUMMARY.md
│   ├── PROJECT-STRUCTURE.md
│   ├── JENKINS-SETUP.md
│   ├── CI-CD-README.md
│   ├── ALB-INGRESS-SETUP.md
│   ├── QUICKSTART.md
│   └── DEPLOYMENT-CHECKLIST.md
│
├── 🎯 Helm Charts (Used by ArgoCD)
│   ├── helm/
│   │   ├── argocd/                 ← Deploy manually with Helm
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml         [Path-based ingress configured]
│   │   │   └── templates/
│   │   │       ├── ingress.yaml
│   │   │       ├── deployment.yaml
│   │   │       └── ...
│   │   │
│   │   ├── jenkins/                ← Deployed by ArgoCD
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml         [Path-based ingress: /jenkins]
│   │   │   └── templates/
│   │   │       ├── ingress.yaml    [Uses pathPrefix]
│   │   │       └── ...
│   │   │
│   │   ├── karpenter/              ← Deployed by ArgoCD
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml         [Path-based ingress: /karpenter]
│   │   │   └── templates/
│   │   │       ├── ingress.yaml
│   │   │       └── ...
│   │   │
│   │   ├── keda/                   ← Deployed by ArgoCD
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml         [Path-based ingress: /keda]
│   │   │   └── templates/
│   │   │       ├── ingress.yaml
│   │   │       └── ...
│   │   │
│   │   └── aws-alb-ingress-controller/
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│
├── 🐳 Kubernetes Manifests (Raw YAML)
│   └── k8s-manifests/
│       ├── alb-ingress-controller-manifests.yaml  ⭐ Deploy with kubectl
│       └── ingress-routes.yaml                    [Optional]
│
├── 🤖 ArgoCD Applications (GitOps)
│   └── argocd-apps/                ⭐ Register with kubectl apply
│       ├── jenkins-app.yaml        [Helm-based deployment]
│       ├── karpenter-app.yaml      [Helm-based deployment]
│       ├── keda-app.yaml           [Helm-based deployment]
│       └── alb-ingress-controller-app.yaml  [Optional]
│
├── 🔧 Terraform (Your infrastructure)
│   ├── vpc/
│   ├── eks/
│   └── modules/
│
├── 📝 Jenkins Pipelines
│   ├── Jenkinsfile                 [Main orchestration]
│   ├── Jenkinsfile.helm            [Helm deployment]
│   ├── Jenkinsfile.terraform       [Terraform deployment]
│   └── Jenkinsfile.security        [Security scanning]
│
├── 🔐 GitHub Actions
│   └── .github/workflows/
│       ├── helm-lint.yml
│       ├── terraform-lint.yml
│       ├── terraform-apply.yml
│       ├── deploy-eks.yml
│       ├── build-images.yml
│       └── security-scan.yml
│
└── 📚 Other
    ├── consolidated-ingress-pathbased.yaml
    ├── verify-pathbased-ingress.sh
    ├── terraform.tfvars.example
    ├── .gitignore
    ├── README.md
    └── LICENSE
```

---

## 🚀 Quick Start (Copy-Paste)

### Prerequisites
```bash
# Verify setup
kubectl cluster-info
helm version
git --version
aws sts get-caller-identity
```

### Deploy in 3 Commands

```bash
# 1. Deploy ArgoCD (manual, 5 min)
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update
helm install argocd ./helm/argocd -n argocd --create-namespace

# 2. Deploy ALB Controller (kubectl, 3 min)
kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml

# 3. Deploy everything else via ArgoCD (automatic, 5-10 min)
kubectl apply -f argocd-apps/
```

**Total: ~15-20 minutes for full production setup**

---

## 🔐 Before Deployment - Update These

Must customize before running deployment:

1. **Git Repository URL**
   ```bash
   sed -i "s|https://github.com/your-org/your-repo|$YOUR_REPO|g" argocd-apps/*.yaml
   ```

2. **AWS Account ID**
   ```bash
   AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
   sed -i "s|ACCOUNT_ID|$AWS_ACCOUNT|g" argocd-apps/*.yaml k8s-manifests/*.yaml
   ```

3. **EKS Cluster Name**
   ```bash
   CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
   sed -i "s|YOUR_CLUSTER_NAME|$CLUSTER|g" k8s-manifests/*.yaml
   ```

4. **VPC ID**
   ```bash
   VPC=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
   sed -i "s|vpc-xxxxxxxx|$VPC|g" argocd-apps/*.yaml
   ```

See **[DEPLOYMENT-COMMANDS.md](DEPLOYMENT-COMMANDS.md)** for detailed instructions.

---

## 📊 What Gets Deployed

### Services
- **Jenkins** - CI/CD orchestration (StatefulSet, 20Gi PVC, Kubernetes plugin)
- **ArgoCD** - GitOps continuous deployment (Deployment, Redis)
- **Karpenter** - Kubernetes autoscaling (Deployment, HPA)
- **KEDA** - Event-driven autoscaling (Deployment, Metrics Server)

### Infrastructure
- **ALB Ingress Controller** - Manages AWS ALB resources
- **Single ALB** - All 4 services via path-based routing
- **Path-based Ingress Routes** - No domain required

### Access Patterns
```
http://ALB-URL/jenkins    → Jenkins UI
http://ALB-URL/argocd     → ArgoCD UI
http://ALB-URL/karpenter  → Karpenter metrics
http://ALB-URL/keda       → KEDA webhook
```

---

## 💰 Cost Estimate

| Component | Cost | Notes |
|-----------|------|-------|
| EKS Control Plane | $72/month | Flat rate |
| ALB (single, consolidated) | $20/month | 1 ALB instead of 4+ |
| EC2 Worker Nodes | $200-500/month | Depends on instance type |
| EBS (Jenkins 20Gi) | $2/month | gp2 storage |
| Data Transfer | $5-10/month | Typical usage |
| ArgoCD | $0 | Runs on cluster |
| **Total Minimum** | **~$300/month** | Excluding worker nodes |

**Savings**: 70-80% vs. host-based routing with multiple ALBs

---

## 🎓 GitOps Workflow

After deployment, follow this workflow for ANY infrastructure change:

```
Edit File in Git → Commit → Push → ArgoCD Detects → Auto-Deploy
```

### Example: Update Jenkins Memory

```bash
# 1. Edit Helm values
vim helm/jenkins/values.yaml
# Change: memory: 1Gi → 2Gi

# 2. Commit and push
git add helm/jenkins/values.yaml
git commit -m "Increase Jenkins memory to 2Gi"
git push origin main

# 3. ArgoCD automatically syncs (within 3 minutes)
# Monitor: kubectl get app jenkins -n argocd -w

# 4. Verify
kubectl get statefulset -n jenkins jenkins -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
# Output: 2Gi
```

---

## ✅ Post-Deployment Checklist

After deployment completes:

- [ ] All pods running: `kubectl get pods -A | grep -E 'jenkins|argocd|karpenter|keda'`
- [ ] All ingresses created: `kubectl get ingress -A`
- [ ] ALB provisioned: `aws elbv2 describe-load-balancers`
- [ ] Jenkins accessible: `curl http://ALB-URL/jenkins`
- [ ] ArgoCD accessible: `curl http://ALB-URL/argocd`
- [ ] ArgoCD apps synced: `argocd app list`
- [ ] No errors in logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

See **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)** for full checklist.

---

## 🔧 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| ArgoCD not syncing | `argocd app sync jenkins --force` |
| ALB not created | Check controller logs: `kubectl logs -n kube-system ...` |
| Pod pending | `kubectl describe pod <pod>` |
| Service unreachable | `kubectl get svc -n <namespace>` |
| Ingress no ADDRESS | Wait 60 seconds for ALB provisioning |

### Quick Fixes

```bash
# View ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# View application status
argocd app get jenkins

# Check pod events
kubectl describe pod -n jenkins jenkins-0

# Verify services
kubectl get svc -n jenkins

# Test connectivity
kubectl exec -it -n jenkins jenkins-0 -- curl localhost:8080
```

---

## 📞 Support Resources

- **[PATH-BASED-INGRESS.md](PATH-BASED-INGRESS.md)** - ALB configuration troubleshooting
- **[GITOPS-DEPLOYMENT-GUIDE.md](GITOPS-DEPLOYMENT-GUIDE.md)** - Detailed troubleshooting section
- **[DEPLOYMENT-COMMANDS.md](DEPLOYMENT-COMMANDS.md)** - Troubleshooting commands
- **[GITOPS-QUICK-REFERENCE.md](GITOPS-QUICK-REFERENCE.md)** - Quick reference table

---

## 🎯 Next Steps After Deployment

1. ✅ Verify all services accessible
2. Setup monitoring (Prometheus, Grafana, CloudWatch)
3. Configure logging (CloudWatch, ELK, Loki)
4. Setup backups (Velero for cluster, EBS snapshots)
5. Create runbooks for common operations
6. Test disaster recovery procedures
7. Setup alerts and on-call rotation
8. Document team procedures

---

## 📝 Summary

```
Infrastructure Type:   Production-ready GitOps on EKS
Deployment Strategy:   50% Manual (ArgoCD+ALB) + 50% Automated (GitOps)
Total Deployment Time: ~30 minutes
Manual Steps:          3 commands
Ongoing Maintenance:   100% GitOps (Git commits only)
Cost:                  ~$300-400/month minimum
Domain Required:       NO (path-based routing)
Recommended:           YES (Industry best practice)
```

---

## 🚀 Ready to Deploy?

1. Read: **[GITOPS-QUICK-REFERENCE.md](GITOPS-QUICK-REFERENCE.md)** (5 min)
2. Run: **[DEPLOYMENT-COMMANDS.md](DEPLOYMENT-COMMANDS.md)** (30 min)
3. Verify: **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)** (5 min)
4. Monitor: Open ArgoCD UI and watch sync

**Questions?** Check the relevant documentation file above.

---

**Last Updated**: 2026-08-08  
**Status**: ✅ Production-Ready  
**Recommended**: Yes
