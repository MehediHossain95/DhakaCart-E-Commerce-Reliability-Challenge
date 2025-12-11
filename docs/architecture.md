# Architecture & Design Documentation

## 🏗️ System Architecture

### High-Level Overview

```
Internet Users (100,000+)
        ↓
   AWS Internet Gateway
        ↓
Application Load Balancer (ALB)
        ↓
Kubernetes Ingress Controller
        ↓
Frontend Service (LoadBalancer)  ←→  Backend Service (ClusterIP)
    (3-8 pods)                           (3-10 pods)
        ↓
  Nginx Reverse Proxy
  HTML Dashboard UI
        ↓
    API Calls
        ↓
  Node.js Express API
  - Health Checks
  - Request Logging
  - Error Handling
        ↓
    AWS RDS Database
    - Multi-AZ Failover
    - Encrypted at Rest
    - Daily Snapshots
```

---

## 🌐 Network Architecture

### VPC Design

```
┌─────────────────────────────────────────────────────────────┐
│ AWS VPC (10.0.0.0/16)                                       │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Public Subnet (10.0.1.0/24)                         │   │
│  │  - Internet Gateway                                   │   │
│  │  - NAT Gateway                                        │   │
│  │  - Application Load Balancer                          │   │
│  │  - Kubernetes Ingress Controller                      │   │
│  └──────────────────────────────────────────────────────┘   │
│         ↓                                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Private Subnet (10.0.2.0/24)                        │   │
│  │  - Kubernetes Nodes                                   │   │
│  │  - Frontend & Backend Pods                            │   │
│  │  - Monitoring Stack                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│         ↓                                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Database Subnet (10.0.3.0/24)                       │   │
│  │  - AWS RDS (Private)                                 │   │
│  │  - No internet access (high security)                │   │
│  │  - Multi-AZ replication                              │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Security Groups

#### Internet Gateway Security Group
- **Inbound:** HTTP (80), HTTPS (443) from 0.0.0.0/0
- **Outbound:** All traffic allowed

#### Kubernetes Node Security Group
- **Inbound:** 
  - SSH (22) from Admin IPs only
  - K3s API (6443) from VPC only
  - Pod networking (ephemeral ports)
- **Outbound:** All traffic allowed

#### Database Security Group
- **Inbound:** PostgreSQL (5432) from K8s nodes only
- **Outbound:** None (isolated)

---

## 🐳 Container Architecture

### Docker Image Hierarchy

```
Base Images (Official)
├─ node:18-alpine
│  └─ Backend Dockerfile
│     ├─ Dependencies layer (npm install)
│     ├─ Application layer
│     ├─ Security context (non-root)
│     └─ Health check endpoint
│
└─ nginx:alpine (Multi-stage)
   ├─ Builder stage
   │  ├─ node:18-alpine
   │  ├─ Build frontend
   │  └─ Optimize assets
   │
   └─ Runtime stage
      ├─ nginx:alpine
      ├─ Copy built assets
      ├─ Configuration
      └─ Start nginx daemon
```

### Container Security

**Backend Container:**
```dockerfile
USER node              # Non-root user
EXPOSE 5000
HEALTHCHECK CMD curl -f http://localhost:5000/health

# Security context in K8s:
runAsNonRoot: true
runAsUser: 1000
readOnlyRootFilesystem: true
```

**Frontend Container:**
```dockerfile
USER nginx            # nginx:101 (Alpine)
EXPOSE 80
```

---

## ☸️ Kubernetes Architecture

### Pod Topology

```
Kubernetes Cluster
├─ Namespace: default
│
├─ Deployment: dhakacart-backend
│  ├─ Replicas: 3 (min) → 10 (max)
│  ├─ Strategy: RollingUpdate (maxSurge=1, maxUnavailable=0)
│  ├─ Pod Affinity: Anti-affinity (spread across nodes)
│  └─ Each Pod:
│     ├─ Container: dhakacart-backend
│     ├─ Resources:
│     │  ├─ Requests: 100m CPU, 128Mi Memory
│     │  └─ Limits: 500m CPU, 512Mi Memory
│     ├─ Probes:
│     │  ├─ Liveness: /health every 10s
│     │  └─ Readiness: /ready every 5s
│     └─ Security: runAsNonRoot=true
│
├─ Deployment: dhakacart-frontend
│  ├─ Replicas: 3 (min) → 8 (max)
│  ├─ Strategy: RollingUpdate
│  ├─ Pod Affinity: Anti-affinity
│  └─ Each Pod:
│     ├─ Container: dhakacart-frontend
│     ├─ Resources:
│     │  ├─ Requests: 50m CPU, 64Mi Memory
│     │  └─ Limits: 250m CPU, 256Mi Memory
│     └─ Environment: API_URL via Service DNS
│
├─ Service: dhakacart-backend-service
│  ├─ Type: ClusterIP (internal only)
│  ├─ Port: 5000
│  └─ Selector: app=backend
│
├─ Service: dhakacart-frontend-service
│  ├─ Type: ClusterIP
│  ├─ Port: 80
│  └─ Selector: app=frontend
│
├─ Ingress: dhakacart-ingress
│  ├─ Class: nginx
│  ├─ Rule: / → frontend:80
│  ├─ Rule: /api → backend:5000
│  └─ TLS: Let's Encrypt (future)
│
├─ HPA: backend-hpa
│  ├─ Min replicas: 3
│  ├─ Max replicas: 10
│  ├─ CPU target: 70%
│  └─ Memory target: 80%
│
├─ HPA: frontend-hpa
│  ├─ Min replicas: 3
│  ├─ Max replicas: 8
│  ├─ CPU target: 75%
│  └─ Memory target: 85%
│
├─ NetworkPolicy: dhakacart-network-policy
│  ├─ Frontend ← Ingress Controller
│  ├─ Backend ← Frontend
│  └─ Database ← Backend (future)
│
└─ Deployment: prometheus (Monitoring)
   ├─ ServiceAccount: prometheus
   ├─ ClusterRole: scrape all pods
   └─ PVC: metrics storage
```

### Deployment Process

```
1. Developer pushes code to GitHub
              ↓
2. GitHub Actions triggered
   ├─ Run tests (backend/frontend)
   ├─ Security scan (Trivy)
   └─ Build Docker images
              ↓
3. Push images to GHCR
              ↓
4. Deploy to Kubernetes
   ├─ kubectl apply -f k8s/
   ├─ Rolling update starts
   │  ├─ Surge pod created (4 total)
   │  ├─ New pod passes readiness
   │  ├─ Old pod drained gracefully
   │  └─ Process repeats until all updated
   └─ Health checks verify stability
              ↓
5. Send Slack notification
   ├─ ✅ Deployment successful
   └─ Version: SHA-XXXXX
```

---

## 💾 Database Architecture

### RDS Setup

```
AWS RDS Instance (Multi-AZ)
├─ Engine: PostgreSQL 14
├─ Instance Class: db.t3.micro (development)
├─ Storage: 20GB gp2
├─ Multi-AZ: Enabled
│  ├─ Primary (ap-southeast-1a)
│  └─ Standby (ap-southeast-1b)
├─ Backup:
│  ├─ Backup retention: 7 days
│  ├─ Automated snapshots daily
│  └─ S3 backup storage
├─ Security:
│  ├─ Encryption at rest (AWS KMS)
│  ├─ Encryption in transit (SSL/TLS)
│  ├─ VPC endpoint (private)
│  ├─ Security group (Backend pods only)
│  └─ Secrets Manager (password)
└─ Monitoring:
   ├─ CloudWatch metrics
   ├─ Enhanced monitoring
   └─ Alerts on:
      ├─ CPU > 80%
      ├─ Storage > 80%
      └─ Connection errors
```

### Database Schema (Future)

```sql
-- Products table
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10, 2),
  stock INT DEFAULT 0,
  category VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Orders table
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  order_number VARCHAR(50) UNIQUE,
  customer_id INT,
  total_amount DECIMAL(10, 2),
  status VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indices for performance
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_created ON orders(created_at);
```

---

## 📊 Monitoring & Observability

### Metrics Collection

```
Prometheus Scraping
├─ Kubernetes Metrics Server
│  ├─ CPU usage per pod
│  ├─ Memory usage per pod
│  ├─ Network I/O
│  └─ Storage usage
│
├─ Backend Pods (/metrics)
│  ├─ HTTP request rate
│  ├─ Response time (p50, p95, p99)
│  ├─ Error rate (4xx, 5xx)
│  └─ Business metrics (items sold, etc.)
│
└─ Custom Alerts
   ├─ CPU > 80%
   ├─ Memory > 85%
   ├─ Response time > 1s
   ├─ Error rate > 1%
   └─ Pod restarts > 3
```

### Grafana Dashboards

1. **System Health Dashboard**
   - Node CPU/Memory/Disk
   - Pod resource usage
   - Network I/O

2. **Application Dashboard**
   - Request rate (req/sec)
   - Response latency (ms)
   - Error rate (%)
   - Top endpoints

3. **Scaling Dashboard**
   - Current replicas
   - Desired replicas
   - CPU/Memory trends
   - Scaling events log

---

## 🔐 Security Architecture

### Defense in Depth

```
Layer 1: Network Level
├─ AWS Security Groups (firewall rules)
├─ Network ACLs
├─ VPC isolation (public/private subnets)
└─ Private database subnet

Layer 2: Kubernetes Level
├─ Network Policies (pod-to-pod networking)
├─ Pod Security Standards
├─ RBAC (role-based access control)
└─ Service Account restrictions

Layer 3: Application Level
├─ HTTPS/TLS encryption
├─ Input validation
├─ Rate limiting
├─ SQL prepared statements
└─ Error handling (no sensitive data in errors)

Layer 4: Data Level
├─ Database encryption at rest (KMS)
├─ Encryption in transit (SSL/TLS)
├─ Secrets in AWS Secrets Manager
└─ Audit logging
```

### Secrets Management

```
Credentials Flow
├─ AWS Secrets Manager
│  ├─ Database password
│  ├─ API keys
│  └─ JWT secrets
│
├─ Kubernetes Secrets
│  ├─ Base64 encoded (for pod mount)
│  ├─ Mounted as volumes
│  └─ Never in logs
│
└─ Pod Environment Variables
   └─ Set from secrets
```

---

## 🔄 CI/CD Architecture

### GitHub Actions Workflow

```
Event: git push
├─ Trigger: main or feature branches
├─ Concurrency: max 1 deployment per branch
│
├─ Job 1: Test Backend
│  ├─ Checkout code
│  ├─ Setup Node.js 18
│  ├─ npm install
│  ├─ npm lint
│  └─ npm test
│
├─ Job 2: Test Frontend
│  ├─ Checkout code
│  ├─ Setup Node.js 18
│  ├─ npm install
│  ├─ npm build
│  └─ npm test
│
├─ Job 3: Security Scan
│  ├─ Checkout code
│  ├─ Run Trivy scan
│  └─ Upload SARIF results
│
├─ Job 4: Build & Push (requires tests to pass)
│  ├─ Setup buildx
│  ├─ Login to GHCR
│  ├─ Build backend image
│  ├─ Push backend image
│  ├─ Build frontend image
│  └─ Push frontend image
│
└─ Job 5: Deploy (requires build to pass)
   ├─ Setup kubectl
   ├─ Get kubeconfig from secrets
   ├─ kubectl apply -f k8s/
   ├─ Wait for rollout (5min timeout)
   ├─ Send Slack notification
   └─ On failure: Automatic rollback
```

### Image Registry

```
GitHub Container Registry (GHCR)
└─ ghcr.io/username/
   ├─ dhakacart-backend
   │  ├─ main-latest
   │  ├─ main-SHA12345
   │  └─ v1.0.0
   │
   └─ dhakacart-frontend
      ├─ main-latest
      ├─ main-SHA12345
      └─ v1.0.0
```

---

## 🚀 Scaling Strategy

### Horizontal Pod Autoscaling (HPA)

**Backend HPA**
```
Target: Deployment/dhakacart-backend
Min Replicas: 3
Max Replicas: 10
Metrics:
  - CPU: 70% utilization
  - Memory: 80% utilization

Behavior:
  Scale Up: 
    - 100% increase every 15 seconds
    - +2 pods every 15 seconds
  Scale Down:
    - 50% decrease every 15 seconds (after 5min stable)
    - -1 pod every 15 seconds
```

**Load Profile**

```
Time          Traffic    Backend Pods   Frontend Pods
00:00-06:00   Low (1k)   3              3
06:00-09:00   Medium(15k) 5             4
09:00-18:00   High (50k) 8-10           6-8
18:00-23:00   Medium(25k) 6             5
23:00-00:00   Low (2k)   3              3

Peak Eid Sale: 100k+ users
├─ Backend scales to 10 pods (max)
├─ Frontend scales to 8 pods (max)
└─ Load balancer distributes across all
```

---

## 📈 Capacity Planning

### Resource Allocation

**Per Backend Pod:**
- CPU: 500m (half core)
- Memory: 512Mi
- Network: ~10 Mbps (varies)
- Estimated users: 10,000 (with 3 replicas)

**Per Frontend Pod:**
- CPU: 250m
- Memory: 256Mi
- Network: ~5 Mbps
- Estimated requests: 5,000/sec (with 3 replicas)

**Total Cluster (Max Scaling):**
- Backend: 10 pods × 500m = 5 vCPU
- Frontend: 8 pods × 250m = 2 vCPU
- Monitoring: 1 vCPU
- **Total: ~8 vCPU equivalent**

---

## 🔧 Technology Decisions & Rationale

### Why Kubernetes (K3s)?
- ✅ Auto-healing (restart failed pods)
- ✅ Auto-scaling (respond to load)
- ✅ Rolling updates (zero downtime)
- ✅ Multi-host deployment
- ✅ Built-in monitoring/logging hooks
- ✅ Industry standard

### Why Terraform?
- ✅ Infrastructure as Code (reproducible)
- ✅ Version control (git history)
- ✅ Modular (reusable components)
- ✅ AWS native support
- ✅ State management

### Why GitHub Actions?
- ✅ Native GitHub integration
- ✅ Free for public repos
- ✅ Extensive marketplace
- ✅ Easy configuration (YAML)
- ✅ Matrix testing support

### Why AWS RDS?
- ✅ Managed service (no ops overhead)
- ✅ Multi-AZ automatic failover
- ✅ Automated backups
- ✅ Encryption at rest
- ✅ CloudWatch integration

---

## 📊 Performance Targets

| Metric | Target | How Achieved |
|--------|--------|--------------|
| Response Time (p95) | < 200ms | Optimized Node.js, caching |
| Availability | 99.9% | 3+ replicas, failover |
| Auto-scale Time | < 1 min | HPA checks every 15s |
| Deployment Time | < 10 min | Parallel builds, push |
| MTTD (Mean Time To Detect) | < 1 min | Prometheus alerts |
| MTTR (Mean Time To Recover) | < 1 min | Auto-failover + probes |

---

**Architecture Version:** 1.0  
**Last Updated:** December 11, 2025
