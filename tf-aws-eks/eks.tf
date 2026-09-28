# https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# Module v21 renamed several inputs (cluster_name -> name, cluster_version -> kubernetes_version,
# cluster_endpoint_public_access -> endpoint_public_access, cluster_addons -> addons).
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Public API endpoint so Jenkins (a different VPC) can reach the cluster.
  endpoint_public_access = true

  # Without this the identity that creates the cluster (the Jenkins role) gets
  # "Unauthorized" from kubectl. Adds it as cluster admin through an access entry.
  enable_cluster_creator_admin_permissions = true

  # Core add-ons. vpc-cni and the pod identity agent must exist BEFORE the nodes start,
  # otherwise nodes never become Ready (NodeCreationFailure).
  addons = {
    coredns                = {}
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    nodes = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }
}
