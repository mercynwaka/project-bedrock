# --- VPC ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "project-bedrock-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # single nat gatway saves cost
  enable_dns_hostnames = true

  # Required for ALB Controller discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = { Project = "Bedrock" }
}

# --- EKS CLUSTER ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "project-bedrock-cluster"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Logging (Core 4.4)
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Enable OIDC for Service Accounts (Required for ingress)
  enable_irsa = true

  eks_managed_node_groups = {
    free-tier-nodes = {
      min_size       = 1
      max_size       = 4
      desired_size   = 3
      instance_types = ["t3.micro"]
      disk_size = 20
      # Add policy for SSM (helpful for debugging)
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  # Grant the creator admin access
  enable_cluster_creator_admin_permissions = true

  tags = { Project = "Bedrock" }
}

# --- OBSERVABILITY  ---
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"
  depends_on   = [module.eks.eks_managed_node_groups]
}
