# terraform/main.tf

provider "aws" {
  region = "ap-southeast-1"
}

# 1. Create the VPC (Virtual Data Center)
resource "aws_vpc" "dhakacart_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "DhakaCart-VPC"
  }
}

# 2. Create a Public Subnet (For Load Balancer)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.dhakacart_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"

  tags = {
    Name = "DhakaCart-Public-Subnet"
  }
}

# 3. Create an Internet Gateway (To allow internet access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dhakacart_vpc.id

  tags = {
    Name = "DhakaCart-IGW"
  }
}

# 4. Create a Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.dhakacart_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "DhakaCart-Public-RT"
  }
}

# 5. Associate Route Table with Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Security Group (Firewall)
resource "aws_security_group" "k3s_sg" {
  vpc_id      = aws_vpc.dhakacart_vpc.id
  name        = "dhakacart-k3s-sg"
  description = "Allows SSH, HTTP, and K3s traffic"

  # Inbound: SSH Access from Anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: HTTP (Frontend)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: K3s API (Port 6443) - Strictly needed for kubectl access
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Outbound: All Traffic Allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DhakaCart-K3s-SG"
  }
}

# 7. Import SSH Key Pair
resource "aws_key_pair" "dhakacart_key" {
  key_name   = "dhakacart-key"
  public_key = file("${path.module}/../dhakacart-key.pub")
}
# 8. K3s Installation Script
resource "local_file" "setup_script" {
  content  = <<-EOT
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
EOT
  filename = "setup.sh"
}

# 9. EC2 Instance (Our single Kubernetes node)
resource "aws_instance" "k3s_node" {
  # Ubuntu 22.04 LTS HVM AMI in ap-southeast-1. 
  ami                    = "ami-00d8fc944fb171e29"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.dhakacart_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  associate_public_ip_address = true
  
  # Inject the K3s installation script
  user_data = local_file.setup_script.content

  tags = {
    Name = "DhakaCart-K3s-Server"
  }
}

# Outputs
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.k3s_node.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.k3s_node.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ../dhakacart-key ubuntu@${aws_instance.k3s_node.public_ip}"
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_instance.k3s_node.public_ip}"
}
