output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Attribute block containing certificate-authority-data for cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = aws_eks_node_group.main.status
}

output "vpc_id" {
  description = "The VPC ID of the cluster"
  value       = var.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs of the cluster"
  value       = var.subnet_ids
}

output "node_security_group_id" {
  description = "The shared security group ID created by EKS for nodes"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_group_role_arn" {
  description = "IAM role ARN of the worker nodes"
  value       = aws_iam_role.node_group.arn
}

output "node_group_role_name" {
  description = "IAM role name of the worker nodes"
  value       = aws_iam_role.node_group.name
}

