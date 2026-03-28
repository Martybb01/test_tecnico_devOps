output "function_arn" {
  description = "ARN della Lambda"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Nome della Lambda"
  value       = aws_lambda_function.this.function_name
}
