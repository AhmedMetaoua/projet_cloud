#!/bin/bash
# Removed 'set -e' to allow fallbacks if git clone fails
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting frontend deployment script ==="

# ── Mise à jour et installation de nginx ──
apt-get update -y
apt-get install -y nginx git curl wget unzip

# ── Install Node.js 20 ──
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── Try to clone frontend repo ──
echo "Attempting to clone repository from ${github_repo}..."
cd /tmp

# Retry git clone with retries
CLONE_SUCCESS=false
for i in {1..3}; do
  if git clone ${github_repo} frontend-app --depth 1 2>&1; then
    CLONE_SUCCESS=true
    echo "Git clone succeeded on attempt $i"
    break
  else
    echo "Git clone failed on attempt $i, retrying..."
    sleep 5
  fi
done

# ── Fallback: Download as ZIP if git fails ──
if [ "$CLONE_SUCCESS" = false ]; then
  echo "Git clone failed, attempting ZIP download..."
  # Convert git URL to ZIP download URL
  REPO_ZIP=$(echo "${github_repo}" | sed 's|.git$||' | sed 's|git@github.com:|https://github.com/|')
  REPO_ZIP="${REPO_ZIP}/archive/refs/heads/main.zip"
  
  if wget -q "$REPO_ZIP" -O /tmp/repo.zip && unzip -q /tmp/repo.zip -d /tmp/ 2>/dev/null; then
    mv /tmp/projet_cloud-main /tmp/frontend-app 2>/dev/null || mv /tmp/projet_cloud-* /tmp/frontend-app
    echo "ZIP download succeeded"
    CLONE_SUCCESS=true
  else
    echo "ZIP download failed"
  fi
fi

# ── Build Angular if repository was obtained ──
if [ "$CLONE_SUCCESS" = true ] && [ -f "/tmp/frontend-app/client/package.json" ]; then
  echo "Building Angular application..."
  cd /tmp/frontend-app/client
  
  if npm install --legacy-peer-deps 2>&1; then
    if npm run build 2>&1 || npx ng build --configuration production 2>&1; then
      echo "Angular build succeeded"
      
      # Deploy to nginx
      echo "Deploying to nginx..."
      rm -rf /var/www/html/*
      cp -r dist/client/browser/* /var/www/html/
      
      # Create config with ALB DNS
      cat > /var/www/html/config.js <<CFGEOF
window.API_HOST = '${alb_dns_name}';
CFGEOF
      
      # Inject into index.html
      sed -i '/<head>/a\  <script src="/config.js"><\/script>' /var/www/html/index.html
      
      echo "Angular app deployed successfully"
    else
      echo "Angular build failed"
    fi
  else
    echo "npm install failed"
  fi
fi

# ── Ensure nginx directory has content ──
if [ ! -f "/var/www/html/index.html" ]; then
  echo "No index.html found, creating placeholder..."
  mkdir -p /var/www/html
  cat > /var/www/html/index.html <<'PLACEOF'
<!DOCTYPE html>
<html>
<head>
  <title>Frontend Deployment</title>
  <script src="/config.js"></script>
</head>
<body>
  <h1>Frontend is deploying...</h1>
  <p>API Host: <span id="api-host">Loading...</span></p>
  <script>
    document.getElementById('api-host').textContent = window.API_HOST || 'Not configured';
  </script>
</body>
</html>
PLACEOF
  
  # Create config
  cat > /var/www/html/config.js <<CFGEOF
window.API_HOST = '${alb_dns_name}';
CFGEOF
fi

# ── Start nginx ──
echo "Starting nginx..."
systemctl start nginx
systemctl enable nginx

echo "=== Frontend deployment script completed ==="
ls -lah /var/www/html/ 2>&1
curl -I http://localhost/ 2>&1 || true
