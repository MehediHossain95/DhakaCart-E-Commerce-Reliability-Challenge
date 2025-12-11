# DhakaCart AWS Deployment Guide

## ✅ AWS Configuration Status

**Credentials**: ✅ Configured
**Region**: ap-southeast-1 (Singapore)
**Account**: 388449571465
**User**: d5nc-poridhi
**Permissions**: VPC, EC2, RDS, S3, Auto Scaling, EBS, Snapshots

## 🚀 Deployment Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                   AWS Account (ap-southeast-1)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────── VPC (10.0.0.0/16) ────────────────┐   │
│  │                                                       │   │
│  │  Internet Gateway                                    │   │
│  │          │                                           │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │        Public Subnet (10.0.1.0/24)               │ │   │
│  │  │  ┌────────────────┐      ┌────────────────┐     │ │   │
│  │  │  │  EC2 Frontend  │      │  EC2 Backend   │     │ │   │
│  │  │  │  (Nginx)       │      │  (Node.js)     │     │ │   │
│  │  │  │  Port 80, 443  │      │  Port 5000     │     │ │   │
│  │  │  └────────────────┘      └────────────────┘     │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  │                       │                              │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │      Private Subnet (10.0.2.0/24)               │ │   │
│  │  │  ┌────────────────────────────────────────────┐ │ │   │
│  │  │  │  RDS Database (PostgreSQL Multi-AZ)        │ │ │   │
│  │  │  │  Port 5432                                 │ │ │   │
│  │  │  │  Snapshots & PITR Enabled                  │ │ │   │
│  │  │  └────────────────────────────────────────────┘ │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  │                                                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  S3 Bucket (Application backups & logs)                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Pre-Deployment Checklist

- ✅ AWS Credentials configured
- ✅ Region set to ap-southeast-1 (Singapore)
- ✅ AWS CLI ready
- ✅ Terraform prepared
- ✅ Docker images available
- ✅ Security groups planned

## 🛠️ Step 1: Prepare Terraform Variables

Create `terraform/terraform.tfvars`:

```hcl
aws_region = "ap-southeast-1"
project_name = "dhakacart"
environment = "production"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# EC2 Configuration
instance_type = "t3.medium"
instance_count = 2

# RDS Configuration
db_name = "dhakacart_db"
db_username = "admin"
db_allocated_storage = 20
db_engine_version = "14.7"

# Application Configuration
backend_port = 5000
frontend_port = 80
```

## 🏗️ Step 2: Deploy Infrastructure with Terraform

```bash
cd terraform/

# Initialize Terraform
terraform init

# Plan the deployment (review resources)
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan

# Save outputs
terraform output > ../deployment-outputs.json
```

Expected outputs:

- VPC ID
- Subnet IDs
- Security Group IDs
- EC2 Instance IPs
- RDS Endpoint
- S3 Bucket Name

## 🐳 Step 3: Build and Push Docker Images

```bash
# Authenticate with Amazon ECR (if using ECR)
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin 388449571465.dkr.ecr.ap-southeast-1.amazonaws.com

# Build images
docker build -t dhakacart-backend:latest ./backend
docker build -t dhakacart-frontend:latest ./frontend

# Tag images for ECR
docker tag dhakacart-backend:latest \
  388449571465.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-backend:latest
docker tag dhakacart-frontend:latest \
  388449571465.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-frontend:latest

# Push to ECR
docker push 388449571465.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-backend:latest
docker push 388449571465.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-frontend:latest
```

## 📦 Step 4: Configure RDS Database

```bash
# Get RDS endpoint from Terraform outputs
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Connect to RDS (requires PostgreSQL client)
psql -h $RDS_ENDPOINT -U admin -d dhakacart_db

# Run database migrations
psql -h $RDS_ENDPOINT -U admin -d dhakacart_db -f ./database/schema.sql
psql -h $RDS_ENDPOINT -U admin -d dhakacart_db -f ./database/seed.sql
```

## 🚀 Step 5: Deploy Applications to EC2

```bash
# Get EC2 instance IPs
BACKEND_IP=$(terraform output -raw backend_instance_ip)
FRONTEND_IP=$(terraform output -raw frontend_instance_ip)

# SSH into backend instance
ssh -i ~/.ssh/dhakacart-key.pem ec2-user@$BACKEND_IP

# On backend instance:
# 1. Install Docker
# 2. Pull and run backend container
# 3. Configure environment variables

docker pull 388449571465.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-backend:latest
docker run -d \
  -p 5000:5000 \
  -e DATABASE_URL="postgresql://admin:password@$RDS_ENDPOINT:5432/dhakacart_db" \
  -e NODE_ENV=production \
  --name dhakacart-backend \
  388449571465.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-backend:latest

# Similar process for frontend
```

## 📊 Step 6: Configure Monitoring

```bash
# Enable CloudWatch detailed monitoring
aws ec2 monitor-instances --instance-ids i-1234567890abcdef0 --region ap-southeast-1

# Create CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name dhakacart-cpu-high \
  --alarm-description "Alert when CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --region ap-southeast-1
```

## 💾 Step 7: Configure Backups

```bash
# Enable RDS automated backups (via Terraform or AWS Console)
# Backup retention: 35 days (for PITR)
# Multi-AZ: Enabled for high availability

# Create S3 bucket for application backups
aws s3 mb s3://dhakacart-backups-$(date +%s) --region ap-southeast-1

# Configure S3 backup policy
aws s3api put-bucket-versioning \
  --bucket dhakacart-backups \
  --versioning-configuration Status=Enabled \
  --region ap-southeast-1
```

## 🔐 Step 8: Setup SSL/TLS

```bash
# Request ACM certificate for your domain
aws acm request-certificate \
  --domain-name dhakacart.example.com \
  --validation-method DNS \
  --region ap-southeast-1

# Update Application Load Balancer (if used) to use HTTPS
# Configure security group to allow port 443
```

## 🧪 Step 9: Verify Deployment

```bash
# Check EC2 instances
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' \
  --output table \
  --region ap-southeast-1

# Check RDS database
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]' \
  --output table \
  --region ap-southeast-1

# Test backend connectivity
BACKEND_IP=$(terraform output -raw backend_instance_ip)
curl http://$BACKEND_IP:5000/

# Test frontend connectivity
FRONTEND_IP=$(terraform output -raw frontend_instance_ip)
curl http://$FRONTEND_IP/
```

## 📈 Step 10: Setup Auto Scaling (Optional)

```bash
# Create Auto Scaling group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name dhakacart-asg \
  --launch-configuration dhakacart-lc \
  --min-size 1 \
  --max-size 5 \
  --desired-capacity 2 \
  --vpc-zone-identifier "subnet-xxxxx" \
  --region ap-southeast-1

# Create scaling policies
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name dhakacart-asg \
  --policy-name scale-up \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration TargetValue=70.0,PredefinedMetricSpecification={PredefinedMetricType=ASGAverageCPUUtilization} \
  --region ap-southeast-1
```

## 🔍 Troubleshooting

### Cannot connect to RDS

```bash
# Check security group
aws ec2 describe-security-groups \
  --region ap-southeast-1 \
  --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions]' \
  --output table

# Ensure EC2 security group allows outbound to RDS security group
```

### EC2 instances not responding

```bash
# Check instance status
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx \
  --region ap-southeast-1

# Check system log
aws ec2 get-console-output \
  --instance-id i-xxxxx \
  --region ap-southeast-1

# Check security groups
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --region ap-southeast-1
```

### Database connection issues

```bash
# Test RDS connectivity
psql -h <rds-endpoint> -U admin -d dhakacart_db -c "SELECT 1"

# Check RDS logs
aws rds describe-db-logs \
  --db-instance-identifier dhakacart-db \
  --region ap-southeast-1
```

## 📚 Useful AWS CLI Commands

```bash
# List all resources
aws ec2 describe-instances --region ap-southeast-1
aws rds describe-db-instances --region ap-southeast-1
aws s3 ls

# Monitor costs
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-11 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region ap-southeast-1

# Create snapshots
aws ec2 create-snapshot \
  --volume-id vol-xxxxx \
  --description "DhakaCart backup" \
  --region ap-southeast-1

aws rds create-db-snapshot \
  --db-instance-identifier dhakacart-db \
  --db-snapshot-identifier dhakacart-backup-$(date +%Y%m%d-%H%M%S) \
  --region ap-southeast-1
```

## 🎯 Deployment Checklist

- [ ] Terraform initialized and variables configured
- [ ] AWS credentials verified
- [ ] VPC and subnets created
- [ ] Security groups configured
- [ ] EC2 instances launched
- [ ] RDS database created and accessible
- [ ] Docker images built and pushed to ECR
- [ ] Applications deployed to EC2
- [ ] Database migrations completed
- [ ] Monitoring and alarms configured
- [ ] Backups configured
- [ ] SSL/TLS certificates installed
- [ ] Health checks passing
- [ ] Load testing completed
- [ ] Security hardening verified

## 📞 Support & Resources

- [AWS Console](https://388449571465.signin.aws.amazon.com/console)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- DhakaCart Documentation: See README.md in project root

## ⏰ Estimated Timeline

- Terraform Setup: 15 minutes
- Infrastructure Deployment: 20 minutes
- Docker Image Build: 10 minutes
- Application Deployment: 15 minutes
- Configuration & Testing: 20 minutes
- **Total: ~80 minutes**

---

**Status**: ✅ Ready for AWS Deployment
**Region**: ap-southeast-1 (Singapore)
**Account**: 388449571465
**User**: d5nc-poridhi
**Date**: December 11, 2025
