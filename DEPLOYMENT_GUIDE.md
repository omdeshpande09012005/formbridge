# FormBridge Deployment Guide

## Prerequisites

- AWS Account with permissions for Lambda, DynamoDB, SES, API Gateway
- AWS SAM CLI installed (`sam --version`)
- AWS CLI configured with credentials
- SES sender email verified in AWS SES (console → Verified Identities)

## Migration from Old Schema

If you have existing data in the old schema:

### Option 1: Fresh Start (Recommended for new deployments)

The new SAM template will create a new table. Existing data will remain in the old table but won't be accessed.

### Option 2: Data Migration

```bash
# 1. Export old data
aws dynamodb scan \
  --table-name contact-form-submissions \
  --region us-east-1 > old_data.json

# 2. Transform old items to new schema (use migration script below)
python3 migrate_schema.py old_data.json > new_data.json

# 3. Import new data (after deploying new table)
aws dynamodb batch-write-item \
  --request-items file://new_data.json \
  --region us-east-1
```

**Migration Script (`migrate_schema.py`):**

```python
import json
import uuid
from datetime import datetime

def migrate_item(old_item):
    """Convert old schema to new schema."""
    submission_id = old_item.get('submissionId', {}).get('S', str(uuid.uuid4()))
    ts = old_item.get('createdAt', {}).get('S', datetime.utcnow().isoformat() + 'Z')
    
    new_item = {
        "pk": {"S": "FORM#default"},
        "sk": {"S": f"SUBMIT#{ts}#{submission_id}"},
        "id": {"S": submission_id},
        "form_id": {"S": "default"},
        "name": old_item.get('name', {"S": ""}),
        "email": old_item.get('email', {"S": ""}),
        "message": old_item.get('message', {"S": ""}),
        "page": {"S": ""},
        "ua": {"S": ""},
        "ip": {"S": ""},
        "ts": {"S": ts},
    }
    return new_item

# Read old data
with open('old_data.json') as f:
    data = json.load(f)

# Transform items
new_items = {'contact-form-submissions': [{'PutRequest': {'Item': migrate_item(item)}} 
             for item in data.get('Items', [])]}

# Write new data
with open('new_data.json', 'w') as f:
    json.dump(new_items, f, indent=2)
```

## Deployment Steps

### 1. Set Environment Variables

```bash
# Create a samconfig.toml or set via CLI
export STACK_NAME="formbridge-api"
export AWS_REGION="us-east-1"
export PROFILE="default"  # if using named profile

# Or create samconfig.toml
cat > backend/samconfig.toml << 'EOF'
version = 0.1
[default]
[default.deploy]
[default.deploy.parameters]
stack_name = "formbridge-api"
region = "us-east-1"
confirm_changeset = true
capabilities = "CAPABILITY_IAM"
EOF
```

### 2. Build

```bash
cd backend
sam build
```

### 3. Deploy (First Time)

```bash
sam deploy --guided \
  --parameter-overrides \
    SesSender=noreply@formbridge.com \
    SesRecipients=admin@formbridge.com,ops@formbridge.com \
    FrontendOrigin=https://omdeshpande09012005.github.io
```

**Guided mode will prompt for:**
- Stack name (e.g., `formbridge-api`)
- AWS Region (e.g., `us-east-1`)
- Confirm changes before deploy (y/n)
- Allow SAM CLI to create IAM roles (y/n)

### 4. Deploy (Subsequent Updates)

```bash
sam deploy \
  --parameter-overrides \
    SesSender=noreply@formbridge.com \
    SesRecipients=admin@formbridge.com,ops@formbridge.com
```

### 5. Retrieve API Endpoint

```bash
aws cloudformation describe-stacks \
  --stack-name formbridge-api \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

**Output:** `https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/submit`

## Verify Deployment

### Test Endpoint

```bash
ENDPOINT="https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/submit"

curl -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "test",
    "name": "Test User",
    "email": "test@example.com",
    "message": "This is a test",
    "page": "https://example.com/contact"
  }'
```

**Expected Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Check DynamoDB

```bash
aws dynamodb scan \
  --table-name contact-form-submissions \
  --region us-east-1 \
  --limit 10
```

### Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/contactFormProcessor \
  --region us-east-1 \
  --follow
```

## Configuration Management

### Update SES Recipients

```bash
sam deploy \
  --parameter-overrides \
    SesRecipients="new-admin@example.com,backup@example.com"
```

### Update CORS Origin

```bash
sam deploy \
  --parameter-overrides \
    FrontendOrigin="https://new-domain.com"
```

### Disable Email Notifications

Leave `SesRecipients` empty:

```bash
sam deploy \
  --parameter-overrides \
    SesRecipients=""
```

## Monitoring

### CloudWatch Metrics

```bash
# Monitor Lambda invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=contactFormProcessor \
  --start-time 2025-11-01T00:00:00Z \
  --end-time 2025-11-05T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### DynamoDB Throughput

```bash
# Check consumed capacity
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=contact-form-submissions \
  --start-time 2025-11-01T00:00:00Z \
  --end-time 2025-11-05T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## Cleanup

```bash
# Delete the entire stack (removes Lambda, API Gateway, DynamoDB, etc.)
aws cloudformation delete-stack \
  --stack-name formbridge-api \
  --region us-east-1

# Verify deletion
aws cloudformation describe-stacks \
  --stack-name formbridge-api \
  --region us-east-1
# Will error with "does not exist" once deleted
```

## Troubleshooting

### SES SendEmail Failure: "MessageRejected"

**Cause:** Sender email not verified in SES

**Fix:**
```bash
# Verify email in SES
aws ses verify-email-identity \
  --email-address noreply@example.com \
  --region us-east-1

# Or verify domain
aws ses verify-domain-identity \
  --domain example.com \
  --region us-east-1
```

### Lambda Timeout

**Cause:** DynamoDB or SES taking too long (rare)

**Fix:**
```bash
sam deploy \
  --parameter-overrides \
    "LambdaTimeout=60"  # Increase timeout in template first
```

### CORS Error in Frontend

**Cause:** Frontend origin not matching `FRONTEND_ORIGIN` env var

**Fix:**
```bash
sam deploy \
  --parameter-overrides \
    FrontendOrigin="https://your-actual-domain.com"
```

### DynamoDB ConsumedWriteCapacityUnits High

**Cause:** Many submissions triggering high write throughput

**Note:** Table uses `PAY_PER_REQUEST` billing, so no provisioned capacity needed. Costs scale with actual usage.

**Optimization:** Consider adding DynamoDB TTL to auto-delete old submissions.

## Cost Optimization

1. **DynamoDB TTL:** Auto-delete submissions older than 90 days

   ```bash
   aws dynamodb update-time-to-live \
     --table-name contact-form-submissions \
     --time-to-live-specification 'AttributeName=ttl,Enabled=true' \
     --region us-east-1
   ```

   Then update Lambda to set `ttl` on each item:

   ```python
   from datetime import datetime, timedelta
   
   item['ttl'] = int((datetime.utcnow() + timedelta(days=90)).timestamp())
   ```

2. **SES:** Verify domain for better reputation and lower costs
3. **Lambda Layers:** Share common code (boto3 is built-in, but consider other libraries if added)
