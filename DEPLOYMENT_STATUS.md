# AWS Deployment Status

**Date**: December 11, 2025
**Status**: ✅ LIVE AND RUNNING

## Deployment Summary

Your DhakaCart infrastructure has been successfully deployed to AWS ap-southeast-1 (Singapore).

### Deployed Resources

**EC2 Instance**:

- Instance ID: `i-0f0b59325ca0c4508`
- Instance Type: `t2.micro`
- State: **RUNNING** ✅
- Public IP: **54.254.42.92**
- Region: `ap-southeast-1` (Singapore)
- Name: `DhakaCart-K3s-Server`

**Network Infrastructure**:

- VPC ID: `vpc-09d9ffd7a7036b6c9`
- VPC CIDR: `10.0.0.0/16`
- Public Subnet: `subnet-00c30755adc15944d`
- Subnet CIDR: `10.0.1.0/24`
- Availability Zone: `ap-southeast-1a`
- Internet Gateway: `igw-0373e6afe465e5005`
- Route Table: `rtb-0b5400df58c716b93`

**Security**:

- Security Group: `sg-06ba466d52f03c410`
- Key Pair: `dhakacart-key`
- SSH Access: Enabled (port 22)
- HTTP Access: Enabled (port 80)
- HTTPS Access: Enabled (port 443)
- Kubernetes API: Enabled (port 6443)

## Deployment Progress

| Component | Status | Time |
|-----------|--------|------|
| VPC Creation | ✅ Complete | 17s |
| Internet Gateway | ✅ Complete | 5s |
| Subnet Creation | ✅ Complete | 16s |
| Route Table | ✅ Complete | 3s |
| Security Group | ✅ Complete | 8s |
| Key Pair | ✅ Complete | 3s |
| EC2 Instance Launch | ✅ Complete | 26s |
| **Total Infrastructure** | ✅ Complete | **2 minutes** |
| K3s Installation | ⏳ In Progress | **5-10 minutes** |

## Accessing Your Instance

### SSH Access

```bash
ssh -i ~/.ssh/dhakacart-key.pem ubuntu@54.254.42.92
```

### Verify K3s Installation

```bash
# Check if K3s is running
sudo systemctl status k3s

# View K3s logs
sudo journalctl -u k3s -f

# Check K3s version (once ready)
sudo /usr/local/bin/k3s --version

# Get kubeconfig
cat /home/ubuntu/k3s.yaml
```

## Next Steps

### 1. Wait for K3s to Finish Installing (5-10 minutes)

The EC2 instance is automatically running a startup script that installs K3s (lightweight Kubernetes). This takes 5-10 minutes.

### 2. Retrieve Kubeconfig

Once K3s is ready:

```bash
ssh -i ~/.ssh/dhakacart-key.pem ubuntu@54.254.42.92
cat k3s.yaml > ~/dhakacart-k3s.yaml
chmod 600 ~/dhakacart-k3s.yaml
```

### 3. Deploy Applications

Create Kubernetes manifests and deploy:

```bash
# Deploy backend
kubectl --kubeconfig=~/dhakacart-k3s.yaml apply -f backend-deployment.yaml

# Deploy frontend
kubectl --kubeconfig=~/dhakacart-k3s.yaml apply -f frontend-deployment.yaml
```

### 4. Check Deployment Status

```bash
kubectl --kubeconfig=~/dhakacart-k3s.yaml get pods
kubectl --kubeconfig=~/dhakacart-k3s.yaml get services
kubectl --kubeconfig=~/dhakacart-k3s.yaml get nodes
```

### 5. Access Applications

- **Backend API**: `http://54.254.42.92:5000`
- **Frontend**: `http://54.254.42.92:80` or `http://54.254.42.92`

## AWS CLI Commands

### View Instance Details

```bash
export PATH="/home/mehedi/.local/bin:$PATH"

aws ec2 describe-instances \
  --region ap-southeast-1 \
  --instance-ids i-0f0b59325ca0c4508 \
  --query 'Reservations[0].Instances[0]'
```

### Check VPC Details

```bash
aws ec2 describe-vpcs \
  --region ap-southeast-1 \
  --vpc-ids vpc-09d9ffd7a7036b6c9
```

### View Security Group Rules

```bash
aws ec2 describe-security-groups \
  --region ap-southeast-1 \
  --group-ids sg-06ba466d52f03c410
```

### Monitor Instance Status Checks

```bash
aws ec2 describe-instance-status \
  --region ap-southeast-1 \
  --instance-ids i-0f0b59325ca0c4508
```

## Cost Information

**Billing Estimate** (Poridhi Lab Environment):

- t2.micro Instance: ~$0.01/hour
- Data Transfer: ~$0/hour (within free tier)
- EBS Storage: ~$0/month (small root volume)
- **Total**: ~$7-10/month (or **FREE** with AWS free tier)

The t2.micro instance qualifies for AWS free tier (750 hours/month for 12 months), so costs may be minimal or free.

## Instance Management

### Stop Instance (to reduce costs)

```bash
aws ec2 stop-instances \
  --region ap-southeast-1 \
  --instance-ids i-0f0b59325ca0c4508
```

### Start Instance (when needed)

```bash
aws ec2 start-instances \
  --region ap-southeast-1 \
  --instance-ids i-0f0b59325ca0c4508
```

### Terminate Instance (destroy everything)

```bash
# Via Terraform
cd terraform/
terraform destroy

# OR via AWS CLI
aws ec2 terminate-instances \
  --region ap-southeast-1 \
  --instance-ids i-0f0b59325ca0c4508
```

## Terraform State

- **State File**: `terraform/terraform.tfstate`
- **State Lock**: Not configured (single user)
- **Resources Tracked**: 9 resources
- **Plan File**: `terraform/tfplan` (saved for reference)

To view the state:

```bash
cd terraform/
terraform state list
terraform state show aws_instance.k3s_node
```

## Security Considerations

1. **Key Pair Security**: Keep `~/.ssh/dhakacart-key.pem` private

```bash
chmod 400 ~/.ssh/dhakacart-key.pem
```

1. **Security Group**: Currently allows public SSH access
   - Consider restricting to your IP: `your-ip/32`
   - Example: `aws ec2 authorize-security-group-ingress --group-id sg-06ba466d52f03c410 --protocol tcp --port 22 --cidr your-ip/32`

1. **Firewall Rules**: Review security group rules before production

1. **Secrets Management**: Use AWS Secrets Manager for credentials
   - Database passwords
   - API keys
   - Authentication tokens

## Monitoring

### CloudWatch Metrics (if enabled)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-0f0b59325ca0c4508 \
  --start-time 2025-12-11T00:00:00Z \
  --end-time 2025-12-11T23:59:59Z \
  --period 3600 \
  --statistics Average
```

### System Logs

```bash
aws ec2 get-console-output \
  --instance-id i-0f0b59325ca0c4508 \
  --region ap-southeast-1
```

## Troubleshooting

### Cannot SSH to Instance

1. Check security group allows SSH (port 22):

```bash
aws ec2 describe-security-groups --group-ids sg-06ba466d52f03c410
```

1. Check instance is running:

```bash
aws ec2 describe-instances --instance-ids i-0f0b59325ca0c4508
```

1. Check key permissions:

```bash
ls -la ~/.ssh/dhakacart-key.pem
chmod 400 ~/.ssh/dhakacart-key.pem
```

### K3s Not Starting

1. SSH into instance and check logs:

```bash
ssh -i ~/.ssh/dhakacart-key.pem ubuntu@54.254.42.92
sudo journalctl -u k3s -n 50
```

1. Check if setup script finished:

```bash
cat /var/log/cloud-init-output.log
```

### Cannot Reach Application

1. Verify K3s is running: `sudo systemctl status k3s`
2. Check pods are deployed: `kubectl get pods`
3. Check services: `kubectl get svc`
4. Verify security group allows traffic on port 80, 443, 5000

## Next Phase: Deploy Applications

Once K3s is running and accessible, proceed with:

1. Build Docker images for backend and frontend
2. Push images to Amazon ECR
3. Create Kubernetes manifests (Deployment, Service, Ingress)
4. Deploy applications to K3s cluster
5. Configure DNS or use public IP
6. Enable HTTPS with Let's Encrypt
7. Setup monitoring and logging
8. Configure backups and disaster recovery

## Support & Resources

- **AWS Console**: [AWS Management Console](https://388449571465.signin.aws.amazon.com/console)
- **AWS CLI Documentation**: [AWS CLI Docs](https://docs.aws.amazon.com/cli/)
- **K3s Documentation**: [K3s Docs](https://docs.k3s.io/)
- **Terraform State**: `terraform/terraform.tfstate`

## Timeline Summary

| Phase | Status | Completion |
|-------|--------|-----------|
| Phase 1: Infrastructure | ✅ Complete | Dec 11, 2025 |
| Phase 2: Monitoring | ✅ Complete | Dec 11, 2025 |
| Phase 3: Security | ✅ Complete | Dec 11, 2025 |
| Phase 4: Testing & Documentation | ✅ Complete | Dec 11, 2025 |
| AWS Deployment | ✅ Complete | Dec 11, 2025 |
| Application Deployment | ⏳ Pending | Dec 12-13, 2025 |
| Final Submission | ⏳ Pending | Dec 15, 2025 |

---

**Deployment Summary**: Infrastructure successfully deployed to AWS. EC2 instance running at `54.254.42.92`. K3s cluster initializing. Ready for application deployment.

**Status**: 🟢 **LIVE AND RUNNING**
