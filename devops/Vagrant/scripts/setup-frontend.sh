#!/bin/sh
set -eu

: "${BACKEND_IP:?BACKEND_IP environment variable is required}"

export REACT_APP_BACKEND_URL="http://${BACKEND_IP}:8080"

echo "=== Installing Nginx, Node.js, and Git ==="
apk add --no-cache nginx nodejs npm git

echo "=== Fetching Repository ==="
REPO_URL="https://github.com/dishua/DevOpsProject-UserStory.git"
TARGET_DIR="/tmp/frontend_repo"

rm -rf "$TARGET_DIR"
git clone --depth=1 --filter=blob:none --sparse -b master "$REPO_URL" "$TARGET_DIR"

cd "$TARGET_DIR"
git sparse-checkout set frontend

echo "=== Building Frontend ==="
cd "$TARGET_DIR/frontend"
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund
else
  npm install --no-audit --no-fund
fi

echo "=== Deploying Static Assets ==="
mkdir -p /var/www/html
rm -rf /var/www/html/*
cp -r build/* /var/www/html/

rm -rf "$TARGET_DIR"

echo "=== Configuring Nginx Reverse Proxy ==="
cat <<EOF > /etc/nginx/http.d/default.conf
server {
    listen 80;
    server_name localhost;

    location / {
        root /var/www/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://${BACKEND_IP}:8080/;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "=== Validating and Starting Nginx ==="
nginx -t

rc-update add nginx default
if rc-service nginx status >/dev/null 2>&1; then
  rc-service nginx restart
else
  rc-service nginx start
fi

echo "=== Frontend Setup Complete ==="