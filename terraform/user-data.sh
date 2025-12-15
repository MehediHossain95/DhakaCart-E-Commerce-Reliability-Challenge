#!/bin/bash
set -e

# Update system
apt-get update -qq

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Wait for K3s
while ! systemctl is-active k3s; do sleep 5; done

# Set kubeconfig permissions
chmod 644 /etc/rancher/k3s/k3s.yaml

# Install nginx
apt-get install -y nginx

# Configure nginx for proxying
cat > /etc/nginx/sites-available/dhakacart << 'NGINX'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:30000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:30001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }
}
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/dhakacart /etc/nginx/sites-enabled/
systemctl restart nginx
systemctl enable nginx

echo "Setup complete!"
