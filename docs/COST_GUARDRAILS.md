# Cost Guardrails for FormBridge

**Last Updated**: November 5, 2025  
**Status**: ✅ Production Ready

---

## Overview

FormBridge's cost guardrails system provides multi-layered protection against unexpected AWS charges through:

1. **AWS Budgets** with tiered SNS alerts (50%, 80%, 100%)
2. **Mandatory cost tagging** for resource tracking and filtering
3. **Configuration verification** for DynamoDB, SQS, and other services
4. **Read-only auditing** with monthly cost estimation
5. **Safe teardown automation** with confirmation workflow

---

## Quick Start (1 Minute)

### 1. Setup Cost Guardrails

```bash
# Export configuration
export REGION=ap-south-1
export ALERT_EMAIL=ops@example.com
export BUDGET_LIMIT=3.00

# Run setup (bash)
bash scripts/setup-cost-guardrails.sh

# OR run setup (PowerShell)
$env:REGION = "ap-south-1"
$env:ALERT_EMAIL = "ops@example.com"
$env:BUDGET_LIMIT = "3.00"
& .\scripts\setup-cost-guardrails.ps1
```

### 2. Confirm SNS Subscription

- Check your email inbox
- Click the AWS SNS confirmation link
- Done! You'll now receive budget alerts

### 3. Audit Current Cost Posture

```bash
bash scripts/verify-cost-posture.sh
# Reviews: tagging, costs, DynamoDB config, SQS depth, SES status, API metrics
```

---

## What Gets Protected?

### AWS Budgets

**Name**: `FormBridge-Monthly-Budget`

**Alerting Thresholds**:

| Threshold | Alert Type | Action |
|-----------|-----------|--------|
| 50% of budget | Notification | Monitor spending |
| 80% of budget | **Warning** | Investigate costs |
| 100% of budget | **Critical** | Take immediate action |

**Cost Filter**: Tagged resources only (`Project=FormBridge`)

**Recommendation**: Set `BUDGET_LIMIT=3.00` USD for typical production usage with safety buffer

### SNS Topic

**Name**: `FormBridge-Budget-Alerts`

**Subscriptions**: Email notifications sent to `ALERT_EMAIL`

**Each Alert Includes**:
- Budget name and account ID
- Current spending vs. limit
- Percentage of budget used
- Date and time of alert

### Mandatory Tags

All FormBridge resources are tagged with:

```
Project=FormBridge
Env=Prod
Owner=OmDeshpande
```

**Tagged Resources**:
- Lambda functions (2x: contact processor, webhook dispatcher)
- API Gateway endpoints
- DynamoDB tables (2x: submissions, config)
- SQS queues (2x: main, DLQ)
- SNS topics
- CloudWatch alarms

**Cost Explorer Filtering**:
```bash
# Filter to FormBridge-only spending
aws ce get-cost-and-usage \
  --filter "Tags={Key={Key=Project,Values=[FormBridge]}}" \
  --granularity DAILY \
  --metrics UnblendedCost
```

---

## Configuration Verification

### DynamoDB Settings

The setup script validates:

✅ **Billing Mode**: PAY_PER_REQUEST (on-demand)
- Ideal for variable traffic
- No minimum costs
- Pay per request

✅ **TTL (Time-To-Live)**: ENABLED
- Automatic item expiration
- Reduces storage costs over time
- Set on the `ttl` attribute

❌ **PITR (Point-In-Time Recovery)**: DISABLED (by default)
- Adds ~20% to table cost
- Only enable if disaster recovery is needed
- Enable: `aws dynamodb update-continuous-backups --table-name <name> --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true`

### SQS Queue Settings

The setup script validates:

✅ **Main Queue Retention**: 4 days (345,600 seconds)
- Balances cost vs. visibility window
- Messages expire automatically

✅ **DLQ Retention**: 14 days (max)
- Sufficient for investigation of failures
- Reduces cost vs. unlimited

✅ **DLQ Redrive**: maxReceiveCount = 5
- Move to DLQ after 5 failed deliveries
- Prevents infinite retry loops

✅ **Queue Depth**: Monitor to detect stuck messages
- Depth > 1000: investigate
- Depth = 0: normal operation

---

## Cost Estimation

### Sample Monthly Breakdown

Assuming typical production load:

| Service | Request Volume | Estimated Cost | Notes |
|---------|---------------|-----------------|-------|
| Lambda | 1M invocations | $0.20 | 256MB, 1s avg |
| API Gateway | 1M requests | $0.35 | No caching |
| DynamoDB | Pay-per-request | $0.50 | Variable write load |
| SQS | 100K messages | $0.04 | Webhook delivery |
| SES | 10K emails | ~$0.00 | First 62K free |
| CloudWatch | Metrics & logs | $0.50 | Standard logs |
| **Total** | | **~$1.59/month** | Conservative estimate |

**Recommended Budget**: $3.00 USD (buffer for spikes)

### Cost Explorer View

```
https://console.aws.amazon.com/cost-management/home?region=ap-south-1#/custom
```

Filter by tag: `Project$FormBridge`

---

## Audit Script Usage

The `verify-cost-posture.sh` script provides a comprehensive read-only audit:

```bash
# Run full audit
REGION=ap-south-1 bash scripts/verify-cost-posture.sh
```

**Output Sections**:

1. **📊 Tagged Resources**: Count by service, verify tagging
2. **💰 Cost Estimation**: Last 7 days, monthly projection
3. **📦 DynamoDB**: BillingMode, TTL, PITR, item counts
4. **🚀 SQS**: Queue depths, retention, DLQ config
5. **📧 SES**: Sandbox status, verified identities
6. **🌐 API Gateway**: Request count, error rates, latency
7. **⚡ Lambda**: Invocations, errors, duration

---

## Recommended Limits

### Budget Thresholds

| Budget | Scenario | Alert at 50% | Alert at 80% |
|--------|----------|-------------|-------------|
| $3.00 | Dev/Test | $1.50 | $2.40 |
| $10.00 | Staging | $5.00 | $8.00 |
| $50.00 | Production | $25.00 | $40.00 |

### Per-Service Limits (Monthly)

| Service | Reasonable Limit | Optimization |
|---------|-----------------|--------------|
| Lambda | $5.00 | Enable concurrency limits |
| DynamoDB | $1.00 | Keep billing mode ON_DEMAND |
| API Gateway | $1.00 | Consider caching, throttling |
| SQS | $0.50 | Monitor queue depth |
| SES | $0.10 | Use quota for production volume |

---

## Safe Teardown

### Dry-Run (Safe Preview)

```bash
# See what would be deleted
bash scripts/teardown-formbridge.sh --dry-run
```

### Real Teardown (Destructive)

```bash
# Actually delete resources
bash scripts/teardown-formbridge.sh --really-destroy
```

**Confirmation Required**:
```
[?] Type 'yes, really destroy FormBridge' to confirm:
```

### Options

```bash
# Keep DynamoDB data (non-destructive)
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
2. SQS event source mappings
3. Consumer Lambda
4. SQS queues
5. API Gateway
6. Main Lambda
7. DynamoDB tables (optional)
8. SNS topics (optional)
9. AWS Budget (optional)
10. SSM/Secrets (optional)

---

## Troubleshooting

### Alert Email Not Received

**Symptoms**: SNS subscription pending, no confirmation email

**Solution**:
1. Check spam folder
2. Resend confirmation:
   ```bash
   ALERT_EMAIL=ops@example.com bash scripts/setup-cost-guardrails.sh
   ```
3. Verify email address spelling

### Budget Not Created

**Symptoms**: Budget doesn't appear in AWS Console

**Check**:
1. Account ID is correct: `aws sts get-caller-identity`
2. IAM permissions include `budgets:CreateBudget`
3. Budget name unique in account

### Cost Overages

**If you receive 100% alert**:

1. Run cost audit:
   ```bash
   bash scripts/verify-cost-posture.sh
   ```

2. Check top cost drivers:
   ```bash
   aws ce get-cost-and-usage \
     --filter "Tags={Key={Key=Project,Values=[FormBridge]}}" \
     --group-by TYPE,KEY \
     --granularity DAILY \
     --metrics UnblendedCost
   ```

3. Consider emergency teardown:
   ```bash
   bash scripts/teardown-formbridge.sh --dry-run
   # Review, then:
   bash scripts/teardown-formbridge.sh --really-destroy
   ```

---

## Best Practices

### ✅ Do's

- ✅ Run `verify-cost-posture.sh` weekly
- ✅ Keep DynamoDB TTL enabled
- ✅ Monitor SQS queue depth
- ✅ Confirm SNS email subscriptions
- ✅ Archive/clean up old submissions regularly
- ✅ Test teardown with `--dry-run` regularly

### ❌ Don'ts

- ❌ Disable budget alerts
- ❌ Remove cost tags
- ❌ Leave queues with stuck messages
- ❌ Ignore 80% threshold alert
- ❌ Forget to confirm SNS subscription
- ❌ Run `--really-destroy` without dry-run

---

## Console Links

| Resource | Link |
|----------|------|
| **AWS Budgets** | https://console.aws.amazon.com/budgets/home#/budgets |
| **Cost Explorer** | https://console.aws.amazon.com/cost-management/home#/custom |
| **DynamoDB Tables** | https://console.aws.amazon.com/dynamodb/home#/tables |
| **SQS Queues** | https://console.aws.amazon.com/sqs/home |
| **API Gateway** | https://console.aws.amazon.com/apigateway/home |
| **CloudWatch Logs** | https://console.aws.amazon.com/cloudwatch/home#logstream: |
| **Billing Dashboard** | https://console.aws.amazon.com/billing/home |

---

## Support

For cost-related issues:

1. Check this documentation
2. Run `verify-cost-posture.sh` for diagnostics
3. Review AWS Billing & Cost Management console
4. Contact: ops@example.com

---

**Remember**: Cost guardrails are automated safeguards, not prevention. Always monitor and act proactively! 🛡️💰
