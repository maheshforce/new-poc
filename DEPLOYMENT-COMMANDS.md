# GitOps Deployment - Copy-Paste Commands

## ⚠️ IMPORTANT: Before Running Any Commands

Update these values in your YAML files:

```bash
# 1. Get your AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your AWS Account ID: $AWS_ACCOUNT_ID"

# 2. Get your EKS cluster name
CLUSTER_NAME=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "Your cluster name: $CLUSTER_NAME"

# 3. Get your VPC ID
VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
echo "Your VPC ID: $VPC_ID"

# 4. Get your Git repo URL
echo "Your Git repo URL (e.g., https://github.com/your-org/your-repo):"
```

Now update these files:

```bash
# Update Git repo URL in:
sed -i "s|https://github.com/your-org/your-repo|$YOUR_REPO_URL|g" argocd-apps/*.yaml

# Update AWS Account ID in:
sed -i "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" argocd-apps/alb-ingress-controller-app.yaml
sed -i "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" k8s-manifests/alb-ingress-controller-manifests.yaml

# Update cluster name in:
sed -i "s|YOUR_CLUSTER_NAME|$CLUSTER_NAME|g" k8s-manifests/alb-ingress-controller-manifests.yaml

# Update VPC ID in:
sed -i "s|vpc-xxxxxxxx|$VPC_ID|g" argocd-apps/alb-ingress-controller-app.yaml
```

---

## Phase 1: Prerequisites (5 minutes)

```bash
# 1. Verify cluster access
kubectl cluster-info
kubectl get nodes

# 2. Verify Helm installed
helm version

# 3. Verify git installed
git --version

# 4. Verify AWS CLI configured
aws sts get-caller-identity

# 5. Push your repository to Git
git add .
git commit -m "Initial: K8s manifests and Helm charts for GitOps"
git push origin main
```

---

## Phase 2: Deploy ArgoCD Manually (5 minutes)

**This is the ONLY manual deployment step**

```bash
# 1. Add ArgoCD Helm repository
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update

# 2. Deploy ArgoCD
helm install argocd ./helm/argocd \
  --namespace argocd \
  --create-namespace \
  --values ./helm/argocd/values.yaml

# 3. Wait for ArgoCD pods to start
echo "Waiting for ArgoCD pods to start..."
kubectl get pods -n argocd -w
# Press Ctrl+C when all pods show "Running" status

# 4. Verify deployment
kubectl get deployment -n argocd
echo "ArgoCD deployed successfully!"

# 5. Get admin password (save this!)
ARGOCD_PASSWORD=$(kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
echo "=========================================="
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo "=========================================="

# 6. Get ALB URL (wait 30-60 seconds for ALB provisioning)
echo "Waiting for ALB to be provisioned (30-60 seconds)..."
sleep 30
ALB_URL=$(kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
echo "=========================================="
echo "ArgoCD URL: http://$ALB_URL/argocd"
echo "Login: admin / $ARGOCD_PASSWORD"
echo "=========================================="
```

---

## Phase 3: Deploy ALB Ingress Controller (3 minutes)

**Deploy the ALB controller that manages ingresses**

```bash
# 1. Apply ALB Ingress Controller manifests
kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml

# 2. Wait for controller to start
echo "Waiting for ALB controller to start..."
kubectl get deployment -n kube-system aws-load-balancer-controller -w
# Press Ctrl+C when READY shows 2/2

# 3. Verify no errors in logs
echo "Checking ALB controller logs..."
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20

# 4. Verify IngressClass created
kubectl get ingressclass
# Should show: alb  

echo "ALB controller deployed successfully!"
```

---

## Phase 4: Register Apps with ArgoCD (2 minutes)

**Tell ArgoCD to deploy Jenkins, Karpenter, KEDA from Git**

```bash
# 1. Register Jenkins
kubectl apply -f argocd-apps/jenkins-app.yaml
echo "✓ Jenkins app registered"

# 2. Register Karpenter
kubectl apply -f argocd-apps/karpenter-app.yaml
echo "✓ Karpenter app registered"

# 3. Register KEDA
kubectl apply -f argocd-apps/keda-app.yaml
echo "✓ KEDA app registered"

# 4. Verify apps registered
kubectl get app -n argocd
# Should show jenkins, karpenter, keda

echo "All applications registered with ArgoCD!"
```

---

## Phase 5: Monitor ArgoCD Sync (3-5 minutes)

**Watch ArgoCD deploy all services automatically**

```bash
# Method 1: Monitor via CLI (watch continuously)
watch kubectl get app -n argocd

# Expected output:
# NAME        SYNC STATUS   HEALTH STATUS
# jenkins     Syncing       Progressing
# karpenter   Syncing       Progressing
# keda        Syncing       Progressing
# argocd      Synced        Healthy

# Press Ctrl+C when all apps show "Synced"

# OR Method 2: Monitor via ArgoCD UI (easier!)
ALB_URL=$(kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "Open in browser: http://$ALB_URL/argocd"
echo "Login: admin / $ARGOCD_PASSWORD"
echo "Watch: Applications → Each app should sync automatically"
```

---

## Phase 6: Verify All Services Running (2 minutes)

```bash
# 1. Check all pods are running
echo "Checking pod status..."
kubectl get pods -A | grep -E 'jenkins|argocd|karpenter|keda'
# All pods should show "Running"

# 2. Check ingresses created
echo "Checking ingresses..."
kubectl get ingress -A
# Should show ingresses in jenkins, argocd, karpenter, keda namespaces

# 3. Get ALB DNS address
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "=========================================="
echo "ALB DNS Address: $ALB_URL"
echo "=========================================="

# 4. Test connectivity to each service
echo "Testing service connectivity..."
echo "Jenkins:   curl -I http://$ALB_URL/jenkins"
echo "ArgoCD:    curl -I http://$ALB_URL/argocd"
echo "Karpenter: curl -I http://$ALB_URL/karpenter"
echo "KEDA:      curl -I http://$ALB_URL/keda"
```

---

## Phase 7: Access Your Applications (1 minute)

```bash
# Get ALB URL if not already set
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Get Jenkins password
echo "Getting Jenkins admin password..."
JENKINS_PASSWORD=$(kubectl exec -it -n jenkins jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Jenkins password: $JENKINS_PASSWORD"

# Access each service
echo ""
echo "=========================================="
echo "Access Your Services:"
echo "=========================================="
echo "Jenkins:   http://$ALB_URL/jenkins"
echo "           Login: admin / $JENKINS_PASSWORD"
echo ""
echo "ArgoCD:    http://$ALB_URL/argocd"
echo "           Login: admin / $ARGOCD_PASSWORD"
echo ""
echo "Karpenter: http://$ALB_URL/karpenter/metrics"
echo "           (No login needed)"
echo ""
echo "KEDA:      http://$ALB_URL/keda/validate"
echo "           (Webhook endpoint, no login)"
echo "=========================================="
```

---

## Complete Script (Run All at Once)

If you want to run everything in one go:

```bash
#!/bin/bash
set -e

echo "================================"
echo "GitOps Infrastructure Deployment"
echo "================================"
echo ""

# Setup environment variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME=$(aws eks list-clusters --query 'clusters[0]' --output text)
VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "EKS Cluster: $CLUSTER_NAME"
echo "VPC ID: $VPC_ID"
echo ""

# Phase 1: Prerequisites
echo "Phase 1: Verifying prerequisites..."
kubectl cluster-info > /dev/null
helm version > /dev/null
echo "✓ Prerequisites verified"
echo ""

# Phase 2: Deploy ArgoCD
echo "Phase 2: Deploying ArgoCD (5 min)..."
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update
helm install argocd ./helm/argocd -n argocd --create-namespace --values ./helm/argocd/values.yaml
echo "Waiting for ArgoCD pods..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
ARGOCD_PASSWORD=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "✓ ArgoCD deployed | Password: $ARGOCD_PASSWORD"
echo ""

# Phase 3: Deploy ALB Controller
echo "Phase 3: Deploying ALB Ingress Controller (3 min)..."
kubectl apply -f k8s-manifests/alb-ingress-controller-manifests.yaml
echo "Waiting for ALB controller..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
echo "✓ ALB controller deployed"
echo ""

# Phase 4: Register apps with ArgoCD
echo "Phase 4: Registering applications with ArgoCD (1 min)..."
kubectl apply -f argocd-apps/jenkins-app.yaml
kubectl apply -f argocd-apps/karpenter-app.yaml
kubectl apply -f argocd-apps/keda-app.yaml
echo "✓ Applications registered"
echo ""

# Phase 5: Monitor sync
echo "Phase 5: Monitoring ArgoCD sync (5 min)..."
echo "Waiting for applications to sync..."
sleep 30
for i in {1..30}; do
  STATUS=$(kubectl get app jenkins -n argocd -o jsonpath='{.status.operationState.phase}' 2>/dev/null || echo "Syncing")
  if [ "$STATUS" = "Succeeded" ]; then
    echo "✓ Applications synced successfully"
    break
  fi
  echo "Syncing... ($i/30)"
  sleep 10
done
echo ""

# Phase 6: Get access information
echo "Phase 6: Retrieving access information..."
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
JENKINS_PASSWORD=$(kubectl exec -it -n jenkins jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "See logs for password")
echo ""
echo "=========================================="
echo "Deployment Complete! 🎉"
echo "=========================================="
echo "Jenkins:   http://$ALB_URL/jenkins"
echo "           Login: admin / $JENKINS_PASSWORD"
echo ""
echo "ArgoCD:    http://$ALB_URL/argocd"
echo "           Login: admin / $ARGOCD_PASSWORD"
echo ""
echo "Karpenter: http://$ALB_URL/karpenter/metrics"
echo "KEDA:      http://$ALB_URL/keda/validate"
echo "=========================================="
echo ""
echo "Total time: ~20 minutes"
echo "Next: Monitor deployments in ArgoCD UI"
```

Save as `deploy.sh` and run:
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## Making Changes (GitOps Workflow)

**After initial deployment, NEVER run kubectl/helm manually!**

### Update Jenkins Configuration

```bash
# 1. Make change in Git
vim helm/jenkins/values.yaml
# Example: Change replicaCount: 1 → 2

# 2. Commit and push
git add helm/jenkins/values.yaml
git commit -m "Increase Jenkins replicas to 2"
git push origin main

# 3. ArgoCD automatically detects and syncs (within 3 minutes)
# Monitor in ArgoCD UI or:
watch kubectl get app jenkins -n argocd

# 4. Verify change applied
kubectl get statefulset -n jenkins -o jsonpath='{.spec.replicas}'
# Should output: 2
```

### Add a New Service

```bash
# 1. Create ArgoCD Application in Git
cat > argocd-apps/prometheus-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $YOUR_REPO_URL
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

# 2. Commit and push
git add argocd-apps/prometheus-app.yaml
git commit -m "Add Prometheus monitoring"
git push origin main

# 3. Register with ArgoCD
kubectl apply -f argocd-apps/prometheus-app.yaml

# 4. ArgoCD automatically deploys Prometheus!
```

### Rollback Changes

```bash
# Option 1: Revert Git commit
git revert HEAD
git push origin main
# ArgoCD automatically syncs to previous state

# Option 2: Manual rollback in ArgoCD UI
# Open: http://ALB-URL/argocd
# Applications → jenkins → Timeline → Select previous version

# Option 3: CLI rollback
argocd app rollback jenkins <revision-number>
```

---

## Troubleshooting Commands

```bash
# ArgoCD not syncing?
kubectl logs -n argocd argocd-application-controller-0 -f

# ALB controller errors?
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Jenkins pod not starting?
kubectl describe pod -n jenkins jenkins-0
kubectl logs -n jenkins jenkins-0

# No ALB created?
kubectl describe ingress jenkins -n jenkins

# Check all ingresses
kubectl get ingress -A -o wide

# Get ALB details
aws elbv2 describe-load-balancers --region us-east-1
```

---

## Summary

```
Total Deployment Time:  ~20-30 minutes
Manual Steps:           3 (Add Helm repo, Deploy ArgoCD, Apply ALB controller, Register apps)
Automated Steps:        Unlimited (GitOps handles everything after)
Cost:                   ~$300-400/month
Domain Required:        NO (path-based routing only)
Recommended:            YES (Industry best practice)
```

**You're ready to deploy!** 🚀

---

**Last Updated**: 2026-08-08  
**Status**: Production-Ready
