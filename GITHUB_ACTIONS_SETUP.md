# GitHub Actions CI/CD Setup

## Current Status
✅ **Application Deployed and Running**
- URL: http://18.143.130.128
- Frontend: ✓ Operational
- Backend API: ✓ Operational  
- Infrastructure: AWS EC2 t3.medium (Singapore)

## GitHub Secrets Configuration

To enable automated CI/CD deployments, configure these secrets in your GitHub repository:

### Navigate to:
```
Repository → Settings → Secrets and variables → Actions → New repository secret
```

### Required Secrets:

#### 1. EC2_HOST
```
18.143.130.128
```

#### 2. SSH_PRIVATE_KEY
Copy the entire content from: `dhakacart-key` file

## CI/CD Workflow

### Trigger
- **Push to `main` branch** - Full deployment
- **Push to `develop` branch** - Build and test only
- **Pull Request to `main`** - Test only

### Pipeline Jobs

1. **test-backend** - Install dependencies and run backend tests
2. **test-frontend** - Build frontend and run tests  
3. **build-docker** - Build and push Docker images to GitHub Container Registry (ghcr.io)
4. **deploy** - Deploy to EC2 using SSH

### Workflow Features
- ✓ Automated testing
- ✓ Docker image building
- ✓ Security scanning (Trivy)
- ✓ Zero-downtime deployment
- ✓ Health checks
- ✓ Automatic rollback on failure

## Manual Deployment (Current Setup)

The application is currently deployed using:
```bash
# On EC2 instance
cd ~/dhakacart
sudo docker-compose up -d
```

## Testing CI/CD

After configuring secrets, trigger deployment with:
```bash
git add .
git commit -m "feat: trigger CI/CD deployment"
git push origin main
```

Monitor the workflow at:
```
https://github.com/MehediHossain95/DhakaCart-E-Commerce-Reliability-Challenge/actions
```

## Deployment Architecture

```
GitHub Actions (CI/CD)
    ↓
Build Docker Images → Push to ghcr.io
    ↓
SSH to EC2 Instance
    ↓
Pull Latest Images
    ↓
Docker Compose Up
    ↓
Nginx Reverse Proxy
    ↓
Frontend (port 8080) + Backend (port 5000)
```

## Quick Commands

### View Application Logs
```bash
ssh -i dhakacart-key ubuntu@18.143.130.128 'cd ~/dhakacart && sudo docker-compose logs -f'
```

### Restart Services
```bash
ssh -i dhakacart-key ubuntu@18.143.130.128 'cd ~/dhakacart && sudo docker-compose restart'
```

### Check Container Status
```bash
ssh -i dhakacart-key ubuntu@18.143.130.128 'sudo docker ps'
```

### Manual Deployment
```bash
ssh -i dhakacart-key ubuntu@18.143.130.128
cd ~/dhakacart
sudo docker-compose pull
sudo docker-compose up -d
```

## Monitoring & Logging

### Available for K8s Deployment
- Prometheus for metrics
- Grafana for dashboards
- ELK Stack for centralized logging
- HPA for auto-scaling

### Current Setup (Docker Compose)
- Docker logs: `sudo docker-compose logs`
- Nginx access logs: `/var/log/nginx/access.log`
- System logs: `journalctl -u docker`

## Security

- ✓ Encrypted EBS volumes
- ✓ Security groups limiting access
- ✓ SSH key authentication only
- ✓ Docker container isolation
- ✓ Trivy vulnerability scanning
- ✓ No hardcoded secrets in code

## Next Steps

1. Configure GitHub secrets (EC2_HOST, SSH_PRIVATE_KEY)
2. Push changes to main branch
3. Monitor GitHub Actions workflow
4. Verify deployment at http://18.143.130.128
5. (Optional) Enable K8s deployment with monitoring stack

---

**Last Updated:** December 15, 2025  
**Deployment Status:** ✅ OPERATIONAL
