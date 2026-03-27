aws_region   = "eu-south-1"
project_name = "app"
environment  = "prod"

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["eu-south-1a", "eu-south-1b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

eks_cluster_version = "1.34" 
node_instance_type  = "t3a.large"
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 4

enable_rds_proxy = false
