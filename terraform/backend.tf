terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  backend "s3" {
    bucket         = "app-tfstate-prod"
    key            = "eks/terraform.tfstate"
    region         = "eu-south-1"
    use_lockfile   = true # S3 lockin nativo al posto di usare DynamoDB
  }
}
