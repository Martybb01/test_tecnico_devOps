# crea risorse kube direttamente via OpenTofu

# legge info esistenti da AWS
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint # output del cluster endopoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
  token                  = data.aws_eks_cluster_auth.main.token
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = "app-${var.environment}"

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  depends_on = [module.eks]
}

