output "file_system_id" {
  value = aws_efs_file_system.this.id
}

output "security_group_id" {
  value = aws_security_group.efs.id
}

output "access_point_id" {
  value = aws_efs_access_point.jenkins.id
}

output "dev_access_point_id" {
  value = aws_efs_access_point.dev.id
}

output "prod_access_point_id" {
  value = aws_efs_access_point.prod.id
}