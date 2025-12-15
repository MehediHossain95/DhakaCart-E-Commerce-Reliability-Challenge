terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# VPC Configuration
resource "aws_vpc" "dhakacart_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dhakacart-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "dhakacart_igw" {
  vpc_id = aws_vpc.dhakacart_vpc.id

  tags = {
    Name = "dhakacart-igw"
  }
}

# Public Subnet
resource "aws_subnet" "dhakacart_public" {
  vpc_id                  = aws_vpc.dhakacart_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "dhakacart-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "dhakacart_public_rt" {
  vpc_id = aws_vpc.dhakacart_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dhakacart_igw.id
  }

  tags = {
    Name = "dhakacart-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "dhakacart_public_rta" {
  subnet_id      = aws_subnet.dhakacart_public.id
  route_table_id = aws_route_table.dhakacart_public_rt.id
}

# Security Group
resource "aws_security_group" "dhakacart_sg" {
  name        = "dhakacart-security-group"
  description = "Security group for DhakaCart application"
  vpc_id      = aws_vpc.dhakacart_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "dhakacart-sg"
  }
}

# SSH Key Pair
resource "aws_key_pair" "dhakacart_key" {
  key_name   = "dhakacart-key"
  public_key = file("${path.module}/../dhakacart-key.pub")

  tags = {
    Name = "dhakacart-key"
  }
}

# User Data Script
data "template_file" "user_data" {
  template = <<-EOF
    #!/bin/bash
    set -e
    
    apt-get update
    apt-get upgrade -y
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install nginx
    apt-get install -y nginx
    
    mkdir -p /opt/dhakacart
    
    touch /var/log/user-data-complete.log
    echo "User data completed at $(date)" >> /var/log/user-data-complete.log
  EOF
}

# EC2 Instance
resource "aws_instance" "dhakacart_instance" {
  ami           = "ami-047126e50991d067b"
  instance_type = "t3.medium"
  
  subnet_id                   = aws_subnet.dhakacart_public.id
  vpc_security_group_ids      = [aws_security_group.dhakacart_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.dhakacart_key.key_name
  
  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "dhakacart-instance"
  }
}

# Outputs
output "instance_id" {
  value = aws_instance.dhakacart_instance.id
}

output "instance_public_ip" {
  value = aws_instance.dhakacart_instance.public_ip
}

output "ssh_command" {
  value = "ssh -i dhakacart-key ubuntu@${aws_instance.dhakacart_instance.public_ip}"
}

output "application_url" {
  value = "http://${aws_instance.dhakacart_instance.public_ip}"
}
