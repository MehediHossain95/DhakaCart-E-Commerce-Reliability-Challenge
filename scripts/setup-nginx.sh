#!/bin/bash
set -e

echo "Setting up nginx reverse proxy..."

# Install nginx
sudo apt update -qq && sudo apt install -y nginx

# Configure nginx
sudo tee /etc/nginx/sites-available/dhakacart > /dev/null << 'NGINX_CONF'
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
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_CONF

# Enable configuration
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/dhakacart /etc/nginx/sites-enabled/

# Restart nginx
sudo nginx -t && sudo systemctl restart nginx && sudo systemctl enable nginx

echo "✅ Nginx configured successfully!"
echo "✅ Application accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
