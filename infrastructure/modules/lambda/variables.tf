variable "function_name" {
  type        = string
  description = "Nome della Lambda"
}

variable "handler" {
  type        = string
  description = "file.nomefunzione"
}

variable "runtime" {
  type        = string
  description = "Runtime Lambda"
}

variable "timeout" {
  type        = number
  description = "Timeout in secondi"
}

variable "memory_size" {
  type        = number
  description = "Memoria allocata in MB"
}

variable "source_dir" {
  type        = string
  description = "Path alla directory con il codice della Lambda"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "reserved_concurrent_executions" {
  type        = number
  description = "Concorrenza riservata (-1 = nessun limite)"
  default     = -1
}

variable "environment_variables" {
  type        = map(string)
  description = "Variabili d'ambiente passate alla Lambda a runtime"
  default     = {}
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs per vpc_config"
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs per vpc_config"
  default     = []
}

variable "ephemeral_storage_size" {
  type        = number
  description = "Dimensione /tmp in MB"
  default     = 512
}

variable "enable_xray" {
  type        = bool
  description = "Abilita X-Ray tracing"
  default     = false
}

variable "event_bus_arn" {
  type        = string
  description = "ARN dell'EventBridge bus su cui la Lambda può fare PutEvents"
  default     = ""
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN del topic SNS su cui la Lambda può fare Publish"
  default     = ""
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN della tabella DynamoDB"
  default     = ""
}

variable "data_lake_bucket_arn" {
  type        = string
  description = "ARN del bucket S3 data lake"
  default     = ""
}

variable "kms_key_arn" {
  type        = string
  description = "ARN della chiave KMS per encryption S3"
  default     = ""
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN della SQS queue da consumare"
  default     = ""
}

variable "enable_sqs_trigger" {
  type        = bool
  description = "Abilita il permesso IAM per consumare messaggi SQS"
  default     = false
}

variable "ses_sender_arn" {
  type        = string
  description = "ARN dell'identità SES verificata"
  default     = ""
}
