# - No output per RDS Proxy perchè è disabilitato e opentofu darebbe errore

output "vpc_id" {
  description = "ID della VPC creata"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs delle subnet private (EKS nodes)"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs delle subnet pubbliche (ALB, NAT)"
  value       = module.vpc.public_subnet_ids
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS del cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Nome del cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority" {
  description = "CA certificate del cluster (base64)"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "node_security_group_id" {
  description = "Security Group ID dei worker nodes"
  value       = module.eks.node_security_group_id
}
