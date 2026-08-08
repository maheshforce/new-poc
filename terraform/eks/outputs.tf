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
