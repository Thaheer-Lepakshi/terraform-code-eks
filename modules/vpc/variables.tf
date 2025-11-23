variable "region" {}
variable "vpc_cidr_block" {}
variable "public_cidr_block" {}
variable "private_cidr_block" {}
variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}