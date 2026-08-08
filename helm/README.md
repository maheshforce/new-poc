# Helm Charts

This directory contains production-ready Helm charts for deploying essential Kubernetes infrastructure components.

## Charts Included

### 1. ArgoCD
GitOps continuous deployment for Kubernetes using declarative Git repositories.

**Install:**
```bash
helm install argocd ./argocd -n argocd --create-namespace
```

**Key Features:**
- High-availability setup with multiple replicas
- Web UI with load balancer/ingress access
- RBAC and security context configured
- Redis for caching
- Webhook support

**Values to Customize:**
- `global.domain`: Set your ArgoCD domain
- `server.service.type`: Change to LoadBalancer or NodePort as needed
- `server.ingress.hosts`: Configure your domain

### 2. Karpenter
Kubernetes autoscaler optimizing compute resources on AWS.

**Install:**
```bash
helm install karpenter ./karpenter -n karpenter --create-namespace
```

**Key Features:**
- Just-in-time node provisioning
- Cost optimization through node consolidation
- AWS EC2 integration
- Metrics and monitoring
- HPA support

**Values to Customize:**
- `settings.aws.clusterName`: Set your EKS cluster name
- `settings.aws.defaultInstanceProfile`: Configure IAM instance profile
- `resources`: Adjust CPU and memory requests/limits

### 3. KEDA
Kubernetes Event-Driven Autoscaling for scaling workloads based on external events.

**Install:**
```bash
helm install keda ./keda -n keda --create-namespace
```

**Key Features:**
- Event-driven pod autoscaling
- Multiple scalers support (AWS SQS, Kafka, RabbitMQ, etc.)
- Metrics server for custom metrics
- Webhook validation
- Monitoring and alerting

**Values to Customize:**
- `replicaCount`: Adjust controller replicas
- `metricsServer.enabled`: Enable/disable metrics server
- `monitoring.alertRules.enabled`: Enable Prometheus alert rules

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- kubectl configured to access your cluster

## Installation Order

For best results, install in this order:

1. **Karpenter** - Node autoscaling foundation
2. **KEDA** - Pod autoscaling capability
3. **ArgoCD** - GitOps deployment

## Common Commands

### Validate Chart
```bash
helm lint ./argocd
helm lint ./karpenter
helm lint ./keda
```

### Dry Run
```bash
helm install argocd ./argocd -n argocd --create-namespace --dry-run --debug
```

### Upgrade Chart
```bash
helm upgrade argocd ./argocd -n argocd
```

### Uninstall Chart
```bash
helm uninstall argocd -n argocd
```

### Get Chart Values
```bash
helm get values argocd -n argocd
```

## Configuration Best Practices

### Security
- All charts include security contexts with non-root users
- RBAC is configured and enabled by default
- Service accounts are created automatically

### High Availability
- All charts are configured with multiple replicas by default
- Pod disruption budgets can be added for better resilience
- Anti-affinity rules can be enabled for pod distribution

### Resource Management
- CPU and memory requests/limits are pre-configured
- Horizontal Pod Autoscaling (HPA) is available
- Adjust based on your workload

### Monitoring
- Metrics endpoints are exposed for Prometheus
- Log levels can be adjusted
- Health checks (liveness/readiness) are configured

## Troubleshooting

### Check Chart Status
```bash
helm status argocd -n argocd
helm status karpenter -n karpenter
helm status keda -n keda
```

### View Chart History
```bash
helm history argocd -n argocd
```

### Rollback Chart
```bash
helm rollback argocd 1 -n argocd
```

### Check Pod Logs
```bash
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n karpenter deployment/karpenter
kubectl logs -n keda deployment/keda
```

## Customization

Each chart includes a `values.yaml` file with all configurable options. Create a custom values file and override:

```bash
helm install argocd ./argocd -n argocd --create-namespace -f custom-values.yaml
```

## Support

For issues or updates, refer to:
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Karpenter Documentation](https://karpenter.sh)
- [KEDA Documentation](https://keda.sh)

## License

These charts are provided as-is for use within Rapyder Cloud Solutions.
