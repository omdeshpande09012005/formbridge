# 🔐 AWS Profile Configuration for formbridge-deploy User

## ⚠️ IMPORTANT: Always Use formbridge-deploy User

This guide ensures all future deployments use the `formbridge-deploy` IAM user which has proper CloudFormation permissions.

---

## ✅ Configured Profile

**Profile Name**: `formbridge-deploy`  
**Region**: `ap-south-1`  
**Permissions**: ✅ CloudFormation, Lambda, DynamoDB, SES, SQS, IAM

---

## 🚀 How to Use

### Option 1: Set Default Profile (Persistent)

**For PowerShell** (Current Terminal):
```powershell
$env:AWS_PROFILE="formbridge-deploy"
```

**For Windows (System-wide)**:
1. Right-click "This PC" → Properties
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Click "New" under User variables
5. Variable name: `AWS_PROFILE`
6. Variable value: `formbridge-deploy`
7. Click OK

**For Linux/Mac**:
```bash
export AWS_PROFILE=formbridge-deploy
```

### Option 2: Use Profile in Commands

Add `--profile formbridge-deploy` to any AWS command:

```bash
# SAM deploy
sam deploy --profile formbridge-deploy

# AWS CLI
aws s3 ls --profile formbridge-deploy

# Terraform
export AWS_PROFILE=formbridge-deploy
```

---

## 📋 Verify Profile is Set

```powershell
# Check current profile
echo $env:AWS_PROFILE

# Verify credentials
aws sts get-caller-identity --profile formbridge-deploy
```

**Expected output**:
```json
{
    "UserId": "AIDA4STEF76HCTVPSR7VK",
    "Account": "864572276622",
    "Arn": "arn:aws:iam::864572276622:user/formbridge-deploy"
}
```

---

## 🔧 SAM Deployment Commands

**Always use these**:

```bash
# Build
cd backend
sam build

# Deploy
sam deploy --stack-name formbridge-stack --capabilities CAPABILITY_IAM --no-confirm-changeset

# Or use the batch script
DEPLOY_BACKEND.bat
```

---

## 📝 Profile Details

### Credentials Location

Windows:
```
C:\Users\%USERNAME%\.aws\credentials
```

Linux/Mac:
```
~/.aws/credentials
```

### View Configured Profile

```powershell
cat ~/.aws/config | grep formbridge -A 3
```

---

## ✅ Deployment Checklist

Before deploying:

- [ ] `$env:AWS_PROFILE="formbridge-deploy"` is set
- [ ] `aws sts get-caller-identity` shows `formbridge-deploy` user
- [ ] `cd backend` before running `sam` commands
- [ ] Use `sam build && sam deploy` sequence

---

## 🎯 Quick Start Template

```powershell
# 1. Set profile
$env:AWS_PROFILE="formbridge-deploy"

# 2. Verify
aws sts get-caller-identity --profile formbridge-deploy

# 3. Deploy
cd backend
sam build
sam deploy --stack-name formbridge-stack --capabilities CAPABILITY_IAM --no-confirm-changeset
```

---

## ⚠️ Never Use

❌ OD_User (has restricted permissions)  
❌ Default AWS credentials (if not formbridge-deploy)  
❌ Manual AWS_ACCESS_KEY_ID without profile  

✅ **Always use**: `formbridge-deploy` IAM user

---

## 🐛 Troubleshooting

### Error: "User is not authorized"

**Solution**: Verify profile is set
```powershell
echo $env:AWS_PROFILE
```

Should show: `formbridge-deploy`

### Error: "Credentials not found"

**Solution**: Reconfigure credentials
```powershell
aws configure --profile formbridge-deploy
```

### Error: "Stack update failed"

**Solution**: Ensure formbridge-deploy user is being used
```powershell
aws sts get-caller-identity --profile formbridge-deploy
```

---

## 📞 Reference

**Active IAM User**: `formbridge-deploy`  
**Region**: `ap-south-1`  
**Stack Name**: `formbridge-stack`  
**Last Deployment**: November 6, 2025 ✅

---

**Remember**: Always use `formbridge-deploy` for all FormBridge deployments!

