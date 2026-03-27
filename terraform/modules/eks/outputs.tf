output "cluster_name" {
  description = "Nome del cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS del cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "CA certificate del cluster (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "node_security_group_id" {
  description = "Security Group ID dei worker nodes"
  value       = aws_security_group.nodes.id
}

