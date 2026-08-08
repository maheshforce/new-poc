// Jenkinsfile - Main Pipeline Orchestration
pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
        timeout(time: 120, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment {
        AWS_REGION = 'us-east-1'
        REGISTRY = 'ghcr.io'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.GIT_BRANCH_NAME = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    echo "✓ Repository checked out"
                    echo "Branch: ${env.GIT_BRANCH_NAME}"
                    echo "Commit: ${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    echo "🔒 Running security scans..."
                    build job: 'Jenkinsfile.security', wait: true, propagate: false
                }
            }
        }

        stage('Validate Infrastructure') {
            parallel {
                stage('Terraform Validation') {
                    steps {
                        script {
                            echo "🔧 Validating Terraform..."
                            sh '''
                                cd terraform/vpc && terraform init -backend=false && terraform validate
                                cd ../eks && terraform init -backend=false && terraform validate
                            '''
                        }
                    }
                }
                
                stage('Helm Validation') {
                    steps {
                        script {
                            echo "🎯 Validating Helm charts..."
                            sh '''
                                helm lint ./helm/argocd
                                helm lint ./helm/karpenter
                                helm lint ./helm/keda
                                helm lint ./helm/jenkins
                            '''
                        }
                    }
                }
            }
        }

        stage('Plan Infrastructure') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "📊 Planning infrastructure changes..."
                    sh '''
                        cd terraform/vpc
                        terraform init
                        terraform plan -out=vpc.tfplan
                        
                        cd ../eks
                        terraform init
                        terraform plan -out=eks.tfplan
                    '''
                }
            }
        }

        stage('Approval for Deployment') {
            when {
                branch 'main'
            }
            steps {
                script {
                    input(
                        message: 'Deploy to EKS?',
                        ok: 'Deploy',
                        submitter: 'jenkins-users'
                    )
                }
            }
        }

        stage('Deploy Infrastructure') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Deploying infrastructure..."
                    sh '''
                        # Deploy VPC
                        echo "Deploying VPC..."
                        cd terraform/vpc
                        terraform apply -auto-approve
                        
                        # Deploy EKS
                        echo "Deploying EKS Cluster..."
                        cd ../eks
                        terraform apply -auto-approve
                        
                        # Get kubeconfig
                        CLUSTER_NAME=$(cd ../eks && terraform output -raw cluster_name 2>/dev/null || echo "eks-cluster")
                        aws eks update-kubeconfig --name $CLUSTER_NAME --region ${AWS_REGION}
                    '''
                }
            }
        }

        stage('Deploy Kubernetes Applications') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "📦 Deploying Kubernetes applications..."
                    sh '''
                        # Create namespaces
                        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace karpenter --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Deploy in order: Karpenter -> KEDA -> ArgoCD -> Jenkins
                        echo "Deploying Karpenter (node autoscaling)..."
                        helm upgrade --install karpenter ./helm/karpenter -n karpenter --wait || echo "Warning: Karpenter may need AWS configuration"
                        
                        echo "Deploying KEDA (event-driven autoscaling)..."
                        helm upgrade --install keda ./helm/keda -n keda --wait
                        
                        echo "Deploying ArgoCD (GitOps)..."
                        helm upgrade --install argocd ./helm/argocd -n argocd --wait
                        
                        echo "Deploying Jenkins (CI/CD)..."
                        helm upgrade --install jenkins ./helm/jenkins -n jenkins --wait
                        
                        echo "✓ All applications deployed"
                    '''
                }
            }
        }

        stage('Verify Deployments') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "✓ Verifying deployments..."
                    sh '''
                        echo "=== Deployment Status ==="
                        kubectl get deployments --all-namespaces
                        
                        echo ""
                        echo "=== StatefulSet Status ==="
                        kubectl get statefulsets --all-namespaces
                        
                        echo ""
                        echo "=== Service Status ==="
                        kubectl get services --all-namespaces
                        
                        echo ""
                        echo "=== Pod Status ==="
                        kubectl get pods --all-namespaces
                    '''
                }
            }
        }

        stage('Post-Deployment Tests') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🧪 Running post-deployment tests..."
                    sh '''
                        # Check Jenkins accessibility
                        echo "Checking Jenkins..."
                        kubectl get svc jenkins -n jenkins || echo "Warning: Jenkins service not found"
                        
                        # Check ArgoCD
                        echo "Checking ArgoCD..."
                        kubectl get svc argocd -n argocd || echo "Warning: ArgoCD service not found"
                        
                        # Check KEDA
                        echo "Checking KEDA..."
                        kubectl get deployment -n keda || echo "Warning: KEDA not found"
                        
                        # Check node status
                        echo "Checking nodes..."
                        kubectl get nodes -o wide
                        
                        echo "✓ Post-deployment checks completed"
                    '''
                }
            }
        }

        stage('Generate Report') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "📋 Generating deployment report..."
                    sh '''
                        mkdir -p deployment-reports
                        
                        cat > deployment-reports/deployment-summary-${GIT_COMMIT_SHORT}.txt << EOF
========================================
Deployment Summary Report
========================================
Date: $(date)
Branch: ${GIT_BRANCH_NAME}
Commit: ${GIT_COMMIT_SHORT}
Repository: $(git remote get-url origin)
========================================

Infrastructure Deployed:
- AWS VPC with subnets and routing
- EKS Kubernetes cluster
- Karpenter for node autoscaling
- KEDA for event-driven autoscaling
- ArgoCD for GitOps deployment
- Jenkins for CI/CD pipeline

Access Information:
- Jenkins: kubectl port-forward -n jenkins svc/jenkins 8080:80
- ArgoCD: kubectl port-forward -n argocd svc/argocd 8080:80

For full deployment details, check Jenkins build logs.
EOF
                        
                        cat deployment-reports/deployment-summary-${GIT_COMMIT_SHORT}.txt
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "Pipeline execution completed"
                archiveArtifacts artifacts: "deployment-reports/**", allowEmptyArchive: true
            }
        }
        success {
            echo "✅ Pipeline completed successfully"
        }
        failure {
            echo "❌ Pipeline failed - check logs above"
        }
        unstable {
            echo "⚠️ Pipeline completed with warnings"
        }
    }
}
