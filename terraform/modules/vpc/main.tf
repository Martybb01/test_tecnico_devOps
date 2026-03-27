# =============================================================================
# VPC MODULE
# =============================================================================
# Crea la rete isolata (Virtual Private Cloud) con:
# - Subnet pubbliche: hanno route verso internet via Internet Gateway (IGW)
#   Usate per: ALB (load balancer pubblico), NAT Gateway
# - Subnet private: NON hanno route diretta verso internet
#   Usate per: EKS worker nodes, RDS, Redis - mai esposti direttamente
# - NAT Gateway: permette alle risorse nelle subnet private di fare
#   richieste OUTBOUND verso internet (es. pull di immagini Docker)
#   senza essere raggiungibili dall'esterno (inbound bloccato)

locals {
  name = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # enable_dns_hostnames necessario per EKS - i nodes devono risolvere
  # i nomi DNS interni AWS (es. nome RDS endpoint)
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

# -----------------------------------------------------------------------------
# SUBNET PUBBLICHE
# I worker EKS non vivono qui - solo ALB e NAT Gateway
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Le istanze lanciate in subnet pubbliche ricevono un IP pubblico automaticamente
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-${var.azs[count.index]}"
    # Questo tag dice al AWS Load Balancer Controller di usare queste subnet
    # per creare ALB pubblici (ingress di tipo internet-facing)
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.name}"       = "shared"
  }
}

# -----------------------------------------------------------------------------
# SUBNET PRIVATE
# Qui vivono i worker nodes EKS, RDS, Redis - mai esposti direttamente
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name}-private-${var.azs[count.index]}"
    # Questo tag dice all'AWS LBC di usare queste subnet per internal ALB
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.name}"       = "shared"
  }
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# Permette il traffico tra la VPC (public subnet e load balancer) e internet (in entrambe le direzioni)
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-igw"
  }
}

# -----------------------------------------------------------------------------
# ELASTIC IP per NAT Gateway
# Il NAT Gateway ha bisogno di un IP pubblico statico
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT GATEWAY
# Uno solo, nella prima subnet pubblica.
# Scelta costi: un NAT per AZ è più resiliente (se una AZ cade il traffico
# della altra AZ non passa per il NAT caduto) ma costa di più.
# Per produzione con requisiti di HA si potrebbero creare 2 NAT.
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${local.name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# ROUTE TABLES
# Definiscono "dove mando il traffico" per ogni subnet
# -----------------------------------------------------------------------------

# Route table pubblica: tutto il traffico non-locale va all'IGW (internet)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name}-public-rt"
  }
}

# Route table privata: il traffico internet va al NAT Gateway (uscita solo)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name}-private-rt"
  }
}

# Associa le route table alle rispettive subnet
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
