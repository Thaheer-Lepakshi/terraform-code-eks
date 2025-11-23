
output "eks_cluster_name" {
  value = aws_eks_cluster.my_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.my_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.my_cluster.certificate_authority[0].data
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.oidc.arn
}
output "cluster_version" {
  value = aws_eks_cluster.my_cluster.version
}