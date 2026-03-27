locals {
  name = "${var.project_name}-${var.environment}"
}

# chi può parlare con l'API server del cluster?
resource "aws_security_group" "cluster" {
  name        = "${local.name}-eks-cluster-sg"
  description = "Security group per EKS control plane"
  vpc_id      = var.vpc_id

  # i worker nodes devono poter comunicare con l'API server
  ingress {
    description     = "Worker nodes → API server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # qualsiasi protocollo
    cidr_blocks = ["0.0.0.0/0"] # qualsiasi destinazione
  }

  tags = {
    Name = "${local.name}-eks-cluster-sg"
  }
}

resource "aws_security_group" "nodes" {
  name        = "${local.name}-eks-nodes-sg"
  description = "Security group per EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Comunicazione inter-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-eks-nodes-sg"
  }
}

resource "aws_eks_cluster" "main" {
  name     = local.name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = {
    Name = local.name
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    environment = var.environment
    node-type   = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy,
  ]

  tags = {
    Name = "${local.name}-node-group"
  }
}

resource "aws_eks_addon" "core" {
  for_each = toset(["kube-proxy", "coredns", "vpc-cni", "aws-ebs-csi-driver"])

  cluster_name      = aws_eks_cluster.main.name
  addon_name        = each.value
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}
