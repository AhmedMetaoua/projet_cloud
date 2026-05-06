# ============================================
# RÉSEAU — VPC, Subnets, IGW, NAT GW, Routes
# ============================================

# ════════════════════════════════════════
# Le VPC — le réseau isolé
# ════════════════════════════════════════
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # 65 536 adresses IP disponibles
  enable_dns_hostnames = true          # Permet aux instances d'avoir un nom DNS
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ════════════════════════════════════════
# Internet Gateway — la porte vers internet
# ════════════════════════════════════════
# Sans IGW, rien dans le VPC ne peut communiquer avec internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ════════════════════════════════════════
# Sous-réseaux PUBLICS (ALB + Frontend)
# ════════════════════════════════════════
# Les ressources ici reçoivent une IP publique et sont accessibles depuis internet.

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"        # 256 adresses
  availability_zone       = "${var.aws_region}a" # Zone A
  map_public_ip_on_launch = true                 # IP publique automatique

  tags = {
    Name    = "${var.project_name}-subnet-public-a"
    Project = var.project_name
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b" # Zone B — pour la résilience
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-public-b"
    Project = var.project_name
  }
}

# ════════════════════════════════════════
# Sous-réseaux PRIVÉS (Backend EC2 + RDS)
# ════════════════════════════════════════
# Les ressources ici n'ont PAS d'IP publique — inaccessibles directement depuis internet.

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name    = "${var.project_name}-subnet-private-a"
    Project = var.project_name
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name    = "${var.project_name}-subnet-private-b"
    Project = var.project_name
  }
}

# ════════════════════════════════════════
# NAT Gateway — sortie internet pour les privés
# ════════════════════════════════════════
# Permet aux instances privées (backend, RDS) de faire des requêtes sortantes
# (ex: apt install, git clone) SANS être accessibles depuis internet.
#
# Il faut d'abord une IP élastique (adresse IP publique fixe) pour le NAT.

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw] # L'IGW doit exister avant

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id # Placé dans le sous-réseau PUBLIC

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.igw]
}

# ════════════════════════════════════════
# Tables de routage
# ════════════════════════════════════════
# La table de routage dit à chaque paquet réseau "par où tu dois passer".
#
# Table publique : trafic vers internet → IGW
# Table privée   : trafic vers internet → NAT GW (sortie seulement, pas d'entrée)

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                 # Tout le trafic externe
    gateway_id = aws_internet_gateway.igw.id # passe par l'IGW
  }

  tags = {
    Name    = "${var.project_name}-rt-public"
    Project = var.project_name
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id # passe par le NAT GW
  }

  tags = {
    Name    = "${var.project_name}-rt-private"
    Project = var.project_name
  }
}

# ── Associer chaque sous-réseau à sa table de routage ──

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}