# il flusso è: il messaggio in dlq che email-notifier non è riuscito a processare viene letto dal dlq-processor (lambda) che logga l'errore su cloudwatch

resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-${var.environment}-email-notifier-dlq"

  message_retention_seconds = 1209600  # 14 giorni

  visibility_timeout_seconds = 300 # invisibile agli altri consumers per 300s

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


output "dlq_arn" {
  description = "ARN della DLQ"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_queue_url" {
  description = "URL della DLQ"
  value       = aws_sqs_queue.dlq.url
}

