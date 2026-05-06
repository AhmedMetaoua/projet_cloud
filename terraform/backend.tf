# ============================================
# BACKEND — ALB + Target Group + Launch Template + ASG + Scaling Policy
# ============================================

# ════════════════════════════════════════
# Application Load Balancer
# ════════════════════════════════════════
# L'ALB reçoit le trafic HTTP et le distribue entre les instances du Target Group.
# Il est placé dans les sous-réseaux PUBLICS pour être accessible depuis internet.
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # false = exposé à internet
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

# ════════════════════════════════════════
# Target Group — groupe d'instances cibles
# ════════════════════════════════════════
# Le Target Group contient les instances EC2 backend.
# L'ALB envoie le trafic vers les instances "saines" du groupe.
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check : l'ALB vérifie régulièrement que l'API répond
  # Si GET /health ne renvoie pas 200, l'instance est retirée du pool
  health_check {
    path                = "/health" # Votre API doit avoir cette route !
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30 # Vérification toutes les 30s
    timeout             = 5  # Timeout après 5s
    healthy_threshold   = 2  # 2 succès → instance saine
    unhealthy_threshold = 3  # 3 échecs → instance retirée
  }

  tags = {
    Name    = "${var.project_name}-tg"
    Project = var.project_name
  }
}

# ════════════════════════════════════════
# Listener — règle de routage de l'ALB
# ════════════════════════════════════════
# Le Listener dit à l'ALB : "pour tout trafic sur le port 80, envoie vers le Target Group"
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ════════════════════════════════════════
# Launch Template — modèle pour les instances backend
# ════════════════════════════════════════
# Le Launch Template décrit comment chaque nouvelle instance doit être configurée.
# L'ASG utilise ce modèle pour créer de nouvelles instances automatiquement.
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.backend.id]

  # Le script User Data est injecté avec les variables (db_host, db_pass, etc.)
  # templatefile() remplace les ${variables} par leurs valeurs réelles
  user_data = base64encode(
    templatefile("${path.module}/user_data_backend.sh", {
      github_repo = var.github_repo
      db_host     = aws_db_instance.main.address # L'endpoint RDS, généré automatiquement
      db_name     = var.db_name
      db_username = var.db_username
      db_password = var.db_password
      app_port    = var.app_port
    })
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-backend"
      Project = var.project_name
    }
  }

  lifecycle {
    create_before_destroy = true # Crée la nouvelle version avant de supprimer l'ancienne
  }
}

# ════════════════════════════════════════
# Auto Scaling Group
# ════════════════════════════════════════
# L'ASG maintient le nombre d'instances souhaité.
# Si une instance tombe en panne → l'ASG en lance une nouvelle automatiquement.
# Si le CPU dépasse 70% → l'ASG en lance d'autres (jusqu'à max 4).
resource "aws_autoscaling_group" "backend" {
  name = "${var.project_name}-asg"

  # Capacité : min=2 (toujours au moins 2), desired=2 (on veut 2), max=4 (jamais plus de 4)
  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  # Réparti sur les deux sous-réseaux privés (une instance par AZ au minimum)
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  # Modèle à utiliser pour créer les instances
  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest" # Toujours utiliser la dernière version du template
  }

  # Enregistrer automatiquement les instances dans le Target Group de l'ALB
  target_group_arns = [aws_lb_target_group.backend.arn]

  # Utiliser le health check de l'ALB (plus fiable que le health check EC2 de base)
  health_check_type         = "ELB"
  health_check_grace_period = 120 # 2 minutes pour que l'instance démarre avant le check

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-instance"
    propagate_at_launch = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_db_instance.main # La DB doit être prête avant que les instances démarrent
  ]
}

# ════════════════════════════════════════
# Scaling Policy — ajout automatique si CPU > 70%
# ════════════════════════════════════════
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${var.project_name}-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0 # Si CPU moyen > 70%, AWS ajoute des instances
  }
}
