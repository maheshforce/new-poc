module "vpc" {
  source = "../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name
  environment          = var.environment
  single_nat_gateway   = var.single_nat_gateway
  tags                 = var.tags

}
