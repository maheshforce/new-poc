variable "aws_region" {
  description = "AWS region to deploy EKS cluster in"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment identifier (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "The VPC ID (from VPC deployment outputs)"
  type        = string
}

variable "subnet_ids" {
  description = "List of Subnet IDs (typically private subnets from VPC deployment outputs)"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
  default     = "demo-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS Cluster"
  type        = string
  default     = "1.31"
}


variable "node_group_name" {
  description = "Name of the EKS Managed Node Group"
  type        = string
  default     = "demo-node-group"
}

variable "instance_types" {
  description = "Instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "disk_size" {

  description = "Node disk size in GB"
  type        = number
  default     = 20
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "admin_user_arns" {
  description = "List of IAM User/Role ARNs granted EKS Cluster Admin permissions for AWS Console access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

