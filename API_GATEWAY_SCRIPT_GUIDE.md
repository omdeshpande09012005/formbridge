# API Gateway Analytics Endpoint Script Guide

## Overview

This bash script (`add_analytics_endpoint.sh`) automates the setup of a new `/analytics` endpoint in your AWS API Gateway REST API.

**What it does:**
- ✅ Creates `/analytics` resource
- ✅ Sets up POST method with Lambda proxy integration
- ✅ Enables API Key requirement
- ✅ Configures CORS headers
- ✅ Creates OPTIONS method for CORS preflight
- ✅ Deploys to your specified stage
- ✅ Provides test commands

---

## Prerequisites

### Required Tools
```bash
# AWS CLI v2
aws --version

# jq (JSON processor)
brew install jq          # macOS
apt-get install jq       # Ubuntu/Debian
choco install jq         # Windows with Chocolatey
```

### Required AWS Resources
- ✅ REST API with `/submit` endpoint already created
- ✅ Lambda function named per your configuration
- ✅ AWS CLI credentials configured
- ✅ Sufficient IAM permissions for API Gateway and Lambda

### Verify Prerequisites
```bash
# Check AWS CLI
aws sts get-caller-identity

# Check jq
jq --version

# List your REST APIs
aws apigateway get-rest-apis --region us-east-1
```

---

## Configuration

### Step 1: Edit the Script

Open `add_analytics_endpoint.sh` and replace the placeholders (ALL CAPS):

```bash
# Line 36-42
API_ID="YOUR_API_ID_HERE"
REGION="us-east-1"
LAMBDA_NAME="contactFormProcessor"
STAGE_NAME="prod"
USAGE_PLAN_NAME="contact-form-usage-plan"
API_KEY_NAME="contact-form-api-key"
FRONTEND_ORIGIN="https://yourdomain.com"
```

### Finding Your Values

#### API_ID
```bash
aws apigateway get-rest-apis --region us-east-1 --output json | jq '.items[] | {name, id}'
```

#### REGION
Your AWS region (e.g., `us-east-1`, `us-west-2`, `eu-west-1`)

#### LAMBDA_NAME
```bash
aws lambda list-functions --region us-east-1 --output json | jq '.Functions[].FunctionName'
```

#### STAGE_NAME
The deployment stage name (typically `prod`, `dev`, `staging`)

#### FRONTEND_ORIGIN
The domain that will call the API (e.g., `https://omdeshpande09012005.github.io`)

---

## Usage

### Method 1: Run Directly

```bash
# Make executable
chmod +x add_analytics_endpoint.sh

# Run the script
./add_analytics_endpoint.sh
```

### Method 2: Run with bash

```bash
bash add_analytics_endpoint.sh
```

---

## What the Script Does (Step by Step)

### Step 1: Validation
- Checks all placeholders are replaced
- Verifies AWS CLI and jq are installed
- Displays configuration

### Step 2: Find /submit Resource
- Queries API Gateway for `/submit` resource
- Gets parent (root) resource ID

### Step 3: Create /analytics Resource
- Creates `/analytics` resource if it doesn't exist
- Idempotent: skips if already exists

### Step 4: Create POST Method
- Adds POST method to `/analytics`
- Sets up for AWS_PROXY (Lambda) integration

### Step 5: Lambda Integration
- Configures AWS_PROXY integration to your Lambda
- Sets up integration response

### Step 6: Enable API Key Requirement
- Patches POST method to require `X-Api-Key` header

### Step 7: Create OPTIONS Method
- Adds OPTIONS method for CORS preflight requests
- Sets up MOCK integration

### Step 8: Configure CORS Headers
- Sets `Access-Control-Allow-Origin: FRONTEND_ORIGIN`
- Sets `Access-Control-Allow-Methods: OPTIONS,POST`
- Sets `Access-Control-Allow-Headers: Content-Type,X-Api-Key`

### Step 9: Lambda Permissions
- Grants API Gateway permission to invoke Lambda

### Step 10: Deploy API
- Creates deployment to your stage
- Makes the endpoint live

### Step 11: Verify Setup
- Checks for usage plan
- Looks up API key
- Displays setup summary

---

## Test Commands

After the script completes, you'll see test commands. Here's how they work:

### Test 1: Without API Key (Should Fail)

```bash
curl -i -X POST "https://API_ID.execute-api.REGION.amazonaws.com/STAGE_NAME/analytics" \
  -H "Content-Type: application/json" \
  -d '{"form_id":"my-portfolio"}'
```

**Expected Response:**
```
HTTP/1.1 403 Forbidden
{"message":"Forbidden"}
```

### Test 2: With API Key (Should Succeed)

```bash
curl -i -X POST "https://API_ID.execute-api.REGION.amazonaws.com/STAGE_NAME/analytics" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY_VALUE" \
  -d '{"form_id":"my-portfolio"}'
```

**Expected Response:**
```
HTTP/1.1 200 OK
{
  "form_id": "my-portfolio",
  "total_submissions": 42,
  "last_7_days": [
    {"date": "2025-10-29", "count": 5},
    ...
  ],
  "latest_id": "uuid",
  "last_submission_ts": "2025-11-04T18:32:15Z"
}
```

### Test 3: OPTIONS for CORS

```bash
curl -i -X OPTIONS "https://API_ID.execute-api.REGION.amazonaws.com/STAGE_NAME/analytics" \
  -H "Origin: FRONTEND_ORIGIN" \
  -H "Access-Control-Request-Method: POST"
```

**Expected Response:**
```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: FRONTEND_ORIGIN
Access-Control-Allow-Methods: OPTIONS,POST
Access-Control-Allow-Headers: Content-Type,X-Api-Key
```

---

## Troubleshooting

### Issue: "Could not find /submit resource"

**Cause:** The API doesn't have a `/submit` endpoint yet.

**Solution:**
```bash
# Create /submit first
aws apigateway create-resource \
  --rest-api-id API_ID \
  --parent-id ROOT_ID \
  --path-part "submit" \
  --region REGION
```

### Issue: "Placeholder not replaced"

**Cause:** You forgot to replace the ALL CAPS placeholders.

**Solution:**
1. Open the script with a text editor
2. Find each placeholder (ALL CAPS)
3. Replace with actual values
4. Save the file

### Issue: "Could not find root resource"

**Cause:** Corrupted API configuration.

**Solution:**
```bash
# Get resources and look for "/" path
aws apigateway get-resources --rest-api-id API_ID --region REGION
```

### Issue: Lambda returns 502 Bad Gateway

**Cause:** Lambda function not configured to handle API Gateway format.

**Solution:**
- Verify Lambda uses AWS_PROXY (Lambda Proxy) format
- Check Lambda function code handles event properly
- View Lambda logs: `aws logs tail /aws/lambda/LAMBDA_NAME --follow`

### Issue: CORS Error in Browser

**Cause:** `FRONTEND_ORIGIN` doesn't match browser origin exactly.

**Solution:**
```bash
# Re-run script with correct origin
# FRONTEND_ORIGIN must include https:// and exact domain
# Examples:
# https://example.com
# https://omdeshpande09012005.github.io
# https://app.example.com:3000
```

### Issue: API Key Required but No Key Returned

**Cause:** Usage plan not associated with API.

**Solution:**
```bash
# Create usage plan
aws apigateway create-usage-plan \
  --name "contact-form-usage-plan" \
  --region REGION

# Associate API with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id USAGE_PLAN_ID \
  --key-id API_KEY_ID \
  --key-type "API_KEY" \
  --region REGION
```

---

## Idempotency

The script is **idempotent**, meaning you can run it multiple times safely:

- If `/analytics` exists → skips creation
- If POST method exists → skips creation
- If OPTIONS method exists → skips creation
- If Lambda permission exists → skips creation

This is useful for:
- Updating CORS origin
- Re-deploying after changes
- Adding to existing setup

---

## Useful AWS CLI Commands

### View All Endpoints
```bash
aws apigateway get-resources --rest-api-id API_ID --region REGION --output json | jq '.items[] | {path, id}'
```

### View Method Details
```bash
aws apigateway get-method \
  --rest-api-id API_ID \
  --resource-id RESOURCE_ID \
  --http-method POST \
  --region REGION
```

### View Integration
```bash
aws apigateway get-integration \
  --rest-api-id API_ID \
  --resource-id RESOURCE_ID \
  --http-method POST \
  --region REGION
```

### Delete Endpoint
```bash
aws apigateway delete-resource \
  --rest-api-id API_ID \
  --resource-id ANALYTICS_RESOURCE_ID \
  --region REGION
```

### Create API Key
```bash
aws apigateway create-api-key \
  --name "analytics-key" \
  --enabled \
  --region REGION
```

### List API Keys
```bash
aws apigateway get-api-keys --region REGION --output json | jq '.items[] | {name, id}'
```

### Get API Key Value
```bash
aws apigateway get-api-key \
  --api-key KEY_ID \
  --include-value \
  --region REGION \
  | jq '.value'
```

### View Deployment History
```bash
aws apigateway get-deployments --rest-api-id API_ID --region REGION
```

### View Lambda Logs
```bash
# Real-time tail
aws logs tail /aws/lambda/LAMBDA_NAME --follow

# Last hour
aws logs filter-log-events \
  --log-group-name /aws/lambda/LAMBDA_NAME \
  --start-time $(($(date +%s)*1000 - 3600000))
```

---

## Advanced Usage

### Update CORS Origin After Deployment

If you need to change the CORS origin:

1. Edit the script
2. Change `FRONTEND_ORIGIN`
3. Run the script again
4. It will update the headers

### Add Authentication (AWS_IAM)

To use AWS IAM instead of API Keys:

```bash
# Modify the script to use --authorization-type AWS_IAM
# Instead of --authorization-type NONE
aws apigateway put-method \
  --rest-api-id API_ID \
  --resource-id RESOURCE_ID \
  --http-method POST \
  --authorization-type "AWS_IAM" \
  --region REGION
```

### Add Rate Limiting

```bash
# After running script, add throttling to usage plan
aws apigateway update-usage-plan \
  --usage-plan-id USAGE_PLAN_ID \
  --patch-operations \
    op=replace,path=/throttle/burstLimit,value=5000 \
    op=replace,path=/throttle/rateLimit,value=2000 \
  --region REGION
```

---

## Security Best Practices

### 1. Keep API Key Secret
- Store API key in secure storage (secrets manager)
- Never commit to version control
- Rotate keys regularly

### 2. Restrict CORS Origin
- Don't use `*` for `FRONTEND_ORIGIN`
- Be specific with domain names
- Update for each environment

### 3. Use API Keys for Non-Critical APIs
- For production, use AWS IAM or OAuth
- API Keys are for low-security scenarios
- Rotate keys periodically

### 4. Monitor Usage
```bash
aws apigateway get-usage \
  --usage-plan-id USAGE_PLAN_ID \
  --start-date "2025-11-01" \
  --end-date "2025-11-05" \
  --region REGION
```

### 5. Enable Logging
```bash
aws apigateway update-stage \
  --rest-api-id API_ID \
  --stage-name STAGE_NAME \
  --patch-operations \
    op=replace,path/logging/loglevel,value=INFO \
  --region REGION
```

---

## Performance Considerations

### Lambda Timeout
Default: 30 seconds

If your analytics query takes longer:
```bash
aws lambda update-function-configuration \
  --function-name LAMBDA_NAME \
  --timeout 60 \
  --region REGION
```

### API Gateway Timeout
Maximum: 30 seconds for regular, 29 for websocket

### DynamoDB Throttling
If queries are slow, check DynamoDB metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=TABLENAME \
  --start-time 2025-11-01T00:00:00Z \
  --end-time 2025-11-05T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

---

## Complete Workflow Example

```bash
# 1. Edit script with your values
vim add_analytics_endpoint.sh

# 2. Make executable
chmod +x add_analytics_endpoint.sh

# 3. Run the script
./add_analytics_endpoint.sh

# 4. Copy the test command from output
# 5. Test without API key (should fail)
curl -i -X POST "https://API_ID.execute-api.REGION.amazonaws.com/STAGE_NAME/analytics" \
  -H "Content-Type: application/json" \
  -d '{"form_id":"my-portfolio"}'

# 6. Test with API key (should succeed)
curl -i -X POST "https://API_ID.execute-api.REGION.amazonaws.com/STAGE_NAME/analytics" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{"form_id":"my-portfolio"}'

# 7. Check logs
aws logs tail /aws/lambda/contactFormProcessor --follow
```

---

## Need Help?

### Check Logs
```bash
aws logs tail /aws/lambda/LAMBDA_NAME --follow
```

### Verify Configuration
```bash
aws apigateway get-integration \
  --rest-api-id API_ID \
  --resource-id RESOURCE_ID \
  --http-method POST \
  --region REGION
```

### Test Lambda Directly
```bash
aws lambda invoke \
  --function-name LAMBDA_NAME \
  --payload '{"form_id":"test"}' \
  response.json && cat response.json
```

---

**Version:** 1.0  
**Last Updated:** November 2025  
**Status:** ✅ Production Ready

