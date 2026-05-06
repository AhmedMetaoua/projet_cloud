# ============================================
# BASE DE DONNÉES — Amazon RDS
# ============================================

# ── Subnet Group : indique à RDS dans quels sous-réseaux se déployer ──
# RDS a besoin d'au moins 2 sous-réseaux dans 2 AZ différentes (bonne pratique AWS)
resource "aws_db_subnet_group" "rds" {
  name = "${var.project_name}-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

# ── L'instance RDS ──
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-db"
  engine            = var.db_engine         # "mysql" ou "postgres"
  engine_version    = var.db_engine_version # "8.0" pour MySQL
  port              = var.db_engine == "postgres" ? 5432 : 3306
  instance_class    = "db.t3.micro" # Éligible au Free Tier
  allocated_storage = 20            # 20 Go de stockage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password # Vient de terraform.tfvars — jamais en dur dans le code !

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Important : jamais accessible depuis internet
  publicly_accessible = false

  # Pour le projet — supprime le snapshot final lors de terraform destroy
  skip_final_snapshot = true

  tags = {
    Name    = "${var.project_name}-rds"
    Project = var.project_name
  }
}