# Cost Guardrails Scripts - README

**Status**: ✅ Production Ready  
**Last Updated**: November 5, 2025  

---

## Overview

FormBridge includes three comprehensive scripts for cost management and infrastructure safety:

1. **setup-cost-guardrails.sh / .ps1** — Create AWS Budget, SNS alerts, apply tags
2. **verify-cost-posture.sh** — Read-only audit of current costs, config, metrics  
3. **teardown-formbridge.sh / .ps1** — Safe infrastructure cleanup with confirmation

All scripts are:
- ✅ **Idempotent** — Safe to run repeatedly
- ✅ **Bash + PowerShell** — Both Unix and Windows support
- ✅ **Production-ready** — Proper error handling, logging
- ✅ **Well-documented** — Inline comments, usage examples

---

## Quick Start

### 1. Setup Cost Guardrails (5 minutes)

**Bash** (macOS/Linux/WSL):
```bash
export REGION=ap-south-1
export ALERT_EMAIL=ops@example.com
export BUDGET_LIMIT=3.00
bash scripts/setup-cost-guardrails.sh
```

**PowerShell** (Windows):
```powershell
$env:REGION = "ap-south-1"
$env:ALERT_EMAIL = "ops@example.com"
$env:BUDGET_LIMIT = "3.00"
& .\scripts\setup-cost-guardrails.ps1
```

**What Happens**:
- ✓ Creates AWS Budget: FormBridge-Monthly-Budget
- ✓ Creates SNS Topic: FormBridge-Budget-Alerts
- ✓ Subscribes email to budget alerts
- ✓ Tags all resources with: Project=FormBridge, Env=Prod, Owner=OmDeshpande
- ✓ Verifies DynamoDB: Billing mode, TTL, PITR status
- ✓ Verifies SQS: Queue depth, retention, DLQ config
- ✓ Reports summary with console links

**Next Step**: Check your email and confirm the SNS subscription

---

### 2. Verify Cost Posture (Weekly)

**Bash**:
```bash
REGION=ap-south-1 bash scripts/verify-cost-posture.sh
```

**What Reports**:
- 📊 **Tagged Resources**: Count by service
- 💰 **Cost Estimation**: Last 7 days + monthly projection
- 📦 **DynamoDB**: Billing mode, TTL, PITR, item counts
- 🚀 **SQS**: Queue depth, retention, DLQ setup
- 📧 **SES**: Sandbox status, verified identities
- 🌐 **API Gateway**: Request count, errors, latency
- ⚡ **Lambda**: Invocations, errors, duration

**Example Output**:
```
[INFO] FormBridge Cost Posture Audit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 TAGGED RESOURCES (Project=FormBridge)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✓] contactFormProcessor (tagged)
[✓] formbridgeWebhookDispatcher (tagged)
[✓] contact-form-submissions (tagged)
...

💰 ESTIMATED COSTS (Last 7 Days)
[✓] Total cost (7 days): USD $0.45
[INFO] Daily average:      USD $0.064
[INFO] Monthly estimate:   USD $1.92
```

---

### 3. Teardown Infrastructure (Optional)

**Dry-Run** (Safe, preview what would be deleted):
```bash
bash scripts/teardown-formbridge.sh --dry-run
```

**Real Teardown** (Actually delete):
```bash
bash scripts/teardown-formbridge.sh --really-destroy
```

**Confirmation Required**:
```
[?] Type 'yes, really destroy FormBridge' to confirm:
```

**Options**:
```bash
# Keep DynamoDB data (don't delete tables)
bash scripts/teardown-formbridge.sh --really-destroy --keep-data

# Keep SNS topics
bash scripts/teardown-formbridge.sh --really-destroy --keep-sns

# Keep AWS Budget
bash scripts/teardown-formbridge.sh --really-destroy --keep-budget

# Also delete SSM/Secrets Manager
bash scripts/teardown-formbridge.sh --really-destroy --purge-secrets
```

**Deletion Order** (safe dependency order):
1. CloudFormation stacks
2. SQS event source mappings (Lambda ← SQS)
3. Consumer Lambda (formbridgeWebhookDispatcher)
4. SQS queues (main + DLQ)
5. API Gateway
6. Main Lambda (contactFormProcessor)
7. DynamoDB tables (optional with --keep-data)
8. SNS topics (optional with --keep-sns)
9. AWS Budget (optional with --keep-budget)
10. SSM/Secrets (optional with --purge-secrets)

---

## Environment Variables

### setup-cost-guardrails.sh

| Variable | Required | Default | Example |
|----------|----------|---------|---------|
| `REGION` | No | `ap-south-1` | `us-east-1` |
| `ALERT_EMAIL` | **Yes** | N/A | `ops@example.com` |
| `BUDGET_LIMIT` | No | `3.00` | `5.00`, `10.00` |
| `AWS_PROFILE` | No | `default` | `formbridge-deploy` |

### verify-cost-posture.sh

| Variable | Required | Default | Example |
|----------|----------|---------|---------|
| `REGION` | No | `ap-south-1` | `us-east-1` |
| `AWS_PROFILE` | No | `default` | `formbridge-deploy` |

### teardown-formbridge.sh

| Flag | Effect |
|------|--------|
| `--dry-run` | Preview deletion (no changes) |
| `--really-destroy` | Actually delete resources |
| `--keep-data` | Don't delete DynamoDB tables |
| `--keep-sns` | Don't delete SNS topics |
| `--keep-budget` | Don't delete AWS Budget |
| `--purge-secrets` | Also delete SSM/Secrets Manager |

---

## Recommended Workflow

### Weekly
```bash
# Audit current cost posture
bash scripts/verify-cost-posture.sh
```

### Monthly
```bash
# Review in AWS Budgets console
# https://console.aws.amazon.com/budgets/home#/budgets

# If costs spike, audit:
bash scripts/verify-cost-posture.sh
```

### When Cleaning Up
```bash
# First: preview with dry-run
bash scripts/teardown-formbridge.sh --dry-run

# Review the output
# Then: actually destroy
bash scripts/teardown-formbridge.sh --really-destroy
```

---

## Typical Monthly Budget Breakdown

**Scenario: 1M form submissions, 100K webhooks**

| Service | Usage | Cost | % of Budget |
|---------|-------|------|------------|
| Lambda | 1.1M invocations | $0.38 | 38% |
| API Gateway | 1M requests | $0.35 | 35% |
| DynamoDB | On-demand, ~5GB | $0.50 | 50% |
| SQS | 100K messages | $0.04 | 4% |
| SES | 10K emails | $0.00 | 0% |
| CloudWatch | Logs + metrics | $0.50 | 50% |
| **Total** | | **$1.77** | **177%** |

**Budget Recommendation**: $3.00 USD (150% of estimate for safety)

**If exceeding $3.00**:
1. Run `verify-cost-posture.sh` to identify the issue
2. Check CloudWatch logs for errors or retries
3. Review DynamoDB item count and consider archiving old data
4. Check SQS queue depth for stuck messages

---

## Troubleshooting

### "ALERT_EMAIL environment variable is required"

```bash
# Make sure to export the variable
export ALERT_EMAIL=ops@example.com
bash scripts/setup-cost-guardrails.sh
```

### "aws: command not found"

```bash
# Install AWS CLI v2
# macOS: brew install awscliv2
# Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# Windows: https://awscli.amazonaws.com/AWSCLIV2.msi

# Verify installation
aws --version
```

### "Unable to locate credentials"

```bash
# Configure AWS credentials
aws configure --profile formbridge-deploy

# Then use that profile
bash scripts/setup-cost-guardrails.sh  # Uses 'default'
# OR
AWS_PROFILE=formbridge-deploy bash scripts/setup-cost-guardrails.sh
```

### Budget alerts not sending

1. Check SNS subscription in email inbox
2. Click confirmation link in SNS email
3. Wait 5 minutes for subscription to activate
4. Trigger a test by modifying budget

### Teardown hangs or fails

```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks \
  --region ap-south-1 \
  --query "Stacks[?StackStatus=='DELETE_IN_PROGRESS'].StackName"

# Wait for stack deletion to complete (can take 5-10 minutes)
# Or manually delete in AWS Console
```

---

## Console Links

| Resource | Link |
|----------|------|
| **AWS Budgets** | https://console.aws.amazon.com/budgets/home#/budgets |
| **Cost Explorer** | https://console.aws.amazon.com/cost-management/home#/custom |
| **DynamoDB** | https://console.aws.amazon.com/dynamodb/home#/tables |
| **SQS** | https://console.aws.amazon.com/sqs/home |
| **API Gateway** | https://console.aws.amazon.com/apigateway/home |
| **Lambda** | https://console.aws.amazon.com/lambda/home#/functions |
| **SNS** | https://console.aws.amazon.com/sns/home#/topics |
| **CloudFormation** | https://console.aws.amazon.com/cloudformation/home#/stacks |
| **IAM Policies** | https://console.aws.amazon.com/iam/home#/policies |

---

## Script Details

### setup-cost-guardrails.sh

**Location**: `scripts/setup-cost-guardrails.sh`  
**Lines**: ~650  
**Functions**:
- `setup_sns_topic()` — Create SNS topic and subscribe email
- `setup_budget()` — Create AWS Budget with 50%/80%/100% thresholds
- `tag_core_resources()` — Apply mandatory tags to all FormBridge resources
- `verify_dynamodb()` — Check billing mode, TTL, PITR
- `verify_sqs()` — Check queue depth, retention, DLQ config
- `verify_cloudwatch_alarms()` — Tag CloudWatch alarms

**Idempotency**: Yes — checks if resources exist before creating

---

### verify-cost-posture.sh

**Location**: `scripts/verify-cost-posture.sh`  
**Lines**: ~650  
**Functions**:
- `audit_tagged_resources()` — Count resources by service with tags
- `audit_cost_estimation()` — Get last 7 days costs from Cost Explorer
- `audit_dynamodb()` — Report billing mode, TTL, PITR, item count
- `audit_sqs()` — Check queue depth, retention, DLQ setup
- `audit_ses()` — Check sandbox status, verified identities
- `audit_api_gateway()` — Get request count, errors, latency
- `audit_lambda_metrics()` — Report invocations, errors, duration
- `print_recommendations()` — Output best practices

**Read-Only**: Yes — no changes to AWS resources

---

### teardown-formbridge.sh

**Location**: `scripts/teardown-formbridge.sh`  
**Lines**: ~750  
**Functions**:
- `delete_cloudformation_stacks()` — Delete CloudFormation stacks first
- `delete_event_source_mappings()` — Remove Lambda ← SQS bindings
- `delete_consumer_lambda()` — Remove formbridgeWebhookDispatcher
- `delete_sqs_queues()` — Remove webhook queues
- `delete_api_gateway()` — Remove API Gateway
- `delete_main_lambda()` — Remove contactFormProcessor
- `delete_dynamodb_tables()` — Remove tables (optional)
- `delete_sns_topics()` — Remove SNS topics (optional)
- `delete_budget()` — Remove AWS Budget (optional)
- `delete_secrets()` — Remove SSM/Secrets Manager (optional)

**Safety Features**:
- Requires `--really-destroy` flag
- Interactive text confirmation: "yes, really destroy FormBridge"
- `--dry-run` mode for preview
- Tracks deleted, skipped, and kept resources

---

## Best Practices

✅ **Do**:
- Run `verify-cost-posture.sh` weekly
- Keep DynamoDB TTL enabled
- Monitor SQS queue depth
- Test `--dry-run` before real teardown
- Use `--keep-data` if you want to preserve submissions

❌ **Don't**:
- Run setup script with wrong `ALERT_EMAIL`
- Delete budget without understanding cost implications
- Run `--really-destroy` without `--dry-run` first
- Ignore 80% budget threshold alert
- Forget to confirm SNS subscription

---

## Support & Documentation

**Full Documentation**: See `docs/COST_GUARDRAILS.md`

**Questions?**:
1. Check this README first
2. Review `docs/COST_GUARDRAILS.md` for detailed guide
3. Run script with verbose output: `bash -x scripts/setup-cost-guardrails.sh`
4. Check AWS CloudTrail for API calls

---

**Scripts are production-ready and well-tested** ✅  
**All operations are safe with proper confirmation workflows** 🛡️  
**Cost transparency and control, automated** 💰
