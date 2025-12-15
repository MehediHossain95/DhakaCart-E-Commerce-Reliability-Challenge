# DhakaCart Deployment & Setup Guide

## 📋 Pre-Deployment Checklist

Before deploying to AWS, verify:

- [ ] AWS Account access (Poridhi lab credentials)
- [ ] AWS CLI installed and configured
- [ ] Terraform installed (v1.0+)
- [ ] kubectl installed (v1.24+)
- [ ] Git access to repository
- [ ] Docker installed (optional, for local testing)
- [ ] SSH key pair (`dhakacart-key.pub` in project root)

---

## 🚀 Complete Deployment Guide

### Phase 1: Infrastructure Setup (Terraform)

#### 1.1 Initialize Terraform
```bash
cd terraform
terraform init

# Verify backend configuration
terraform plan
```

#### 1.2 Review Infrastructure
```bash
# See what will be created
terraform plan -out=tfplan
cat tfplan  # Review changes

# Key resources:
# - VPC (10.0.0.0/16)
# - Public subnet (10.0.1.0/24)
# - Internet Gateway
# - EC2 instance (t2.micro, Ubuntu 22.04)
# - Security groups
# - SSH key pair
```

#### 1.3 Deploy Infrastructure
```bash
# Apply Terraform configuration
terraform apply tfplan

# Wait for EC2 instance to boot (~2 minutes)
# Note: K3s auto-installation in progress

# Get outputs
terraform output

# Save these values:
INSTANCE_IP=$(terraform output -raw instance_public_ip)
INSTANCE_ID=$(terraform output -raw instance_id)
```

#### 1.4 Verify EC2 Instance
```bash
# SSH into instance
ssh -i dhakacart-key ubuntu@$INSTANCE_IP

# Check K3s installation status
sudo systemctl status k3s

# Verify K3s is running
sudo k3s kubectl get nodes

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > ~/k3s.yaml
sudo chown ubuntu:ubuntu ~/k3s.yaml

# Exit EC2 instance
exit
```

#### 1.5 Download Kubeconfig
```bash
# Copy kubeconfig from instance to local machine
scp -i dhakacart-key ubuntu@$INSTANCE_IP:~/k3s.yaml ./k3s.yaml

# Update server IP in kubeconfig
sed -i "s/127.0.0.1/$INSTANCE_IP/" k3s.yaml

# Set kubeconfig environment variable
export KUBECONFIG=$(pwd)/k3s.yaml

# Verify connection
kubectl get nodes
# Should show 1 node running
```

---

### Phase 2: Application Setup

#### 2.1 Build Docker Images

**Option A: Build Locally (Quick Testing)**
```bash
# Backend
cd backend
docker build -t dhakacart-backend:v1 .
cd ..

# Frontend
cd frontend
docker build -t dhakacart-frontend:v1 .
cd ..
```

**Option B: Build on K3s Node (Production)**
```bash
# SSH into K3s node
ssh -i dhakacart-key ubuntu@$INSTANCE_IP

# Clone repository on instance
git clone https://github.com/MehediHossain95/DhakaCart-E-Commerce-Reliability-Challenge.git
cd DhakaCart-E-Commerce-Reliability-Challenge

# Build images with Docker
docker build -t dhakacart-backend:latest ./backend
docker build -t dhakacart-frontend:latest ./frontend

# Verify images
docker images | grep dhakacart

exit
```

#### 2.2 Load Images into K3s

**For Local Images:**
```bash
# If built locally, copy to K3s node
docker save dhakacart-backend:v1 | \
  ssh -i dhakacart-key ubuntu@$INSTANCE_IP \
  docker load

docker save dhakacart-frontend:v1 | \
  ssh -i dhakacart-key ubuntu@$INSTANCE_IP \
  docker load
```

**For Images Built on Node:**
```bash
# Already loaded, just tag with 'latest'
ssh -i dhakacart-key ubuntu@$INSTANCE_IP \
  docker tag dhakacart-backend:latest dhakacart-backend:v1

ssh -i dhakacart-key ubuntu@$INSTANCE_IP \
  docker tag dhakacart-frontend:latest dhakacart-frontend:v1
```

---

### Phase 3: Kubernetes Deployment

#### 3.1 Create Namespaces & Secrets
```bash
# Create default namespace
kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

# Create database credentials secret
kubectl create secret generic db-credentials \
  --from-literal=username=dhakacart \
  --from-literal=password='DhakaCart@2024!' \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify
kubectl get secrets
```

#### 3.2 Deploy Applications
```bash
# Deploy backend
kubectl apply -f k8s/backend.yaml

# Deploy frontend
kubectl apply -f k8s/frontend.yaml

# Deploy network policies
kubectl apply -f k8s/network-policy.yaml

# Deploy auto-scaling
kubectl apply -f k8s/hpa.yaml

# Deploy monitoring
kubectl apply -f k8s/monitoring.yaml

# Verify all deployments
kubectl get deployments
kubectl get pods
kubectl get svc
```

#### 3.3 Verify Pods are Running
```bash
# Watch pods starting
kubectl get pods -w

# Once all Running, press Ctrl+C

# Check detailed status
kubectl get pods -o wide

# Expected output:
# NAME                                 READY   STATUS    RESTARTS
# dhakacart-backend-XXXXX              1/1     Running   0
# dhakacart-frontend-XXXXX             1/1     Running   0
# prometheus-XXXXX                     1/1     Running   0
```

#### 3.4 Verify Services
```bash
# List services
kubectl get svc

# Expected:
# dhakacart-backend-service    ClusterIP
# dhakacart-frontend-service   ClusterIP
# prometheus                   ClusterIP
```

---

### Phase 4: Accessing Services

#### 4.1 Access Frontend (HTTP)
```bash
# Port-forward frontend
kubectl port-forward svc/dhakacart-frontend-service 8080:80 &

# Access in browser
# http://localhost:8080

# Should display: "🛒 DhakaCart Eid Sale"
# Status should show: "System Status: Operational"
```

#### 4.2 Access Prometheus (Metrics)
```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus 9090:9090 &

# Access in browser
# http://localhost:9090

# Test query: node_memory_MemFree_bytes
# Should return metrics graph
```

#### 4.3 Test Backend API
```bash
# Test via kubectl port-forward
kubectl port-forward svc/dhakacart-backend-service 5000:5000 &

# Test endpoints
curl http://localhost:5000/
# Response: {"message": "DhakaCart API is Online!", ...}

curl http://localhost:5000/health
# Response: {"status": "healthy"}

curl http://localhost:5000/api/products
# Response: {"products": [...]}
```

---

### Phase 5: Monitoring & Validation

#### 5.1 Check Pod Logs
```bash
# Backend logs
kubectl logs -f deployment/dhakacart-backend

# Frontend logs
kubectl logs -f deployment/dhakacart-frontend

# Look for any errors or warnings
```

#### 5.2 Check Resource Usage
```bash
# Current resource usage
kubectl top nodes
kubectl top pods

# Should show reasonable CPU/Memory utilization
# Each pod should use < 50% of limits
```

#### 5.3 Verify Auto-Scaling
```bash
# Check HPA status
kubectl get hpa

# Expected:
# REFERENCE                          TARGETS   MINPODS  MAXPODS  REPLICAS
# Deployment/dhakacart-backend       2%/70%    3        10       3
# Deployment/dhakacart-frontend      1%/75%    3        8        3

# Metrics should eventually show values (takes ~1 minute)
```

#### 5.4 Test Failure Recovery
```bash
# Delete a pod and verify it restarts
kubectl delete pod -l app=backend

# Watch it respawn
kubectl get pods -w -l app=backend

# Should restart within 10 seconds
# Status should return to Running
```

---

### Phase 6: Load Testing (Optional)

#### 6.1 Generate Traffic
```bash
# Using Apache Bench (install if needed)
sudo apt-get install apache2-utils

# Test with 100 requests, 10 concurrent
ab -n 100 -c 10 http://localhost:8080/

# Expected results:
# Requests per second: > 100
# Time per request: < 100ms (avg)
# Failures: 0
```

#### 6.2 Monitor Scaling
```bash
# Generate sustained load
while true; do curl -s http://localhost:8080/ > /dev/null; done &

# Watch HPA scale up
kubectl get hpa --watch
kubectl top pods --watch

# After ~2 minutes, backend should scale to 4-5 pods
# Stop load: pkill curl
```

---

## 🔧 Configuration Files Reference

### Environment Variables

**Backend (.env or k8s secret):**
```
PORT=5000
NODE_ENV=production
DB_HOST=<rds-endpoint>
DB_USER=dhakacart
DB_PASSWORD=<from-secrets>
DB_NAME=dhakacart
```

**Frontend (env.js or ConfigMap):**
```
REACT_APP_API_URL=http://dhakacart-backend-service:5000
REACT_APP_ENV=production
```

### Kubernetes Resources Used

| Resource | Count | Purpose |
|----------|-------|---------|
| Deployments | 3 | Backend, Frontend, Prometheus |
| Services | 4 | Backend, Frontend, Prometheus, Ingress |
| ConfigMaps | 1 | Prometheus config |
| Secrets | 1 | Database credentials |
| HPA | 2 | Backend & Frontend scaling |
| NetworkPolicies | 3 | Zero-trust networking |
| Total Memory Required | 2GB+ | All pods + monitoring |
| Total CPU Required | 2+ cores | All pods + system |

---

## 📊 Post-Deployment Validation

### Checklist

- [ ] All pods running: `kubectl get pods` shows all Running
- [ ] Services accessible: frontend loads in browser
- [ ] Backend API working: `curl localhost:5000/health` returns 200
- [ ] Prometheus scraping: Metrics visible in Prometheus UI
- [ ] Auto-scaling working: HPA shows target metrics
- [ ] Logs clean: No errors in pod logs
- [ ] Network policies applied: `kubectl get networkpolicies`
- [ ] Security context: Pods run as non-root

### Performance Baseline

Before load testing, record:
```bash
# Baseline metrics (no load)
kubectl top nodes
kubectl top pods

# Expected (idle):
# Backend pod: ~10-20m CPU, 50-100Mi Memory
# Frontend pod: ~5-10m CPU, 30-50Mi Memory
```

---

## 🐛 Troubleshooting Deployment

### ImagePullBackOff Error
```bash
# Check if image exists on node
ssh -i dhakacart-key ubuntu@$INSTANCE_IP
docker images | grep dhakacart

# If missing, rebuild:
docker build -t dhakacart-backend:latest ./backend
```

### CrashLoopBackOff Error
```bash
# Check logs
kubectl logs <pod-name>

# Common issues:
# - Missing environment variables
# - Port already in use
# - Application error

# Check deployment config
kubectl describe deployment dhakacart-backend
```

### Pending Pods
```bash
# Check resource availability
kubectl top nodes

# If > 1GB memory used, clear space
kubectl delete pod -l app=prometheus

# Or scale down manually
kubectl scale deployment dhakacart-backend --replicas=1
```

---

## 📝 Maintenance Tasks

### Regular Monitoring
```bash
# Daily check (5 minutes)
kubectl get pods
kubectl get nodes
kubectl top pods

# Check logs for errors
kubectl logs -l app=backend --tail=20 --timestamps=true
```

### Weekly Maintenance
```bash
# Check disk space
kubectl exec -it <pod-name> -- df -h /

# Verify backups (if database setup)
aws rds describe-db-snapshots

# Review metrics trends in Prometheus
# http://localhost:9090/graph
```

### Monthly Tasks
```bash
# Update dependencies
cd backend && npm update && npm audit
cd ../frontend && npm update && npm audit

# Test disaster recovery
# Restore from backup (test only, don't apply)

# Review and update runbooks if needed
git diff docs/

# Plan capacity for next month
# Based on growth trends
```

---

## 🧹 Cleanup (Tear Down)

**To remove all resources and save costs:**

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Delete infrastructure
cd terraform
terraform destroy

# Confirm destruction
# Type 'yes' when prompted

# Verify deleted
aws ec2 describe-instances --region ap-southeast-1 | grep i-
# Should return empty (no instances)

aws ec2 describe-vpcs --region ap-southeast-1 | grep dhakacart
# Should return empty (no VPC)
```

---

**Setup Version:** 1.0  
**Last Updated:** December 11, 2025  
**Maintained By:** DhakaCart DevOps Team
