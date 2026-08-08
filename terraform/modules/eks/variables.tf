variable "cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS Cluster"
  type        = string
  default     = "1.31"
}


variable "vpc_id" {
  description = "VPC ID where EKS cluster and node group will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of Subnet IDs for EKS Cluster control plane and worker nodes"
  type        = list(string)
}

variable "node_group_name" {
  description = "Name of the EKS Managed Node Group"
  type        = string
  default     = "main-node-group"
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

variable "instance_types" {
  description = "List of EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Type of capacity for node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "disk_size" {

  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "admin_user_arns" {
  description = "List of IAM User/Role ARNs granted EKS Cluster Admin permissions for AWS Console access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

