#!/bin/bash
set -e

# ── System update and tools installation ──
apt-get update -y
apt-get install -y git curl

# ── Install Node.js 18 ──
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# ── Clone your application ──
cd /home/ubuntu
git clone ${github_repo} app

# ── Write .env file BEFORE npm install ──
cat > /home/ubuntu/app/backend/.env <<EOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
DB_PASS=${db_password}
PORT=${app_port}
NODE_ENV=production
EOF

# ── Go to backend folder ──
cd /home/ubuntu/app/backend

# ── Install dependencies ──
npm install --production

# ── Install PM2 ──
npm install -g pm2

# ── Start the application with PM2 ──
pm2 start npm --name "backend" -- start

# ── Save PM2 and enable startup on reboot ──
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | bash