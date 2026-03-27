variable "project_name" {
  description = "Nome del progetto"
  type        = string
}

variable "environment" {
  description = "Ambiente (prod, staging)"
  type        = string
}

variable "vpc_id" {
  description = "ID della VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs delle subnet private dove posizionare il proxy"
  type        = list(string)
}

variable "db_secret_arn" {
  description = "ARN del Secrets Manager secret con le credenziali RDS"
  type        = string
}
