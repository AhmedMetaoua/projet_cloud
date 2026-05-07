#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting frontend deployment script ==="

# ── Update and install nginx ──
apt-get update -y
apt-get install -y nginx

# ── Create a simple Angular-like SPA placeholder ──
mkdir -p /var/www/html

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
  REPO_ZIP="$REPO_ZIP/archive/refs/heads/main.zip"
  
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
      
      # Handle both old and new Angular build output structures
      if [ -d "dist/client/browser" ]; then
        cp -r dist/client/browser/* /var/www/html/
      elif [ -d "dist/client" ]; then
        cp -r dist/client/* /var/www/html/
      else
        echo "ERROR: Angular build output not found at expected location"
        echo "Contents of dist/:"
        ls -la dist/
        exit 1
      fi
      
      echo "Angular app deployed successfully"
    else
      echo "Angular build failed"
    fi
  else
    echo "npm install failed"
  fi
fi

# ── Configure nginx for Angular SPA ──
echo "Configuring nginx for Single Page Application..."
cat > /etc/nginx/sites-available/default <<'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    # SPA routing: serve index.html for all non-file requests
    location / {
        try_files $$uri $$uri/ /index.html;
    }

    # Cache-busting for versioned assets (with content hash)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|eot)$$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Don't cache index.html
    location = /index.html {
        expires -1;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate, max-age=0";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
NGINXEOF

# ── Test and apply nginx configuration ──
echo "Testing nginx configuration..."
if nginx -t 2>&1; then
  echo "Nginx configuration is valid"
else
  echo "ERROR: Nginx configuration test failed!"
  exit 1
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
    <p class="info">Your Angular application is being built and deployed.</p>
    <p class="info">If you see this page after 5+ minutes, check the deployment logs.</p>
    <hr/>
    <h3>Debug Information:</h3>
    <pre id="debug" style="background: #f0f0f0; padding: 10px; border-radius: 4px;"></pre>
  </div>
  <script>
    document.getElementById('debug').textContent = 
      'Hostname: ' + window.location.hostname + '\n' +
      'Time: ' + new Date().toISOString() + '\n' +
      'User Agent: ' + navigator.userAgent;
  </script>
</body>
</html>
PLACEOF
fi

# ── Start/restart nginx ──
echo "Starting nginx service..."
systemctl start nginx
systemctl enable nginx
systemctl reload nginx

echo "=== Frontend deployment script completed ==="
echo "Nginx is $(systemctl is-active nginx)"
echo "HTML directory contents:"
ls -lah /var/www/html/ 2>&1
echo "Testing local connection:"
curl -I http://localhost/ 2>&1 || echo "Local curl test failed"
