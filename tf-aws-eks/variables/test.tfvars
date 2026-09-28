aws_region      = "us-east-1"
environment     = "test"
cluster_name    = "my-eks-test"
vpc_name        = "eks-test-vpc"
vpc_cidr        = "172.16.0.0/16"
public_subnets  = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
private_subnets = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]

node_instance_types = ["t3.medium", "t3a.medium"]
node_capacity_type  = "SPOT"
node_min_size       = 1
node_desired_size   = 2
node_max_size       = 3
