# ============================================
# SECURITY GROUPS - Firewalls by layer
# ============================================
#
# Authorized traffic architecture:
#
#   Internet -> ALB port 80
#   ALB -> Backend EC2 API port
#   Backend EC2 -> RDS port 3306 or 5432
#   Internet -> Frontend EC2 port 80
#   Your IP -> Frontend EC2 port 22 SSH
#   Frontend -> Backend port 22 SSH (temporary for debugging)
#
# No other communication is allowed.
# ============================================

# ============================================
# SG 1: ALB - receives internet traffic
# ============================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "ALB : accepte HTTP depuis internet uniquement"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP entrant"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-alb"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# SG 2: Backend EC2 - receives traffic from ALB only
# ============================================
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "Backend EC2 - traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # ← TEMPORARY: remove this block after debugging
  ingress {
    description     = "SSH from frontend for debugging"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-backend"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# SG 3: RDS - receives database traffic from backend only
# ============================================
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "RDS - database traffic from backend only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from backend"
    from_port       = var.db_engine == "postgres" ? 5432 : 3306
    to_port         = var.db_engine == "postgres" ? 5432 : 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-rds"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# SG 4: Frontend EC2 - public HTTP and SSH from my IP
# ============================================
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-frontend"
  description = "Frontend EC2 - public HTTP and SSH from my IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-frontend"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}