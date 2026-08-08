#!/bin/bash

# verify-pathbased-ingress.sh
# Diagnostic script for EKS LoadBalancer Path-Based routing

# Set colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}     EKS PATH-BASED ALB ROUTING DIAGNOSTICS        ${NC}"
echo -e "${GREEN}===================================================${NC}"

# Check kubectl connectivity
echo -e "\nChecking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Error: Cannot connect to Kubernetes cluster. Make sure your kubeconfig is correct and active.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Connected to cluster.${NC}"
fi

# Check namespaces
echo -e "\nChecking required namespaces..."
for ns in jenkins argocd karpenter keda kube-system; do
    if kubectl get namespace "$ns" &>/dev/null; then
        echo -e "${GREEN}✓ Namespace '$ns' exists.${NC}"
    else
        echo -e "${YELLOW}⚠ Namespace '$ns' does not exist yet.${NC}"
    fi
done

# Check ALB Controller
echo -e "\nChecking AWS Load Balancer Controller deployment..."
ALB_DEPLOYMENT=$(kubectl get deployment -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$ALB_DEPLOYMENT" ]; then
    # try looking without filter
    ALB_DEPLOYMENT=$(kubectl get deployment -n kube-system -l app.kubernetes.io/instance=aws-load-balancer-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

if [ -n "$ALB_DEPLOYMENT" ]; then
    REPLICAS=$(kubectl get deployment -n kube-system "$ALB_DEPLOYMENT" -o jsonpath='{.status.readyReplicas}')
    if [ "$REPLICAS" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✓ AWS Load Balancer Controller is running ($REPLICAS ready replicas).${NC}"
    else
        echo -e "${YELLOW}⚠ AWS Load Balancer Controller is deployed but has 0 ready replicas.${NC}"
    fi
else
    echo -e "${RED}✗ AWS Load Balancer Controller deployment not found in kube-system namespace.${NC}"
    echo -e "  Please deploy it using: helm install aws-alb-ingress-controller ./helm/aws-alb-ingress-controller -n kube-system"
fi

# Check Ingress configurations
echo -e "\nChecking Ingress resources and group configurations..."
INGRESSES=$(kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null)

if [ -z "$INGRESSES" ]; then
    echo -e "${YELLOW}⚠ No ingress resources found in the cluster.${NC}"
else
    # Check if they belong to group 'consolidated-apps'
    for ing in $INGRESSES; do
        ns=$(echo "$ing" | cut -d'/' -f1)
        name=$(echo "$ing" | cut -d'/' -f2)
        group=$(kubectl get ingress -n "$ns" "$name" -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/group\.name}' 2>/dev/null)
        if [ "$group" == "consolidated-apps" ]; then
            echo -e "${GREEN}✓ Ingress '$name' in namespace '$ns' belongs to group 'consolidated-apps'.${NC}"
        else
            echo -e "${YELLOW}⚠ Ingress '$name' in namespace '$ns' does NOT belong to group 'consolidated-apps' (group: '$group').${NC}"
        fi
    done
fi

# Retrieve ALB DNS Name
echo -e "\nRetrieving ALB URL..."
ALB_DNS=$(kubectl get ingress -n jenkins -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -z "$ALB_DNS" ]; then
    # Try fetching from argocd
    ALB_DNS=$(kubectl get ingress -n argocd -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
fi

if [ -n "$ALB_DNS" ]; then
    echo -e "${GREEN}✓ ALB Load Balancer DNS Name Found:${NC}"
    echo -e "  ${GREEN}http://$ALB_DNS${NC}"
    echo -e "\nServices can be accessed at:"
    echo -e "  - Jenkins:   ${GREEN}http://$ALB_DNS/jenkins${NC}"
    echo -e "  - ArgoCD:    ${GREEN}http://$ALB_DNS/argocd${NC}"
    echo -e "  - Karpenter: ${GREEN}http://$ALB_DNS/karpenter/metrics${NC}"
    echo -e "  - KEDA:      ${GREEN}http://$ALB_DNS/keda${NC}"
else
    echo -e "${YELLOW}⚠ ALB DNS Name not provisioned yet by AWS Load Balancer Controller.${NC}"
    echo -e "  It typically takes 2-3 minutes for AWS to allocate the DNS name after applying the ingress."
    echo -e "  To check progress, view controller logs:"
    echo -e "    kubectl logs -n kube-system deployment/aws-load-balancer-controller"
fi

echo -e "\n${GREEN}===================================================${NC}"
