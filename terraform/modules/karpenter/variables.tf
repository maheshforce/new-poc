variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC Issuer URL of the EKS cluster"
}

variable "node_role_arn" {
  type        = string
  description = "ARN of the EKS worker node group role"
}

variable "node_role_name" {
  type        = string
  description = "Name of the EKS worker node group role"
}
