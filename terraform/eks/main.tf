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
