# Path-Based ALB Ingress Routing Guide

## Overview

Since you don't have a domain, we use **path-based routing** instead of host-based routing. All services are accessible through a single ALB URL with different paths:

```
ALB-URL/jenkins    → Jenkins UI
ALB-URL/argocd     → ArgoCD UI
ALB-URL/karpenter  → Karpenter API
ALB-URL/keda       → KEDA Operator
```

## Architecture

```
┌─────────────────────────────────────────────┐
│     AWS ALB (Single, Internet-facing)       │
│    Listens on port 80 (or 443 with TLS)    │
└─────────────────┬──────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
  /jenkins      /argocd      /karpenter  /keda
    │             │             │           │
    ▼             ▼             ▼           ▼
┌────────┐  ┌──────────┐  ┌──────────┐  ┌──────┐
│Jenkins │  │ ArgoCD   │  │Karpenter │  │ KEDA │
│ :8080  │  │ :8080    │  │ :8080    │  │:6443 │
└────────┘  └──────────┘  └──────────┘  └──────┘
```

## Deployment Steps

### Step 1: Deploy ALB Ingress Controller

```bash
helm install aws-alb-ingress-controller ./helm/aws-alb-ingress-controller \
  -n kube-system --create-namespace \
  --set aws.region=us-east-1
```

### Step 2: Deploy All Applications with Path-Based Ingress

```bash
# Deploy Jenkins with /jenkins path
helm install jenkins ./helm/jenkins -n jenkins --create-namespace

# Deploy ArgoCD with /argocd path
helm install argocd ./helm/argocd -n argocd --create-namespace

# Deploy Karpenter with /karpenter path
helm install karpenter ./helm/karpenter -n karpenter --create-namespace

# Deploy KEDA with /keda path
helm install keda ./helm/keda -n keda --create-namespace
```

### Step 3: Verify Ingresses Created

```bash
kubectl get ingress --all-namespaces

# Output should show:
# NAMESPACE   NAME       CLASS   HOSTS   ADDRESS                                  PORTS   AGE
# jenkins     jenkins    alb     *       k8s-jenkins-jenkins-1234.us-east-1.elb   80      2m
# argocd      argocd     alb     *       k8s-argocd-argocd-5678.us-east-1.elb     80      2m
# karpenter   karpenter  alb     *       k8s-karpenter-karpenter-9012.us-east-1.elb 80    2m
# keda        keda       alb     *       k8s-keda-keda-3456.us-east-1.elb          80      2m
```

### Step 4: Consolidate to Single ALB (Optional)

For cost optimization, you can use a single ALB with path-based routing:

```bash
# Apply consolidated ingress
kubectl apply -f consolidated-ingress-pathbased.yaml

# This creates a single ALB that routes:
# - /jenkins → Jenkins service
# - /argocd → ArgoCD service
# - /karpenter → Karpenter service
# - /keda → KEDA service
```

### Step 5: Access Applications

```bash
# Get ALB DNS name
ALB_URL=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "ALB URL: $ALB_URL"

# Access services:
curl http://$ALB_URL/jenkins
curl http://$ALB_URL/argocd
curl http://$ALB_URL/karpenter
curl http://$ALB_URL/keda
```

## Configuration Details

### Path-Based Routing Annotations

Each Helm chart uses these ALB annotations:

```yaml
ingress:
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/backend-protocol: HTTP
  # Path prefix for this ingress
  pathPrefix: /service-name
```

### Service-Specific Configuration

**Jenkins**: Path `/jenkins`
- Port: 80 (maps to 8080)
- Health check: `/`
- Type: Internet-facing

**ArgoCD**: Path `/argocd`
- Port: 80 (maps to 8080)
- Health check: `/`
- Type: Internet-facing

**Karpenter**: Path `/karpenter`
- Port: 8080
- Health check: `/healthz`
- Type: Internet-facing

**KEDA**: Path `/keda`
- Port: 80 (maps to 6443)
- Health check: `/healthz`
- Type: Internet-facing

## Ingress Resources

Each service has its own Ingress resource:

```bash
# Check ingress for Jenkins
kubectl get ingress -n jenkins jenkins -o yaml

# Check ingress for ArgoCD
kubectl get ingress -n argocd argocd -o yaml

# Check ingress for Karpenter
kubectl get ingress -n karpenter karpenter -o yaml

# Check ingress for KEDA
kubectl get ingress -n keda keda -o yaml
```

## Accessing Web UIs

### Jenkins
```bash
# Open in browser
http://ALB-URL/jenkins

# Or with port-forward
kubectl port-forward -n jenkins svc/jenkins 8080:80

# Access at http://localhost:8080
```

### ArgoCD
```bash
# Open in browser
http://ALB-URL/argocd

# Or with port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:80

# Get initial password
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

### Karpenter
```bash
# Metrics endpoint
curl http://ALB-URL/karpenter/metrics

# Or with port-forward
kubectl port-forward -n karpenter svc/karpenter 8080:8080
curl http://localhost:8080/metrics
```

### KEDA
```bash
# Webhook endpoint
curl https://ALB-URL/keda/validate

# Or with port-forward
kubectl port-forward -n keda svc/keda-operator 6443:6443
curl https://localhost:6443/validate --insecure
```

## ALB URL Examples

### Get ALB Address
```bash
# Show all ingress addresses
kubectl get ingress -A -o wide

# Or for specific service
kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
# Output: k8s-jenkins-jenkins-1234567890.us-east-1.elb.amazonaws.com
```

### Access Examples

```bash
# Jenkins
http://k8s-jenkins-jenkins-1234567890.us-east-1.elb.amazonaws.com/jenkins

# ArgoCD
http://k8s-argocd-argocd-9876543210.us-east-1.elb.amazonaws.com/argocd

# Karpenter
http://k8s-karpenter-karpenter-5555555555.us-east-1.elb.amazonaws.com/karpenter

# KEDA
http://k8s-keda-keda-1111111111.us-east-1.elb.amazonaws.com/keda
```

## Troubleshooting

### Check Ingress Status

```bash
# View ingress details
kubectl describe ingress -n jenkins

# Check events
kubectl get events -n jenkins --sort-by='.lastTimestamp'

# View ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Path Routing Not Working

```bash
# 1. Verify service exists
kubectl get svc -n jenkins

# 2. Check pod endpoints
kubectl get endpoints -n jenkins

# 3. Test pod connectivity
kubectl exec -it pod/jenkins-0 -n jenkins -- curl localhost:8080

# 4. Check ALB target groups
aws elbv2 describe-target-groups --region us-east-1

# 5. Check target health
aws elbv2 describe-target-health --target-group-arn <arn> --region us-east-1
```

### Health Checks Failing

```bash
# 1. Verify health check path is correct
kubectl describe ingress -n jenkins | grep healthcheck-path

# 2. Test health check manually
kubectl exec -it pod/jenkins-0 -n jenkins -- curl http://localhost:8080/

# 3. Check pod logs
kubectl logs -n jenkins jenkins-0

# 4. Verify security groups allow health check traffic
aws ec2 describe-security-groups --region us-east-1
```

### ALB Not Created

```bash
# 1. Check ALB controller status
kubectl get deployment -n kube-system aws-load-balancer-controller

# 2. View controller logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# 3. Verify IAM role attached
kubectl describe sa -n kube-system aws-load-balancer-controller

# 4. Check subnets are tagged
aws ec2 describe-subnets --region us-east-1 | grep -i kubernetes
```

## Customization

### Change Path Prefixes

To use different paths, update the `pathPrefix` in values.yaml:

```yaml
# For Jenkins, use /ci instead of /jenkins
ingress:
  pathPrefix: /ci

# For ArgoCD, use /gitops instead of /argocd
ingress:
  pathPrefix: /gitops
```

### Add Additional Services

To add more services to the path-based ALB:

1. Create ingress in the application's namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /myapp
            pathType: Prefix
            backend:
              service:
                name: myapp-service
                port:
                  number: 8080
```

2. Apply the ingress:

```bash
kubectl apply -f myapp-ingress.yaml
```

## Cost Analysis

### Single ALB with Path-Based Routing
- **Fixed Cost**: $16.20/month (capacity units)
- **Variable Cost**: ~$1-5/month (LCU charges)
- **Total**: ~$20-25/month

### Multiple Host-Based ALBs
- **Fixed Cost**: $64.80/month (4 ALBs × $16.20)
- **Variable Cost**: ~$4-20/month (LCU charges)
- **Total**: ~$70-100/month

**Savings**: 70-80% reduction in ALB costs!

## Security Considerations

### Network Policies

Restrict ingress traffic to your applications:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-alb
  namespace: jenkins
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: jenkins
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

### WAF Integration

Add AWS WAF to ALB:

```yaml
annotations:
  alb.ingress.kubernetes.io/wafv2-web-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/example/xxxxx
```

### Path Validation

Add validation middleware in applications to verify incoming paths.

## Performance Tuning

### Connection Draining

```yaml
annotations:
  alb.ingress.kubernetes.io/deregistration-delay.timeout-seconds: '30'
```

### Cross-Zone Load Balancing

```yaml
annotations:
  alb.ingress.kubernetes.io/load-balancer-attributes: 'load_balancing.cross_zone.enabled=true'
```

### Idle Timeout

```yaml
annotations:
  alb.ingress.kubernetes.io/load-balancer-attributes: 'idle_timeout.connection.s=60'
```

## Monitoring

### Check ALB Metrics

```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/k8s-consolidated-apps/xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### View ALB Logs

```bash
# List ALBs
aws elbv2 describe-load-balancers --region us-east-1

# Check access logs
aws s3 ls s3://your-alb-logs-bucket/
```

## Next Steps

1. ✅ Deploy ALB Ingress Controller
2. ✅ Deploy applications with path-based routing
3. Verify all services are accessible
4. Setup monitoring and alerts
5. Configure TLS certificates (optional)
6. Setup backup and disaster recovery
7. Test failover scenarios
8. Document access procedures for team

---

**Status**: Ready for Deployment
**Last Updated**: 2026-08-08
**Recommended**: Single consolidated ALB for cost optimization
