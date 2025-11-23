provider "aws" {
  region = var.region
}

module "vpc" {
  source             = "./modules/vpc"
  region             = var.region
  vpc_cidr_block     = "11.0.0.0/16"
  public_cidr_block  = ["11.0.1.0/24", "11.0.2.0/24"]
  private_cidr_block = ["11.0.100.0/24", "11.0.101.0/24"]
  eks_cluster_name   = var.eks_cluster_name
}

module "s3" {
  source           = "./modules/S3"
  componentTagName = "s3-Assignment"
  bucket_name      = "bucket-${random_id.rand.hex}"
}

resource "random_id" "rand" {
  byte_length = 4
}

module "eks" {
  source                  = "./modules/eks"
  vpc_id                  = module.vpc.vpc_id
  eks_cluster_name        = var.eks_cluster_name
  cluster_version         = "1.33"
  subnet_ids              = module.vpc.private_subnet_ids
  node_group_desired_size = 2
  node_group_min_size     = 1
  node_group_max_size     = 3
  instance_type           = "t2.medium"
}

module "eks-blueprints-addons" {
  source            = "aws-ia/eks-blueprints-addons/aws"
  version           = "1.22.0"
  cluster_name      = module.eks.eks_cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_metrics_server        = true
  enable_kube_prometheus_stack = true

}




