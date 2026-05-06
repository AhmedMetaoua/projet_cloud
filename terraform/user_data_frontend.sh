#!/bin/bash
set -e

# ── Mise à jour et installation de nginx ──
apt-get update -y
apt-get install -y nginx git curl

# ── Install Node.js 18 ──
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# ── Cloner votre frontend ──
cd /tmp
git clone ${github_repo} frontend-app

# ── Installer et builder l'application Angular ──
cd /tmp/frontend-app/client
npm install
npx ng build --configuration production

# ── Déployer la build dans le dossier de nginx ──
rm -rf /var/www/html/*
cp -r /tmp/frontend-app/client/dist/client/browser/* /var/www/html/

# ── Remplacer l'URL de l'API par le DNS de l'ALB ──
find /var/www/html -name "*.js" -o -name "*.html" | xargs sed -i \
  "s|http://localhost:${app_port}|http://${alb_dns_name}|g"

# ── Démarrer nginx ──
systemctl start nginx
systemctl enable nginx

echo "Frontend déployé avec succès ✅"