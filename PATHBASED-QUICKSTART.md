# Path-Based ALB Ingress - Quick Start Guide

## No Domain? No Problem! 🎯

Access all services through a single ALB using path-based routing:

```
http://ALB-URL/jenkins    → Jenkins
http://ALB-URL/argocd     → ArgoCD  
http://ALB-URL/karpenter  → Karpenter
http://ALB-URL/keda       → KEDA
```

## 5-Minute Setup

### 1. Deploy ALB Controller (1 minute)

```bash
helm install aws-alb-ingress-controller ./helm/aws-alb-ingress-controller \
  -n kube-system --create-namespace \
  --set aws.region=us-east-1
```

### 2. Deploy All Apps with Path-Based Ingress (2 minutes)

```bash
# All values.yaml files already configured for path-based routing
helm install jenkins ./helm/jenkins -n jenkins --create-namespace
helm install argocd ./helm/argocd -n argocd --create-namespace
helm install karpenter ./helm/karpenter -n karpenter --create-namespace
helm install keda ./helm/keda -n keda --create-namespace
```

### 3. Get ALB URL (1 minute)

```bash
# Wait for ALB to be created (30-60 seconds)
kubectl get ingress -A -o wide

# Get the ALB DNS name from the ADDRESS column
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "Your ALB URL: $ALB_URL"
```

### 4. Access Your Apps (1 minute)

```bash
# Open in browser or curl
curl http://$ALB_URL/jenkins
curl http://$ALB_URL/argocd
curl http://$ALB_URL/karpenter
curl http://$ALB_URL/keda
```

## How It Works

```
Single ALB with 4 Ingresses
↓
Path-based routing rules
├─ /jenkins → Jenkins service:8080
├─ /argocd → ArgoCD service:8080
├─ /karpenter → Karpenter service:8080
└─ /keda → KEDA service:6443
```

## Each Helm Chart Configuration

All values.yaml files updated with:

```yaml
ingress:
  enabled: true
  className: alb
  pathPrefix: /service-name  # Changed from host-based to path-based
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # ... other ALB config
```

## Verify Ingresses

```bash
# View all ingresses
kubectl get ingress -A

# Expected output:
# NAMESPACE   NAME       CLASS   ADDRESS                              PORTS
# argocd      argocd     alb     k8s-argocd-argocd-xxxxx.us-e...    80
# jenkins     jenkins    alb     k8s-jenkins-jenkins-xxxxx.us-e...  80
# karpenter   karpenter  alb     k8s-karpenter-karpenter-xxxxx.us-e... 80
# keda        keda       alb     k8s-keda-keda-xxxxx.us-e...         80
```

## Ingress Consolidation via IngressGroups (Cost Optimization)

Instead of a single external YAML file, the consolidation is natively handled by the **AWS ALB IngressGroups** annotation (`alb.ingress.kubernetes.io/group.name: consolidated-apps`) defined inside each application's Helm chart. 

When you deploy the Helm charts, the AWS Load Balancer Controller automatically merges their separate, segregated Ingress resources into a **single, shared Application Load Balancer**.
- **Result**: Single ALB serving all 4 paths (`/jenkins`, `/argocd`, `/karpenter`, `/keda`).
- **Cost**: ~$20/month instead of ~$70/month (70%+ savings).

## Troubleshooting

### ALB not created?

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Verify OIDC/IAM setup
kubectl describe sa -n kube-system aws-load-balancer-controller
```

### Services not accessible?

```bash
# Check ingress details
kubectl describe ingress jenkins -n jenkins

# Verify services exist
kubectl get svc -n jenkins
kubectl get svc -n argocd

# Test pod connectivity
kubectl exec -it pod/jenkins-0 -n jenkins -- curl localhost:8080
```

### Health checks failing?

```bash
# Check ingress health check path
kubectl describe ingress jenkins -n jenkins | grep healthcheck

# Test manually
kubectl exec -it pod/jenkins-0 -n jenkins -- curl http://localhost:8080/
```

## Key Files

- **PATH-BASED-INGRESS.md** - Complete guide with advanced configuration
- **helm/*/values.yaml** - Path-based ingress configuration for each app
- **helm/*/templates/ingress.yaml** - Path-based ingress templates

## Benefits

✅ **No domain required** - Works without DNS  
✅ **Single ALB** - Lower costs (~$20/month vs $70+/month)  
✅ **Easy to manage** - Single URL with multiple paths  
✅ **Path-based routing** - Standard Kubernetes feature  
✅ **Scalable** - Add more services with additional paths  

## Common Issues

| Issue | Solution |
|-------|----------|
| ALB DNS name not showing | Wait 30-60 seconds, check ALB controller logs |
| Services not responding | Verify pods running, check security groups |
| Health checks failing | Confirm health check path matches app's endpoint |
| Slow response times | Check target group health, increase timeout |

## Next Steps

1. ✅ Deploy ALB controller
2. ✅ Deploy all apps with path-based ingress
3. Access services through ALB URL
4. Setup DNS CNAME record to ALB (optional)
6. Configure TLS/SSL (optional)
7. Setup monitoring and alerts

## Support

For detailed configuration, see:
- **PATH-BASED-INGRESS.md** - Full documentation
- **ALB-INGRESS-SETUP.md** - Advanced ALB setup
- Helm values.yaml files - Service-specific config

---

**Status**: Ready to Deploy
**Deployment Time**: ~5 minutes
**Monthly Cost**: ~$20 (with consolidated ALB)
**Last Updated**: 2026-08-08
