# FormBridge v2 - AWS Deployment Configuration Guide

## Overview

This guide explains the deployment script and provides step-by-step instructions for configuring FormBridge on AWS.

---

## Prerequisites

✅ **AWS CLI** installed and configured
```bash
aws --version
aws sts get-caller-identity  # Verify credentials
```

✅ **jq** installed (for JSON processing)
```bash
jq --version
```

✅ **curl** installed (for API testing)
```bash
curl --version
```

✅ **Bash 4.0+** (for script execution)
```bash
bash --version
```

---

## Configuration Values Reference

Based on your FormBridge project setup:

### AWS Account Details
```
REGION                 = ap-south-1           # Asia Pacific (Mumbai)
ACCOUNT_ID             = 864572276622         # Your AWS Account ID
```

### DynamoDB
```
TABLE_NAME             = contact-form-submissions
- Composite key: pk (String) + sk (String)
- Billing: PAY_PER_REQUEST (on-demand)
- No partition key needed beyond pk/sk
```

### Lambda
```
LAMBDA_NAME            = contactFormProcessor
ROLE_NAME              = formbridge-deploy
```

### API Gateway
```
API_ID                 = [Get from CloudFormation output]
STAGE_NAME             = Prod
```

### CORS & Frontend
```
FRONTEND_ORIGIN        = https://omdeshpande09012005.github.io
```

### SES Configuration
```
SES_SENDER             = omdeshpande123456789@gmail.com (verified)
                       or omdeshpande0901@gmail.com (verified)
                       
SES_RECIPIENTS         = omdeshpande123456789@gmail.com (verified) ✓
                         omdeshpande0901@gmail.com (verified) ✓
                         aayush.das@mitwpu.edu.in (UNVERIFIED) ✗
                         sahil.bobhate@mitwpu.edu.in (verified) ✓
                         yash.dharap@mitwpu.edu.in (verified) ✓
                         om.deshpande@mitwpu.edu.in (verified) ✓
```

---

## Step-by-Step Deployment

### Step 0: Get API_ID and Lambda Details

```bash
# If using SAM deployment, get API ID from CloudFormation outputs
STACK_NAME="formbridge-api"

aws cloudformation describe-stacks \
  --stack-name ${STACK_NAME} \
  --region ap-south-1 \
  --query 'Stacks[0].Outputs' \
  --output table

# This will show you:
# - ApiUrl (contains API_ID and STAGE_NAME)
# - Lambda function name
# - DynamoDB table name
```

### Step 1: Extract Values from CloudFormation

```bash
# Extract API URL
API_FULL_URL=$(aws cloudformation describe-stacks \
  --stack-name formbridge-api \
  --region ap-south-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

# Parse API_ID and STAGE_NAME from URL
# URL format: https://[API_ID].execute-api.[REGION].amazonaws.com/[STAGE]
API_ID=$(echo ${API_FULL_URL} | cut -d'/' -f3 | cut -d'.' -f1)
STAGE_NAME=$(echo ${API_FULL_URL} | rev | cut -d'/' -f1 | rev)

echo "API_ID: ${API_ID}"
echo "STAGE_NAME: ${STAGE_NAME}"
```

### Step 2: Get Lambda Role Name

```bash
# Get Lambda function configuration
aws lambda get-function \
  --function-name contactFormProcessor \
  --region ap-south-1 \
  --query 'Configuration.Role' \
  --output text

# Output will be: arn:aws:iam::864572276622:role/formbridge-deploy
# Extract role name: formbridge-deploy
ROLE_NAME=$(aws lambda get-function \
  --function-name contactFormProcessor \
  --region ap-south-1 \
  --query 'Configuration.Role' \
  --output text | cut -d'/' -f2)

echo "ROLE_NAME: ${ROLE_NAME}"
```

### Step 3: Update deploy.sh Configuration

Edit `deploy.sh` and replace these lines:

```bash
# Line 25-33: Update with your actual values
REGION="ap-south-1"
ACCOUNT_ID="864572276622"
TABLE_NAME="contact-form-submissions"
LAMBDA_NAME="contactFormProcessor"
ROLE_NAME="formbridge-deploy"              # ← Update this
API_ID="YOUR_API_ID_HERE"                  # ← Update this (from Step 1)
STAGE_NAME="Prod"                          # ← Update this (from Step 1)
FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
SES_SENDER="omdeshpande123456789@gmail.com"  # ← Use verified email
SES_RECIPIENTS="..."                       # ← Update this
```

### Step 4: Run Deployment Script

```bash
# Make script executable
chmod +x deploy.sh

# Run with verbose output
bash -x deploy.sh

# Or simply run
./deploy.sh
```

---

## Manual Verification Commands

If you prefer to run commands individually instead of using the script:

### 1. Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name contact-form-submissions \
  --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1

# Wait for table to be active
aws dynamodb wait table-exists \
  --table-name contact-form-submissions \
  --region ap-south-1

# Verify table
aws dynamodb describe-table \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  --query 'Table.[TableName,TableStatus,BillingModeSummary.BillingMode]' \
  --output table
```

### 2. Update Lambda Environment Variables

```bash
# Get current environment (if any)
aws lambda get-function-configuration \
  --function-name contactFormProcessor \
  --region ap-south-1 \
  --query 'Environment.Variables' \
  --output json

# Update environment variables
aws lambda update-function-configuration \
  --function-name contactFormProcessor \
  --region ap-south-1 \
  --environment Variables='{
    DDB_TABLE=contact-form-submissions,
    SES_SENDER=omdeshpande123456789@gmail.com,
    SES_RECIPIENTS=omdeshpande123456789@gmail.com\,omdeshpande0901@gmail.com\,sahil.bobhate@mitwpu.edu.in\,yash.dharap@mitwpu.edu.in\,om.deshpande@mitwpu.edu.in,
    FRONTEND_ORIGIN=https://omdeshpande09012005.github.io
  }'

# Verify update
aws lambda get-function-configuration \
  --function-name contactFormProcessor \
  --region ap-south-1 \
  --query 'Environment.Variables' \
  --output json | jq '.'
```

### 3. Attach IAM Policy to Lambda Role

```bash
# Create policy JSON
cat > /tmp/formbridge-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DynamoDBWrite",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:ap-south-1:864572276622:table/contact-form-submissions"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-south-1:864572276622:log-group:/aws/lambda/contactFormProcessor:*"
    },
    {
      "Sid": "SESEmail",
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy
aws iam put-role-policy \
  --role-name formbridge-deploy \
  --policy-name formbridge-policy \
  --policy-document file:///tmp/formbridge-policy.json

# Verify
aws iam get-role-policy \
  --role-name formbridge-deploy \
  --policy-name formbridge-policy \
  --output json | jq '.PolicyDocument'
```

### 4. Configure API Gateway CORS

```bash
# 1. Get /submit resource ID
API_ID="YOUR_API_ID"
RESOURCES=$(aws apigateway get-resources \
  --rest-api-id ${API_ID} \
  --region ap-south-1 \
  --output json)

SUBMIT_RESOURCE_ID=$(echo ${RESOURCES} | jq -r '.items[] | select(.path=="/submit") | .id')
echo "Submit resource ID: ${SUBMIT_RESOURCE_ID}"

# 2. Create OPTIONS method
aws apigateway put-method \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region ap-south-1

# 3. Create MOCK integration
aws apigateway put-integration \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --type MOCK \
  --region ap-south-1

# 4. Set response headers
aws apigateway put-method-response \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters method.response.header.Access-Control-Allow-Methods=false,method.response.header.Access-Control-Allow-Headers=false,method.response.header.Access-Control-Allow-Origin=false \
  --region ap-south-1

aws apigateway put-integration-response \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters method.response.header.Access-Control-Allow-Methods="'OPTIONS,POST'",method.response.header.Access-Control-Allow-Headers="'Content-Type,X-Api-Key'",method.response.header.Access-Control-Allow-Origin="'https://omdeshpande09012005.github.io'" \
  --region ap-south-1

# 5. Redeploy API
aws apigateway create-deployment \
  --rest-api-id ${API_ID} \
  --stage-name Prod \
  --region ap-south-1
```

### 5. Test the API

```bash
API_URL="https://YOUR_API_ID.execute-api.ap-south-1.amazonaws.com/Prod"

# Test with curl
curl -X POST "${API_URL}/submit" \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-us",
    "name": "Test User",
    "email": "test@example.com",
    "message": "This is a test",
    "page": "https://omdeshpande09012005.github.io/contact"
  }' -i
```

### 6. Query DynamoDB

```bash
# Query submissions from "contact-us" form
aws dynamodb query \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  --key-condition-expression "pk = :p AND begins_with(sk, :s)" \
  --expression-attribute-values \
    ':p={"S":"FORM#contact-us"}' \
    ':s={"S":"SUBMIT#"}' \
  --output json | jq '.Items[] | {id, form_id, name, email, ts}'
```

### 7. Verify SES Identities

```bash
# List all verified identities
aws ses list-identities \
  --region ap-south-1 \
  --output table

# Verify a new email (if needed)
aws ses verify-email-identity \
  --email-address aayush.das@mitwpu.edu.in \
  --region ap-south-1

# Get verification attributes
aws ses get-identity-verification-attributes \
  --identities omdeshpande123456789@gmail.com \
  --region ap-south-1
```

---

## Troubleshooting

### Issue: API returns 403 Forbidden

**Cause:** Lambda doesn't have permission to call DynamoDB or SES

**Fix:** Re-run STEP 3 (IAM permissions) to ensure policy is attached

```bash
aws iam get-role-policy \
  --role-name formbridge-deploy \
  --policy-name formbridge-policy \
  --region ap-south-1
```

### Issue: SES Email Not Received

**Cause:** Sender email not verified in SES

**Fix:** Verify email address

```bash
aws ses verify-email-identity \
  --email-address ${SES_SENDER} \
  --region ap-south-1

# Wait ~5 minutes for verification link in email
# Click link to verify
```

### Issue: CORS Error in Browser

**Cause:** API Gateway CORS not configured correctly

**Fix:** Re-run STEP 4 (CORS configuration)

```bash
# Verify OPTIONS method
aws apigateway get-method \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --region ap-south-1
```

### Issue: DynamoDB Table Already Exists

**Cause:** Table created in previous run

**Fix:** Script will detect and skip creation. If you want to recreate:

```bash
# Delete table (WARNING: deletes all data)
aws dynamodb delete-table \
  --table-name contact-form-submissions \
  --region ap-south-1

# Wait for deletion
aws dynamodb wait table-not-exists \
  --table-name contact-form-submissions \
  --region ap-south-1

# Re-run script
./deploy.sh
```

---

## Monitoring & Logs

### View Lambda Logs

```bash
# Live tail
aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1

# Last 10 log entries
aws logs tail /aws/lambda/contactFormProcessor --max-items 10 --region ap-south-1
```

### View SES Sending Statistics

```bash
aws ses get-send-statistics --region ap-south-1
```

### Monitor DynamoDB Metrics

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=contact-form-submissions \
  --start-time 2025-11-05T00:00:00Z \
  --end-time 2025-11-06T00:00:00Z \
  --period 3600 \
  --statistics Sum \
  --region ap-south-1
```

---

## Post-Deployment Checklist

- [ ] DynamoDB table created and ACTIVE
- [ ] Lambda environment variables set (DDB_TABLE, SES_SENDER, SES_RECIPIENTS)
- [ ] IAM policy attached to Lambda role
- [ ] API Gateway CORS configured for /submit
- [ ] API Gateway redeployed
- [ ] Smoke test passed (curl returned 200 + submission ID)
- [ ] DynamoDB record exists for test submission
- [ ] All SES identities verified (except aayush.das@mitwpu.edu.in if unverified)
- [ ] SES in production mode (not sandbox)
- [ ] Frontend updated to send POST requests to API endpoint

---

## Next Steps

1. Update your frontend (`index.html`) to submit forms to:
   ```
   https://YOUR_API_ID.execute-api.ap-south-1.amazonaws.com/Prod/submit
   ```

2. Test end-to-end from frontend

3. Monitor CloudWatch logs for errors

4. Verify email delivery in inboxes

5. Check DynamoDB for stored submissions

---

## Reference Links

- [AWS CLI DynamoDB Docs](https://docs.aws.amazon.com/cli/latest/reference/dynamodb/index.html)
- [AWS CLI Lambda Docs](https://docs.aws.amazon.com/cli/latest/reference/lambda/index.html)
- [AWS CLI SES Docs](https://docs.aws.amazon.com/cli/latest/reference/ses/index.html)
- [API Gateway CORS](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)
