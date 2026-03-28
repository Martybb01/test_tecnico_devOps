variable "dlq_arn" {
  type        = string
  description = "ARN della DLQ SQS"
}

variable "dlq_queue_url" {
  type        = string
  description = "URL della DLQ SQS"
}

variable "email_notifier_arn" {
  type        = string
  description = "ARN della Lambda email-notifier"
}

variable "email_notifier_function_name" {
  type        = string
  description = "Nome della Lambda email-notifier"
}

variable "data_sync_arn" {
  type        = string
  description = "ARN della Lambda data-sync"
}

variable "data_sync_function_name" {
  type        = string
  description = "Nome della Lambda data-sync"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}
