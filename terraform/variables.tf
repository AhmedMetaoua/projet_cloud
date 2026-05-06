# ============================================
# VARIABLES — Paramètres de l'infrastructure
# ============================================

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Préfixe pour nommer toutes les ressources"
  type        = string
  default     = "projet-cloud"
}

variable "instance_type" {
  description = "Type d'instance EC2 (backend et frontend)"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH dans AWS"
  type        = string
  default     = "projet-cloud-key"
}

variable "public_key_path" {
  description = "Chemin vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/projet-cloud-key.pub"
}

variable "private_key_path" {
  description = "Chemin vers la clé privée SSH (pour SSH manuel)"
  type        = string
  default     = "~/.ssh/projet-cloud-key"
}

variable "my_ip" {
  description = "Votre IP publique pour autoriser le SSH (format : x.x.x.x/32)"
  type        = string
  # Pas de valeur par défaut — vous devez la fournir dans terraform.tfvars
}

variable "app_port" {
  description = "Port sur lequel tourne votre API backend"
  type        = number
  default     = 3000
}

variable "github_repo" {
  description = "URL complète de votre dépôt GitHub (ex: https://github.com/user/repo.git)"
  type        = string
}

# ── Variables RDS ──

variable "db_engine" {
  description = "Moteur de base de données : mysql ou postgres"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Version du moteur"
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "Nom de la base de données"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Nom d'utilisateur RDS"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Mot de passe RDS — ne pas écrire ici, mettre dans terraform.tfvars"
  type        = string
  sensitive   = true # Terraform masquera cette valeur dans les logs
}