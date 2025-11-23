variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "cluster_version" {
  type        = string
  default     = "1.33"
  description = "EKS Kubernetes version"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for EKS"
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "node_group_max_size" {
  type    = number
  default = 3
}

variable "node_group_min_size" {
  type    = number
  default = 1
}

variable "instance_type" {
  type    = string
  default = "t3.micro"

}
variable "region" {
  description = "AWS region where EKS will be deployed"
  type        = string
  default = "us-east-1"
}
variable "vpc_id" {
  type = string
}
variable "create_alb_policy" {
  type    = bool
  default = true
}
variable "create_ebs_csi_policy" {
  type    = bool
  default = true
}