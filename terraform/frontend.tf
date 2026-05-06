# ============================================
# FRONTEND — Instance EC2 publique
# ============================================
# Cette instance sert votre HTML/CSS/JS aux navigateurs des utilisateurs.
# Elle est placée dans un sous-réseau PUBLIC pour être accessible directement.
resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id # Sous-réseau PUBLIC
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true # Nécessaire pour être accessible depuis internet

  user_data = base64encode(
    templatefile("${path.module}/user_data_frontend.sh", {
      github_repo  = var.github_repo
      alb_dns_name = aws_lb.main.dns_name # L'URL de l'ALB, injectée dans le config frontend
      app_port     = var.app_port
    })
  )

  tags = {
    Name    = "${var.project_name}-frontend"
    Project = var.project_name
  }

  # Attendre que l'ALB soit prêt avant de démarrer le frontend
  # (le frontend a besoin du DNS de l'ALB pour configurer ses appels API)
  depends_on = [aws_lb.main]
}