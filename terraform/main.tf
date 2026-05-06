# ============================================
# CONFIGURATION PRINCIPALE
# ============================================
# Ce fichier configure :
#   - Le provider AWS (la "connexion" à AWS)
#   - La recherche automatique de l'image Ubuntu
#
# Commandes principales :
#   terraform init     → Télécharger le plugin AWS
#   terraform plan     → Voir ce qui va être créé (sans rien faire)
#   terraform apply    → Créer toutes les ressources
#   terraform destroy  → Tout supprimer proprement
# ============================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Les identifiants sont lus depuis les variables d'environnement :
  # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
}

# ── Trouver automatiquement l'image Ubuntu 22.04 la plus récente ──
# Au lieu de copier-coller un AMI ID qui change selon la région,
# Terraform le trouve tout seul à chaque fois.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (l'éditeur d'Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Enregistrer la clé SSH publique dans AWS ──
resource "aws_key_pair" "deployer" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)

  tags = {
    Name    = var.key_pair_name
    Project = var.project_name
  }
}