output "karpenter_controller_role_arn" {
  value       = aws_iam_role.karpenter_controller.arn
  description = "ARN of the IAM role for Karpenter controller"
}

output "karpenter_instance_profile_name" {
  value       = aws_iam_instance_profile.karpenter_node.name
  description = "Name of the IAM instance profile for Karpenter nodes"
}
