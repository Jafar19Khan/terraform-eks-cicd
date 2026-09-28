aws_region      = "us-east-1"
environment     = "prod"
cluster_name    = "my-eks-prod"
vpc_name        = "eks-prod-vpc"
vpc_cidr        = "10.10.0.0/16"
public_subnets  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
private_subnets = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"]

node_instance_types = ["t3.large"]
node_capacity_type  = "ON_DEMAND"
node_min_size       = 2
node_desired_size   = 3
node_max_size       = 5
