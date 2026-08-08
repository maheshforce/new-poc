#!/bin/bash

# Path-Based ALB Ingress Verification Script
# This script verifies that all components are correctly configured

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  Path-Based ALB Ingress Verification Script"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

# Check 1: Kubernetes cluster connectivity
echo -e "${BLUE}1. Checking Kubernetes Cluster Connectivity${NC}"
if kubectl cluster-info &>/dev/null; then
    check_pass "Connected to Kubernetes cluster"
    CLUSTER_INFO=$(kubectl cluster-info | head -1)
    echo "   $CLUSTER_INFO"
else
    check_fail "Cannot connect to Kubernetes cluster"
    exit 1
fi
echo ""

# Check 2: ALB Ingress Controller
echo -e "${BLUE}2. Checking ALB Ingress Controller${NC}"
if kubectl get deployment -n kube-system aws-load-balancer-controller &>/dev/null; then
    check_pass "ALB Ingress Controller deployed"
    REPLICAS=$(kubectl get deployment -n kube-system aws-load-balancer-controller -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')
    if [ "$REPLICAS" = "2/2" ] || [ "$REPLICAS" = "1/1" ]; then
        echo "   Replicas: $REPLICAS (Ready)"
    else
        check_warn "ALB Controller replicas: $REPLICAS (might not be ready yet)"
    fi
else
    check_fail "ALB Ingress Controller not found"
    echo "   Run: helm install aws-alb-ingress-controller ./helm/aws-alb-ingress-controller -n kube-system"
fi
echo ""

# Check 3: Namespaces
echo -e "${BLUE}3. Checking Application Namespaces${NC}"
NAMESPACES=("jenkins" "argocd" "karpenter" "keda")
for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
        check_pass "Namespace '$ns' exists"
    else
        check_fail "Namespace '$ns' does not exist"
    fi
done
echo ""

# Check 4: Jenkins Deployment
echo -e "${BLUE}4. Checking Jenkins Deployment${NC}"
if kubectl get statefulset -n jenkins jenkins &>/dev/null; then
    check_pass "Jenkins StatefulSet deployed"
    REPLICAS=$(kubectl get statefulset -n jenkins jenkins -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || echo "0/1")
    if [ "$REPLICAS" = "1/1" ]; then
        check_pass "Jenkins pod is running"
    else
        check_warn "Jenkins pod status: $REPLICAS"
    fi
    # Check ingress
    if kubectl get ingress -n jenkins jenkins &>/dev/null; then
        check_pass "Jenkins Ingress configured"
        PATH_PREFIX=$(kubectl get ingress -n jenkins jenkins -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
        echo "   Path prefix: $PATH_PREFIX"
    else
        check_fail "Jenkins Ingress not found"
    fi
else
    check_fail "Jenkins StatefulSet not deployed"
fi
echo ""

# Check 5: ArgoCD Deployment
echo -e "${BLUE}5. Checking ArgoCD Deployment${NC}"
if kubectl get deployment -n argocd argocd-server &>/dev/null; then
    check_pass "ArgoCD deployment exists"
    REPLICAS=$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || echo "0/1")
    if [ "$REPLICAS" = "2/2" ] || [ "$REPLICAS" = "1/1" ]; then
        check_pass "ArgoCD pods are running"
    else
        check_warn "ArgoCD pod status: $REPLICAS"
    fi
    # Check ingress
    if kubectl get ingress -n argocd argocd &>/dev/null; then
        check_pass "ArgoCD Ingress configured"
        PATH_PREFIX=$(kubectl get ingress -n argocd argocd -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
        echo "   Path prefix: $PATH_PREFIX"
    else
        check_fail "ArgoCD Ingress not found"
    fi
else
    check_fail "ArgoCD not deployed"
fi
echo ""

# Check 6: Karpenter Deployment
echo -e "${BLUE}6. Checking Karpenter Deployment${NC}"
if kubectl get deployment -n karpenter karpenter &>/dev/null; then
    check_pass "Karpenter deployment exists"
    REPLICAS=$(kubectl get deployment -n karpenter karpenter -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || echo "0/1")
    if [ "$REPLICAS" = "2/2" ] || [ "$REPLICAS" = "1/1" ]; then
        check_pass "Karpenter pods are running"
    else
        check_warn "Karpenter pod status: $REPLICAS"
    fi
    # Check ingress
    if kubectl get ingress -n karpenter karpenter &>/dev/null; then
        check_pass "Karpenter Ingress configured"
        PATH_PREFIX=$(kubectl get ingress -n karpenter karpenter -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
        echo "   Path prefix: $PATH_PREFIX"
    else
        check_fail "Karpenter Ingress not found"
    fi
else
    check_fail "Karpenter not deployed"
fi
echo ""

# Check 7: KEDA Deployment
echo -e "${BLUE}7. Checking KEDA Deployment${NC}"
if kubectl get deployment -n keda keda-operator &>/dev/null; then
    check_pass "KEDA deployment exists"
    REPLICAS=$(kubectl get deployment -n keda keda-operator -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || echo "0/1")
    if [ "$REPLICAS" = "2/2" ] || [ "$REPLICAS" = "1/1" ]; then
        check_pass "KEDA pods are running"
    else
        check_warn "KEDA pod status: $REPLICAS"
    fi
    # Check ingress
    if kubectl get ingress -n keda keda &>/dev/null; then
        check_pass "KEDA Ingress configured"
        PATH_PREFIX=$(kubectl get ingress -n keda keda -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
        echo "   Path prefix: $PATH_PREFIX"
    else
        check_fail "KEDA Ingress not found"
    fi
else
    check_fail "KEDA not deployed"
fi
echo ""

# Check 8: ALB Creation
echo -e "${BLUE}8. Checking ALB Status${NC}"
INGRESSES=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
if [ "$INGRESSES" -gt 0 ]; then
    check_pass "Found $INGRESSES ingresses"
    
    # Get ALB DNS from first ingress
    ALB_DNS=$(kubectl get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$ALB_DNS" ]; then
        check_pass "ALB provisioned and accessible"
        echo "   ALB DNS: $ALB_DNS"
        echo ""
        echo "   Service URLs:"
        echo "   - Jenkins:   http://$ALB_DNS/jenkins"
        echo "   - ArgoCD:    http://$ALB_DNS/argocd"
        echo "   - Karpenter: http://$ALB_DNS/karpenter"
        echo "   - KEDA:      http://$ALB_DNS/keda"
    else
        check_warn "ALB DNS not yet assigned (still provisioning, wait 30-60 seconds)"
    fi
else
    check_fail "No ingresses found"
fi
echo ""

# Check 9: Services
echo -e "${BLUE}9. Checking Services${NC}"
SERVICES=("jenkins:jenkins" "argocd-server:argocd" "karpenter:karpenter" "keda-operator:keda")
for service_info in "${SERVICES[@]}"; do
    IFS=":" read -r service namespace <<< "$service_info"
    if kubectl get svc "$service" -n "$namespace" &>/dev/null; then
        check_pass "Service '$service' exists in namespace '$namespace'"
        ENDPOINTS=$(kubectl get svc "$service" -n "$namespace" -o jsonpath='{.spec.clusterIP}')
        echo "   Cluster IP: $ENDPOINTS"
    else
        check_fail "Service '$service' not found in namespace '$namespace'"
    fi
done
echo ""

# Check 10: Storage (if applicable)
echo -e "${BLUE}10. Checking Storage${NC}"
if kubectl get pvc -n jenkins &>/dev/null; then
    JENKINS_PVC=$(kubectl get pvc -n jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$JENKINS_PVC" ]; then
        check_pass "Jenkins PVC found: $JENKINS_PVC"
        PVC_STATUS=$(kubectl get pvc "$JENKINS_PVC" -n jenkins -o jsonpath='{.status.phase}')
        echo "   Status: $PVC_STATUS"
    fi
fi

if kubectl get pvc -n argocd &>/dev/null; then
    ARGOCD_PVC=$(kubectl get pvc -n argocd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$ARGOCD_PVC" ]; then
        check_pass "ArgoCD PVC found: $ARGOCD_PVC"
    fi
fi
echo ""

# Check 11: ConfigMaps and Secrets
echo -e "${BLUE}11. Checking Configuration${NC}"
if kubectl get configmap -n kube-system aws-alb-ingress-controller &>/dev/null; then
    check_pass "ALB controller ConfigMap found"
fi

if kubectl get secret -n argocd argocd-initial-admin-secret &>/dev/null; then
    check_pass "ArgoCD admin secret found"
    echo "   Run: kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi
echo ""

# Check 12: RBAC
echo -e "${BLUE}12. Checking RBAC Configuration${NC}"
if kubectl get clusterrole aws-load-balancer-controller &>/dev/null; then
    check_pass "ALB controller ClusterRole found"
fi

if kubectl get clusterrolebinding aws-load-balancer-controller &>/dev/null; then
    check_pass "ALB controller ClusterRoleBinding found"
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Passed: $PASS${NC} | ${YELLOW}Warnings: $WARN${NC} | ${RED}Failed: $FAIL${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Wait for ALB to be fully provisioned (30-60 seconds)"
    echo "2. Get ALB DNS: kubectl get ingress -A -o wide"
    echo "3. Access services:"
    echo "   - Jenkins: http://ALB-DNS/jenkins"
    echo "   - ArgoCD: http://ALB-DNS/argocd"
    echo "   - Karpenter: http://ALB-DNS/karpenter"
    echo "   - KEDA: http://ALB-DNS/keda"
    echo ""
    exit 0
elif [ $WARN -gt 0 ] && [ $FAIL -eq 0 ]; then
    echo -e "${YELLOW}⚠ Checks passed with warnings${NC}"
    echo ""
    echo "Some resources may still be provisioning. Run this script again in 30-60 seconds."
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check ALB controller logs: kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
    echo "2. Verify IAM role is attached to the controller"
    echo "3. Check subnets are tagged for ALB discovery"
    echo "4. Review deployment status: kubectl get all -n [namespace]"
    echo ""
    exit 1
fi
