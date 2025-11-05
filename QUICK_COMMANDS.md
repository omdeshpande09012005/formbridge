# FormBridge Implementation - Quick Command Reference

Copy-paste ready commands for each task.

---

## TASK 1: Deploy Lambda & DynamoDB

```bash
# Navigate to backend
cd w:\PROJECTS\formbridge\backend

# Build
sam build

# Deploy (interactive - fill in prompts)
sam deploy --guided
```

**When prompted:**
- Stack name: `formbridge-stack`
- Region: `us-east-1`
- DDBTableName: `contact-form-submissions`
- SesSender: Your verified SES email
- SesRecipients: Email to receive notifications
- FrontendOrigin: `https://omdeshpande09012005.github.io`

---

## TASK 2: Verify SES

```bash
# Check SES status
aws ses get-account-sending-enabled --region us-east-1

# Verify email (if needed)
aws ses verify-email-identity --email-address your-email@example.com --region us-east-1
```

---

## TASK 3: Set Up API Key

Run these commands in order:

```bash
# 1. Get API ID
API_ID=$(aws apigateway get-rest-apis \
  --region us-east-1 \
  --query "items[?name=='FormApi'].id" \
  --output text)

echo "API ID: $API_ID"

# 2. Create usage plan
USAGE_PLAN_ID=$(aws apigateway create-usage-plan \
  --name "formbridge-usage-plan" \
  --api-stages "apiId=${API_ID},stage=Prod" \
  --region us-east-1 \
  --query 'id' \
  --output text)

echo "Usage Plan ID: $USAGE_PLAN_ID"

# 3. Create API key
API_KEY_ID=$(aws apigateway create-api-key \
  --name "formbridge-analytics-key" \
  --enabled \
  --region us-east-1 \
  --query 'id' \
  --output text)

echo "API Key ID: $API_KEY_ID"

# 4. Get API key value (SAVE THIS!)
API_KEY_VALUE=$(aws apigateway get-api-key \
  --api-key "$API_KEY_ID" \
  --include-value \
  --region us-east-1 \
  --query 'value' \
  --output text)

echo "API Key Value: $API_KEY_VALUE"

# 5. Associate key with usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id "$USAGE_PLAN_ID" \
  --key-id "$API_KEY_ID" \
  --key-type API_KEY \
  --region us-east-1

# 6. Get /analytics resource ID
ANALYTICS_RESOURCE=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region us-east-1 \
  --query "items[?path=='/analytics'].id" \
  --output text)

echo "Analytics Resource: $ANALYTICS_RESOURCE"

# 7. Enable API key requirement
aws apigateway update-method \
  --rest-api-id "$API_ID" \
  --resource-id "$ANALYTICS_RESOURCE" \
  --http-method POST \
  --patch-operations "op=replace,path=/apiKeyRequired,value=true" \
  --region us-east-1

# 8. Deploy
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name Prod \
  --region us-east-1
```

---

## TASK 4: Test Endpoints

First, get your endpoints from CloudFormation:

```bash
# Get all outputs
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

Then test:

```bash
# Test /submit
curl -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/submit" \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "portfolio-contact",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message"
  }'

# Test /analytics without key (should fail)
curl -i -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/analytics" \
  -H "Content-Type: application/json" \
  -d '{"form_id": "portfolio-contact"}'

# Test /analytics with key (should work)
curl -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/analytics" \
  -H "X-Api-Key: YOUR_API_KEY_VALUE" \
  -H "Content-Type: application/json" \
  -d '{"form_id": "portfolio-contact"}'
```

---

## TASK 5: Monitor

```bash
# View Lambda logs (live)
aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1

# View recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/contactFormProcessor \
  --filter-pattern "ERROR" \
  --region us-east-1

# Check DynamoDB submissions
aws dynamodb scan \
  --table-name contact-form-submissions \
  --max-items 10 \
  --region us-east-1 \
  --query 'Items' | jq '.'

# Check API metrics
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

## Troubleshooting Commands

```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'Stacks[0].[StackStatus,StackStatusReason]'

# Check CloudFormation events (if deployment failed)
aws cloudformation describe-stack-events \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceStatusReason]' \
  --output table

# Check Lambda configuration
aws lambda get-function-configuration \
  --function-name contactFormProcessor \
  --region us-east-1

# Check DynamoDB table
aws dynamodb describe-table \
  --table-name contact-form-submissions \
  --region us-east-1 \
  --query 'Table.[TableStatus,BillingModeSummary,StreamSpecification.StreamViewType]'

# Check SES verified identities
aws ses list-verified-email-addresses --region us-east-1

# Check API Gateway resources
aws apigateway get-resources \
  --rest-api-id YOUR_API_ID \
  --region us-east-1 \
  --query 'items[*].[path,id]' \
  --output table

# Check API key details
aws apigateway get-api-key \
  --api-key YOUR_API_KEY_ID \
  --include-value \
  --region us-east-1

# Check usage plan details
aws apigateway get-usage-plan \
  --usage-plan-id YOUR_USAGE_PLAN_ID \
  --region us-east-1
```

---

## Configuration File Lookup

After running TASK 1, find these values:

```bash
# Get Submit URL
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text

# Get Analytics URL
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`AnalyticsUrl`].OutputValue' \
  --output text

# Get Lambda ARN
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`FunctionArn`].OutputValue' \
  --output text

# Get DynamoDB Table Name
aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`DynamoDBTable`].OutputValue' \
  --output text
```

---

## Update Frontend

Navigate to your React component and update:

```javascript
const SUBMIT_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/submit";

// In your form handler:
const response = await fetch(SUBMIT_URL, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    form_id: 'portfolio-contact',
    name: formData.name,
    email: formData.email,
    message: formData.message,
    page: window.location.href
  })
});

const data = await response.json();
if (response.ok) {
  // Success - show message
} else {
  // Error - show data.error
}
```

---

## Useful Aliases (Optional)

Add to your `.bashrc` or `.zshrc`:

```bash
alias formbridge-logs='aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1'
alias formbridge-status='aws cloudformation describe-stacks --stack-name formbridge-stack --region us-east-1 --query "Stacks[0].StackStatus"'
alias formbridge-outputs='aws cloudformation describe-stacks --stack-name formbridge-stack --region us-east-1 --query "Stacks[0].Outputs" --output table'
alias formbridge-items='aws dynamodb scan --table-name contact-form-submissions --max-items 10 --region us-east-1 --query "Items"'
```

Then use:
```bash
formbridge-logs
formbridge-status
formbridge-outputs
formbridge-items
```

