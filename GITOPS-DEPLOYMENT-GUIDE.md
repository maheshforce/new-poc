# GitOps Deployment - Step-by-Step Guide

## Overview

This guide walks you through deploying your infrastructure using ArgoCD and YAML manifests:

1. **Manual Helm**: Deploy ArgoCD (one-time manual step)
2. **Automated YAML**: Deploy ALB Ingress Controller
3. **GitOps**: Deploy Jenkins, Karpenter, KEDA via ArgoCD (automatically synced from Git)

## Prerequisites

```bash
# 1. Verify cluster access
kubectl cluster-info
kubectl get nodes

# 2. Verify Helm installed
helm version

# 3. Verify git installed
git --version

# 4. AWS credentials configured
aws sts get-caller-identity
```

## Step 1: Prepare Git Repository

```bash
# 1. Clone or create your repo
git clone <your-repo> && cd <your-repo>

# 2. Verify directory structure
tree
# Should show:
# helm/
# ├── argocd/
# ├── jenkins/
# ├── karpenter/
# ├── keda/
# └── aws-alb-ingress-controller/
# argocd-apps/
# ├── jenkins-app.yaml
# ├── karpenter-app.yaml
# ├── keda-app.yaml
# └── alb-ingress-controller-app.yaml

# 3. Update repo URLs in argocd-apps/*.yaml
# Replace: https://github.com/your-org/your-repo
# With your actual repo URL

# 4. Update AWS configuration in alb-ingress-controller-app.yaml
# - serviceAccount.annotations.eks.amazonaws.com/role-arn: Your IAM role ARN
# - aws.vpcId: Your VPC ID

# Get your VPC ID
aws ec2 describe-vpcs --region us-east-1 --query 'Vpcs[0].VpcId' --output text

# 5. Commit changes
git add .
git commit -m "Initial: Update repository and AWS configuration"
git push origin main
```

## Step 2: Deploy ArgoCD Manually (5 minutes)

This is the ONLY manual deployment step:

```bash
# 1. Add ArgoCD Helm repository
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update

# 2. Create argocd namespace
kubectl create namespace argocd

# 3. Deploy ArgoCD with values.yaml from Helm chart
# Using the values.yaml from your repo (has path-based ingress configured)
helm install argocd ./helm/argocd \
  --namespace argocd \
  --values ./helm/argocd/values.yaml

# Alternative: If using official ArgoCD chart from Helm repo
helm install argocd argocd/argo-cd \
  --namespace argocd \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=alb \
  --set 'server.ingress.annotations.alb\.ingress\.kubernetes\.io/scheme=internet-facing' \
  --set 'server.ingress.annotations.alb\.ingress\.kubernetes\.io/target-type=ip' \
  --set 'server.ingress.annotations.alb\.ingress\.kubernetes\.io/listen-ports=\[{\"HTTP\": 80}\]'

# 4. Wait for ArgoCD pods to start (~30 seconds)
kubectl get pods -n argocd -w
# Press Ctrl+C when all pods are Running

# 5. Verify ArgoCD is running
kubectl get deployment -n argocd
# Output: argocd-application-controller, argocd-server, etc.

# 6. Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"
# Save this password somewhere safe!

# 7. Get ALB URL for ArgoCD (wait 30-60 seconds for ALB to be provisioned)
ALB_URL=$(kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
echo "ArgoCD URL: http://$ALB_URL/argocd"
# Open in browser: http://ALB-URL/argocd
```

## Step 3: Deploy ALB Ingress Controller via YAML (5 minutes)

Now deploy the ALB Ingress Controller that other services depend on:

```bash
# 1. Apply ALB Ingress Controller Helm chart via ArgoCD
kubectl apply -f argocd-apps/alb-ingress-controller-app.yaml

# 2. Monitor deployment
kubectl get app -n argocd alb-ingress-controller -w
# Or in ArgoCD UI: http://ALB-URL/argocd (Applications → alb-ingress-controller)

# 3. Wait for ALB controller to be ready (~1-2 minutes)
kubectl get deployment -n kube-system aws-load-balancer-controller

# 4. Check logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Verify successful deployment:
# - 2 replicas should be ready
# - No errors in logs
# - RBAC shows clusterrole and clusterrolebinding
```

## Step 4: Deploy Applications via ArgoCD GitOps (2 minutes)

Deploy Jenkins, Karpenter, and KEDA automatically through ArgoCD:

```bash
# 1. Register applications with ArgoCD
kubectl apply -f argocd-apps/jenkins-app.yaml
kubectl apply -f argocd-apps/karpenter-app.yaml
kubectl apply -f argocd-apps/keda-app.yaml

# 2. Verify applications registered
kubectl get app -n argocd

# Expected output:
# NAME                        SYNC STATUS   HEALTH STATUS
# jenkins                     OutOfSync     Healthy
# karpenter                   OutOfSync     Healthy
# keda                        OutOfSync     Healthy
# alb-ingress-controller      Synced        Healthy

# 3. Monitor sync progress (watch ArgoCD UI is easier)
# Open: http://ALB-URL/argocd
# Login with: admin / $ARGOCD_PASSWORD
# Watch each application sync

# 4. Alternative: Monitor via CLI
watch kubectl get app -n argocd

# 5. Check individual application status
argocd app get jenkins
argocd app get karpenter
argocd app get keda
```

## Step 5: Verify All Services Are Running

```bash
# 1. Check all pods across namespaces
kubectl get pods -A | grep -E 'jenkins|argocd|karpenter|keda'

# 2. Check ingresses (should show ALB addresses)
kubectl get ingress -A

# Expected output shows multiple ingresses with different paths:
# NAMESPACE   NAME        CLASS   HOSTS   ADDRESS                         PORTS
# jenkins     jenkins     alb     *       k8s-jenkins-jenkins-xxxx.us-e...  80
# argocd      argocd      alb     *       k8s-argocd-argocd-yyyy.us-e...    80
# karpenter   karpenter   alb     *       k8s-karpenter-karpenter-zzzz.us-e... 80
# keda        keda        alb     *       k8s-keda-keda-aaaa.us-e...        80

# 3. Get ALB DNS name (should be same for all or consolidate)
kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# 4. Test connectivity to each service
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

curl -I http://$ALB_URL/jenkins      # Should return 200/302
curl -I http://$ALB_URL/argocd       # Should return 200/302
curl -I http://$ALB_URL/karpenter    # Should return 200/404 (metrics endpoint)
curl -I http://$ALB_URL/keda         # Should return 200/404 (webhook endpoint)
```

## Step 6: Access Your Applications

### Jenkins

```bash
# Get Jenkins initial admin password
kubectl exec -it -n jenkins jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword

# Open browser
# http://ALB-URL/jenkins
# Login as: admin / [password from above]
```

### ArgoCD

```bash
# Already have credentials from Step 2
# Open browser
# http://ALB-URL/argocd
# Login as: admin / $ARGOCD_PASSWORD
```

### Karpenter

```bash
# Karpenter doesn't have a web UI, only metrics/webhook
# Access metrics endpoint
curl http://ALB-URL/karpenter/metrics

# Or port-forward for detailed metrics
kubectl port-forward -n karpenter svc/karpenter 8080:8080
# Then: curl http://localhost:8080/metrics
```

### KEDA

```bash
# KEDA doesn't have a web UI, only metrics/webhook
# Access webhook endpoint
curl https://ALB-URL/keda/validate --insecure

# Or port-forward
kubectl port-forward -n keda svc/keda-operator 6443:6443
# Then: curl https://localhost:6443/validate --insecure
```

## Step 7: Making Changes (GitOps Workflow)

From now on, NEVER run kubectl/helm manually. Always use Git:

```bash
# Example: Increase Jenkins replicas

# 1. Make changes in Git
vim helm/jenkins/values.yaml
# Change: replicaCount: 1 → 2

# 2. Commit and push
git add helm/jenkins/values.yaml
git commit -m "Increase Jenkins replicas to 2"
git push origin main

# 3. ArgoCD automatically detects and syncs (within 3 minutes)
# Monitor in UI: http://ALB-URL/argocd

# 4. Or manually trigger sync
argocd app sync jenkins

# 5. Verify Jenkins scaled
kubectl get statefulset -n jenkins
kubectl get pods -n jenkins -w
```

## Deployment Status Checklist

### Phase 1: ArgoCD Deployment ✅
- [ ] ArgoCD pods running: `kubectl get pods -n argocd`
- [ ] ArgoCD accessible: `curl http://ALB-URL/argocd`
- [ ] Admin password saved securely

### Phase 2: ALB Controller ✅
- [ ] ALB controller pods running: `kubectl get deployment -n kube-system aws-load-balancer-controller`
- [ ] No errors in logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

### Phase 3: Applications ✅
- [ ] Jenkins app shows "Synced": `argocd app get jenkins`
- [ ] Karpenter app shows "Synced": `argocd app get karpenter`
- [ ] KEDA app shows "Synced": `argocd app get keda`
- [ ] All pods running: `kubectl get pods -A`

### Phase 4: Access ✅
- [ ] Jenkins accessible: `curl http://ALB-URL/jenkins`
- [ ] ArgoCD accessible: `curl http://ALB-URL/argocd`
- [ ] Karpenter metrics: `curl http://ALB-URL/karpenter/metrics`
- [ ] KEDA webhook: `curl https://ALB-URL/keda/validate --insecure`

## Troubleshooting

### ArgoCD not syncing

```bash
# Check application status
kubectl describe app jenkins -n argocd

# Check ArgoCD logs
kubectl logs -n argocd argocd-application-controller-0 -f

# Check Git connection
kubectl logs -n argocd argocd-repo-server-0 -f
```

### Pods not starting

```bash
# Check pod events
kubectl describe pod -n jenkins jenkins-0

# Check logs
kubectl logs -n jenkins jenkins-0 --previous

# Check PVC status
kubectl get pvc -n jenkins
```

### ALB not created

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Verify IAM role attached
kubectl describe sa -n kube-system aws-load-balancer-controller

# Check ingress annotations
kubectl describe ingress -n jenkins
```

## Quick Reference Commands

```bash
# View all ArgoCD applications
argocd app list

# Sync specific application
argocd app sync jenkins

# See application details
argocd app get jenkins

# View application logs
argocd app logs jenkins --follow

# Get ArgoCD credentials
argocd login <server> --insecure

# View cluster info
argocd cluster list

# Refresh application from Git (force pull)
argocd app actions run jenkins refresh
```

## Timeline

| Phase | Time | Action |
|-------|------|--------|
| 1 | 5 min | Manual ArgoCD Helm deployment |
| 2 | 2 min | Deploy ALB controller |
| 3 | 3 min | Register apps with ArgoCD |
| 4 | 2-3 min | Wait for ALB provisioning |
| 5 | 1 min | Verify and test |
| **Total** | **~13-15 min** | Full infrastructure deployed |

## Cleanup (if needed)

```bash
# Remove all applications
kubectl delete -f argocd-apps/

# Remove ArgoCD
helm uninstall argocd -n argocd

# Remove namespaces
kubectl delete namespace jenkins karpenter keda

# Note: ALB will auto-cleanup when ingresses are deleted
```

## Security Best Practices

1. **Store credentials securely**
   ```bash
   # Never commit secrets to Git
   # Use git-secrets to prevent accidental commits
   git secrets install
   ```

2. **Enable RBAC in ArgoCD**
   ```bash
   # Restrict who can deploy what
   kubectl apply -f argocd-rbac.yaml
   ```

3. **Use branch protection in Git**
   - Require pull request reviews before merge
   - Enable status checks (require tests to pass)

4. **Enable network policies**
   ```bash
   # Restrict pod-to-pod communication
   kubectl apply -f network-policies/
   ```

## Summary

✅ Manual step: Deploy ArgoCD with Helm  
✅ Automated: Deploy ALB controller  
✅ GitOps: Deploy Jenkins, Karpenter, KEDA via ArgoCD  
✅ Time to production: ~15 minutes  
✅ Ongoing maintenance: Git commits (no manual kubectl!)  

**You're ready to deploy!** 🚀

---

**Last Updated**: 2026-08-08  
**Status**: Ready for Production  
**Estimated Deployment Time**: 15 minutes
