#!/bin/bash
set -e
    
# 1. Install K3s (Lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -
    
# 2. Wait for K3s to be ready
echo "Waiting for K3s to start..."
while ! sudo systemctl is-active k3s; do
  sleep 5
done
    
# 3. Set kubeconfig permissions
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    
# 4. Install nginx
sudo apt-get update -qq
sudo apt-get install -y nginx
    
# 5. Configure nginx reverse proxy
sudo tee /etc/nginx/sites-available/dhakacart > /dev/null << 'NGINX'
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://localhost:30000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
    location /api {
        proxy_pass http://localhost:30001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
NGINX
    
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/dhakacart /etc/nginx/sites-enabled/
sudo systemctl restart nginx
sudo systemctl enable nginx
    
echo "K3s and nginx setup complete!"
