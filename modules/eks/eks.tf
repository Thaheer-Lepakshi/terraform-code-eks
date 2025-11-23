# -------------------------------
# EKS Cluster IAM Role
# -------------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.eks_cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -------------------------------
# EKS Cluster
# -------------------------------
resource "aws_eks_cluster" "my_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_attach
  ]
}

# -------------------------------
# Node Group IAM Role
# -------------------------------
resource "aws_iam_role" "node_group_role" {
  name = "${var.eks_cluster_name}-nodegroup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodegroup_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AutoScalingFullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
  role       = aws_iam_role.node_group_role.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "${var.eks_cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types = [var.instance_type]

  tags = {
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/${var.eks_cluster_name}" = "owned"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodegroup_policies
  ]
}

# -------------------------------
# OIDC Provider for IRSA
# -------------------------------
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.my_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.my_cluster.identity[0].oidc[0].issuer
}

# -------------------------------
# EBS CSI Driver IAM Role
# -------------------------------
resource "aws_iam_role" "ebs_csi" {
  name = "${var.eks_cluster_name}-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.oidc.arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

data "aws_iam_policy_document" "ebs_csi_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:EnableFastSnapshotRestores",
      "ec2:ListTagsForResource",
      "ec2:DescribeSnapshotTierStatus",
      "ec2:ListVolumes"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ebs_csi" {
  name   = "${var.eks_cluster_name}-ebs-csi-1"
  policy = data.aws_iam_policy_document.ebs_csi_policy.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = aws_iam_policy.ebs_csi.arn
}

# -------------------------------
# Kubernetes Service Account for EBS CSI
# -------------------------------
resource "kubernetes_service_account" "ebs_csi_sa" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi.arn
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi,
    aws_iam_openid_connect_provider.oidc
  ]
}

# -------------------------------
# EKS Add-on for EBS CSI
# -------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.eks_cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.53.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [
    kubernetes_service_account.ebs_csi_sa
  ]
}

# -------------------------------
# ALB Controller IAM Role & Service Account
# -------------------------------
resource "aws_iam_role" "alb_controller" {
  name = "alb-controller-${replace(replace(replace(replace(timestamp(), "-", ""), ":", ""), "T", ""), "Z", "")}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole",
      Condition = { StringEquals = { "sts:ExternalId" = "eks.amazonaws.com" } }
    }]
  })
}

data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller_policy" {
  count       = var.create_alb_policy ? 1 : 0
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.alb_controller_policy.body
}

resource "kubernetes_service_account" "alb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
}

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.16.0"

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb_controller_sa.metadata[0].name
      }
      region = var.region
      vpcId  = var.vpc_id
      image = { tag = "v2.7.1" }
    })
  ]
}
