#!/bin/bash
set -e

echo "=== DhakaCart AWS Deployment Script ==="
echo "Region: ap-southeast-1 (Singapore)"
echo "Starting deployment..."

# Install Terraform if not present
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    wget -O terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
    unzip -o terraform.zip
    sudo mv terraform /usr/local/bin/
    rm terraform.zip
fi

# Install kubectl if not present
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

echo "✓ All required tools installed"

# Initialize Terraform
cd terraform
echo "Initializing Terraform..."
terraform init

echo "Planning infrastructure..."
terraform plan -out=tfplan

echo ""
echo "=== Deployment Ready ==="
echo "To apply changes, run: cd terraform && terraform apply tfplan"
echo "After infrastructure is ready, the GitHub Actions CI/CD will handle application deployment"
