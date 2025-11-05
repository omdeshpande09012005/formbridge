# API Gateway 403 Fix - Quick Reference

## One-Liner Quick Fixes

### Audit (No Changes)
```bash
bash scripts/diagnose-api-403.sh
```

### Apply All Fixes (Permissive Policy + Logging)
```bash
bash scripts/diagnose-api-403.sh --fix-permissive
```

---

## Manual AWS CLI Commands

### Get API Info
```bash
# List APIs
aws apigateway get-rest-apis --region ap-south-1

# Get stage
aws apigateway get-stage --rest-api-id 12mse3zde5 --stage-name Prod --region ap-south-1

# Get resources
aws apigateway get-resources --rest-api-id 12mse3zde5 --region ap-south-1
```

### Check API Key Setup
```bash
# List usage plans
aws apigateway get-usage-plans --region ap-south-1

# Get plan details (keys, stages)
aws apigateway get-usage-plan --usage-plan-id <PLAN_ID> --region ap-south-1

# Get plan keys
aws apigateway get-usage-plan-keys --usage-plan-id <PLAN_ID> --region ap-south-1

# Get API key value
aws apigateway get-api-key --api-key <KEY_ID> --include-value --region ap-south-1
```

### Check Method Configuration
```bash
# Get /submit resource ID
RESOURCE_ID=$(aws apigateway get-resources --rest-api-id 12mse3zde5 --region ap-south-1 \
  | jq -r '.items[] | select(.path == "/submit") | .id')

# Get POST method
aws apigateway get-method \
  --rest-api-id 12mse3zde5 \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --region ap-south-1
```

### Enable API Key Requirement
```bash
RESOURCE_ID=$(aws apigateway get-resources --rest-api-id 12mse3zde5 --region ap-south-1 \
  | jq -r '.items[] | select(.path == "/submit") | .id')

aws apigateway put-method \
  --rest-api-id 12mse3zde5 \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --api-key-required \
  --region ap-south-1
```

### Check Resource Policy
```bash
aws apigateway get-resource-policy --rest-api-id 12mse3zde5 --region ap-south-1
```

### Apply Permissive Policy (Testing Only)
```bash
POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "execute-api:Invoke",
    "Resource": "arn:aws:execute-api:ap-south-1:*:12mse3zde5/*"
  }]
}'

aws apigateway put-resource-policy \
  --rest-api-id 12mse3zde5 \
  --policy "$POLICY" \
  --region ap-south-1
```

### Test Invoke (Bypass Network Policies)
```bash
RESOURCE_ID=$(aws apigateway get-resources --rest-api-id 12mse3zde5 --region ap-south-1 \
  | jq -r '.items[] | select(.path == "/submit") | .id')

aws apigateway test-invoke-method \
  --rest-api-id 12mse3zde5 \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --body '{"form_id":"test","message":"hello"}' \
  --region ap-south-1
```

### Deploy API
```bash
aws apigateway create-deployment \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --region ap-south-1
```

### Enable Execution Logging
```bash
aws apigateway update-stage \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --patch-operations \
    op=replace,path=/*/*/logging/loglevel,value=INFO \
    op=replace,path=/*/*/logging/datatraceenabled,value=true \
  --region ap-south-1
```

---

## cURL Testing

### Without API Key (Should be 403 if key required)
```bash
curl -i -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"hello"}'
```

### With API Key (Should be 200)
```bash
curl -i -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{"form_id":"test","message":"hello"}'
```

---

## CloudWatch Logs

### View Logs in Real-Time
```bash
aws logs tail /aws/apigateway/12mse3zde5/Prod --follow --region ap-south-1
```

### Search for 403 Errors
```bash
aws logs start-query \
  --log-group-name /aws/apigateway/12mse3zde5/Prod \
  --start-time $(($(date +%s) - 3600)) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /403|Forbidden|Access denied/ | sort @timestamp desc' \
  --region ap-south-1
```

---

## PowerShell Equivalents

### Run Diagnostic (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\diagnose-api-403.ps1
```

### Get API Key (PowerShell)
```powershell
$key = aws apigateway get-api-key --api-key <KEY_ID> --include-value --region ap-south-1 | ConvertFrom-Json
$key.value
```

### cURL from PowerShell
```powershell
$headers = @{
    "Content-Type" = "application/json"
    "X-Api-Key" = "YOUR_API_KEY"
}

$body = @{
    form_id = "test"
    message = "hello"
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" `
  -Method POST `
  -Headers $headers `
  -Body $body
```

---

## Decision Tree

```
403 Forbidden Response?
│
├─ Run diagnostic script
│   bash scripts/diagnose-api-403.sh
│
├─ Test-invoke returns 200?
│   ├─ YES → Resource policy is blocking (apply permissive policy)
│   │   bash scripts/diagnose-api-403.sh --fix-permissive
│   │
│   └─ NO → Lambda integration or method config issue
│       ├─ Check CloudWatch logs
│       ├─ Enable execution logging if not already
│       └─ Verify Lambda role has API Gateway permissions
│
├─ External curl returns 200 with API key?
│   ├─ YES → Working! Continue to k6 tests
│   │
│   └─ NO → Check:
│       ├─ API key is in X-Api-Key header
│       ├─ API key is bound to usage plan
│       ├─ Stage is bound to usage plan
│       └─ Check CloudWatch logs for specific error
```

---

## Environment Setup for k6 Testing

Once 403 is fixed:

```bash
# Export configuration
export BASE_URL="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod"
export FORM_ID="my-portfolio"
export HMAC_ENABLED="false"

# Get API key
API_KEY=$(aws apigateway get-api-key --api-key <KEY_ID> --include-value --region ap-south-1 | jq -r '.value')
export API_KEY="$API_KEY"

# Test with k6
k6 run loadtest/submit_smoke.js
```

---

## Common Errors & Solutions

| Error | Solution |
|-------|----------|
| `ResourceNotFoundException` | API ID or stage name incorrect |
| `UnauthorizedException` | AWS credentials invalid or missing permissions |
| `BadRequestException: apiKeyRequired must be true/false` | Use correct boolean format |
| `ConflictException` | API needs to be redeployed after changes |
| 403 even with key | Check resource policy, CloudWatch logs, usage plan binding |

---

## Next Steps

1. ✓ Run diagnostic: `bash scripts/diagnose-api-403.sh`
2. ✓ Review findings and errors
3. ✓ Apply fixes if needed: `bash scripts/diagnose-api-403.sh --fix-permissive`
4. ✓ Test with curl commands from output
5. ✓ Monitor CloudWatch: `aws logs tail /aws/apigateway/12mse3zde5/Prod --follow`
6. ✓ Run k6 tests: `k6 run loadtest/submit_smoke.js`

---

**Last Updated**: 2025-11-05  
**Tested On**: AWS API Gateway (REST API)  
**Regions**: All (use --region parameter)
