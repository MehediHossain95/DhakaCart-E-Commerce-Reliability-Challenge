# Emergency Runbooks & Troubleshooting

## 🚨 Critical Incident Response

### Step 1: Assess Situation
```bash
# Get overall cluster status
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get svc

# Check for obvious issues
kubectl describe nodes
kubectl top nodes
kubectl top pods
```

### Step 2: Identify Affected Service
```bash
# Check frontend
kubectl get pods -l app=frontend
kubectl logs -f deployment/dhakacart-frontend --tail=50

# Check backend
kubectl get pods -l app=backend  
kubectl logs -f deployment/dhakacart-backend --tail=50

# Check monitoring
kubectl get pods -l app=prometheus
```

### Step 3: Determine Root Cause
```bash
# Memory issues?
kubectl top pods | grep -v "MEMORY"

# CPU throttling?
kubectl describe node | grep -A5 "Allocated resources"

# Restart loop?
kubectl get events --sort-by='.lastTimestamp'

# Disk space?
df -h /var/lib/kubelet
```

---

## 🐛 Troubleshooting Guide

### Issue: Pod Stuck in Pending State

**Symptoms:**
- Pod not starting
- Status: Pending

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
# Look for: "insufficient cpu", "insufficient memory", "node not found"
```

**Resolution:**

**Option A: Insufficient Resources**
```bash
# Check available resources
kubectl top nodes

# Scale down other services temporarily
kubectl scale deployment <name> --replicas=0

# Or add more nodes
terraform apply  # (increase node count in main.tf)
```

**Option B: Node Not Ready**
```bash
# Check node status
kubectl describe node <node-name>

# Restart kubelet on node
ssh ubuntu@<node-ip>
sudo systemctl restart kubelet
sudo systemctl status kubelet
```

---

### Issue: Pod in CrashLoopBackOff

**Symptoms:**
- Pod restarting repeatedly
- Status: CrashLoopBackOff

**Diagnosis:**
```bash
# Check logs for errors
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -n default

# Check events
kubectl describe pod <pod-name>

# Check for resource limits exceeded
kubectl top pod <pod-name>
```

**Resolution:**

**Option A: Application Error**
```bash
# View full logs
kubectl logs <pod-name> --tail=100

# If Node.js error: check environment variables
kubectl exec -it <pod-name> -- env | grep -i api

# Rollback to previous version
kubectl rollout undo deployment/<deployment-name>
```

**Option B: Resource Limits Exceeded**
```bash
# Check current limits
kubectl describe pod <pod-name>

# Edit deployment to increase limits
kubectl edit deployment <deployment-name>
# Increase: resources.limits.memory and .cpu

# Restart deployment
kubectl rollout restart deployment/<deployment-name>
```

**Option C: Health Check Failing**
```bash
# Test health endpoint manually
kubectl exec -it <pod-name> -- curl http://localhost:5000/health

# If failed, check application logs
# Update health check if too strict
kubectl edit deployment <deployment-name>
# Change: initialDelaySeconds: 30 (increase from 10)
```

---

### Issue: High CPU Usage

**Symptoms:**
- CPU > 80%
- Slow response times
- Some requests timing out

**Diagnosis:**
```bash
# Find hotspot
kubectl top pods | sort -k3 -rn | head

# Check which pod is consuming CPU
kubectl exec -it <high-cpu-pod> -- top -bn1

# Check slow queries (if database)
# SELECT * FROM pg_stat_statements ORDER BY mean_time DESC;
```

**Resolution:**

**Option A: Code Issue**
```bash
# Check logs for error loop
kubectl logs <pod-name> --tail=50

# May be infinite loop or heavy computation
# Rollback deployment
kubectl rollout undo deployment/<deployment-name>

# Then:
# 1. Fix code
# 2. Test locally
# 3. Commit and push
# 4. Let GitHub Actions redeploy
```

**Option B: Load Too High**
```bash
# Check request rate
curl <service-ip>/metrics | grep http_requests_total

# Auto-scaling should handle this
# If not, manually scale
kubectl scale deployment dhakacart-backend --replicas=8

# Check HPA status
kubectl describe hpa backend-hpa
```

**Option C: Database Query Slow**
```bash
# Check slow query log
kubectl exec -it <backend-pod> -- psql $DATABASE_URL
# SELECT pg_stat_statements();

# Look for queries taking > 1 second
# Add indexes if needed:
# CREATE INDEX idx_name ON table(column);
```

---

### Issue: High Memory Usage / OOM Kill

**Symptoms:**
- Memory > 85%
- Pod killed by kubelet
- Exit code: 137

**Diagnosis:**
```bash
# Check memory trend
kubectl top pods --watch

# Check previous container termination reason
kubectl describe pod <pod-name>
# Look for: "Reason: OOMKilled"

# Check for memory leaks
kubectl exec -it <pod-name> -- node -e "console.log(process.memoryUsage())"
```

**Resolution:**

**Immediate (Temporary):**
```bash
# Delete old pods to free memory
kubectl delete pod <pod-name>

# Restart deployments
kubectl rollout restart deployment/dhakacart-backend
kubectl rollout restart deployment/dhakacart-frontend
```

**Permanent (Update Limits):**
```bash
# Edit deployment
kubectl edit deployment dhakacart-backend

# Increase limits (old: 512Mi)
resources:
  limits:
    memory: "1Gi"     # Double the limit
    cpu: "1000m"

# Apply and monitor
kubectl rollout status deployment/dhakacart-backend --watch
```

**Find Memory Leak:**
```bash
# If still happening, check code
# 1. Are you caching unbounded data?
# 2. Are connections leaking (not closed)?
# 3. Are event listeners accumulating?

# Restart service after fix
kubectl rollout restart deployment/dhakacart-backend
```

---

### Issue: Database Connection Failed

**Symptoms:**
- Backend pods failing
- Logs: "ECONNREFUSED" or "database unreachable"
- API returning 5xx errors

**Diagnosis:**
```bash
# Check if database is running
kubectl get svc dhakacart-db

# Test connection from pod
kubectl exec -it <backend-pod> -- \
  psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1"

# Check credentials
kubectl get secret db-credentials
kubectl describe secret db-credentials
```

**Resolution:**

**Option A: Wrong Credentials**
```bash
# Update secret with correct credentials
kubectl delete secret db-credentials
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password='correct-password'

# Restart pods to pick up new secret
kubectl rollout restart deployment/dhakacart-backend
```

**Option B: Database Down**
```bash
# Check RDS status in AWS
aws rds describe-db-instances --db-instance-identifier dhakacart

# If down, restore from backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier dhakacart-restored \
  --db-snapshot-identifier dhakacart-snapshot-latest

# Update connection string
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password='password' \
  -o yaml | kubectl apply -f -

# Restart backend
kubectl rollout restart deployment/dhakacart-backend
```

**Option C: Network Issue**
```bash
# Check security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Ensure:
# - Backend pods can reach database
# - Port 5432 allowed from pod CIDR

# Test ping from pod
kubectl exec -it <backend-pod> -- ping <db-host>

# Test telnet
kubectl exec -it <backend-pod> -- nc -zv <db-host> 5432
```

---

### Issue: No Available Endpoints (Service Down)

**Symptoms:**
- Service exists but no pods behind it
- "no available endpoints" error
- 503 Service Unavailable

**Diagnosis:**
```bash
# Check service
kubectl get svc dhakacart-backend-service
kubectl describe svc dhakacart-backend-service
# Look for "Endpoints: <none>"

# Check pods for service
kubectl get pods -l app=backend
kubectl get pods -l app=backend -o wide

# Check labels match selector
kubectl get pods --show-labels | grep backend
```

**Resolution:**

**Option A: Pods Not Running**
```bash
# If no pods exist, scale up
kubectl scale deployment dhakacart-backend --replicas=3

# If pods are crashing, see "CrashLoopBackOff" section above
kubectl logs -f <pod-name>
```

**Option B: Label Mismatch**
```bash
# Check service selector
kubectl get svc dhakacart-backend-service -o yaml | grep -A3 selector

# Check pod labels
kubectl describe pod <pod-name> | grep Labels

# If mismatch, add label to pod
kubectl label pod <pod-name> app=backend --overwrite
```

**Option C: Readiness Probe Failing**
```bash
# Check probe status
kubectl describe pod <pod-name>
# Look for: "Readiness probe failed"

# Test endpoint manually
kubectl exec -it <pod-name> -- curl http://localhost:5000/ready

# If failing, the issue is in app logic
# Check logs:
kubectl logs <pod-name>

# May need to increase initialDelaySeconds if app takes time to start
```

---

### Issue: Slow Response Times / Timeouts

**Symptoms:**
- Requests taking > 1 second
- Some requests timing out
- Occasional 504 Gateway Timeout

**Diagnosis:**
```bash
# Check backend latency
kubectl exec -it <backend-pod> -- curl -w "@-" http://localhost:5000/

# Check frontend → backend communication
kubectl logs -f deployment/dhakacart-frontend | grep api

# Check for resource contention
kubectl top nodes
kubectl top pods | grep dhakacart

# Check if auto-scaling is working
kubectl describe hpa backend-hpa
```

**Resolution:**

**Option A: Not Enough Replicas**
```bash
# Check current replicas
kubectl get deployment dhakacart-backend
# DESIRED, CURRENT, READY should all match

# If HPA not scaling, manually scale
kubectl scale deployment dhakacart-backend --replicas=8

# Check HPA metrics
kubectl get hpa backend-hpa
kubectl top pods -l app=backend
```

**Option B: Slow Database Queries**
```bash
# Enable slow query logging
# ALTER DATABASE dhakacart SET log_min_duration_statement = 1000;

# Or check existing queries
kubectl exec -it <backend-pod> -- \
  psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "SELECT query, calls, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10"

# Add indexes for slow queries
# CREATE INDEX idx_name ON table(column);
```

**Option C: Network Latency**
```bash
# Measure latency
kubectl exec -it <backend-pod> -- ping -c 5 <database-host>

# Check if on different AZs (higher latency)
kubectl describe node | grep -i topology

# May need to replicate database across AZs
# Or use read replicas for queries
```

---

### Issue: Disk Space Full

**Symptoms:**
- Pods cannot create logs
- Deployments failing
- df -h shows 100% usage

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find large files
du -sh /* | sort -rh

# Check docker images
docker images | head -20

# Check Kubernetes data
du -sh /var/lib/kubelet
du -sh /var/lib/docker
```

**Resolution:**

**Immediate:**
```bash
# Clean up old logs
sudo journalctl --vacuum=100M

# Clean old docker images
docker image prune -a --force

# Clean old pods
kubectl delete pod --all --grace-period=0 --force

# Clean pod logs
kubectl logs --tail=1 <pod-name> > /dev/null
```

**Permanent:**
```bash
# Increase volume size (Terraform)
# In main.tf, increase: ebs_volume_size = 50 (from 20)

# Apply changes
cd terraform
terraform apply

# Monitor in future
# Set alerts when disk > 70%
```

---

## 🔄 Deployment Issues

### Issue: Deployment Rollback Needed

**Trigger:**
- Bad deployment detected
- Errors in logs after deployment
- Response codes elevated

**Quick Rollback:**
```bash
# Check rollout history
kubectl rollout history deployment/dhakacart-backend

# Rollback to previous version
kubectl rollout undo deployment/dhakacart-backend

# Check status
kubectl rollout status deployment/dhakacart-backend

# Verify working
kubectl get pods
curl <service-ip>/health
```

---

### Issue: Zero Downtime Deployment Failed

**Symptoms:**
- Brief downtime during deployment
- Some requests returning 503

**Diagnosis:**
```bash
# Check deployment strategy
kubectl get deployment dhakacart-backend -o yaml | grep -A5 strategy

# Check if using maxUnavailable > 0
# Should be: maxUnavailable: 0, maxSurge: 1

# Check if readiness probe configured
kubectl get deployment dhakacart-backend -o yaml | grep -A10 readinessProbe
```

**Fix:**
```bash
# Verify in k8s/backend.yaml:
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0

readinessProbe:
  httpGet:
    path: /ready
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5

# Reapply manifests
kubectl apply -f k8s/backend.yaml
```

---

## 📊 Performance Debugging

### Check HPA Status
```bash
# Get HPA metrics
kubectl get hpa
kubectl describe hpa backend-hpa

# Check if metrics available
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

### Check Metrics Server
```bash
# Verify metrics server running
kubectl get deployment metrics-server -n kube-system

# If not running, install
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Monitor in Real-Time
```bash
# Watch pods scaling
kubectl get hpa backend-hpa --watch

# Watch pod creation
kubectl get pods -l app=backend --watch

# Watch resource usage
kubectl top pods --watch
```

---

## 🔐 Security Incidents

### Unauthorized Access Attempt

**Response:**
```bash
# Check logs for suspicious IPs
kubectl logs <pod-name> | grep "401\|403\|Unauthorized"

# Block IP in security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --cidr <suspicious-ip>/32 \
  --protocol tcp \
  --port 443 \
  --region ap-southeast-1

# Rotate credentials
kubectl delete secret db-credentials
kubectl create secret generic db-credentials \
  --from-literal=username=dbuser \
  --from-literal=password='new-password'

# Restart pods
kubectl rollout restart deployment/dhakacart-backend
```

---

## 📞 Escalation Procedure

### Level 1: Try Self-Service Fixes
1. Check monitoring dashboards
2. Look at pod logs
3. Try automatic rollback
4. Scale resources if needed

### Level 2: Contact DevOps Team
- Severity: Data loss or > 30 min downtime
- Info needed: Error logs, timeline, impact

### Level 3: Declare Incident
- Severity: Complete system outage
- Actions: Activate incident response plan

---

## ✅ Post-Incident Checklist

After resolving incident:

- [ ] Root cause identified and documented
- [ ] Permanent fix deployed (not temporary)
- [ ] Monitoring alert added to prevent recurrence
- [ ] Code changes tested locally
- [ ] PR created with fix
- [ ] Deployment verified (canary first if possible)
- [ ] Stakeholders notified of resolution
- [ ] Post-mortem scheduled (if critical)
- [ ] Follow-up actions assigned

---

**Last Updated:** December 11, 2025  
**Maintained By:** DhakaCart SRE Team
