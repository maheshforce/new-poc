module "eks" {
  source = "../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  node_group_name = var.node_group_name
  instance_types  = var.instance_types
  capacity_type   = var.capacity_type
  ami_type        = var.ami_type
  disk_size       = var.disk_size


  desired_size = var.desired_size
  min_size     = var.min_size
  max_size     = var.max_size

  environment     = var.environment
  admin_user_arns = var.admin_user_arns
  tags            = var.tags

}

module "ebs_csi" {
  source = "../modules/ebs"

  cluster_name     = module.eks.cluster_name
  oidc_issuer_url  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

module "efs" {
  source = "../modules/efs"

  cluster_name           = module.eks.cluster_name
  vpc_id                 = module.eks.vpc_id
  node_security_group_id = module.eks.node_security_group_id
  subnet_ids             = module.eks.private_subnet_ids
}

module "karpenter" {
  source = "../modules/karpenter"

  cluster_name    = module.eks.cluster_name
  oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  node_role_arn   = module.eks.node_group_role_arn
  node_role_name  = module.eks.node_group_role_name
}