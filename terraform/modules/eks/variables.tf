variable "project_name" {
  description = "Nome del progetto"
  type        = string
}

variable "environment" {
  description = "Ambiente (prod, staging)"
  type        = string
}

variable "cluster_version" {
  description = "Versione Kubernetes per EKS"
  type        = string
}

variable "vpc_id" {
  description = "ID della VPC dove creare il cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs delle subnet private per i worker nodes"
  type        = list(string)
}

variable "node_instance_type" {
  description = "Tipo di istanza EC2 per i worker nodes"
  type        = string
}

variable "node_desired_size" {
  description = "Numero desiderato di worker nodes"
  type        = number
}

variable "node_min_size" {
  description = "Numero minimo di worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Numero massimo di worker nodes"
  type        = number
}
