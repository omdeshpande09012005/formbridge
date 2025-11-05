# FormBridge Lambda Deployment Guide

## Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- AWS SAM CLI installed (`sam --version`)
- AWS credentials configured (`~/.aws/credentials` or `aws configure`)
- Docker installed (for SAM local testing)

### Deploy in 5 Minutes
```bash
cd backend
sam build
sam deploy --guided
```

---

## Step-by-Step Deployment

### 1. Build the Lambda Function

```bash
cd backend
sam build
```

**Output:**
```
Build Succeeded
Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml
```

### 2. Deploy to AWS

**First-time deployment (interactive):**
```bash
sam deploy --guided
```

**Prompts & Recommended Values:**
```
Stack Name [sam-app]: formbridge-stack
Region [us-east-1]: us-east-1  # or your preferred region
Confirm changes before deploy [y/N]: y
Allow SAM CLI IAM role creation [Y/n]: Y
DDBTableName [contact-submissions]: contact-submissions-prod
SESFromEmail: noreply@formbridge.example.com
SESRecipients: admin@example.com,team@example.com
FrontendOrigin [https://omdeshpande09012005.github.io]: https://omdeshpande09012005.github.io

Changeset created successfully. ...
Deploy this changeset? [y/N]: y
```

**Subsequent deployments (automated):**
```bash
sam deploy
```

Uses saved parameters from `samconfig.toml`

### 3. Verify Deployment

**Check CloudFormation stack:**
```bash
aws cloudformation describe-stacks --stack-name formbridge-stack
```

**Get API Gateway URL:**
```bash
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ContactFormApi`].OutputValue' \
  --output text
```

**Save to variable:**
```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ContactFormApi`].OutputValue' \
  --output text)
echo "API URL: $API_URL"
```

---

## Configuration

### Environment Variables

Set these before deployment in `samconfig.toml` or via CLI:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DDBTableName` | Yes | `contact-submissions` | DynamoDB table name |
| `SESFromEmail` | Yes | - | Verified SES sender email |
| `SESRecipients` | Yes | - | Comma-separated recipient emails |
| `FrontendOrigin` | No | `https://omdeshpande09012005.github.io` | CORS allowed origin |

### Update Configuration

**Modify environment in AWS Console:**
```bash
aws lambda update-function-configuration \
  --function-name ContactFormFunction \
  --environment Variables='{
    DDB_TABLE=contact-submissions-prod,
    SES_SENDER=noreply@formbridge.example.com,
    SES_RECIPIENTS=admin@example.com;team@example.com,
    FRONTEND_ORIGIN=https://omdeshpande09012005.github.io
  }'
```

Or update `samconfig.toml` and redeploy:
```bash
sam deploy
```

---

## SES Configuration

### Prerequisites

1. **Verify Sender Email**
   ```bash
   aws ses verify-email-identity --email-address noreply@formbridge.example.com
   ```
   
   Check email inbox for verification link and click it.

2. **Verify Recipient Emails** (if not in production account)
   ```bash
   aws ses verify-email-identity --email-address admin@example.com
   aws ses verify-email-identity --email-address team@example.com
   ```

3. **Check SES Sending Quota**
   ```bash
   aws ses get-send-statistics
   ```

### SES Sandbox Mode

If your account is in **SES Sandbox**, you must verify both sender and recipients.

**To exit Sandbox:**
1. Go to AWS SES Console
2. Submit limit increase request for your account
3. AWS reviews and approves (usually within 24 hours)

### Test Email Sending

```bash
aws ses send-email \
  --source noreply@formbridge.example.com \
  --destination ToAddresses=admin@example.com \
  --message Subject={Data="Test",Charset=UTF-8},Body={Text={Data="Test email",Charset=UTF-8}}
```

---

## DynamoDB Configuration

### Table Creation (Automatic via SAM)

SAM template creates table with:
- **Partition Key:** `pk` (String)
- **Sort Key:** `sk` (String)
- **Billing Mode:** PAY_PER_REQUEST (on-demand)
- **TTL:** Enabled on `ttl` attribute

### Manual Table Creation (if needed)

```bash
aws dynamodb create-table \
  --table-name contact-submissions-prod \
  --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
```

### Enable TTL

```bash
aws dynamodb update-time-to-live \
  --table-name contact-submissions-prod \
  --time-to-live-specification AttributeName=ttl,Enabled=true
```

### Monitor DynamoDB

**Check table status:**
```bash
aws dynamodb describe-table --table-name contact-submissions-prod
```

**Monitor metrics:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=contact-submissions-prod \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

---

## API Gateway Configuration

### Get API Details

```bash
# List API Gateway APIs
aws apigateway get-rest-apis --query 'items[?name==`ContactFormApi`]'

# Get resources
API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`ContactFormApi`].id' \
  --output text)

aws apigateway get-resources --rest-api-id $API_ID
```

### Custom Domain (Optional)

1. **Register domain or use Route53:**
   ```bash
   # Use existing domain or create new
   DOMAIN="forms.example.com"
   ```

2. **Create Certificate Manager certificate:**
   ```bash
   aws acm request-certificate \
     --domain-name $DOMAIN \
     --validation-method DNS
   ```

3. **Create API Gateway custom domain:**
   ```bash
   aws apigateway create-domain-name \
     --domain-name $DOMAIN \
     --certificate-arn arn:aws:acm:...
   ```

4. **Update Route53 DNS:**
   ```bash
   # Points to API Gateway CloudFront distribution
   # Instructions provided in ACM console
   ```

---

## Local Testing Before Deployment

### Start Local Emulation

```bash
cd backend
sam local start-api --port 3001
```

### Test Endpoints Locally

**Submit endpoint:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "name": "Test User",
    "email": "test@example.com",
    "message": "This is a local test"
  }'
```

**Analytics endpoint:**
```bash
curl -X POST http://localhost:3001/analytics \
  -H "Content-Type: application/json" \
  -d '{"form_id":"contact-form"}'
```

### Mock DynamoDB & SES Locally

```bash
# Start DynamoDB Local
docker run -d -p 8000:8000 amazon/dynamodb-local

# Set environment variables
export AWS_ACCESS_KEY_ID=local
export AWS_SECRET_ACCESS_KEY=local
export AWS_DEFAULT_REGION=us-east-1

# Create local table
aws dynamodb create-table \
  --table-name contact-submissions-dev \
  --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:8000

# Set environment variables for SAM
export DDB_TABLE=contact-submissions-dev
export SES_SENDER=noreply@example.com
export SES_RECIPIENTS=admin@example.com

# Start SAM with local DynamoDB
sam local start-api --port 3001 --docker-network local
```

---

## Monitoring & Logs

### CloudWatch Logs

**View Lambda logs:**
```bash
# Real-time tail
sam logs -n ContactFormFunction --stack-name formbridge-stack --tail

# Historical logs (last hour)
aws logs tail /aws/lambda/ContactFormFunction --since 1h
```

**Query specific submissions:**
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/ContactFormFunction \
  --filter-pattern "Stored submission"
```

### CloudWatch Metrics

**Create custom dashboard:**
```bash
aws cloudwatch put-dashboard \
  --dashboard-name FormBridgeMetrics \
  --dashboard-body file://dashboard.json
```

**Example `dashboard.json`:**
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Invocations", {"stat": "Sum"}],
          ["AWS/Lambda", "Duration", {"stat": "Average"}],
          ["AWS/Lambda", "Errors", {"stat": "Sum"}],
          ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "FormBridge Metrics"
      }
    }
  ]
}
```

### CloudWatch Alarms

**Alert on Lambda errors:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name FormBridge-Lambda-Errors \
  --alarm-description "Alert when Lambda has errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT:FormBridge-Alerts
```

---

## CI/CD Integration

### GitHub Actions

**`.github/workflows/deploy.yml`:**
```yaml
name: Deploy FormBridge

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
          aws-region: us-east-1
      
      - name: Build
        run: sam build --use-container
        working-directory: backend
      
      - name: Deploy
        run: sam deploy --no-confirm-changeset
        working-directory: backend
```

---

## Rollback & Recovery

### Rollback to Previous Version

**List stack changes:**
```bash
aws cloudformation describe-stack-resources \
  --stack-name formbridge-stack
```

**Rollback to previous version:**
```bash
aws cloudformation cancel-update-stack --stack-name formbridge-stack
```

### Manual Rollback

```bash
# Get previous template
aws cloudformation get-template \
  --stack-name formbridge-stack \
  --template-stage ORIGINAL > previous.yaml

# Update stack with previous template
aws cloudformation update-stack \
  --stack-name formbridge-stack \
  --template-body file://previous.yaml
```

### Disaster Recovery

**Backup submissions:**
```bash
# Export all items from DynamoDB
aws dynamodb scan \
  --table-name contact-submissions-prod \
  --output json > submissions-backup.json
```

**Restore from backup:**
```bash
# Batch write items
aws dynamodb batch-write-item \
  --request-items file://submissions-backup.json
```

---

## Cost Optimization

### Estimate Costs

**Assumptions per month:**
- 1,000 form submissions
- 10 analytics queries per submission
- DynamoDB: 1,000 writes + 10,000 reads

**Pricing (US East 1):**
- Lambda: 0.20$ per 1M requests + compute time (~$0.02/month)
- DynamoDB on-demand: $1.25 per million write units + $0.25 per million read units (~$0.01/month)
- SES: $0.10 per 1,000 emails ($0.10/month)
- **Total: ~$0.13/month**

### Cost Reduction Tips

1. **Use DynamoDB provisioned capacity** instead of on-demand for predictable traffic
2. **Cache analytics results** in ElastiCache (Redis) for 5-10 minutes
3. **Batch SES emails** instead of sending individually
4. **Archive old submissions** to S3 Glacier (after 90-day TTL)

---

## Troubleshooting Deployment

### Issue: "User is not authorized to perform: iam:PassRole"

**Fix:** Ensure IAM user has these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole",
        "cloudformation:*",
        "lambda:*",
        "dynamodb:*",
        "apigateway:*",
        "ses:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Issue: "SES MessageRejected: Email address not verified"

**Fix:** Verify sender email:
```bash
aws ses verify-email-identity --email-address noreply@formbridge.example.com
```

Then check verification email and click link.

### Issue: "DynamoDB table already exists"

**Fix:** Use existing table:
```bash
sam deploy --parameter-overrides DDBTableName=contact-submissions-prod
```

### Issue: "Lambda function timeout"

**Increase timeout:**
```bash
aws lambda update-function-configuration \
  --function-name ContactFormFunction \
  --timeout 30
```

### Issue: "CORS error in browser"

**Verify origin matches:**
```bash
# Current setting
aws lambda get-function-configuration \
  --function-name ContactFormFunction \
  --query 'Environment.Variables.FRONTEND_ORIGIN'

# Update if needed
aws lambda update-function-configuration \
  --function-name ContactFormFunction \
  --environment Variables='{...,FRONTEND_ORIGIN=https://your-domain.com}'
```

---

## Cleanup & Deletion

### Remove AWS Resources

**Delete CloudFormation stack:**
```bash
aws cloudformation delete-stack --stack-name formbridge-stack
```

**This removes:**
- Lambda function
- API Gateway
- IAM roles
- DynamoDB table ⚠️ (with all submissions!)

**Verify deletion:**
```bash
aws cloudformation describe-stacks --stack-name formbridge-stack
```

### Backup Before Deletion

```bash
# Export submissions
aws dynamodb scan \
  --table-name contact-submissions-prod \
  > submissions-backup-$(date +%Y%m%d).json

# Then delete
aws cloudformation delete-stack --stack-name formbridge-stack
```

---

## Next Steps

- [ ] Deploy to dev environment
- [ ] Test all endpoints
- [ ] Configure monitoring/alarms
- [ ] Set up CI/CD pipeline
- [ ] Deploy to production
- [ ] Document custom domain (if using)
- [ ] Set up log retention policies
- [ ] Implement caching strategy
- [ ] Plan disaster recovery procedure

