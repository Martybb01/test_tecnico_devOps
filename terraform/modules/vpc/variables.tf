variable "project_name" {
  description = "Nome del progetto per naming e tagging"
  type        = string
}

variable "environment" {
  description = "Ambiente (prod, staging)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block della VPC"
  type        = string
}

variable "azs" {
  description = "Lista di Availability Zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks per le subnet private"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks per le subnet pubbliche"
  type        = list(string)
}
