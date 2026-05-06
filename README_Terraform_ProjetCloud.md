# Projet Cloud : Déploiement Full-Stack sur AWS avec Terraform

## Contexte

Ce projet est la mise en pratique de toute l'infrastructure AWS vue en cours, mais cette fois **codifiée avec Terraform**. Au lieu de cliquer dans la console AWS pour créer votre VPC, vos subnets, votre ALB et votre ASG, vous allez décrire toute cette infrastructure en code HCL — et Terraform se chargera de la construire pour vous.

> ⚠️ **Rappel du sujet :** N'utilisez PAS Elastic Beanstalk. Vous devez construire et contrôler chaque composant vous-même : VPC, ALB, ASG, Launch Template, RDS. Avec Terraform, vous faites exactement ça — mais en code.

> ⚠️ **Prérequis :**
> - Avoir un compte **AWS Academy** avec accès au **Learner Lab** via Vocareum
> - Avoir une application full-stack (backend API + frontend) sur GitHub
> - Connaître les bases du terminal (naviguer dans les dossiers, exécuter des commandes)

## Durée estimée : 4 à 5 heures

---

# 🤔 PARTIE 0 : Pourquoi Terraform pour ce projet ?

## Le problème avec la console AWS

Sans Terraform, vous devriez créer à la main, dans la console AWS, **une vingtaine de ressources** dans le bon ordre :

```
1. Créer le VPC               → cliquer
2. Créer 4 sous-réseaux       → cliquer × 4
3. Créer l'Internet Gateway   → cliquer, puis attacher au VPC
4. Créer la NAT Gateway       → cliquer, allouer une IP élastique
5. Créer 2 tables de routage  → cliquer, ajouter des routes, associer
6. Créer 4 Security Groups    → cliquer × 4, ajouter des règles
7. Créer le Subnet Group RDS  → cliquer
8. Lancer l'instance RDS      → cliquer
9. Créer le Launch Template   → cliquer, écrire le User Data
10. Créer le Target Group     → cliquer, configurer le health check
11. Créer l'ALB               → cliquer, configurer le listener
12. Créer l'ASG               → cliquer, configurer min/desired/max
13. Créer la Scaling Policy   → cliquer
14. Lancer l'EC2 frontend     → cliquer
```

Si vous faites une erreur, vous devez tout recommencer. Si votre lab expire, vous recommencez depuis zéro. Si vous voulez tout supprimer à la fin, vous devez retrouver et supprimer chaque ressource une par une.

## Ce que Terraform change

```
Sans Terraform                      Avec Terraform
──────────────────                  ──────────────────
😰 ~80 clics dans AWS               😊 terraform apply
🐛 Erreur = tout recommencer        🔁 Corriger le code → re-apply
📋 Infra documentée en captures     📄 Infra documentée en code
🗑️ Supprimer = chercher partout     🗑️ terraform destroy → tout supprimé
```

**Terraform** résout ces problèmes : vous décrivez ce que vous voulez dans des fichiers `.tf`, et Terraform crée (ou supprime) tout d'un seul coup.

## Les composants à construire et leur rôle

Voici ce que vous allez déployer, et pourquoi chaque pièce existe :

```
Internet
    │
    │ HTTP :80
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  SOUS-RÉSEAUX PUBLICS (AZ-A et AZ-B)                            │
│                                                                 │
│  ┌──────────────┐     ┌────────────────┐                        │
│  │   ALB         │     │  EC2 Frontend  │                        │
│  │ (répartiteur) │     │  (HTML/CSS/JS) │                        │
│  └──────┬───────┘     └────────────────┘                        │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │ trafic HTTP vers le backend
          ▼
┌─────────────────────────────────────────────────────────────────┐
│  SOUS-RÉSEAUX PRIVÉS (AZ-A et AZ-B)                             │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐                           │
│  │  EC2 Backend │    │  EC2 Backend │  ← ASG gère ces instances │
│  │   (API)      │    │   (API)      │                           │
│  └──────┬───────┘    └──────┬───────┘                           │
│         │                  │                                    │
│         └────────┬─────────┘                                    │
│                  │ SQL                                          │
│         ┌────────▼────────┐                                     │
│         │   Amazon RDS    │                                     │
│         │  (MySQL/Postgres)│                                    │
│         └─────────────────┘                                     │
└─────────────────────────────────────────────────────────────────┘
```

| Composant | Rôle | Où ? |
|-----------|------|------|
| **VPC + Subnets** | Le réseau isolé de votre app | Partout |
| **Internet Gateway** | La porte d'entrée depuis internet | VPC |
| **NAT Gateway** | Permet aux serveurs privés d'accéder à internet (pour `apt install`, `git clone`) | Sous-réseau public |
| **ALB** | Répartit le trafic entre les instances backend | Sous-réseaux publics |
| **Launch Template + ASG** | Lance et remplace automatiquement les instances backend | Sous-réseaux privés |
| **EC2 Frontend** | Sert votre HTML/CSS/JS aux navigateurs | Sous-réseau public |
| **RDS** | Base de données relationnelle | Sous-réseaux privés |
| **Security Groups** | Pare-feux — contrôlent qui parle à qui | Chaque couche |

**❓ Questions de compréhension :**
1. Pourquoi le backend est-il dans un sous-réseau **privé** et non public ?
2. Pourquoi a-t-on besoin d'une NAT Gateway si le backend est privé ?
3. Que se passe-t-il si une instance EC2 backend tombe en panne ? Qui la remplace ?

---

# 🏗️ PARTIE 1 : Préparation

## Étape 1.1 : Démarrer votre lab AWS

1. Connectez-vous à **AWS Academy** via Vocareum
2. Cliquez sur **Start Lab** et attendez que le voyant passe au **vert 🟢**
3. Cliquez sur **AWS Details** → **Show** à côté de "AWS CLI" — gardez cette page ouverte, vous en aurez besoin bientôt

> 💡 **Le voyant vert** = votre lab est actif. **Voyant rouge** = vos identifiants ont expiré → Stop Lab → Start Lab.

## Étape 1.2 : Installer Terraform

Terraform est un programme que vous installez **sur votre ordinateur** (pas sur AWS).

<details>
<summary>🍎 macOS</summary>

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```
</details>

<details>
<summary>🐧 Linux (Ubuntu/Debian)</summary>

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```
</details>

<details>
<summary>🪟 Windows</summary>

```powershell
choco install terraform
```
Ou téléchargez depuis https://developer.hashicorp.com/terraform/downloads
</details>

**Vérifiez :**

```bash
terraform --version
# Terraform v1.x.x ✅
```

## Étape 1.3 : Créer une clé SSH

Vous en aurez besoin pour accéder à l'instance frontend et pour déboguer si nécessaire.

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/projet-cloud-key -N ""
chmod 400 ~/.ssh/projet-cloud-key
```

> 💡 Deux fichiers sont créés :
> - `~/.ssh/projet-cloud-key` → **clé privée** (ne la partagez jamais !)
> - `~/.ssh/projet-cloud-key.pub` → **clé publique** (celle qu'AWS mettra sur vos serveurs)

## Étape 1.4 : Trouver votre adresse IP publique

Elle sera utilisée pour autoriser le SSH uniquement depuis votre machine.

```bash
curl ifconfig.me
# Exemple : 86.238.42.123
```

📝 **Notez cette IP**, vous en aurez besoin dans le fichier `terraform.tfvars`.

## Étape 1.5 : Configurer vos identifiants AWS

Terraform a besoin de vos identifiants Vocareum pour créer des ressources sur votre compte.

```bash
export AWS_ACCESS_KEY_ID="copiez_depuis_vocareum"
export AWS_SECRET_ACCESS_KEY="copiez_depuis_vocareum"
export AWS_SESSION_TOKEN="copiez_depuis_vocareum"
```

**Vérifiez :**
```bash
aws sts get-caller-identity
# Doit afficher un JSON avec votre Account ID ✅
```

> ⚠️ **À refaire** à chaque fois que le lab expire (Stop Lab → Start Lab → re-exporter).

---

# 🗂️ PARTIE 2 : Structure des fichiers Terraform

Créez un dossier `terraform/` à la racine de votre projet :

```bash
mkdir terraform && cd terraform
```

Voici **l'ensemble des fichiers** que vous allez créer et à quoi sert chacun :

```
terraform/
├── main.tf                  ← Provider AWS + data sources (AMI Ubuntu)
├── variables.tf             ← Déclaration de tous les paramètres
├── outputs.tf               ← Infos affichées après apply (DNS ALB, IP frontend...)
├── terraform.tfvars         ← VOS valeurs (non commité sur GitHub)
│
├── vpc.tf                   ← VPC, subnets, IGW, NAT GW, tables de routage
├── security_groups.tf       ← Les 4 pare-feux (ALB, backend, RDS, frontend)
├── rds.tf                   ← Base de données RDS
├── backend.tf               ← ALB, Target Group, Launch Template, ASG, Scaling Policy
├── frontend.tf              ← Instance EC2 frontend
│
├── user_data_backend.sh     ← Script de démarrage des instances backend
├── user_data_frontend.sh    ← Script de démarrage de l'instance frontend
└── .gitignore               ← Fichiers à ne PAS mettre sur GitHub
```

> 💡 **Pourquoi autant de fichiers ?** Terraform les fusionne tous automatiquement — c'est juste pour que vous vous y retrouviez. Un seul gros `main.tf` avec 500 lignes serait illisible.

---

# 🔧 PARTIE 3 : Fichiers de configuration Terraform

## Fichier 1 : `variables.tf` — Les paramètres

Ce fichier **déclare** tous les paramètres utilisables dans la configuration. Pensez-y comme la liste de tous les réglages possibles.

Créez `terraform/variables.tf` :

```hcl
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
  sensitive   = true   # Terraform masquera cette valeur dans les logs
}
```

## Fichier 2 : `main.tf` — Provider et image serveur

Créez `terraform/main.tf` :

```hcl
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
  owners      = ["099720109477"]  # Canonical (l'éditeur d'Ubuntu)

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
```

## Fichier 3 : `vpc.tf` — Le réseau

C'est le socle de toute l'infrastructure. Tout le reste sera créé **à l'intérieur** de ce VPC.

> 💡 **Analogie :** Imaginez que le VPC est un immeuble privé. Les sous-réseaux publics sont le hall d'entrée visible de la rue. Les sous-réseaux privés sont les bureaux du fond — seul le personnel autorisé y accède.

Créez `terraform/vpc.tf` :

```hcl
# ============================================
# RÉSEAU — VPC, Subnets, IGW, NAT GW, Routes
# ============================================

# ════════════════════════════════════════
# Le VPC — le réseau isolé
# ════════════════════════════════════════
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"   # 65 536 adresses IP disponibles
  enable_dns_hostnames = true             # Permet aux instances d'avoir un nom DNS
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
  cidr_block              = "10.0.1.0/24"         # 256 adresses
  availability_zone       = "${var.aws_region}a"   # Zone A
  map_public_ip_on_launch = true                   # IP publique automatique

  tags = {
    Name    = "${var.project_name}-subnet-public-a"
    Project = var.project_name
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"   # Zone B — pour la résilience
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
  depends_on = [aws_internet_gateway.igw]  # L'IGW doit exister avant

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id   # Placé dans le sous-réseau PUBLIC

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
    cidr_block = "0.0.0.0/0"                  # Tout le trafic externe
    gateway_id = aws_internet_gateway.igw.id   # passe par l'IGW
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
    nat_gateway_id = aws_nat_gateway.nat.id   # passe par le NAT GW
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
```

## Fichier 4 : `security_groups.tf` — Les pare-feux

C'est l'une des parties les plus importantes du projet. Les Security Groups contrôlent **qui peut parler à qui**.

> 🔒 **Règle d'or :** Le principe du moindre privilège. Chaque composant n'accepte que le trafic dont il a strictement besoin — rien de plus.

Créez `terraform/security_groups.tf` :

```hcl
# ============================================
# SECURITY GROUPS — Pare-feux par couche
# ============================================
#
# Architecture des flux autorisés :
#
#   Internet → ALB (port 80)
#   ALB → Backend EC2 (port API)
#   Backend EC2 → RDS (port 3306/5432)
#   Internet → Frontend EC2 (port 80)
#   Votre IP → Frontend EC2 (port 22, SSH)
#
# Aucune autre communication n'est autorisée.
# ============================================

# ════════════════════════════════════════
# SG 1 : ALB — reçoit le trafic internet
# ════════════════════════════════════════
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "ALB : accepte HTTP depuis internet uniquement"
  vpc_id      = aws_vpc.main.id

  # HTTP depuis n'importe où sur internet
  ingress {
    description = "HTTP entrant"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # L'ALB peut sortir vers les instances du Target Group
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
}

# ════════════════════════════════════════
# SG 2 : Backend EC2 — reçoit trafic de l'ALB seulement
# ════════════════════════════════════════
# ⚠️ Jamais depuis internet directement !
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "Backend EC2 : trafic entrant uniquement depuis le SG de l'ALB"
  vpc_id      = aws_vpc.main.id

  # Accepte uniquement les connexions venant du Security Group de l'ALB
  # (pas depuis 0.0.0.0/0 — même si le port est le bon !)
  ingress {
    description     = "Trafic API depuis l'ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ← référence au SG ALB
  }

  # Sortie libre pour git clone, npm install, etc.
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
}

# ════════════════════════════════════════
# SG 3 : RDS — reçoit trafic du backend seulement
# ════════════════════════════════════════
# ⚠️ Jamais depuis internet, jamais depuis votre ordinateur !
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "RDS : trafic entrant uniquement depuis le SG backend"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL depuis le backend"
    from_port       = 3306     # Changez en 5432 si vous utilisez PostgreSQL
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]  # ← backend seulement
    # ⚠️ JAMAIS cidr_blocks = ["0.0.0.0/0"] ici !
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
}

# ════════════════════════════════════════
# SG 4 : Frontend EC2 — HTTP public + SSH limité
# ════════════════════════════════════════
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-frontend"
  description = "Frontend EC2 : HTTP public + SSH depuis votre IP seulement"
  vpc_id      = aws_vpc.main.id

  # HTTP depuis n'importe où (les visiteurs accèdent au site)
  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH depuis votre IP uniquement (débogage)
  ingress {
    description = "SSH depuis mon IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]   # ← uniquement votre IP, pas 0.0.0.0/0
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
}
```

> 🔒 **Note d'évaluation :** Ces Security Groups seront vérifiés pendant la démonstration. Assurez-vous de ne jamais mettre `0.0.0.0/0` sur les ports de la base de données (3306/5432) ou sur le port de l'API backend.

**❓ Questions de compréhension :**
1. Pourquoi utilise-t-on `security_groups = [...]` plutôt que `cidr_blocks` pour référencer l'ALB dans le SG backend ?
2. Que se passerait-il si vous mettiez `0.0.0.0/0` dans le SG RDS sur le port 3306 ?

---

## Fichier 5 : `rds.tf` — La base de données

La base de données est dans les sous-réseaux privés, inaccessible depuis internet.

Créez `terraform/rds.tf` :

```hcl
# ============================================
# BASE DE DONNÉES — Amazon RDS
# ============================================

# ── Subnet Group : indique à RDS dans quels sous-réseaux se déployer ──
# RDS a besoin d'au moins 2 sous-réseaux dans 2 AZ différentes (bonne pratique AWS)
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-db-subnet-group"
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
  engine            = var.db_engine          # "mysql" ou "postgres"
  engine_version    = var.db_engine_version  # "8.0" pour MySQL
  instance_class    = "db.t3.micro"          # Éligible au Free Tier
  allocated_storage = 20                     # 20 Go de stockage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password   # Vient de terraform.tfvars — jamais en dur dans le code !

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
```

---

## Fichier 6 : `user_data_backend.sh` — Script de démarrage du backend

Ce script s'exécute **automatiquement** sur chaque nouvelle instance EC2 créée par l'ASG. Il clone votre code, installe les dépendances et démarre l'API — sans connexion SSH manuelle.

Créez `terraform/user_data_backend.sh` :

```bash
#!/bin/bash
set -e   # Arrêter le script si une commande échoue

# ── Mise à jour du système et installation des outils ──
apt update -y
apt install -y git nodejs npm

# ── Cloner votre application ──
cd /home/ubuntu
git clone ${github_repo} app
cd app

# ── Installer les dépendances ──
npm install

# ── Injecter les variables d'environnement (jamais en dur dans le code !) ──
export DB_HOST="${db_host}"
export DB_NAME="${db_name}"
export DB_USER="${db_username}"
export DB_PASS="${db_password}"
export PORT="${app_port}"
export NODE_ENV="production"

# ── Écrire les variables dans un fichier .env pour la persistance ──
cat > /home/ubuntu/app/.env <<EOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASS=${db_password}
PORT=${app_port}
NODE_ENV=production
EOF

# ── Démarrer l'application ──
npm start &

# ── (Optionnel) Installer PM2 pour une gestion plus robuste du processus ──
# npm install -g pm2
# pm2 start npm -- start
# pm2 startup && pm2 save
```

> 💡 Remarquez que les valeurs comme `${db_host}`, `${db_password}` etc. sont des **variables Terraform** — elles seront remplacées automatiquement par `templatefile()` (voir `backend.tf` plus bas).

---

## Fichier 7 : `user_data_frontend.sh` — Script de démarrage du frontend

Créez `terraform/user_data_frontend.sh` :

```bash
#!/bin/bash
set -e

# ── Mise à jour et installation de nginx ──
apt update -y
apt install -y nginx git

# ── Cloner votre frontend ──
cd /tmp
git clone ${github_repo} frontend-app

# ── Copier les fichiers dans le dossier de nginx ──
cp -r /tmp/frontend-app/frontend/* /var/www/html/
# Adaptez ce chemin selon la structure de votre dépôt

# ── Remplacer l'URL de l'API par le DNS de l'ALB ──
# Votre frontend doit appeler l'ALB, jamais directement une IP EC2 !
find /var/www/html -name "*.js" -o -name "*.html" | xargs sed -i \
  "s|http://localhost:${app_port}|http://${alb_dns_name}|g"

# ── Démarrer nginx ──
systemctl start nginx
systemctl enable nginx

echo "Frontend déployé avec succès ✅"
```

> 📌 **Important :** Le frontend doit appeler le backend via le nom DNS de l'ALB — par exemple `http://projet-cloud-alb-1234567890.us-east-1.elb.amazonaws.com` — jamais directement via l'IP d'une instance EC2 backend.

---

## Fichier 8 : `backend.tf` — ALB, ASG, Launch Template

C'est le cœur du backend. Ce fichier crée toute la machinerie qui permet à votre API d'être disponible, résiliente et scalable.

Créez `terraform/backend.tf` :

```hcl
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
  internal           = false                   # false = exposé à internet
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
    path                = "/health"       # Votre API doit avoir cette route !
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30              # Vérification toutes les 30s
    timeout             = 5               # Timeout après 5s
    healthy_threshold   = 2               # 2 succès → instance saine
    unhealthy_threshold = 3               # 3 échecs → instance retirée
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
      db_host     = aws_db_instance.main.address   # L'endpoint RDS, généré automatiquement
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
    create_before_destroy = true   # Crée la nouvelle version avant de supprimer l'ancienne
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
    version = "$Latest"   # Toujours utiliser la dernière version du template
  }

  # Enregistrer automatiquement les instances dans le Target Group de l'ALB
  target_group_arns = [aws_lb_target_group.backend.arn]

  # Utiliser le health check de l'ALB (plus fiable que le health check EC2 de base)
  health_check_type         = "ELB"
  health_check_grace_period = 120   # 2 minutes pour que l'instance démarre avant le check

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-instance"
    propagate_at_launch = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_db_instance.main   # La DB doit être prête avant que les instances démarrent
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
    target_value = 70.0   # Si CPU moyen > 70%, AWS ajoute des instances
  }
}
```

---

## Fichier 9 : `frontend.tf` — L'instance EC2 frontend

Créez `terraform/frontend.tf` :

```hcl
# ============================================
# FRONTEND — Instance EC2 publique
# ============================================
# Cette instance sert votre HTML/CSS/JS aux navigateurs des utilisateurs.
# Elle est placée dans un sous-réseau PUBLIC pour être accessible directement.
resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id  # Sous-réseau PUBLIC
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true   # Nécessaire pour être accessible depuis internet

  user_data = base64encode(
    templatefile("${path.module}/user_data_frontend.sh", {
      github_repo  = var.github_repo
      alb_dns_name = aws_lb.main.dns_name  # L'URL de l'ALB, injectée dans le config frontend
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
```

---

## Fichier 10 : `outputs.tf` — Les informations utiles affichées

Après `terraform apply`, ces informations s'affichent dans le terminal.

Créez `terraform/outputs.tf` :

```hcl
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
```

---

## Fichier 11 : `terraform.tfvars` — Vos valeurs personnelles

Créez `terraform/terraform.tfvars` :

```hcl
# ============================================
# VOS VALEURS PERSONNELLES
# ============================================
# ⚠️ Ce fichier contient des informations sensibles (mot de passe DB).
#    Il est dans .gitignore — ne le commitez JAMAIS sur GitHub !

aws_region   = "us-east-1"
project_name = "projet-cloud"

# Type d'instance EC2
instance_type = "t2.micro"

# Clé SSH
key_pair_name    = "projet-cloud-key"
public_key_path  = "~/.ssh/projet-cloud-key.pub"
private_key_path = "~/.ssh/projet-cloud-key"

# ⚠️ Remplacez par votre IP (trouvée avec : curl ifconfig.me)
# N'oubliez pas le /32 à la fin !
my_ip = "VOTRE_IP_ICI/32"

# Port de votre API backend
app_port = 3000

# ⚠️ Remplacez par l'URL de votre dépôt GitHub
github_repo = "https://github.com/VOTRE_NOM/VOTRE_REPO.git"

# Base de données
db_engine         = "mysql"
db_engine_version = "8.0"
db_name           = "appdb"
db_username       = "admin"

# ⚠️ Choisissez un mot de passe fort — au moins 8 caractères
db_password = "CHANGEZ_MOI_mot_de_passe_fort_123!"
```

> ⚠️ **IMPORTANT :** Remplacez toutes les valeurs en MAJUSCULES par vos vraies valeurs.

---

## Fichier 12 : `.gitignore`

Créez `terraform/.gitignore` :

```gitignore
# État Terraform (contient les IDs et infos sensibles de vos ressources)
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Vos valeurs personnelles (IP, mot de passe DB, chemins clés)
terraform.tfvars

# Logs de crash
crash.log
crash.*.log

# Plans sauvegardés
*.tfplan
```

---

# 🚀 PARTIE 4 : Déployer l'infrastructure

## Étape 4.1 : Initialiser Terraform

```bash
cd terraform
terraform init
```

Cette commande télécharge le plugin AWS. Vous devriez voir :

```
Terraform has been successfully initialized! ✅
```

## Étape 4.2 : Vérifier votre configuration

```bash
terraform validate
```

Si tout est correct :
```
Success! The configuration is valid. ✅
```

## Étape 4.3 : Voir ce qui va être créé

```bash
terraform plan
```

Terraform vous montre **tout ce qu'il va créer** sans rien toucher. C'est votre devis avant travaux.

```
Plan: 23 to add, 0 to change, 0 to destroy.
```

Vous devriez voir environ 23 ressources listées avec le signe `+`.

> 💡 **Lisez toujours le plan !**
> - `+` = ressource à créer (normal lors du premier apply)
> - `~` = ressource à modifier
> - `-` = ressource à supprimer (attention !)
> - `-/+` = ressource à recréer (destruction puis création)

## Étape 4.4 : Créer l'infrastructure !

```bash
terraform apply
```

Terraform affiche le plan une dernière fois et demande :

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Tapez `yes` et appuyez sur Entrée.

⏳ **L'infrastructure prend environ 10 à 15 minutes** à créer — principalement à cause de RDS qui est lent à démarrer.

À la fin, vous verrez vos outputs :

```
Outputs:

alb_dns_name       = "http://projet-cloud-alb-1234567890.us-east-1.elb.amazonaws.com"
frontend_url       = "http://54.123.45.67"
frontend_public_ip = "54.123.45.67"
rds_endpoint       = "projet-cloud-db.xxxx.us-east-1.rds.amazonaws.com"
ssh_frontend       = "ssh -i ~/.ssh/projet-cloud-key ubuntu@54.123.45.67"
```

📝 **Notez ces URLs** — vous en aurez besoin pour les tests.

---

# ✅ PARTIE 5 : Vérification

## Étape 5.1 : Vérifier le VPC dans la console AWS

1. Ouvrez la console AWS → **VPC**
2. Vérifiez que vous voyez votre VPC `projet-cloud-vpc` avec le CIDR `10.0.0.0/16`
3. Sous **Subnets**, vérifiez que vous avez 4 sous-réseaux (2 publics, 2 privés, dans 2 AZ)
4. Sous **Internet Gateways**, vérifiez que l'IGW est attachée à votre VPC
5. Sous **NAT Gateways**, vérifiez que la NAT Gateway est dans un sous-réseau public

## Étape 5.2 : Vérifier les Security Groups

> 🔒 **Ces règles seront vérifiées lors de l'évaluation !**

Dans AWS Console → **EC2** → **Security Groups**, vérifiez pour chaque SG :

| Security Group | Port entrant | Source autorisée |
|---------------|-------------|-----------------|
| `sg-alb` | 80 | `0.0.0.0/0` (internet) |
| `sg-backend` | 3000 (ou votre port) | `sg-alb` uniquement |
| `sg-rds` | 3306 | `sg-backend` uniquement |
| `sg-frontend` | 80 | `0.0.0.0/0` (internet) |
| `sg-frontend` | 22 | Votre IP/32 uniquement |

❌ Si vous voyez `0.0.0.0/0` sur le port 3306 ou sur le port de l'API → **points perdus**

## Étape 5.3 : Tester le backend via l'ALB

```bash
# Remplacez par votre DNS ALB (affiché dans les outputs)
curl http://projet-cloud-alb-1234567890.us-east-1.elb.amazonaws.com/health

# Réponse attendue :
# {"status": "ok"} ou similaire
```

## Étape 5.4 : Tester le frontend

Ouvrez votre navigateur et accédez à l'IP frontend (affichée dans les outputs) :

```
http://54.123.45.67
```

Vous devriez voir votre application web.

## Étape 5.5 : Vérifier l'Auto Scaling Group

1. AWS Console → **EC2** → **Auto Scaling Groups**
2. Sélectionnez votre ASG
3. Vérifiez : Min=2, Desired=2, Max=4
4. Onglet **Instances** : vous devriez voir 2 instances `InService`
5. Onglet **Activity** : l'historique des lancements d'instances

## Étape 5.6 : Tester la résilience

Testez que l'ASG remplace automatiquement une instance défaillante :

```bash
# Dans la console AWS → EC2 → Instances
# Sélectionnez une des instances backend et cliquez sur "Terminate"
# Attendez quelques minutes...
# → L'ASG doit lancer automatiquement une nouvelle instance
```

---

# 🧹 PARTIE 6 : Nettoyage

À la fin du projet (ou quand votre lab expire), supprimez **toutes** vos ressources pour ne pas gaspiller vos crédits :

```bash
terraform destroy
```

Terraform listera tout ce qui sera supprimé et demandera confirmation.

```
Do you really want to destroy all resources?
  Enter a value: yes
```

> ⚠️ Cette commande est **irréversible**. Toutes vos ressources AWS seront supprimées.

```
Destroy complete! Resources: 23 destroyed. ✅
```

---

# 🔧 Dépannage

## Terraform

| Problème | Solution |
|----------|----------|
| `terraform: command not found` | Installez Terraform (cf. Étape 1.2) |
| `No valid credential sources found` | Ré-exportez les credentials Vocareum (cf. Étape 1.5) |
| `UnauthorizedOperation` | Votre lab a expiré → Stop Lab → Start Lab → re-exporter |
| `Error: already exists` | Une ressource du même nom existe déjà → supprimez-la dans la console AWS puis re-essayez |
| `Error: Cycle` | Une dépendance circulaire dans vos ressources — vérifiez les `depends_on` |
| `terraform plan` montre des suppressions inattendues | Quelqu'un a modifié des ressources manuellement dans la console AWS |

## Réseau et connectivité

| Problème | Solution |
|----------|----------|
| Le frontend n'est pas accessible | Vérifiez que l'EC2 est dans un sous-réseau PUBLIC et que le SG autorise le port 80 |
| L'API via l'ALB renvoie 502 Bad Gateway | Le backend n'est pas encore démarré — attendez 2-3 min après `apply`, puis vérifiez les logs |
| L'API backend ne répond pas | Vérifiez le SG backend — le port `app_port` doit venir du SG de l'ALB |
| La DB est inaccessible depuis le backend | Vérifiez le SG RDS — le port 3306 doit venir du SG backend |
| Les instances ASG passent en `Unhealthy` | Le health check `/health` échoue — connectez-vous en SSH à une instance via Session Manager et vérifiez les logs |

## Base de données

| Problème | Solution |
|----------|----------|
| `Error connecting to DB` | Vérifiez que `DB_HOST` correspond bien à `rds_endpoint` dans les outputs |
| `Access denied for user` | Vérifiez `DB_USER` et `DB_PASS` dans votre script User Data |
| La RDS met du temps à créer | Normal — RDS prend 5-10 min à démarrer — soyez patient |

## User Data (script de démarrage)

| Problème | Solution |
|----------|----------|
| L'application ne démarre pas | Connectez-vous à l'EC2 et lisez `/var/log/cloud-init-output.log` |
| `npm: command not found` | Node.js n'est pas installé — vérifiez le script user_data |
| `git clone` échoue | Vérifiez l'URL du dépôt et que le repo est public |

---

# 📋 Aide-mémoire Terraform

| Commande | Ce qu'elle fait |
|----------|----------------|
| `terraform init` | Télécharger les plugins (à faire une fois) |
| `terraform validate` | Vérifier la syntaxe sans contacter AWS |
| `terraform plan` | Voir ce qui va changer (sans rien faire) |
| `terraform apply` | Créer/modifier les ressources |
| `terraform apply -auto-approve` | Appliquer sans demander confirmation |
| `terraform destroy` | Supprimer toutes les ressources |
| `terraform output` | Revoir les outputs (IP, URLs...) |
| `terraform state list` | Lister toutes les ressources gérées |
| `terraform show` | Voir l'état actuel de l'infrastructure |

---

# 🗂️ Structure finale du projet

```
votre-projet/
│
├── terraform/
│   ├── main.tf                  # Provider AWS + AMI Ubuntu
│   ├── variables.tf             # Tous les paramètres
│   ├── outputs.tf               # URLs, IPs, DNS affichés après apply
│   ├── terraform.tfvars         # Vos valeurs (non commité !)
│   │
│   ├── vpc.tf                   # VPC, 4 subnets, IGW, NAT GW, routes
│   ├── security_groups.tf       # 4 Security Groups (ALB, backend, RDS, frontend)
│   ├── rds.tf                   # RDS MySQL + DB Subnet Group
│   ├── backend.tf               # ALB + Target Group + Launch Template + ASG + Policy
│   ├── frontend.tf              # EC2 frontend (sous-réseau public)
│   │
│   ├── user_data_backend.sh     # Script auto-démarrage des instances backend
│   ├── user_data_frontend.sh    # Script auto-démarrage du frontend
│   └── .gitignore               # Exclure tfstate, terraform.tfvars
│
├── backend/                     # Votre code API (doit avoir GET /health → 200)
├── frontend/                    # Votre code HTML/CSS/JS
└── README.md
```

---

# 🏗️ Architecture finale déployée

```
┌──────────────────────────────────────────────────────────────────────┐
│                         VPC 10.0.0.0/16                              │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  SOUS-RÉSEAUX PUBLICS                                           │ │
│  │                                                                 │ │
│  │  AZ-A (10.0.1.0/24)          AZ-B (10.0.2.0/24)               │ │
│  │  ┌─────────────────┐         ┌─────────────────┐               │ │
│  │  │ ALB (nœud A)    │         │  ALB (nœud B)   │               │ │
│  │  │ NAT Gateway     │         │                 │               │ │
│  │  │ EC2 Frontend    │         │                 │               │ │
│  │  └─────────────────┘         └─────────────────┘               │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                           │ ALB distribue                            │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  SOUS-RÉSEAUX PRIVÉS                                            │ │
│  │                                                                 │ │
│  │  AZ-A (10.0.3.0/24)          AZ-B (10.0.4.0/24)               │ │
│  │  ┌─────────────────┐         ┌─────────────────┐               │ │
│  │  │ EC2 Backend     │         │  EC2 Backend    │  ← ASG        │ │
│  │  │ (via ASG)       │         │  (via ASG)      │               │ │
│  │  └────────┬────────┘         └────────┬────────┘               │ │
│  │           │                           │                         │ │
│  │           └───────────┬───────────────┘                         │ │
│  │                       │                                         │ │
│  │               ┌───────▼───────┐                                 │ │
│  │               │  Amazon RDS   │                                 │ │
│  │               │ (Multi-AZ SG) │                                 │ │
│  │               └───────────────┘                                 │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
          ▲                                      ▲
          │ Internet Gateway                     │ NAT Gateway
          │ (entrée internet)                    │ (sortie seulement)
```

---

# 📊 Ce que vous avez accompli

- ✅ **VPC complet** : réseau isolé avec 4 sous-réseaux dans 2 zones de disponibilité
- ✅ **Internet Gateway + NAT Gateway** : connectivité entrante et sortante maîtrisée
- ✅ **Security Groups** : pare-feux en couches, principe du moindre privilège respecté
- ✅ **ALB + Target Group** : répartition de charge et health checks automatiques
- ✅ **Launch Template + ASG** : démarrage automatique des instances, auto-réparation
- ✅ **Scaling Policy** : mise à l'échelle automatique si CPU > 70%
- ✅ **RDS** : base de données dans des sous-réseaux privés, inaccessible depuis internet
- ✅ **Frontend EC2** : application servie depuis un sous-réseau public
- ✅ **Infrastructure as Code** : toute l'infra est reproductible, documentée et versionnable

```
Console AWS (cliquer)  →  Terraform (coder)
Infra jetable          →  Infra reproductible
Aucune traçabilité     →  Git log = historique complet
Suppression manuelle   →  terraform destroy en 1 commande
```

---

# 🏆 Défis

## Défi 1 : HTTPS avec un certificat SSL (⭐⭐)

Ajoutez un certificat SSL sur l'ALB pour exposer votre API en HTTPS.

<details>
<summary>💡 Indice</summary>

```hcl
# Dans backend.tf — ajoutez un listener HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn  # Certificat ACM

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
```
</details>

---

## Défi 2 : Stocker les secrets dans AWS Secrets Manager (⭐⭐)

Au lieu de passer le mot de passe RDS en clair dans `terraform.tfvars`, utilisez AWS Secrets Manager.

<details>
<summary>💡 Indice</summary>

```hcl
# Créer un secret dans Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# Dans le User Data, récupérer le secret via AWS CLI :
# DB_PASS=$(aws secretsmanager get-secret-value --secret-id "projet-cloud/db-password" \
#           --query SecretString --output text)
```
</details>

---

## Défi 3 : Multi-environnements avec Terraform Workspaces (⭐⭐⭐)

Créez un environnement de staging et un environnement de production séparés.

<details>
<summary>💡 Indice</summary>

```bash
# Créer et basculer vers l'environnement staging
terraform workspace new staging
terraform apply -var-file=environments/staging.tfvars

# Créer et basculer vers la production
terraform workspace new production
terraform apply -var-file=environments/production.tfvars

# Voir les workspaces disponibles
terraform workspace list
```

```hcl
# Dans vos ressources, utilisez le workspace comme préfixe
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${terraform.workspace}-${var.project_name}-vpc"
  }
}
```
</details>

---

# 🎉 Félicitations !

Vous avez déployé une infrastructure cloud professionnelle complète avec Terraform. Chaque composant est en code, chaque règle de sécurité est vérifiable, et toute l'infra peut être recréée en une seule commande.

C'est exactement ce que font les ingénieurs cloud et DevOps dans le monde professionnel. Bienvenue dans l'Infrastructure as Code ! ☁️
