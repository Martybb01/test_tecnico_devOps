variable "project_name" {
  type    = string
  default = "devops-test"
}

variable "environment" {
  description = "Ambiente di deployment: prod, staging"
  type        = string
  default     = "staging"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet private per le Lambda con VPC (order-processor, data-sync)"
  default     = []
}

variable "lambda_security_group_ids" {
  type        = list(string)
  description = "Security group per le Lambda con VPC"
  default     = []
}

variable "db_host" {
  type        = string
  description = "Endpoint RDS"
  default     = ""
}

variable "cache_endpoint" {
  type        = string
  description = "Endpoint ElastiCache Redis"
  default     = ""
}

variable "data_lake_bucket" {
  type        = string
  description = "Nome bucket S3 destinazione del sync RDS → S3 in data-sync"
  default     = ""
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN del topic SNS"
  default     = ""
}

variable "event_bus_arn" {
  type        = string
  description = "ARN del bus order-events"
  default     = ""
}

variable "data_lake_bucket_arn" {
  type        = string
  description = "ARN del bucket S3 data lake"
  default     = ""
}

variable "kms_key_arn" {
  type        = string
  description = "ARN chiave KMS per encryption oggetti S3"
  default     = ""
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN della tabella DynamoDB"
  default     = ""
}

variable "ses_sender_arn" {
  type        = string
  description = "ARN identità SES"
  default     = ""
}
