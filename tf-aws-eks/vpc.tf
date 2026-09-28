locals {
  azs = slice(data.aws_availability_zones.azs.names, 0, 3)
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_dns_support   = true
  enable_dns_hostnames = true

  # One shared NAT gateway keeps the lab cheap (use one per AZ in production).
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # Tags used by Kubernetes to find subnets for load balancers
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }
}
