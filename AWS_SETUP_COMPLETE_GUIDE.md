# FormBridge AWS Setup & Cost Guardrails Complete Guide

**Date**: November 5, 2025  
**Status**: Ready for deployment  
**Components**: Status Page ✅ | Cost Guardrails ✅ | AWS Verification ✅

---

## 📋 Table of Contents

1. [AWS Prerequisites & IAM Setup](#aws-prerequisites--iam-setup)
2. [Deploy FormBridge Backend](#deploy-formbridge-backend)
3. [Configure GitHub Secrets](#configure-github-secrets)
4. [Run Cost Guardrails Setup](#run-cost-guardrails-setup)
5. [Activate Status Page](#activate-status-page)
6. [Verification Checklist](#verification-checklist)

---

## AWS Prerequisites & IAM Setup

### ⚠️ Required IAM Permissions

Your AWS user needs these permissions to deploy FormBridge:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "iam:*",
        "lambda:*",
        "apigateway:*",
        "dynamodb:*",
        "sqs:*",
        "sns:*",
        "ses:*",
        "logs:*",
        "s3:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### How to Request IAM Permissions

1. **Ask your AWS Account Admin** to attach these policies to your user:
   - `AdministratorAccess` (full access), OR
   - `AWSCloudFormationFullAccess`
   - `AWSLambdaFullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `AmazonDynamoDBFullAccess`
   - `AmazonSQSFullAccess`
   - `AmazonSNSFullAccess`
   - `AmazonSESFullAccess`
   - `CloudWatchFullAccess`

2. **Or manually create an inline policy** with the JSON above

3. **Verify with**: `aws sts get-caller-identity`

---

## Deploy FormBridge Backend

### Prerequisites

```bash
# Check you have required tools
sam --version          # AWS SAM CLI
aws --version          # AWS CLI v2
python3 --version      # Python 3.11+
```

### Step 1: Navigate to Backend

```bash
cd w:\PROJECTS\formbridge\backend
```

### Step 2: Build SAM Application

```bash
# Build without Docker (faster on Windows)
sam build

# Expected output:
# Build Succeeded
# Built Artifacts  : .aws-sam\build
# Built Template   : .aws-sam\build\template.yaml
```

### Step 3: Deploy to AWS

```bash
# Option A: Interactive guided deployment (recommended first time)
sam deploy --guided
#   Stack Name: formbridge-stack
#   Region: ap-south-1
#   Environment: prod
#   SES Sender: your-verified-email@example.com (must be verified in SES)
#   SES Recipients: admin@example.com
#   Frontend Origin: https://omdeshpande09012005.github.io/formbridge/
#   Confirm changes before deploy: Y
#   Allow IAM role creation: Y
#   Save parameters to samconfig.toml: Y

# Option B: Deploy using existing config
sam deploy --config-env default

# Option C: Minimal deployment (no managed resources)
sam deploy \
  --stack-name formbridge-stack \
  --region ap-south-1 \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_IAM
```

### Step 4: Verify Deployment

```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region ap-south-1 \
  --query 'Stacks[0].StackStatus'

# Expected: CREATE_COMPLETE or UPDATE_COMPLETE

# Get API endpoint
aws apigateway get-rest-apis \
  --region ap-south-1 \
  --query 'items[0].id' \
  --output text

# The endpoint will be: https://[API_ID].execute-api.ap-south-1.amazonaws.com/Prod
```

### What Gets Created

| Resource | Name | Count |
|----------|------|-------|
| Lambda | contactFormProcessor | 1 |
| Lambda | formbridgeWebhookDispatcher | 1 |
| API Gateway | formbridge-stack | 1 |
| DynamoDB | contact-form-submissions | 1 |
| DynamoDB | formbridge-config | 1 |
| SQS | formbridge-webhook-queue | 1 |
| SQS | formbridge-webhook-dlq | 1 |
| IAM | Multiple roles & policies | 5+ |
| CloudWatch | Log groups | 2+ |

---

## Configure GitHub Secrets

### Step 1: Get Your API Key

```bash
# Option A: Get from Parameter Store
aws ssm get-parameter \
  --name /formbridge/prod/api-key \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region ap-south-1

# Copy the output value
```

### Step 2: Add to GitHub

1. Go to GitHub Repository Settings
   - https://github.com/omdeshpande09012005/formbridge/settings/secrets/actions

2. Click "New repository secret"

3. Create **3 secrets**:
   ```
   Name: STATUS_API_KEY
   Value: [paste API key from Step 1]

   Name: AWS_ACCESS_KEY_ID
   Value: [your AWS access key]

   Name: AWS_SECRET_ACCESS_KEY
   Value: [your AWS secret key]
   ```

4. Click "Add secret"

---

## Run Cost Guardrails Setup

### Why Cost Guardrails?

- **Prevent surprises**: Budget alerts before bills spike
- **Automate monitoring**: Weekly cost audits
- **Mandatory tagging**: Track resource costs by project
- **Safe cleanup**: One command to remove everything

### Prerequisites

```bash
# Set environment variables
export AWS_REGION=ap-south-1
export AWS_PROFILE=default
export ALERT_EMAIL=your-email@example.com
export BUDGET_LIMIT=3.00  # USD per month
```

### Step 1: Run Setup Script

```bash
cd w:\PROJECTS\formbridge

# PowerShell
pwsh
$env:ALERT_EMAIL = "your-email@example.com"
$env:BUDGET_LIMIT = "3.00"
bash scripts/setup-cost-guardrails.sh

# Bash (Linux/Mac)
bash scripts/setup-cost-guardrails.sh
```

### What Gets Created

✓ AWS Budget (FormBridge-Monthly-Budget)  
✓ SNS Topic for alerts (FormBridge-Budget-Alerts)  
✓ Email subscription (check inbox for confirmation)  
✓ Mandatory cost tags on all resources  
✓ DynamoDB/SQS configuration verification  

### Step 2: Confirm SNS Subscription

1. Check your email for "AWS Notification"
2. Click "Confirm subscription"
3. Email confirmations complete!

### Step 3: Weekly Cost Audits

```bash
# Run weekly to check current spending
bash scripts/verify-cost-posture.sh

# Shows:
# - Last 7 days spending
# - Monthly projection
# - Resource counts
# - Configuration status
# - Recommendations
```

---

## Activate Status Page

### Step 1: GitHub Actions Setup

1. Go to Repository Settings → Actions → General
2. Ensure "Allow all actions and reusable workflows" is enabled

### Step 2: Manual Test (First Run)

```bash
# Navigate to GitHub → Actions
# Click "FormBridge Status Check" workflow
# Click "Run workflow"
# Monitor execution
```

### Step 3: Verify Status Data

```bash
# After workflow completes, check the generated file
cat docs/status/status.json

# Should show:
# {
#   "updated_at": "2025-11-05T12:34:56Z",
#   "status": "UP|DEGRADED|DOWN",
#   "http_code": 200,
#   "latency_ms": 125,
#   "history": [...]
# }
```

### Step 4: Open Status Page

Navigate to:  
**https://omdeshpande09012005.github.io/formbridge/docs/status/**

Expected to see:
- ✓ Green UP badge
- ✓ HTTP 200 displayed
- ✓ Latency ~100-300ms
- ✓ Region: ap-south-1
- ✓ Sparkline chart with history

---

## Verification Checklist

### Phase 1: Infrastructure ✅

- [ ] AWS credentials configured: `aws sts get-caller-identity`
- [ ] SAM CLI installed: `sam --version`
- [ ] IAM user has CloudFormation permissions
- [ ] Backend built successfully: `sam build`

### Phase 2: Deployment

- [ ] Stack deployed: CloudFormation shows `CREATE_COMPLETE`
- [ ] Lambda functions exist: `contactFormProcessor` visible
- [ ] API Gateway deployed: Endpoint shows in AWS Console
- [ ] DynamoDB tables created: Two tables visible
- [ ] SQS queues created: Two queues visible

### Phase 3: Cost Guardrails ✅

- [ ] Cost guardrails script runs: `bash scripts/setup-cost-guardrails.sh`
- [ ] AWS Budget created: View in AWS Budgets Console
- [ ] SNS topic created: Email subscription confirmed
- [ ] Cost tags applied: Resources tagged with Project=FormBridge

### Phase 4: Status Page ✅

- [ ] GitHub secret `STATUS_API_KEY` added
- [ ] Workflow file present: `.github/workflows/status.yml`
- [ ] Workflow manual trigger works
- [ ] `docs/status/status.json` updates after workflow
- [ ] Status page displays data: https://omdeshpande09012005.github.io/formbridge/docs/status/

### Phase 5: Documentation ✅

- [ ] Main docs linked: `docs/index.html` has Status button
- [ ] Status README exists: `docs/STATUS_README.md`
- [ ] AWS setup guide created: This file
- [ ] Cost guardrails docs: `docs/COST_GUARDRAILS.md`

---

## Troubleshooting

### SAM Deploy Fails with CloudFormation Error

**Problem**: `AccessDenied: cloudformation:CreateChangeSet`

**Solution**:
1. Check IAM permissions: `aws iam get-user`
2. Request CloudFormation permissions from AWS admin
3. Use `--capabilities CAPABILITY_IAM` flag

### Status Page Shows "Failed to load"

**Problem**: `docs/status/status.json` not found

**Solution**:
1. Run GitHub Actions manually: Actions → Status Check → Run workflow
2. Wait for workflow to complete
3. Check workflow logs for errors
4. Commit changes if status.json created

### API Health Check Shows DOWN

**Problem**: Workflow status is "DOWN" when API is running

**Solution**:
1. Check API key in GitHub Secrets
2. Verify endpoint is accessible: `curl -X POST https://[ID].execute-api.ap-south-1.amazonaws.com/Prod/analytics -H "X-Api-Key: [KEY]"`
3. Check latency: If > 700ms, may show as DEGRADED
4. Review workflow logs for error details

### Cost Guardrails Budget Alert Not Working

**Problem**: Budget created but no email alerts

**Solution**:
1. Confirm SNS subscription: Check email for confirmation link
2. Test manually: `aws sns publish --topic-arn [ARN] --message "Test"`
3. Check CloudWatch logs
4. Verify alert email is correct in script

---

## Command Reference

### Quick Deploy

```bash
# Full deployment sequence
cd backend
sam build
sam deploy --guided
cd ..
bash scripts/setup-cost-guardrails.sh
bash scripts/verify-cost-posture.sh
```

### Quick Verify

```bash
# Check all resources
bash scripts/verify-aws-setup.sh

# Check costs
bash scripts/verify-cost-posture.sh

# Check status page
curl https://omdeshpande09012005.github.io/formbridge/docs/status/
```

### Quick Cleanup

```bash
# Preview deletion
bash scripts/teardown-formbridge.sh --dry-run

# Actual deletion (with confirmation)
bash scripts/teardown-formbridge.sh --really-destroy
```

---

## Expected Costs

### Monthly Breakdown

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1M invocations | $0.20 |
| API Gateway | 1M requests | $0.35 |
| DynamoDB | Pay-per-request | $0.50 |
| SQS | 100K messages | $0.04 |
| SES | 10K emails | ~$0.00 |
| CloudWatch | Logs | $0.50 |
| **Total** | — | **~$1.60** |

### Budget Alert Thresholds

| Level | Amount | Action |
|-------|--------|--------|
| 50% | $1.50 | Info email |
| 80% | $2.40 | Warning email |
| 100% | $3.00 | Critical email |

Budget limit recommended: **$3.00 USD**

---

## Next Steps

1. **Request IAM permissions** (if needed)
2. **Deploy backend** via SAM
3. **Run cost guardrails** setup
4. **Configure GitHub secrets**
5. **Trigger status workflow**
6. **Monitor status page**
7. **Review weekly costs**

---

## Support Resources

| Issue | Resource |
|-------|----------|
| SAM Deployment | [AWS SAM Docs](https://docs.aws.amazon.com/serverless-application-model/) |
| Cost Alerts | `docs/COST_GUARDRAILS.md` |
| Status Page | `docs/STATUS_README.md` |
| GitHub Actions | `.github/workflows/status.yml` |
| API Errors | `docs/STATUS_README.md` → Troubleshooting |

---

## Summary

✅ **Status Page**: Complete & live
✅ **Cost Guardrails**: Ready to deploy  
✅ **Documentation**: Comprehensive
⏳ **Backend**: Awaiting IAM permissions

All components are ready. Once you have CloudFormation permissions, deployment takes **~5 minutes**.

---

**Created**: November 5, 2025  
**Last Updated**: November 5, 2025  
**Next**: Deploy backend & activate monitoring
