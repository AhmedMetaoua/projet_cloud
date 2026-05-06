# ============================================
# OUTPUTS — Infos affichées après terraform apply
# ============================================

output "alb_dns_name" {
  description = "URL de votre API backend (via l'ALB)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "frontend_public_ip" {
  description = "IP publique du serveur frontend"
  value       = aws_instance.frontend.public_ip
}

output "frontend_url" {
  description = "URL de votre frontend"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "rds_endpoint" {
  description = "Endpoint de la base de données (à utiliser dans DB_HOST)"
  value       = aws_db_instance.main.address
  sensitive   = false
}

output "ssh_frontend" {
  description = "Commande SSH pour se connecter au frontend"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.frontend.public_ip}"
}

output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group"
  value       = aws_autoscaling_group.backend.name
}