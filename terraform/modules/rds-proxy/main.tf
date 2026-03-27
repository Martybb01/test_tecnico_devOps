# RDS proxy si interpone tra l'app e il db RDS ed è utile per connection pooling, IAM auth tramite token e failover più rapido perchè le app non si disconnettono
# Per farlo funzionare --> deve esistere un RDS istance + secrets su AWS con le cred del DB

locals {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_security_group" "rds_proxy" {
  name        = "${local.name}-rds-proxy-sg"
  description = "Security group per RDS Proxy"
  vpc_id      = var.vpc_id

  # solo risorse dentro la VPC (no esterne) possono connettersi al proxy
  ingress {
    description = "MySQL da EKS nodes e Lambda"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-rds-proxy-sg"
  }
}

resource "aws_iam_role" "rds_proxy" {
  name = "${local.name}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"  # --> solo rds può assumere questo ruolo
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rds_proxy_secrets" {
  name = "${local.name}-rds-proxy-secrets-policy"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [var.db_secret_arn]
    }]
  })
}

resource "aws_db_proxy" "main" {
  name                   = "${local.name}-rds-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]
  vpc_subnet_ids         = var.subnet_ids

  auth {
    auth_scheme = "SECRETS"
    description = "Credenziali DB da Secrets Manager"
    iam_auth    = "REQUIRED"
    secret_arn  = var.db_secret_arn
  }

  tags = {
    Name = "${local.name}-rds-proxy"
  }
}

# Target group: punta al RDS instance/cluster reale
resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}
