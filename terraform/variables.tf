variable "aws_region" {
  description = "AWS region dove verranno create tutte le risorse"
  type        = string
  default     = "eu-south-1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+-[0-9]$", var.aws_region))
    error_message = "La region AWS deve essere in formato 'eu-south-1', 'us-east-1', etc."
  }
}

variable "project_name" {
  description = "Nome del progetto, usato per tagging e naming delle risorse"
  type        = string
  default     = "app"
}

variable "environment" {
  description = "Ambiente di deployment: prod, staging"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["prod", "staging"], var.environment)
    error_message = "L'environment deve essere prod o staging."
  }
}


variable "vpc_cidr" {
  description = "CIDR block della VPC (es. 10.0.0.0/16 dà 65534 IP disponibili)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr deve essere un CIDR valido (es. 10.0.0.0/16)."
  }
}

variable "availability_zones" {
  description = "Lista di AZ da usare - almeno 2 per alta disponibilità"
  type        = list(string)
  default     = ["eu-south-1a", "eu-south-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Servono almeno 2 Availability Zones per garantire alta disponibilità."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR per le subnet private (EKS nodes, DB). Non raggiungibili direttamente da internet."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR per le subnet pubbliche (ALB, NAT Gateway). Raggiungibili da internet via IGW."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "eks_cluster_version" {
  description = "Versione di Kubernetes per il cluster EKS"
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = "Tipo di istanza EC2 per i worker nodes del cluster"
  type        = string
  default     = "t3a.large"
}

variable "node_desired_size" {
  description = "Numero desiderato di worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Numero minimo di worker nodes (autoscaling)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Numero massimo di worker nodes (autoscaling)"
  type        = number
  default     = 4
}

variable "enable_rds_proxy" {
  description = "Abilita il modulo RDS Proxy. Richiede che esista già un'istanza RDS."
  type        = bool
  default     = false
}

variable "rds_secret_arn" {
  description = "ARN del Secrets Manager secret con le credenziali RDS (richiesto se enable_rds_proxy = true)"
  type        = string
  default     = ""
}
