# FormBridge Backend - Deployment Guide

## Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with credentials configured
   ```bash
   aws configure
   ```

2. **AWS CLI v2** installed
   ```bash
   aws --version
   ```

3. **SAM CLI** installed
   ```bash
   sam --version
   ```

4. **Python 3.11+** installed
   ```bash
   python --version
   ```

5. **Verified SES Email** (for sending notifications)
   ```bash
   aws ses verify-email-identity --email-address your-email@example.com --region us-east-1
   ```

---

## Deployment Steps

### Step 1: Navigate to Backend Directory
```bash
cd w:\PROJECTS\formbridge\backend
```

### Step 2: Build the SAM Application
```bash
sam build
```

This will:
- Download dependencies from requirements.txt
- Package your Lambda function
- Prepare everything for deployment

**Expected Output:**
```
Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml
```

### Step 3: Deploy Using SAM (First Time - Interactive)

```bash
sam deploy --guided
```

**You'll be prompted for:**

1. **Stack name** (e.g., `formbridge-stack`)
   - Enter: `formbridge-stack`

2. **AWS Region** (e.g., `us-east-1`)
   - Enter: `us-east-1`

3. **Parameter: DDBTableName** (DynamoDB table name)
   - Enter: `contact-form-submissions`

4. **Parameter: SesSender** (Verified email that sends notifications)
   - Enter: Your verified SES email (e.g., `admin@yourdomain.com`)

5. **Parameter: SesRecipients** (Where to send notifications)
   - Enter: Your email (e.g., `you@gmail.com`)

6. **Parameter: FrontendOrigin** (Your portfolio URL)
   - Enter: `https://omdeshpande09012005.github.io`

7. **Confirm changes before deploy** (SAM will show summary)
   - Type: `y` and press Enter

8. **Allow IAM role creation**
   - Type: `y` and press Enter

**Expected Output:**
```
Successfully created/updated stack - formbridge-stack in us-east-1
CloudFormation outputs:
┌────────────────────────────────────────────────────────────────┐
│ Key                      │ Value                               │
├────────────────────────────────────────────────────────────────┤
│ AnalyticsUrl             │ https://abc123.execute-api.us-e...  │
│ ApiUrl                   │ https://abc123.execute-api.us-e...  │
│ FunctionArn              │ arn:aws:lambda:us-east-1:123456...  │
│ DynamoDBTable            │ contact-form-submissions            │
└────────────────────────────────────────────────────────────────┘
```

### Step 4: Save Configuration (samconfig.toml)

The `samconfig.toml` file is automatically created and will have your settings.

For future deployments, you can simply run:
```bash
sam deploy
```

---

## Post-Deployment

### 1. Capture Important Values

After deployment, save these values:

```bash
# Get API ID
API_ID=$(aws apigateway get-rest-apis --query "items[0].id" --output text --region us-east-1)
echo "API ID: $API_ID"

# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function --function-name contactFormProcessor --query 'Configuration.FunctionArn' --output text --region us-east-1)
echo "Lambda ARN: $LAMBDA_ARN"

# Get DynamoDB Table
TABLE_NAME="contact-form-submissions"
echo "DynamoDB Table: $TABLE_NAME"
```

### 2. Set Up API Key (for /analytics endpoint)

```bash
# Create usage plan
USAGE_PLAN_ID=$(aws apigateway create-usage-plan \
  --name "analytics-usage-plan" \
  --api-stages "{apiId=${API_ID},stage=Prod}" \
  --region us-east-1 \
  --query 'id' \
  --output text)
echo "Usage Plan ID: $USAGE_PLAN_ID"

# Create API key
API_KEY=$(aws apigateway create-api-key \
  --name "analytics-key" \
  --enabled \
  --region us-east-1 \
  --query 'id' \
  --output text)
echo "API Key ID: $API_KEY"

# Get the actual key value
API_KEY_VALUE=$(aws apigateway get-api-key \
  --api-key "$API_KEY" \
  --include-value \
  --region us-east-1 \
  --query 'value' \
  --output text)
echo "API Key Value: $API_KEY_VALUE"

# Associate API key with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id "$USAGE_PLAN_ID" \
  --key-id "$API_KEY" \
  --key-type API_KEY \
  --region us-east-1
```

### 3. Configure /analytics Endpoint with API Key Requirement

The `add_analytics_endpoint.sh` script can automate this, or do it manually:

```bash
# Get /analytics resource ID
ANALYTICS_RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region us-east-1 \
  --query "items[?path=='/analytics'].id" \
  --output text)

# Enable API key requirement for POST method
aws apigateway update-method \
  --rest-api-id "$API_ID" \
  --resource-id "$ANALYTICS_RESOURCE_ID" \
  --http-method POST \
  --patch-operations "op=replace,path=/apiKeyRequired,value=true" \
  --region us-east-1

# Create deployment
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name Prod \
  --region us-east-1
```

### 4. Verify Deployment

Test the `/submit` endpoint:
```bash
curl -X POST https://ABC123.execute-api.us-east-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "portfolio-contact",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message",
    "page": "https://omdeshpande09012005.github.io"
  }'
```

Test the `/analytics` endpoint (should fail without API key):
```bash
curl -i -X POST https://ABC123.execute-api.us-east-1.amazonaws.com/Prod/analytics \
  -H "Content-Type: application/json" \
  -d '{"form_id": "portfolio-contact"}'
```

Test with API key (should succeed):
```bash
curl -X POST https://ABC123.execute-api.us-east-1.amazonaws.com/Prod/analytics \
  -H "X-Api-Key: YOUR_API_KEY_VALUE" \
  -H "Content-Type: application/json" \
  -d '{"form_id": "portfolio-contact"}'
```

---

## Troubleshooting

### Issue: "sam build" fails with "Command not found"
**Solution:** Install SAM CLI
```bash
pip install aws-sam-cli
```

### Issue: "Unable to locate credentials"
**Solution:** Configure AWS credentials
```bash
aws configure
```
Then enter your AWS Access Key ID and Secret Access Key.

### Issue: "Email address is not verified in SES"
**Solution:** Verify your email address
```bash
aws ses verify-email-identity --email-address your-email@example.com --region us-east-1
```

### Issue: "Rate exceeded" during deployment
**Solution:** Wait a few moments and try again
```bash
sam deploy
```

### Issue: Stack creation failed
**Solution:** Check CloudFormation events
```bash
aws cloudformation describe-stack-events \
  --stack-name formbridge-stack \
  --region us-east-1 | jq '.StackEvents[] | {LogicalResourceId, ResourceStatus, ResourceStatusReason}'
```

---

## Updating Deployment

If you make changes to your code or configuration:

### 1. Update Lambda Code
```bash
# Edit contact_form_lambda.py
nano contact_form_lambda.py

# Rebuild
sam build

# Deploy
sam deploy
```

### 2. Update Parameters
```bash
# Deploy with new parameters
sam deploy --parameter-overrides \
  SesSender=newemail@example.com \
  SesRecipients=newrecipient@example.com
```

### 3. Delete Stack (careful!)
```bash
aws cloudformation delete-stack \
  --stack-name formbridge-stack \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name formbridge-stack \
  --region us-east-1
```

---

## Monitoring

### View Lambda Logs
```bash
aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1
```

### View Recent Errors
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/contactFormProcessor \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### Check DynamoDB Items
```bash
aws dynamodb scan \
  --table-name contact-form-submissions \
  --max-items 10 \
  --region us-east-1 | jq '.Items'
```

### Monitor API Usage
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=FormApi \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region us-east-1
```

---

## Cost Estimation

For typical portfolio usage:

- **DynamoDB:** $0-1/month (on-demand pricing, minimal usage)
- **Lambda:** $0-2/month (free tier: 1M invocations)
- **SES:** $0-1/month (free tier: 62k outbound emails)
- **API Gateway:** $1-2/month (free tier: 1M requests)

**Total: ~$2-5/month for a portfolio with light traffic**

---

## Next Steps

1. **Update Frontend:** Add the API endpoint to your portfolio contact form
2. **Configure CORS:** Already set to your portfolio domain
3. **Set Up CI/CD:** See `.github/workflows/` for GitHub Actions setup
4. **Monitor:** Set up CloudWatch alarms for errors
5. **Document:** Keep track of your API credentials securely

---

For more details, see:
- `DEPLOYMENT_GUIDE_FULL.md` - Comprehensive deployment guide
- `TESTING_GUIDE.md` - Test cases and verification
- `API_DOCUMENTATION.md` - API reference

