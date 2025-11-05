# API Gateway Script - Usage Examples

## Example 1: Personal Portfolio Website

### Your Setup
- Website: `https://omdeshpande09012005.github.io`
- Lambda: `contactFormProcessor`
- API: Already created in `us-east-1`
- Stage: `prod`

### Configuration
```bash
#!/bin/bash

# Edit add_analytics_endpoint.sh and set:
API_ID="a1b2c3d4e5"
REGION="us-east-1"
LAMBDA_NAME="contactFormProcessor"
STAGE_NAME="prod"
USAGE_PLAN_NAME="portfolio-usage-plan"
API_KEY_NAME="portfolio-api-key"
FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
```

### Find API_ID
```bash
aws apigateway get-rest-apis --region us-east-1 | jq '.items[] | select(.name=="ContactFormAPI") | .id'
# Output: a1b2c3d4e5
```

### Run
```bash
./add_analytics_endpoint.sh
```

### Test
```bash
# Test without API key (fails)
curl -i -X POST "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/prod/analytics" \
  -H "Content-Type: application/json" \
  -d '{"form_id":"contact-form"}'

# Test with API key (succeeds)
curl -i -X POST "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/prod/analytics" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY_HERE" \
  -d '{"form_id":"contact-form"}'
```

### Frontend Integration
```javascript
// Send analytics query from frontend
async function getFormAnalytics(formId) {
  const response = await fetch(
    'https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/prod/analytics',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Api-Key': 'YOUR_API_KEY_HERE'
      },
      body: JSON.stringify({ form_id: formId })
    }
  );
  
  const data = await response.json();
  console.log(`Total submissions: ${data.total_submissions}`);
  console.log(`Last 7 days: ${JSON.stringify(data.last_7_days)}`);
  return data;
}
```

---

## Example 2: Multi-Stage SaaS Application

### Your Setup
- Dev, Staging, Prod stages
- Different API keys for each
- Different CORS origins
- Same Lambda with multi-tenant code

### Dev Stage Setup
```bash
API_ID="dev123abc456"
REGION="us-west-2"
LAMBDA_NAME="contactFormProcessor"
STAGE_NAME="dev"
USAGE_PLAN_NAME="saas-dev-plan"
API_KEY_NAME="saas-dev-key"
FRONTEND_ORIGIN="http://localhost:3000"
```

### Production Stage Setup
```bash
API_ID="prod789xyz123"  # Note: Different API ID!
REGION="us-west-2"
LAMBDA_NAME="contactFormProcessor-prod"
STAGE_NAME="prod"
USAGE_PLAN_NAME="saas-prod-plan"
API_KEY_NAME="saas-prod-key"
FRONTEND_ORIGIN="https://app.company.com"
```

### Deployment Script
```bash
#!/bin/bash

# Create a wrapper that runs for multiple environments
run_for_environment() {
    local ENV=$1
    local API_ID=$2
    local LAMBDA=$3
    local ORIGIN=$4
    
    echo "Setting up /analytics for $ENV environment..."
    
    # Edit script
    sed -i "s|API_ID=\".*\"|API_ID=\"$API_ID\"|g" add_analytics_endpoint.sh
    sed -i "s|LAMBDA_NAME=\".*\"|LAMBDA_NAME=\"$LAMBDA\"|g" add_analytics_endpoint.sh
    sed -i "s|FRONTEND_ORIGIN=\".*\"|FRONTEND_ORIGIN=\"$ORIGIN\"|g" add_analytics_endpoint.sh
    
    # Run
    ./add_analytics_endpoint.sh
}

# Run for each environment
run_for_environment "dev" "dev123abc456" "contactFormProcessor" "http://localhost:3000"
run_for_environment "prod" "prod789xyz123" "contactFormProcessor-prod" "https://app.company.com"
```

---

## Example 3: Automated CI/CD Pipeline (GitHub Actions)

### GitHub Actions Workflow
```yaml
name: Deploy Analytics Endpoint

on:
  push:
    branches: [main]
    paths:
      - '.github/workflows/deploy-analytics.yml'
      - 'scripts/add_analytics_endpoint.sh'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: us-west-2
      
      - name: Install jq
        run: sudo apt-get install -y jq
      
      - name: Deploy to Dev
        env:
          API_ID: ${{ secrets.DEV_API_ID }}
          LAMBDA_NAME: ${{ secrets.DEV_LAMBDA_NAME }}
          FRONTEND_ORIGIN: ${{ secrets.DEV_FRONTEND_ORIGIN }}
        run: |
          sed -i "s|API_ID=\"API_ID\"|API_ID=\"${API_ID}\"|g" scripts/add_analytics_endpoint.sh
          sed -i "s|LAMBDA_NAME=\"LAMBDA_NAME\"|LAMBDA_NAME=\"${LAMBDA_NAME}\"|g" scripts/add_analytics_endpoint.sh
          sed -i "s|FRONTEND_ORIGIN=\"FRONTEND_ORIGIN\"|FRONTEND_ORIGIN=\"${FRONTEND_ORIGIN}\"|g" scripts/add_analytics_endpoint.sh
          chmod +x scripts/add_analytics_endpoint.sh
          ./scripts/add_analytics_endpoint.sh
      
      - name: Deploy to Prod
        if: github.ref == 'refs/heads/main'
        env:
          API_ID: ${{ secrets.PROD_API_ID }}
          LAMBDA_NAME: ${{ secrets.PROD_LAMBDA_NAME }}
          FRONTEND_ORIGIN: ${{ secrets.PROD_FRONTEND_ORIGIN }}
        run: |
          sed -i "s|API_ID=\"API_ID\"|API_ID=\"${API_ID}\"|g" scripts/add_analytics_endpoint.sh
          sed -i "s|LAMBDA_NAME=\"LAMBDA_NAME\"|LAMBDA_NAME=\"${LAMBDA_NAME}\"|g" scripts/add_analytics_endpoint.sh
          sed -i "s|FRONTEND_ORIGIN=\"FRONTEND_ORIGIN\"|FRONTEND_ORIGIN=\"${FRONTEND_ORIGIN}\"|g" scripts/add_analytics_endpoint.sh
          chmod +x scripts/add_analytics_endpoint.sh
          ./scripts/add_analytics_endpoint.sh
```

---

## Example 4: Testing Strategy

### Local Testing
```bash
#!/bin/bash

# Set your test values
API_ID="test123abc"
REGION="us-east-1"
STAGE="dev"
API_KEY="test-key-12345"

BASE_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE}/analytics"

echo "=== Testing Analytics Endpoint ==="
echo ""

# Test 1: No API Key (should fail)
echo "Test 1: Request without API Key (should return 403)"
curl -i -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test-form"}'
echo ""
echo ""

# Test 2: Invalid API Key (should fail)
echo "Test 2: Request with invalid API Key (should return 403)"
curl -i -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: invalid-key" \
  -d '{"form_id":"test-form"}'
echo ""
echo ""

# Test 3: Valid API Key (should succeed)
echo "Test 3: Request with valid API Key (should return 200)"
curl -i -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: ${API_KEY}" \
  -d '{"form_id":"test-form"}'
echo ""
echo ""

# Test 4: CORS Preflight
echo "Test 4: OPTIONS preflight (should return 200 with CORS headers)"
curl -i -X OPTIONS "$BASE_URL" \
  -H "Origin: https://yourdomain.com" \
  -H "Access-Control-Request-Method: POST"
echo ""
echo ""

# Test 5: Invalid JSON (should return 400)
echo "Test 5: Invalid JSON (should return 400)"
curl -i -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: ${API_KEY}" \
  -d 'not-json'
echo ""
```

### Load Testing
```bash
#!/bin/bash

API_ID="test123abc"
REGION="us-east-1"
STAGE="dev"
API_KEY="test-key-12345"
BASE_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE}/analytics"

echo "Running 100 concurrent requests..."

# Send 100 requests in parallel
for i in {1..100}; do
    curl -s -X POST "$BASE_URL" \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: ${API_KEY}" \
      -d "{\"form_id\":\"test-form-$i\"}" > /dev/null &
done

wait
echo "Load test complete!"
```

---

## Example 5: Monitoring and Alerts

### CloudWatch Metrics
```bash
#!/bin/bash

API_ID="your-api-id"
REGION="us-east-1"
STAGE="prod"

# Get API calls in last hour
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=$API_ID Name=Stage,Value=$STAGE \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Lambda Errors
```bash
#!/bin/bash

# Check for errors in last 24 hours
aws logs filter-log-events \
  --log-group-name /aws/lambda/contactFormProcessor \
  --start-time $(($(date +%s)*1000 - 86400000)) \
  --filter-pattern "ERROR" \
  | jq '.events[] | {time: .timestamp, message: .message}'
```

### API Gateway 4xx Errors
```bash
#!/bin/bash

# Get 4xx errors (client errors)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 4XXError \
  --dimensions Name=ApiName,Value=$API_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```

---

## Example 6: Emergency Rollback

### If Something Goes Wrong
```bash
#!/bin/bash

API_ID="your-api-id"
RESOURCE_ID="analytics-resource-id"  # From script output
REGION="us-east-1"

echo "Rolling back /analytics endpoint..."

# Delete the resource
aws apigateway delete-resource \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --region "$REGION"

echo "Resource deleted."

# Redeploy to previous version
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "prod" \
  --region "$REGION"

echo "API redeployed without /analytics endpoint"
```

---

## Example 7: Updating Configuration

### Change CORS Origin
```bash
#!/bin/bash

# Edit script
sed -i 's|FRONTEND_ORIGIN=".*"|FRONTEND_ORIGIN="https://new-domain.com"|' add_analytics_endpoint.sh

# Re-run (idempotent)
./add_analytics_endpoint.sh

# The CORS headers will be updated
```

### Change API Key
```bash
#!/bin/bash

# Create new API key
NEW_KEY=$(aws apigateway create-api-key \
  --name "analytics-key-v2" \
  --enabled \
  --region us-east-1 \
  --query 'id' \
  --output text)

echo "New API Key ID: $NEW_KEY"

# Get the key value
aws apigateway get-api-key \
  --api-key "$NEW_KEY" \
  --include-value \
  --region us-east-1 \
  --query 'value' \
  --output text
```

---

## Troubleshooting Examples

### Test 1: Check if Lambda is Accessible
```bash
aws lambda get-function --function-name contactFormProcessor
```

### Test 2: Invoke Lambda Directly
```bash
aws lambda invoke \
  --function-name contactFormProcessor \
  --payload '{"form_id":"test"}' \
  response.json && cat response.json
```

### Test 3: Check API Configuration
```bash
aws apigateway get-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --region us-east-1
```

### Test 4: View Recent Errors
```bash
aws logs tail /aws/lambda/contactFormProcessor --follow --since 5m
```

---

## Best Practices

### 1. Store API Keys Securely
```bash
# Don't commit keys to git!
echo "API_KEY=your-key-here" > .env
git add .gitignore  # Make sure .env is ignored
```

### 2. Use Separate Keys per Environment
```bash
# Dev key
DEV_KEY="dev-analytics-key-xxx"

# Prod key
PROD_KEY="prod-analytics-key-xxx"

# Rotate keys monthly
aws apigateway create-api-key --name "analytics-key-$(date +%Y%m)-old"
```

### 3. Monitor Access Patterns
```bash
# Log all requests
aws logs filter-log-events \
  --log-group-name /aws/lambda/contactFormProcessor \
  --filter-pattern '"X-Api-Key"'
```

### 4. Test After Updates
```bash
./add_analytics_endpoint.sh && \
  curl -X POST "https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE/analytics" \
    -H "X-Api-Key: $KEY" \
    -H "Content-Type: application/json" \
    -d '{"form_id":"test"}' && \
  echo "✓ Endpoint working!"
```

---

See `API_GATEWAY_SCRIPT_GUIDE.md` for full documentation.

