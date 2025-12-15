# DhakaCart Operations Runbook

## 🚨 Emergency Procedures

### System Down / Complete Outage

**Priority: CRITICAL**

1. **Assess the situation**
   ```bash
   # Check cluster status
   kubectl get nodes
   kubectl get pods --all-namespaces
   
   # Check recent events
   kubectl get events --all-namespaces --sort-by='.lastTimestamp'
   ```

2. **Check service status**
   ```bash
   # Check if pods are running
   kubectl get pods -o wide
   
   # Check service endpoints
   kubectl get endpoints
   
   # Check ingress
   kubectl describe ingress dhakacart-ingress
   ```

3. **If pods are down**
   ```bash
   # Check logs for errors
   kubectl logs <pod-name> --tail=100
   
   # Describe pod for events
   kubectl describe pod <pod-name>
   
   # Force restart pod
   kubectl delete pod <pod-name> --grace-period=0 --force
   ```

4. **If nodes are down**
   ```bash
   # Check node status
   kubectl describe node <node-name>
   
   # Check EC2 instance in AWS
   aws ec2 describe-instances --region ap-southeast-1
   
   # Reboot node if needed
   aws ec2 reboot-instances --instance-ids i-xxxxx --region ap-southeast-1
   ```

5. **Escalation**
   - If unable to resolve in 5 minutes: Contact AWS support
   - Activate manual failover procedure (database recovery)

---

### Pod CrashLoopBackOff (Application Crashing)

**Priority: HIGH**

1. **Identify crashing pod**
   ```bash
   kubectl get pods
   # Look for pods with STATUS "CrashLoopBackOff"
   ```

2. **Get detailed error**
   ```bash
   kubectl logs <pod-name> --tail=50
   kubectl logs <pod-name> --previous  # Previous crash logs
   kubectl describe pod <pod-name>     # Events section shows errors
   ```

3. **Common causes and solutions**

   **Issue: OOMKilled (Out of Memory)**
   ```bash
   # Solution 1: Increase memory limit
   kubectl edit deployment dhakacart-backend
   # Change limits.memory from 512Mi to 1Gi
   
   # Solution 2: Check for memory leak
   kubectl top pods  # Monitor memory over time
   ```

   **Issue: CrashLoopBackOff - Database connection failed**
   ```bash
   # Check database connection
   kubectl exec -it <backend-pod> -- curl http://database:5432
   
   # Check secrets
   kubectl get secrets
   kubectl describe secret dhakacart-secrets
   
   # Solution: Update connection string in secrets
   kubectl delete secret dhakacart-secrets
   kubectl create secret generic dhakacart-secrets \
     --from-literal=DB_HOST="correct-host"
   ```

   **Issue: Port already in use**
   ```bash
   # Check what's using the port
   kubectl exec -it <pod-name> -- lsof -i :5000
   
   # Solution: Change port or kill process
   kubectl delete pod <pod-name> --grace-period=0 --force
   ```

4. **Rollback if recent deployment**
   ```bash
   kubectl rollout undo deployment/dhakacart-backend
   kubectl rollout status deployment/dhakacart-backend
   ```

---

### High CPU Usage / Performance Degradation

**Priority: HIGH**

1. **Monitor resource usage**
   ```bash
   kubectl top nodes
   kubectl top pods
   ```

2. **Identify resource hog**
   ```bash
   kubectl top pods | sort -k3 -rn  # Sort by CPU
   kubectl top pods | sort -k4 -rn  # Sort by memory
   ```

3. **Inspect problematic pod**
   ```bash
   kubectl logs <pod-name> --tail=200 | grep -i "error\|warning"
   kubectl describe pod <pod-name>
   ```

4. **Solutions**
   ```bash
   # Option 1: Increase resource limits
   kubectl set resources deployment/dhakacart-backend \
     --limits=cpu=1000m,memory=1Gi \
     --requests=cpu=500m,memory=512Mi
   
   # Option 2: Manually scale up
   kubectl scale deployment/dhakacart-backend --replicas=10
   
   # Option 3: Check for infinite loops/leaks
   kubectl logs <pod-name> -f  # Watch logs
   ```

---

### Database Connection Issues

**Priority: HIGH**

1. **Verify database is running**
   ```bash
   # Check RDS instance
   aws rds describe-db-instances \
     --db-instance-identifier dhakacart-db \
     --region ap-southeast-1
   
   # Should show Status: available
   ```

2. **Test connectivity**
   ```bash
   # From backend pod
   kubectl exec -it <backend-pod> -- bash
   # Inside pod:
   psql -h $DB_HOST -U $DB_USER -d $DB_NAME
   # Or for MySQL:
   mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME
   ```

3. **Check credentials**
   ```bash
   kubectl get secret dhakacart-secrets -o yaml
   # Decode base64: echo 'base64-string' | base64 -d
   ```

4. **Restore from backup (if database corrupted)**
   ```bash
   # List backups
   ./db-backup.sh list-backups
   
   # Restore from snapshot
   ./db-backup.sh restore dhakacart-backup-20251211-100000
   
   # Wait for restoration to complete (~5 minutes)
   aws rds describe-db-instances \
     --db-instance-identifier dhakacart-db-restored \
     --region ap-southeast-1
   ```

5. **Point-in-time recovery (if specific data corrupted)**
   ```bash
   # Restore to specific time (before corruption)
   ./db-backup.sh pitr "2025-12-11T08:00:00Z"
   
   # Verify data
   # Then promote to primary
   aws rds promote-read-replica \
     --db-instance-identifier dhakacart-db-restored
   ```

---

### Service Not Accessible / Network Issues

**Priority: CRITICAL**

1. **Check ingress configuration**
   ```bash
   kubectl get ingress
   kubectl describe ingress dhakacart-ingress
   
   # Get ingress IP/hostname
   kubectl get ingress dhakacart-ingress -o wide
   ```

2. **Verify services**
   ```bash
   kubectl get svc -o wide
   kubectl describe svc dhakacart-frontend-service
   kubectl describe svc dhakacart-backend-service
   ```

3. **Check endpoints**
   ```bash
   kubectl get endpoints
   # Should show pod IPs for each service
   ```

4. **Test DNS resolution**
   ```bash
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup dhakacart-frontend-service
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup dhakacart-backend-service
   ```

5. **Check network policies**
   ```bash
   kubectl get networkpolicy
   kubectl describe networkpolicy dhakacart-network-policy
   
   # Temporarily disable to test (emergency only)
   kubectl delete networkpolicy --all
   ```

6. **Check security group (AWS level)**
   ```bash
   aws ec2 describe-security-groups --region ap-southeast-1
   # Ensure ports 80, 443, 5000 are open
   ```

---

### Auto-Scaling Not Triggering

**Priority: MEDIUM**

1. **Check HPA status**
   ```bash
   kubectl get hpa
   kubectl describe hpa backend-hpa
   
   # Should show current/desired replicas
   ```

2. **Verify metrics server**
   ```bash
   kubectl get deployment metrics-server -n kube-system
   # Should be running
   ```

3. **Check pod metrics**
   ```bash
   kubectl top pods
   # If showing "unknown", metrics not available
   ```

4. **Solutions**
   ```bash
   # Restart metrics server
   kubectl delete pod -n kube-system -l k8s-app=metrics-server
   
   # Manually scale while debugging
   kubectl scale deployment dhakacart-backend --replicas=10
   
   # Generate load to test
   while true; do curl http://localhost:8080/; done &
   watch 'kubectl get hpa'  # Watch scaling
   ```

---

### Backup / Recovery Issues

**Priority: HIGH**

1. **Verify automated backups are running**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier dhakacart-db \
     --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow]'
   # Should show RetentionPeriod=7
   ```

2. **Create manual backup**
   ```bash
   ./db-backup.sh backup
   
   # Verify creation
   ./db-backup.sh list-backups
   ```

3. **Test restoration**
   ```bash
   # Create test restore
   ./db-backup.sh restore dhakacart-backup-latest dhakacart-db-test
   
   # Verify data
   # Then delete test instance
   aws rds delete-db-instance \
     --db-instance-identifier dhakacart-db-test \
     --skip-final-snapshot
   ```

---

## 📊 Regular Monitoring Procedures

### Daily Checks (Part of Daily Standup)

```bash
#!/bin/bash
# Daily health check script

echo "=== Cluster Status ==="
kubectl get nodes
kubectl get pods --all-namespaces | grep -i "error\|failed\|pending\|unknown"

echo "=== Resource Usage ==="
kubectl top nodes
kubectl top pods | head -20

echo "=== Recent Events ==="
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

echo "=== Ingress Status ==="
kubectl get ingress -o wide

echo "=== Service Health ==="
curl -s http://localhost:8080/ | head -5
curl -s http://localhost:5000/health

echo "=== Database Status ==="
aws rds describe-db-instances \
  --db-instance-identifier dhakacart-db \
  --query 'DBInstances[0].DBInstanceStatus'

echo "=== Recent Backups ==="
aws rds describe-db-snapshots \
  --db-instance-identifier dhakacart-db \
  --query 'DBSnapshots[-3:].[DBSnapshotIdentifier,SnapshotCreateTime]'
```

### Weekly Checks

- [ ] Review logs for errors/warnings
- [ ] Check disk space on nodes
- [ ] Verify backups completed successfully
- [ ] Test backup restoration (quarterly)
- [ ] Review security group rules
- [ ] Update dependencies/patches
- [ ] Review monitoring alerts configuration

### Monthly Checks

- [ ] Capacity planning review
- [ ] Security audit
- [ ] Performance analysis
- [ ] Documentation updates
- [ ] Disaster recovery drill
- [ ] Team training/knowledge sharing

---

## 🔄 Common Maintenance Tasks

### Deploying Updates

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes and test
# ... edit code ...

# 3. Commit and push
git add .
git commit -m "feat: Add new feature"
git push origin feature/new-feature

# 4. Create pull request (GitHub)
# ... review and merge ...

# 5. GitHub Actions automatically deploys
# Monitor: GitHub Actions tab → Deployments
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/dhakacart-backend \
  backend=dhakacart-backend:v1.0.1

# Monitor rollout
kubectl rollout status deployment/dhakacart-backend -w

# Verify new version
kubectl get pods -o wide
```

### Scaling Nodes

```bash
# Add new node to cluster
# (For K3s: SSH and run installation script)

# Drain existing node (graceful migration)
kubectl drain <node-name> --ignore-daemonsets

# Reboot node
aws ec2 reboot-instances --instance-ids i-xxxxx

# Uncordon node (bring back online)
kubectl uncordon <node-name>
```

### Upgrading Kubernetes

```bash
# Upgrade K3s
ssh -i dhakacart-key ubuntu@<instance-ip>
# On node:
curl -sfL https://get.k3s.io | sh -
```

---

## 📞 Escalation Procedure

### Level 1 (On-Call Engineer)
- Respond to page within 5 minutes
- Assess severity
- Execute immediate remediation steps

### Level 2 (Team Lead)
- Escalate if Level 1 can't resolve in 15 minutes
- Coordinate communication with stakeholders

### Level 3 (Infrastructure Lead)
- Escalate if Level 2 can't resolve in 30 minutes
- Contact AWS support
- Initiate disaster recovery procedures

### Communication Template

```
INCIDENT: [Brief description]
SEVERITY: [CRITICAL/HIGH/MEDIUM]
STATUS: [INVESTIGATING/ONGOING/RESOLVED]
ETA: [Expected time to resolution]
IMPACT: [Number of affected users/services]
ROOT CAUSE: [If known]
MITIGATION: [Steps being taken]
```

---

**Last Updated:** December 11, 2025
**On-Call Contact:** [Phone/Slack]
**AWS Support Case:** [Account ID]
