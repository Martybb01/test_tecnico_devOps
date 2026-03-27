output "proxy_endpoint" {
  description = "Endpoint del RDS Proxy - le app si connettono a questo invece che direttamente al DB"
  value       = aws_db_proxy.main.endpoint
}

output "proxy_arn" {
  description = "ARN del RDS Proxy"
  value       = aws_db_proxy.main.arn
}
