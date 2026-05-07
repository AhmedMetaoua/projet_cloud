#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting frontend deployment script ==="

# ── Update and install nginx ──
apt-get update -y
apt-get install -y nginx

# ── Create a simple Angular-like SPA placeholder ──
mkdir -p /var/www/html

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Project Cloud - Frontend</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; justify-content: center; align-items: center; }
    .container { background: white; border-radius: 10px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); padding: 40px; text-align: center; max-width: 600px; }
    h1 { color: #333; margin-bottom: 20px; }
    .section { margin: 20px 0; padding: 20px; background: #f9f9f9; border-left: 4px solid #667eea; text-align: left; }
    .label { font-weight: bold; color: #333; }
    pre { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; font-size: 12px; }
    button { background: #667eea; color: white; border: none; padding: 12px 24px; border-radius: 5px; cursor: pointer; margin: 5px; }
    button:hover { background: #764ba2; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 Project Cloud</h1>
    <p>Frontend Infrastructure is Ready!</p>
    <div class="section">
      <div class="label">Server Information:</div>
      <pre id="debug"></pre>
    </div>
    <button onclick="location.reload()">Refresh</button>
  </div>
  <script>
    const debug = document.getElementById('debug');
    debug.textContent = 
      'Hostname: ' + window.location.hostname + '\n' +
      'URL: ' + window.location.href + '\n' +
      'Time: ' + new Date().toISOString();
  </script>
</body>
</html>
EOF

# ── Configure nginx for SPA ──
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
        try_files $uri $uri/ /index.html;
    }

    # Cache busting for versioned assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|eot)$ {
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

# ── Test nginx configuration ──
if nginx -t 2>&1; then
  echo "Nginx configuration is valid"
else
  echo "ERROR: Nginx configuration is invalid"
  exit 1
fi

# ── Start nginx ──
systemctl start nginx
systemctl enable nginx
systemctl reload nginx

echo "=== Frontend deployment completed ==="
echo "Nginx is $(systemctl is-active nginx)"
ls -lah /var/www/html/
curl -I http://localhost/ 2>&1 || echo "Local curl test skipped"

