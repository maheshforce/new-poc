# ALB Ingress Configuration Examples

This directory contains example values files for deploying applications with ALB ingress.

## Quick Start

```bash
# Deploy with ALB ingress
helm install jenkins ./helm/jenkins -n jenkins --create-namespace -f jenkins-alb-values.yaml
helm install argocd ./helm/argocd -n argocd --create-namespace -f argocd-alb-values.yaml
helm install karpenter ./helm/karpenter -n karpenter --create-namespace -f karpenter-alb-values.yaml
helm install keda ./helm/keda -n keda --create-namespace -f keda-alb-values.yaml
```

## Files

- `jenkins-alb-values.yaml` - Jenkins with ALB (internet-facing)
- `argocd-alb-values.yaml` - ArgoCD with ALB (internet-facing)
- `karpenter-alb-values.yaml` - Karpenter with ALB (internal)
- `keda-alb-values.yaml` - KEDA with ALB (internal)
- `alb-controller-values.yaml` - ALB Controller deployment
- `alb-consolidated.yaml` - Single ALB for all apps

## Prerequisites

Before deploying, ensure:

1. ✅ AWS ALB Ingress Controller deployed
2. ✅ Subnets tagged for ALB discovery
3. ✅ Security groups configured
4. ✅ IAM role attached to ALB controller
5. ✅ Route53 hosted zone created (optional)
6. ✅ ACM certificate created (optional for HTTPS)

## Customization

Edit the YAML files to customize:

### 1. Domain Names
```yaml
hosts:
  - host: jenkins.your-domain.com  # Change this
```

### 2. SSL Certificates
```yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxxxx
```

### 3. Security Groups
```yaml
annotations:
  alb.ingress.kubernetes.io/security-groups: sg-12345678
```

### 4. Subnets
```yaml
annotations:
  alb.ingress.kubernetes.io/subnets: subnet-12345678,subnet-87654321
```

## Health Check Configuration

Each service has optimized health checks:

- **Jenkins**: `/` (web UI)
- **ArgoCD**: `/` (web UI)
- **Karpenter**: `/healthz` (health endpoint)
- **KEDA**: `/healthz` (health endpoint)

To customize:
```yaml
alb.ingress.kubernetes.io/healthcheck-path: /custom-path
```

## Performance Tuning

### Connection Draining (60 seconds)
```yaml
alb.ingress.kubernetes.io/deregistration-delay.timeout-seconds: '60'
```

### Cross-Zone Load Balancing
```yaml
alb.ingress.kubernetes.io/load-balancer-attributes: 'load_balancing.cross_zone.enabled=true'
```

### Idle Timeout (60 seconds)
```yaml
alb.ingress.kubernetes.io/load-balancer-attributes: 'idle_timeout.connection.s=60'
```

## Network Policies

To restrict traffic to ALB, create NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-alb
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
```

## Monitoring

### Check Ingress Status
```bash
kubectl get ingress -A -o wide
kubectl describe ingress -n jenkins
```

### View ALB Events
```bash
kubectl get events -n jenkins --sort-by='.lastTimestamp'
```

### Check ALB Controller Logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

### AWS CLI
```bash
# List ALBs
aws elbv2 describe-load-balancers --region us-east-1

# Check target groups
aws elbv2 describe-target-groups --region us-east-1

# View target health
aws elbv2 describe-target-health --target-group-arn <arn> --region us-east-1
```

## Troubleshooting

### ALB Not Created
```bash
# 1. Check ingress annotations
kubectl get ingress -n jenkins -o yaml

# 2. Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# 3. Verify IAM role
kubectl describe sa -n kube-system aws-load-balancer-controller

# 4. Check subnets tagged
aws ec2 describe-subnets --region us-east-1 --filters "Name=tag-key,Values=kubernetes.io/cluster/*"
```

### Targets Not Healthy
```bash
# 1. Check pod status
kubectl get pods -n jenkins

# 2. Check security groups
aws ec2 describe-security-groups --region us-east-1

# 3. Check network policies
kubectl get networkpolicy -n jenkins

# 4. Test pod connectivity
kubectl exec -it pod/jenkins-0 -n jenkins -- curl localhost:8080
```

### DNS Not Resolving
```bash
# 1. Check if ingress has ALB DNS
kubectl get ingress -n jenkins

# 2. Verify Route53 record
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# 3. Test DNS resolution
dig jenkins.example.com
nslookup jenkins.example.com
```

## Cost Estimation

### Single ALB
- Capacity Units: $16.20/month
- LCU charges: ~$1-5/month depending on traffic

### Multiple ALBs (Unconsolidated)
- 4 ALBs × $16.20 = $64.80/month
- Plus LCU charges

### Recommendation
Use consolidated ingress (single ALB) to reduce costs:
See `alb-consolidated.yaml` for example.

## Advanced Configuration

### WAF Integration
```yaml
annotations:
  alb.ingress.kubernetes.io/wafv2-web-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/example/a1234567
```

### Custom Response Headers
```yaml
annotations:
  alb.ingress.kubernetes.io/actions.ssl-redirect: |
    {"Type": "redirect", "RedirectConfig":
      {"Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}
```

### Authentication (OIDC)
```yaml
annotations:
  alb.ingress.kubernetes.io/auth-type: oidc
  alb.ingress.kubernetes.io/auth-idp-config: '{"issuer":"https://...","client_id":"...","client_secret":"..."}'
  alb.ingress.kubernetes.io/auth-on-unauthenticated-request: authenticate
```

### IP Whitelisting
```yaml
annotations:
  alb.ingress.kubernetes.io/actions.whitelist: |
    {"Type": "forward"}
  alb.ingress.kubernetes.io/conditions.whitelist: |
    [{"field":"source-ip","sourceIpConfig":{"values":["10.0.0.0/8","203.0.113.0/24"]}}]
```

## Cleanup

### Delete Ingresses
```bash
kubectl delete ingress -n jenkins
kubectl delete ingress -n argocd
kubectl delete ingress -n karpenter
kubectl delete ingress -n keda
```

### Delete ALB Controller
```bash
helm uninstall aws-alb-ingress-controller -n kube-system
```

### AWS Cleanup
```bash
# Delete ALBs
aws elbv2 delete-load-balancer --load-balancer-arn <arn> --region us-east-1

# Delete target groups
aws elbv2 delete-target-group --target-group-arn <arn> --region us-east-1

# Delete IAM role
aws iam delete-role --role-name AWSLoadBalancerControllerRole
```

## Next Steps

1. Deploy ALB controller: `ALB-INGRESS-SETUP.md`
2. Update domain names in values files
3. Deploy applications with ALB
4. Setup DNS records
5. Configure SSL certificates
6. Setup monitoring and alerts
7. Test failover and recovery

---

**Status**: Ready to Use
**Last Updated**: 2026-08-08
