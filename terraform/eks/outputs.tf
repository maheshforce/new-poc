output "cluster_id" {
  description = "The EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}



output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificate authority data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_group_arn" {
  description = "ARN of the EKS Managed Node Group"
  value       = module.eks.node_group_arn
}

output "node_group_status" {
  description = "Status of the EKS Managed Node Group"
  value       = module.eks.node_group_status
}

output "configure_kubectl" {
  description = "Command to update local kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.eks.vpc_id
}

output "subnet_ids" {
  value = module.eks.private_subnet_ids
}

output "karpenter_controller_role_arn" {
  value       = module.karpenter.karpenter_controller_role_arn
  description = "IAM Role ARN for Karpenter Controller ServiceAccount"
}

output "karpenter_instance_profile_name" {
  value       = module.karpenter.karpenter_instance_profile_name
  description = "IAM Instance Profile name for Karpenter nodes"
}

output "ecr_dev_url" {
  value       = aws_ecr_repository.dev.repository_url
  description = "URL of the Dev ECR Repository"
}

output "ecr_prod_url" {
  value       = aws_ecr_repository.prod.repository_url
  description = "URL of the Prod ECR Repository"
}

output "efs_file_system_id" {
  value       = module.efs.file_system_id
  description = "ID of the shared EFS File System"
}

output "efs_dev_access_point_id" {
  value       = module.efs.dev_access_point_id
  description = "ID of the Dev EFS Access Point"
}

output "efs_prod_access_point_id" {
  value       = module.efs.prod_access_point_id
  description = "ID of the Prod EFS Access Point"
}



