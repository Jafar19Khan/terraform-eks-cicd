aws_region      = "us-east-1"
environment     = "dev"
cluster_name    = "my-eks-dev"
vpc_name        = "eks-dev-vpc"
vpc_cidr        = "192.168.0.0/16"
public_subnets  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
private_subnets = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]

node_instance_types = ["t3.medium", "t3a.medium"]
node_capacity_type  = "SPOT"
node_min_size       = 1
node_desired_size   = 2
node_max_size       = 3
