#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting frontend deployment script ==="

# ── System update ──
apt-get update -y
apt-get install -y git curl unzip nginx

# ── Install Node.js 18 (MISSING from original script) ──
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo "Node version: $(node --version)"
echo "NPM version:  $(npm --version)"

# ── Try to clone frontend repo ──
echo "Attempting to clone repository from ${github_repo}..."
cd /tmp

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
  REPO_ZIP=$(echo "${github_repo}" | sed 's|.git$||')
  REPO_ZIP="$REPO_ZIP/archive/refs/heads/main.zip"

  if wget -q "$REPO_ZIP" -O /tmp/repo.zip && unzip -q /tmp/repo.zip -d /tmp/; then
    mv /tmp/projet_cloud-main /tmp/frontend-app 2>/dev/null || mv /tmp/projet_cloud-* /tmp/frontend-app
    echo "ZIP download succeeded"
    CLONE_SUCCESS=true
  else
    echo "ZIP download also failed"
  fi
fi

# ── Build Angular if repository was obtained ──
if [ "$CLONE_SUCCESS" = true ] && [ -f "/tmp/frontend-app/client/package.json" ]; then
  echo "Building Angular application..."
  cd /tmp/frontend-app/client

  # Write environment file pointing to the ALB
  mkdir -p src/environments
  cat > src/environments/environment.prod.ts <<ENVEOF
export const environment = {
  production: true,
  apiUrl: 'http://${alb_dns_name}'
};
ENVEOF

  if npm install --legacy-peer-deps 2>&1; then
    if npm run build -- --configuration production 2>&1; then
      echo "Angular build succeeded"

      rm -rf /var/www/html/*

      if [ -d "dist/client/browser" ]; then
        cp -r dist/client/browser/* /var/www/html/
      elif [ -d "dist/client" ]; then
        cp -r dist/client/* /var/www/html/
      else
        echo "Build output not at expected path. Contents of dist/:"
        ls -la dist/ 2>/dev/null || echo "(dist/ not found)"
      fi

      echo "Angular app deployed successfully"
    else
      echo "Angular build failed — check logs above"
    fi
  else
    echo "npm install failed"
  fi
else
  echo "Skipping build: repo not obtained or client/package.json missing"
fi

sed -i "s|__API_HOST__|${alb_dns_name}|g" /var/www/html/index.html
echo "API_HOST injected: ${alb_dns_name}"

# ── Configure nginx for Angular SPA ──
cat > /etc/nginx/sites-available/default <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location = /index.html {
        expires -1;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate, max-age=0";
    }

    location ~ /\. {
        deny all;
    }
}
NGINXEOF

# ── Fallback placeholder if build produced nothing ──
if [ ! -f "/var/www/html/index.html" ]; then
  echo "No index.html found — creating placeholder page"
  cat > /var/www/html/index.html <<'PLACEOF'
<!DOCTYPE html>
<html>
<head>
  <title>Frontend Deployment</title>
  <style>
    body { font-family: sans-serif; margin: 40px; background: #f5f5f5; }
    .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    h1 { color: #333; }
    .info { color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Frontend Deployment In Progress</h1>
    <p class="info">Angular is being built. If you see this after 10 minutes, check /var/log/user-data.log on the instance.</p>
  </div>
</body>
</html>
PLACEOF
fi

# ── Test and apply nginx configuration ──
nginx -t 2>&1 && echo "nginx config OK" || { echo "nginx config FAILED"; exit 1; }

systemctl start nginx
systemctl enable nginx
systemctl reload nginx

echo "=== Deployment complete ==="
echo "nginx status: $(systemctl is-active nginx)"
echo "HTML dir contents:"
ls -lah /var/www/html/