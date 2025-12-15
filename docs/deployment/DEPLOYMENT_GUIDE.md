# DhakaCart Deployment Guide

## Pre-Deployment Checklist

- [ ] AWS account configured with ap-southeast-1 region
- [ ] Terraform installed (v1.0+)
- [ ] kubectl installed (v1.24+)
- [ ] Docker installed (for local image building)
- [ ] GitHub account with push access to repository
- [ ] GitHub Container Registry (GHCR) token generated
- [ ] Domain name registered (optional, for production)
- [ ] SSL certificates ready (Let's Encrypt will auto-generate)

---

## Phase 1: Infrastructure Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/MehediHossain95/DhakaCart-E-Commerce-Reliability-Challenge.git
cd DhakaCart-E-Commerce-Reliability-Challenge
```

### Step 2: Configure AWS Credentials

```bash
# Option 1: Using AWS CLI
aws configure --profile dhakacart
# Enter Access Key, Secret Key, Region: ap-southeast-1

# Option 2: Export environment variables
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="ap-southeast-1"
export AWS_PROFILE="dhakacart"
```

### Step 3: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure changes
terraform apply
# Type 'yes' when prompted

# Get EC2 instance details
terraform output
```

**Output should show:**
- VPC ID
- Subnet IDs
- Security Group ID
- EC2 Instance Public IP
- SSH Key information

### Step 4: SSH into EC2 Instance

```bash
# Get instance public IP from Terraform output
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# SSH into instance
ssh -i ../dhakacart-key ubuntu@$INSTANCE_IP

# K3s should auto-install (wait 2-3 minutes)
# Verify installation
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Phase 2: Application Deployment

### Step 1: Build Docker Images Locally

```bash
cd /home/mehedi/Projects/DhakaCart-E-Commerce-Reliability-Challenge

# Build backend image
cd backend
docker build -t dhakacart-backend:v1.0.0 .
cd ..

# Build frontend image
cd frontend
docker build -t dhakacart-frontend:v1.0.0 .
cd ..
```

### Step 2: Push to Container Registry

```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin

# Tag images
docker tag dhakacart-backend:v1.0.0 ghcr.io/<username>/dhakacart-backend:v1.0.0
docker tag dhakacart-frontend:v1.0.0 ghcr.io/<username>/dhakacart-frontend:v1.0.0

# Push images
docker push ghcr.io/<username>/dhakacart-backend:v1.0.0
docker push ghcr.io/<username>/dhakacart-frontend:v1.0.0
```

### Step 3: Update Kubernetes Manifests

```bash
# Edit k8s/backend.yaml and k8s/frontend.yaml
# Change image references from:
#   image: dhakacart-backend:latest
# To:
#   image: ghcr.io/<username>/dhakacart-backend:v1.0.0

# Or load images into K3s directly (local development)
scp -i dhakacart-key backend/Dockerfile ubuntu@$INSTANCE_IP:~/
scp -i dhakacart-key frontend/Dockerfile ubuntu@$INSTANCE_IP:~/
```

### Step 4: Create Kubernetes Secrets

```bash
# Set kubeconfig
export KUBECONFIG=/path/to/k3s.yaml

# Create namespace for monitoring
kubectl create namespace monitoring

# Create secrets
kubectl create secret generic dhakacart-secrets \
  --from-literal=DB_HOST="your-db-host" \
  --from-literal=DB_USER="admin" \
  --from-literal=DB_PASSWORD="secure-password" \
  --from-literal=DB_NAME="dhakacart"

# Verify
kubectl get secrets
```

### Step 5: Deploy Applications

```bash
# Apply configurations (order matters)
kubectl apply -f k8s/network-policy.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/monitoring.yaml
kubectl apply -f k8s/logging-monitoring.yaml

# Verify deployments
kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get hpa
```

### Step 6: Verify All Services Running

```bash
# Check pod status
kubectl get pods -w

# View deployment status
kubectl rollout status deployment/dhakacart-backend
kubectl rollout status deployment/dhakacart-frontend

# Check service endpoints
kubectl get endpoints
kubectl get svc -o wide
```

---

## Phase 3: Access Services

### Frontend Access

```bash
# Port-forward for local testing
kubectl port-forward svc/dhakacart-frontend-service 8080:80

# Visit http://localhost:8080 in browser
```

### Backend API Testing

```bash
# Health check
curl http://localhost:5000/health

# Main API
curl http://localhost:5000/

# Products API
curl http://localhost:5000/api/products
```

### Monitoring & Logging

```bash
# Prometheus (metrics)
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit http://localhost:9090

# Grafana (dashboards)
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# Login: admin / admin
# Visit http://localhost:3000

# Loki (logging)
kubectl port-forward svc/loki 3100:3100 -n monitoring
# Visit http://localhost:3100
```

---

## Phase 4: Testing

### Run Integration Tests

```bash
# Make scripts executable
chmod +x integration-test.sh load-test.sh db-backup.sh

# Run integration tests
./integration-test.sh

# Expected output: All tests passing
```

### Run Load Tests

```bash
# Load test with 10,000 requests, 100 concurrent users
./load-test.sh http://localhost:8080 10000 100

# Review results in load-test-results/
cat load-test-results/homepage-results.txt
```

---

## Phase 5: CI/CD Pipeline

### GitHub Actions Configuration

1. Create GitHub secrets:

```bash
# In GitHub repository Settings → Secrets → New secret

# Add secrets:
- KUBECONFIG (base64 encoded k3s.yaml)
- SLACK_WEBHOOK (optional, for notifications)
- DOCKER_REGISTRY_TOKEN (GitHub token with package write access)
```

2. Verify GitHub Actions workflow:

```bash
# Push changes to trigger pipeline
git add .
git commit -m "Deploy updated version"
git push origin main

# Watch pipeline in GitHub Actions tab
```

---

## Phase 6: Database Setup (Optional - For Production)

### Create RDS Database

```bash
# Using AWS CLI
aws rds create-db-instance \
  --db-instance-identifier dhakacart-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username admin \
  --master-user-password "YourSecurePassword123!" \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name default \
  --multi-az \
  --storage-type gp2 \
  --allocated-storage 20 \
  --backup-retention-period 7 \
  --region ap-southeast-1
```

### Database Connection from Kubernetes

```bash
# Update k8s/secrets.yaml with RDS endpoint
# Then deploy:
kubectl apply -f k8s/secrets.yaml

# Backend will connect automatically using environment variables
```

### Enable Automated Backups

```bash
# Using provided script
chmod +x db-backup.sh
./db-backup.sh enable-backups

# Create manual backup
./db-backup.sh backup

# List backups
./db-backup.sh list-backups
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
kubectl top pods
```

### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints

# Check ingress
kubectl describe ingress dhakacart-ingress

# Check network policies
kubectl get networkpolicy
```

### Database Connection Failed

```bash
# Check secrets
kubectl get secret dhakacart-secrets
kubectl describe secret dhakacart-secrets

# Test database connectivity
kubectl exec -it <backend-pod> -- bash
# Inside pod: curl http://database-host:5432
```

---

## Scaling Up for High Traffic

### Auto-Scaling Configuration

```bash
# HPA is already configured in k8s/hpa.yaml
# Current settings:
# - Backend: 3-10 pods (scales at 70% CPU, 80% memory)
# - Frontend: 3-8 pods (scales at 75% CPU, 85% memory)

# Monitor HPA status
kubectl get hpa -w

# Manual scaling (if needed)
kubectl scale deployment dhakacart-backend --replicas=10
```

### Load Balancer Configuration

```bash
# Frontend service is exposed via LoadBalancer
# AWS ALB is automatically created

# Get LoadBalancer IP/DNS
kubectl get svc dhakacart-frontend-service

# Test with domain name (after DNS setup)
curl https://dhakacart.example.com
```

---

## Production Deployment Checklist

- [ ] All secrets properly managed (no hardcoded values)
- [ ] HTTPS/TLS configured
- [ ] Monitoring and alerting active
- [ ] Database backups automated
- [ ] Log aggregation working
- [ ] Network policies enforced
- [ ] Resource limits configured
- [ ] Health checks passing
- [ ] Load testing successful
- [ ] CI/CD pipeline working
- [ ] Runbooks documented
- [ ] Team trained on operations

---

## Rollback Procedures

### Rollback Recent Deployment

```bash
# Check rollout history
kubectl rollout history deployment/dhakacart-backend

# Rollback to previous version
kubectl rollout undo deployment/dhakacart-backend

# Rollback to specific revision
kubectl rollout undo deployment/dhakacart-backend --to-revision=2

# Watch rollback progress
kubectl rollout status deployment/dhakacart-backend
```

### Rollback Database

```bash
# Restore from snapshot
./db-backup.sh list-backups
./db-backup.sh restore <snapshot-id>

# Point-in-time recovery
./db-backup.sh pitr "2025-12-11T10:30:00Z"
```

---

## Support & Contact

For issues or questions:
1. Check logs: `kubectl logs <pod>`
2. Review troubleshooting section above
3. Check GitHub Issues
4. Contact DevOps team

---

**Last Updated:** December 11, 2025
