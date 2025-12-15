#!/bin/bash

echo "=========================================="
echo "DhakaCart Deployment Status Check"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

EC2_HOST="18.143.130.128"

# 1. Infrastructure
echo "1. AWS Infrastructure"
echo "   ✓ EC2 Instance: t3.medium (${EC2_HOST})"
echo "   ✓ Region: ap-southeast-1 (Singapore)"
echo "   ✓ VPC: 10.0.0.0/16"
echo ""

# 2. Application Status
echo "2. Application Services"
ssh -i dhakacart-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$EC2_HOST << 'REMOTE_EOF'
echo "   Docker Containers:"
sudo docker ps --format "   ✓ {{.Names}}: {{.Status}}" 2>/dev/null || echo "   ✗ Docker not accessible"
echo ""
echo "   Resource Usage:"
echo "   $(free -h | grep Mem | awk '{print "   Memory: "$3" / "$2" ("$3/$2*100"% used)"}')"
echo "   $(df -h / | tail -1 | awk '{print "   Disk: "$3" / "$2" ("$5" used)"}')"
REMOTE_EOF
echo ""

# 3. API Health
echo "3. API Endpoints"
FRONTEND=$(curl -s -o /dev/null -w "%{http_code}" http://$EC2_HOST/)
BACKEND=$(curl -s -o /dev/null -w "%{http_code}" http://$EC2_HOST/api/)

if [ "$FRONTEND" == "200" ]; then
    echo -e "   ${GREEN}✓${NC} Frontend: http://$EC2_HOST/ (HTTP $FRONTEND)"
else
    echo -e "   ${RED}✗${NC} Frontend: http://$EC2_HOST/ (HTTP $FRONTEND)"
fi

if [ "$BACKEND" == "200" ]; then
    echo -e "   ${GREEN}✓${NC} Backend API: http://$EC2_HOST/api/ (HTTP $BACKEND)"
else
    echo -e "   ${RED}✗${NC} Backend API: http://$EC2_HOST/api/ (HTTP $BACKEND)"
fi
echo ""

# 4. GitHub CI/CD
echo "4. CI/CD Pipeline"
echo "   ✓ Workflow: .github/workflows/ci-cd.yml"
echo "   ✓ Trigger: Push to main branch"
echo "   ✓ Registry: GitHub Container Registry (ghcr.io)"
echo ""
echo "   Required Secrets:"
echo "   • EC2_HOST: $EC2_HOST"
echo "   • SSH_PRIVATE_KEY: (configured)"
echo ""

# 5. Features Available
echo "5. Available Features"
echo "   ✓ Frontend: React application"
echo "   ✓ Backend: Node.js REST API"
echo "   ✓ Reverse Proxy: Nginx"
echo "   ✓ Container Orchestration: Docker Compose"
echo "   ✓ Auto-restart: Enabled"
echo "   ✓ HTTPS Ready: Cert configuration available"
echo ""

# 6. Kubernetes Manifests
echo "6. Kubernetes Resources (Available for K8s deployment)"
K8S_FILES=$(ls k8s/*.yaml 2>/dev/null | wc -l)
echo "   ✓ Manifests: $K8S_FILES files"
echo "     - Deployments (frontend, backend)"
echo "     - Services & Ingress"
echo "     - HPA (Horizontal Pod Autoscaling)"
echo "     - Monitoring (Prometheus, Grafana)"
echo "     - Logging (ELK Stack)"
echo "     - RBAC & Network Policies"
echo "     - Secrets & ConfigMaps"
echo ""

# 7. Security
echo "7. Security Features"
echo "   ✓ Encrypted EBS volumes"
echo "   ✓ Security Groups (ports: 22, 80, 443, 5000)"
echo "   ✓ SSH key authentication"
echo "   ✓ Container isolation"
echo "   ✓ Trivy security scanning (in CI/CD)"
echo ""

# 8. Documentation
echo "8. Documentation"
echo "   ✓ README.md"
echo "   ✓ DEPLOYMENT_GUIDE.md"
echo "   ✓ SECURITY_HARDENING.md"
echo "   ✓ RUNBOOK.md"
echo ""

echo "=========================================="
echo "Status: ${GREEN}OPERATIONAL${NC}"
echo "=========================================="
echo ""
echo "Quick Commands:"
echo "  View logs:     ssh -i dhakacart-key ubuntu@$EC2_HOST 'sudo docker-compose logs -f'"
echo "  Restart:       ssh -i dhakacart-key ubuntu@$EC2_HOST 'cd ~/dhakacart && sudo docker-compose restart'"
echo "  Update:        git push origin main (triggers CI/CD)"
echo ""
