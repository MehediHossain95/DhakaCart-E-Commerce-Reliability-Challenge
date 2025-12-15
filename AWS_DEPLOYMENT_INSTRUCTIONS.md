# DhakaCart AWS Deployment Instructions

## Overview
This document provides step-by-step instructions for deploying the DhakaCart e-commerce platform to AWS using Infrastructure as Code (Terraform) and CI/CD (GitHub Actions).

## Prerequisites
- AWS Account with credentials configured
- GitHub repository with Actions enabled
- Local development environment with Git installed

## AWS Configuration
- **Region**: ap-southeast-1 (Singapore)
- **Account ID**: 388449571465
- **IAM User**: k1ij-poridhi

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Cloud (Singapore)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                Application Load Balancer                   │ │
│  │  (Distributes traffic across multiple EC2 instances)       │ │
│  └───────────────────┬───────────────────────────────────────┘ │
│                      │                                           │
│         ┌────────────┼─────────────┐                            │
│         │            │              │                            │
│  ┌──────▼────┐ ┌────▼──────┐ ┌────▼──────┐                    │
│  │ EC2       │ │ EC2        │ │ EC2        │                    │
│  │ Frontend  │ │ Backend    │ │ Backend    │                    │
│  │ (React)   │ │ (Node.js)  │ │ (Node.js)  │                    │
│  └───────────┘ └─────┬──────┘ └─────┬──────┘                    │
│                      │                │                           │
│                      └────────┬───────┘                           │
│                               │                                   │
│                      ┌────────▼───────┐                          │
│                      │  RDS PostgreSQL │                          │
│                      │  (Multi-AZ)     │                          │
│                      └─────────────────┘                          │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              S3 Bucket (Static Assets & Backups)           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │          CloudWatch (Monitoring & Logging)                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Steps

### Step 1: Configure GitHub Secrets
GitHub Actions requires AWS credentials as secrets. These have been configured:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

### Step 2: Review Infrastructure Code
Review the Terraform configuration in `terraform/main.tf`:
- VPC with public/private subnets
- EC2 instances with Auto Scaling
- Application Load Balancer
- Security Groups
- RDS database (optional)

### Step 3: Deploy Infrastructure

```bash
# Navigate to project directory
cd ~/projects/DhakaCart-E-Commerce-Reliability-Challenge

# Run deployment script
./deploy-to-aws.sh
```

This script will:
1. Install Terraform, kubectl, and Docker if needed
2. Initialize Terraform
3. Create an execution plan
4. Show you what will be created

### Step 4: Apply Terraform Changes

```bash
cd terraform
terraform apply tfplan
```

This will provision:
- VPC and networking components
- EC2 instances
- Load Balancer
- Security Groups
- S3 buckets

### Step 5: Trigger CI/CD Pipeline

```bash
# Commit and push changes
git add .
git commit -m "Deploy to AWS - Initial deployment"
git push origin main
```

GitHub Actions will automatically:
1. Run tests
2. Build Docker images
3. Push images to registry
4. Deploy to AWS EC2 instances
5. Run health checks

### Step 6: Monitor Deployment

Visit GitHub Actions tab to monitor:
- https://github.com/MehediHossain95/DhakaCart-E-Commerce-Reliability-Challenge/actions

Check AWS Console:
- EC2 Dashboard: https://ap-southeast-1.console.aws.amazon.com/ec2
- Load Balancers: Check for the ALB endpoint
- CloudWatch: Monitor metrics and logs

## Accessing the Application

After successful deployment:

1. **Get Load Balancer DNS**:
```bash
aws elbv2 describe-load-balancers --region ap-southeast-1 --query 'LoadBalancers[0].DNSName' --output text
```

2. **Access Application**:
- Frontend: `http://<load-balancer-dns>`
- Backend API: `http://<load-balancer-dns>/api`

## CI/CD Pipeline Details

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) includes:

1. **Build Stage**:
   - Checkout code
   - Run frontend tests
   - Run backend tests
   - Build Docker images
   - Security scanning with Trivy

2. **Deploy Stage**:
   - Push Docker images to GHCR
   - SSH into EC2 instances
   - Pull latest images
   - Restart containers
   - Health check verification

## Monitoring and Logging

### CloudWatch Dashboards
- CPU Utilization
- Memory Usage
- Request Count
- Error Rates
- Response Times

### Accessing Logs
```bash
# View application logs
aws logs tail /aws/ec2/dhakacart --follow --region ap-southeast-1

# View ALB access logs
aws s3 ls s3://dhakacart-alb-logs/
```

## Auto Scaling

The infrastructure includes auto-scaling:
- **Minimum instances**: 2
- **Maximum instances**: 10
- **Scale-up trigger**: CPU > 70% for 5 minutes
- **Scale-down trigger**: CPU < 30% for 10 minutes

## Security Features

1. **Network Security**:
   - Private subnets for application servers
   - Security groups with minimal required ports
   - NAT Gateway for outbound traffic

2. **Data Security**:
   - RDS encryption at rest
   - SSL/TLS for data in transit
   - Secrets stored in AWS Secrets Manager

3. **Access Control**:
   - IAM roles for EC2 instances
   - Least privilege access policies
   - MFA enabled for AWS console

## Backup and Recovery

### Automated Backups
- **RDS**: Automated daily backups with 7-day retention
- **EBS**: Daily snapshots
- **S3**: Versioning enabled

### Disaster Recovery
```bash
# Restore from RDS snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier dhakacart-restored \
  --db-snapshot-identifier snapshot-id \
  --region ap-southeast-1
```

## Cost Optimization

Expected monthly costs (approximate):
- **EC2 (t3.medium x 2)**: $60
- **ALB**: $20
- **RDS (db.t3.micro)**: $15
- **S3 Storage**: $5
- **Data Transfer**: $10
- **Total**: ~$110/month

### Cost Reduction Tips
1. Use Reserved Instances for 40% savings
2. Enable S3 lifecycle policies
3. Use CloudWatch alarms to prevent over-scaling
4. Stop non-production instances during off-hours

## Troubleshooting

### Common Issues

1. **Deployment fails**:
   - Check GitHub Actions logs
   - Verify AWS credentials
   - Check EC2 instance health

2. **Application not accessible**:
   - Verify security group rules
   - Check ALB target health
   - Review application logs

3. **High latency**:
   - Check RDS connection pool
   - Review CloudWatch metrics
   - Consider adding Redis cache

### Debug Commands

```bash
# Check EC2 instance status
aws ec2 describe-instances --region ap-southeast-1

# View target health
aws elbv2 describe-target-health --target-group-arn <arn>

# SSH into instance
ssh -i dhakacart-key.pem ec2-user@<instance-ip>

# Check Docker containers
docker ps
docker logs <container-id>
```

## Rollback Procedure

If deployment fails:

```bash
# Revert to previous version
git revert HEAD
git push origin main

# Or manually rollback in AWS
aws ecs update-service --service dhakacart --task-definition dhakacart:previous-version
```

## Support and Contact

- **Project Lead**: Mehedi Hossain
- **Email**: mhbabo95@gmail.com
- **GitHub**: @MehediHossain95

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
