# AWS ALB Ingress Controller Setup & Configuration

## Overview

This guide explains the AWS Application Load Balancer (ALB) Ingress Controller integration with Kubernetes. The ALB controller automatically provisions AWS ALBs/NLBs based on Kubernetes Ingress resources.

## Architecture

```
┌─────────────────────────────────────────────┐
│          AWS ALB/NLB (Internet-facing)      │
│         (Managed by ALB Controller)         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│     Kubernetes Ingress Resources            │
│  (jenkins, argocd, karpenter, keda)         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│   AWS Load Balancer Controller (Pod)        │
│   - Watches Ingress resources                │
│   - Creates/Updates ALBs                    │
│   - Manages target groups                   │
└──────────────────────────────────────────────┘
```

## Prerequisites

### AWS Setup
1. **EKS Cluster** with OIDC provider enabled
2. **IAM Role** for the ALB Controller service account
3. **Subnets** tagged for ALB discovery (auto-discovered or specified)
4. **Security Groups** allowing traffic to worker nodes

### Kubernetes Cluster
- kubectl access to EKS cluster
- Helm 3.0+
- ExternalDNS (optional, for DNS management)

## Installation

### Step 1: Create IAM Policy

```bash
# Download the policy document
curl https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json -o iam_policy.json

# Create IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

### Step 2: Create IAM Role

```bash
# Set variables
CLUSTER_NAME="your-cluster-name"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name AWSLoadBalancerControllerRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name AWSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
```

### Step 3: Deploy ALB Controller via Helm

```bash
# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create namespace
kubectl create namespace kube-system

# Install ALB Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=your-cluster-name \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/AWSLoadBalancerControllerRole"

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Step 4: Deploy Using Our Helm Chart (Alternative)

```bash
# Create namespace
kubectl create namespace kube-system

# Deploy our ALB controller chart
helm install aws-alb-ingress-controller ./helm/aws-alb-ingress-controller \
  -n kube-system \
  --set aws.region=us-east-1 \
  --set vpcId=vpc-xxxxx \
  --set subnetIds=subnet-xxxxx,subnet-yyyyy
```

## Deploying Applications with ALB

### Jenkins Example

```bash
# Update jenkins values to enable ingress
helm install jenkins ./helm/jenkins -n jenkins --create-namespace \
  -f - << EOF
ingress:
  enabled: true
  className: alb
  hosts:
    - host: jenkins.your-domain.com
      paths:
        - path: /
          pathType: Prefix
EOF

# Verify ingress created
kubectl get ingress -n jenkins
```

### ArgoCD Example

```bash
helm install argocd ./helm/argocd -n argocd --create-namespace \
  -f - << EOF
server:
  ingress:
    enabled: true
    ingressClassName: alb
    hosts:
      - argocd.your-domain.com
    paths:
      - path: /
        pathType: Prefix
EOF
```

### Deploy All Applications with ALB

```bash
helm install jenkins ./helm/jenkins -n jenkins --create-namespace -f jenkins-alb-values.yaml
helm install argocd ./helm/argocd -n argocd --create-namespace -f argocd-alb-values.yaml
helm install karpenter ./helm/karpenter -n karpenter --create-namespace -f karpenter-alb-values.yaml
helm install keda ./helm/keda -n keda --create-namespace -f keda-alb-values.yaml
```

## ALB Ingress Annotations

### Common Annotations

| Annotation | Values | Purpose |
|-----------|--------|---------|
| `alb.ingress.kubernetes.io/scheme` | `internet-facing`, `internal` | Public or private ALB |
| `alb.ingress.kubernetes.io/target-type` | `ip`, `instance` | Target type for routing |
| `alb.ingress.kubernetes.io/listen-ports` | `[{"HTTP": 80}, {"HTTPS": 443}]` | ALB listener ports |
| `alb.ingress.kubernetes.io/ssl-redirect` | `'443'` | Redirect HTTP to HTTPS |
| `alb.ingress.kubernetes.io/backend-protocol` | `HTTP`, `HTTPS` | Protocol to pods |
| `alb.ingress.kubernetes.io/healthcheck-path` | `/health`, `/` | Health check endpoint |
| `alb.ingress.kubernetes.io/healthcheck-interval-seconds` | `15` | Check interval |
| `alb.ingress.kubernetes.io/healthcheck-timeout-seconds` | `5` | Check timeout |
| `alb.ingress.kubernetes.io/healthy-threshold-count` | `2` | Healthy threshold |
| `alb.ingress.kubernetes.io/unhealthy-threshold-count` | `2` | Unhealthy threshold |

### Example: Internet-facing ALB

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  namespace: jenkins
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/backend-protocol: HTTP
spec:
  ingressClassName: alb
  rules:
    - host: jenkins.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: jenkins
                port:
                  number: 80
```

### Example: Internal NLB

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: karpenter
  namespace: karpenter
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: karpenter.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: karpenter
                port:
                  number: 8080
```

## DNS Management

### Using ExternalDNS

```bash
# Install ExternalDNS
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install external-dns bitnami/external-dns \
  --namespace external-dns --create-namespace \
  --set provider=aws \
  --set policy=sync \
  --set registry=txt \
  --set txtOwnerId=<cluster-name>
```

### Manual DNS Setup

1. Get ALB DNS name:
```bash
kubectl get ingress -n jenkins -o wide
# Copy the ADDRESS column (e.g., k8s-jenkins-jenkins-12345.us-east-1.elb.amazonaws.com)
```

2. Create Route53 alias record:
   - Name: `jenkins.example.com`
   - Type: A (Alias)
   - Target: ALB DNS name

## SSL/TLS Configuration

### Using AWS Certificate Manager

```bash
# Request certificate in ACM
aws acm request-certificate --domain-name example.com --validation COA

# Add certificate annotation to ingress
annotations:
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxxxx
  alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
```

### Using Cert-Manager

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-key
    solvers:
      - http01:
          ingress:
            class: alb
EOF

# Annotate ingress for auto SSL
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt"
spec:
  tls:
    - secretName: jenkins-tls
      hosts:
        - jenkins.example.com
```

## Troubleshooting

### Check ALB Controller Status

```bash
# View pod logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check service account
kubectl get sa -n kube-system aws-load-balancer-controller
kubectl describe sa -n kube-system aws-load-balancer-controller

# Verify IRSA role
kubectl describe pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep iam.amazonaws
```

### Ingress Not Creating ALB

```bash
# Check ingress status
kubectl describe ingress -n jenkins
kubectl get events -n jenkins

# Verify ingress class exists
kubectl get ingressclass

# Check ALB controller logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep -i error
```

### ALB Not Routing Traffic

```bash
# Verify target groups are healthy
aws elbv2 describe-target-groups --region us-east-1

# Check target health
aws elbv2 describe-target-health --target-group-arn <arn> --region us-east-1

# Verify security groups
aws ec2 describe-security-groups --region us-east-1 | grep -i kubernetes
```

### DNS Not Resolving

```bash
# Check if ExternalDNS created DNS record
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Check ExternalDNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Manual DNS test
dig jenkins.example.com
nslookup jenkins.example.com
```

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

### Idle Connection Timeout

```yaml
annotations:
  alb.ingress.kubernetes.io/load-balancer-attributes: 'idle_timeout.connection.s=60'
```

## Cost Optimization

### ALB Consolidation

Multiple ingresses can share single ALB:

```yaml
# Both ingresses share one ALB by using same hostname
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  ingressClassName: alb
  rules:
    - host: example.com
      http:
        paths:
          - path: /jenkins
            pathType: Prefix
            backend:
              service:
                name: jenkins
                port:
                  number: 80
          - path: /argocd
            pathType: Prefix
            backend:
              service:
                name: argocd
                port:
                  number: 80
```

### Resource Tags

Add tags to ALBs for cost tracking:

```yaml
annotations:
  alb.ingress.kubernetes.io/tags: 'Environment=Production,Team=DevOps,CostCenter=Engineering'
```

## Security Best Practices

1. **Use Security Groups**: Restrict traffic to ALB
2. **Enable WAF**: Add AWS WAF rules to ALB
3. **Use HTTPS**: Always enable SSL redirect
4. **Network Policies**: Implement Kubernetes NetworkPolicies
5. **Pod Security**: Run as non-root, read-only filesystem
6. **Audit Logging**: Enable ALB access logs

### Example: WAF Integration

```yaml
annotations:
  alb.ingress.kubernetes.io/wafv2-web-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/example/a1234567-b890-c123-d456-e78901234567
```

## Monitoring

### CloudWatch Metrics

```bash
# View ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/k8s-jenkins-jenkins/1234567890abcdef \
  --start-time 2026-08-01T00:00:00Z \
  --end-time 2026-08-08T00:00:00Z \
  --period 300 \
  --statistics Average
```

### Prometheus Scraping

```yaml
annotations:
  prometheus.io/scrape: 'true'
  prometheus.io/port: '8080'
  prometheus.io/path: '/metrics'
```

## Cleanup

```bash
# Delete ingresses
kubectl delete ingress -n jenkins
kubectl delete ingress -n argocd

# Delete ALB controller
helm uninstall aws-alb-ingress-controller -n kube-system

# Delete IAM role
aws iam detach-role-policy --role-name AWSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
aws iam delete-role --role-name AWSLoadBalancerControllerRole
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
```

## Helm Values Reference

See `helm/aws-alb-ingress-controller/values.yaml` for:
- Replica count configuration
- Resource limits and requests
- Security context settings
- Pod affinity rules
- Network policy options
- CloudWatch logging
- Tag management

## Quick Reference Commands

```bash
# Install ALB controller
helm install aws-alb-ingress-controller ./helm/aws-alb-ingress-controller \
  -n kube-system --create-namespace

# Deploy all apps with ALB
helm install jenkins ./helm/jenkins -n jenkins --create-namespace
helm install argocd ./helm/argocd -n argocd --create-namespace
helm install karpenter ./helm/karpenter -n karpenter --create-namespace
helm install keda ./helm/keda -n keda --create-namespace

# Check ingresses
kubectl get ingress --all-namespaces

# Get ALB DNS names
kubectl get ingress -A -o wide

# Verify ALBs created
aws elbv2 describe-load-balancers --region us-east-1
```

## Related Documentation

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ALB Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Ingress API](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

**Created**: 2026-08-08
**Version**: 1.0
**Status**: Ready for Deployment
