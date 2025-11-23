#!/bin/bash
    
# 1. Install K3s (Lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -
    
# 2. Wait for K3s to be ready
echo "Waiting for K3s to start..."
while ! sudo systemctl is-active k3s; do
  sleep 5
done
    
# 3. Copy Kubeconfig to a readable location
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s.yaml
sudo chown ubuntu:ubuntu /home/ubuntu/k3s.yaml
    
# 4. Remove the default 'localhost' from config for remote access
sed -i 's/127.0.0.1/$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/g' /home/ubuntu/k3s.yaml
    
echo "K3s installation complete. Kubeconfig is ready at /home/ubuntu/k3s.yaml"
