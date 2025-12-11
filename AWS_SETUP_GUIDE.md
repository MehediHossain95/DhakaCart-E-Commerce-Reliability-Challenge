# AWS Configuration Guide

## ✅ AWS CLI Installation

AWS CLI v1 is now installed and ready to use:

```bash
aws-cli/1.43.13 Python/3.12.3 Linux/6.14.0-1014-azure botocore/1.42.7
```

## 🔑 Prerequisites

Before configuring AWS, you need:

1. **AWS Account** - Active AWS account with billing enabled
2. **IAM User** - Create a new IAM user for programmatic access (NOT root account)
3. **Access Credentials** - Access Key ID and Secret Access Key
4. **Proper Permissions** - IAM policy with required permissions

### Step 1: Create IAM User (if not already done)

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. Set username: `dhakacart-deployment` or similar
4. Enable "Provide user access to AWS Management Console" (optional)
5. Click "Next"
6. Attach policies:
   - ✅ EC2FullAccess (for EC2 instances)
   - ✅ RDSFullAccess (for databases)
   - ✅ VPCFullAccess (for networking)
   - ✅ IAMFullAccess (for roles/policies)
   - ✅ S3FullAccess (for storage)
   - ✅ CloudWatchFullAccess (for monitoring)
   - ✅ ECSTaskExecutionRolePolicy (for container roles)

Or attach inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "s3:*",
        "iam:*",
        "cloudwatch:*",
        "ecr:*",
        "ecs:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 2: Create Access Keys

1. In IAM user details, go to "Security credentials"
2. Click "Create access key"
3. Select "Command Line Interface (CLI)"
4. Agree to the warning
5. Click "Create access key"
6. **COPY AND SAVE** (shown only once):
   - Access Key ID
   - Secret Access Key

⚠️ **IMPORTANT**: Never share these credentials!

## 🚀 AWS Configuration

### Method 1: Interactive Configuration (Recommended)

```bash
export PATH="/home/mehedi/.local/bin:$PATH"
aws configure
```

When prompted, enter:

```bash
AWS Access Key ID: [YOUR_ACCESS_KEY_ID]
AWS Secret Access Key: [YOUR_SECRET_ACCESS_KEY]
Default region name: us-east-1
Default output format: json
```

### Method 2: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_DEFAULT_OUTPUT="json"
```

Add to `~/.bashrc` or `~/.zshrc` for persistence:

```bash
echo 'export AWS_ACCESS_KEY_ID="your-key-id"' >> ~/.zshrc
echo 'export AWS_SECRET_ACCESS_KEY="your-secret-key"' >> ~/.zshrc
echo 'export AWS_DEFAULT_REGION="us-east-1"' >> ~/.zshrc
echo 'export AWS_DEFAULT_OUTPUT="json"' >> ~/.zshrc
```

### Method 3: Using AWS Credentials File

```bash
mkdir -p ~/.aws

cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
EOF

cat > ~/.aws/config << EOF
[default]
region = us-east-1
output = json
EOF

chmod 600 ~/.aws/credentials ~/.aws/config
```

## ✅ Verify Configuration

```bash
export PATH="/home/mehedi/.local/bin:$PATH"

# Test AWS CLI
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "AIDAI...",
    "Account": "388449571465",
    "Arn": "arn:aws:iam::388449571465:user/dhakacart-deployment"
}
```

If you see this, configuration is **✅ SUCCESSFUL**!

## 🐛 Troubleshooting

### Error: "Unable to locate credentials"

- Run `aws configure` or set environment variables
- Check `~/.aws/credentials` file exists
- Verify permissions: `ls -la ~/.aws/`

### Error: "Not authorized to perform: ec2:DescribeInstances"

- Your IAM user needs EC2 permissions
- Attach `AmazonEC2FullAccess` policy
- Wait 1-2 minutes for permissions to take effect

### Error: "Invalid Access Key ID"

- Double-check Access Key ID (no spaces)
- Verify you copied the correct credentials
- Check if key is still active (not deleted)

### Error: "The Security Token Included in the Request is Invalid"

- Check Secret Access Key is correct
- Ensure credentials haven't expired

## 🔒 Security Best Practices

1. **Never commit credentials** to Git

   ```bash
   echo "~/.aws/credentials" >> .gitignore
   ```

2. **Use IAM roles** instead of access keys (for EC2 instances)

3. **Rotate credentials** regularly
   - Delete old access key
   - Create new access key
   - Update configuration

4. **Use least privilege** principle
   - Give only necessary permissions to IAM user
   - Don't use full admin access

5. **Enable MFA** for AWS account (optional but recommended)

## 🌍 Available AWS Regions

```bash
aws ec2 describe-regions --query 'Regions[].RegionName' --output text
```

Common regions:

- `us-east-1` (N. Virginia) - Recommended for most deployments
- `us-west-2` (Oregon)
- `eu-west-1` (Ireland)
- `ap-southeast-1` (Singapore)
- `ap-south-1` (Mumbai)

## 📝 Next Steps After Configuration

Once AWS is configured, you can:

1. **Deploy infrastructure using Terraform**:

   ```bash
   cd terraform/
   terraform init
   terraform plan
   terraform apply
   ```

2. **Check EC2 instances**:

   ```bash
   aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' --output table
   ```

3. **View RDS databases**:

   ```bash
   aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]' --output table
   ```

4. **Check S3 buckets**:

   ```bash
   aws s3 ls
   ```

## 💡 Quick Configuration Script

Save as `configure-aws.sh`:

```bash
#!/bin/bash

echo "AWS Configuration Setup"
echo "======================="
echo ""
echo "Please enter your AWS credentials:"
echo ""
read -p "Access Key ID: " ACCESS_KEY
read -sp "Secret Access Key: " SECRET_KEY
echo ""
read -p "Default region [us-east-1]: " REGION
REGION=${REGION:-us-east-1}

mkdir -p ~/.aws

cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
EOF

cat > ~/.aws/config << EOF
[default]
region = $REGION
output = json
EOF

chmod 600 ~/.aws/credentials ~/.aws/config

echo ""
echo "✅ AWS configured successfully!"
echo ""
echo "Verifying configuration..."
aws sts get-caller-identity
```

Run:

```bash
bash configure-aws.sh
```

## 📊 AWS Account Information

- **AWS Account ID**: 388449571465
- **Current IAM User**: d5nc-poridhi (may not have sufficient permissions)

To use with DhakaCart project:

1. Create new IAM user `dhakacart-deployment`
2. Attach required policies
3. Create access keys
4. Configure AWS CLI with those credentials

---

**Status**: ✅ AWS CLI Installed
**Next**: Configure with your credentials
**Expected Grade Impact**: ✅ Deployment capability ready
