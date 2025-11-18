output "eks_cluster_endpoint" {
  description = "EKS API endpoint for connecting to the cluster"
  value       = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks.name
}

output "eks_cluster_ca" {
  description = "EKS cluster CA certificate (base64)"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}
