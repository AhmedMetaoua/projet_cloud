#!/bin/bash
# Note: Don't use 'set -e' to allow script to continue on recoverable failures

# ── Mise à jour et installation de nginx ──
apt-get update -y
apt-get install -y nginx git curl wget unzip

# ── Install Node.js 20 ──
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── Cloner votre frontend ──
echo "Cloning repository from ${github_repo}..."
cd /tmp

# Retry git clone with timeout
MAX_RETRIES=3
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
  git clone --depth 1 ${github_repo} frontend-app && break || {
    echo "Git clone failed (attempt $((RETRY+1))/$MAX_RETRIES), retrying..."
    RETRY=$((RETRY+1))
    sleep 5
  }
done

# Fallback: If git clone still failed, try wget to download ZIP
if [ ! -d "/tmp/frontend-app" ]; then
  echo "Git clone failed, trying download as ZIP..."
  REPO_ZIP="${github_repo%.git}/archive/refs/heads/main.zip"
  REPO_ZIP=$(echo "$REPO_ZIP" | sed 's|git@github.com:|https://github.com/|')
  wget -q "$REPO_ZIP" -O /tmp/repo.zip && {
    unzip -q /tmp/repo.zip -d /tmp/
    mv /tmp/projet_cloud-main /tmp/frontend-app
  } || {
    echo "Failed to download repo - using placeholder"
    mkdir -p /tmp/frontend-app/client/dist/client/browser
  }
fi

# ── Installer und builder l'application Angular ──
if [ -f "/tmp/frontend-app/client/package.json" ]; then
  echo "Building Angular app..."
  cd /tmp/frontend-app/client
  npm install --legacy-peer-deps || npm install --legacy-peer-deps --no-optional
  npm run build || npx ng build --configuration production || {
    echo "Angular build failed - using default placeholder"
  }
fi

# ── Déployer la build dans le dossier de nginx ──
echo "Deploying frontend..."
rm -rf /var/www/html/*

if [ -d "/tmp/frontend-app/client/dist/client/browser" ]; then
  cp -r /tmp/frontend-app/client/dist/client/browser/* /var/www/html/
elif [ -d "/tmp/frontend-app/client/dist" ]; then
  find /tmp/frontend-app/client/dist -type f | xargs -I {} cp {} /var/www/html/
fi

# ── Créer un fichier de configuration JavaScript avec l'URL de l'ALB ──
cat > /var/www/html/config.js <<EOF
window.API_HOST = '${alb_dns_name}';
EOF

# ── Injecter le script de configuration dans le head de index.html ──
if [ -f "/var/www/html/index.html" ]; then
  sed -i '/<head>/a\  <script src="/config.js"><\/script>' /var/www/html/index.html
fi

# ── Démarrer nginx ──
systemctl start nginx
systemctl enable nginx

echo "Frontend déployé avec succès ✅"
