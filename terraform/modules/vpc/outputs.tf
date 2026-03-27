output "vpc_id" {
  description = "ID della VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs delle subnet private"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs delle subnet pubbliche"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ip" {
  description = "IP pubblico del NAT Gateway (utile per whitelist firewall esterni)"
  value       = aws_eip.nat.public_ip
}
