# API Gateway 403 Diagnostic Scripts

Comprehensive idempotent scripts to diagnose and fix **403 Forbidden** errors on AWS API Gateway REST APIs.

## Quick Start

### Linux/macOS (Bash)

```bash
# Audit-only (no changes)
cd w:/PROJECTS/formbridge
bash scripts/diagnose-api-403.sh

# With fixes (permissive policy, enable logging)
bash scripts/diagnose-api-403.sh --fix-permissive
```

### Windows (PowerShell)

```powershell
cd w:\PROJECTS\formbridge
powershell -ExecutionPolicy Bypass -File scripts\diagnose-api-403.ps1

# With specific parameters
powershell -ExecutionPolicy Bypass -File scripts\diagnose-api-403.ps1 `
  -Region ap-south-1 `
  -ApiId 12mse3zde5 `
  -StageName Prod
```

## Environment Variables / Parameters

Set these before running the scripts:

| Variable | Default | Description |
|----------|---------|-------------|
| `REGION` | `ap-south-1` | AWS region |
| `API_ID` | `12mse3zde5` | API Gateway REST API ID |
| `STAGE_NAME` | `Prod` | Deployment stage name |
| `API_KEY_ID` | `` | (optional) API key ID; auto-detected if empty |
| `USAGE_PLAN_NAME` | `` | (optional) Usage plan name; auto-detected if empty |

**Bash:**
```bash
export REGION=ap-south-1
export API_ID=12mse3zde5
export STAGE_NAME=Prod
bash scripts/diagnose-api-403.sh
```

**PowerShell:**
```powershell
$env:REGION = "ap-south-1"
$env:API_ID = "12mse3zde5"
powershell scripts/diagnose-api-403.ps1
```

## What the Scripts Check

### ✓ Prechecks
- AWS CLI, jq, curl installed
- AWS credentials valid
- Configuration parameters set

### ✓ Step 1: Stage Information
- Verify stage exists
- Print endpoint URL
- Check if execution logging is enabled

### ✓ Step 2: Usage Plans & Binding
- List all usage plans
- Find plan containing this API + stage
- Verify stage is associated

### ✓ Step 3: API Key Value
- Fetch actual API key (with `--include-value`)
- Display key preview for testing

### ✓ Step 4: /submit POST Method
- Verify method exists
- Check if `apiKeyRequired=true`
- Verify authorization type

### ✓ Step 5: Resource Policy
- Fetch REST API resource policy
- Check for DENY statements
- Check for restrictive conditions (IP, VPC, Org)
- Apply permissive policy if `--fix-permissive` is passed

### ✓ Step 6: Test-Invoke-Method
- Bypass network policies with internal AWS call
- Test if Lambda integration is working
- Helps isolate resource policy issues

### ✓ Step 7: cURL Commands
- Generate ready-to-use curl commands
- Test WITH and WITHOUT API key
- Copy-paste ready

### ✓ Step 8: CloudWatch Logs
- Display log group name
- Provide tail and Logs Insights queries
- Help diagnose the root cause

## Output Example

```
═══════════════════════════════════════════════════════════════
PRECHECKS
═══════════════════════════════════════════════════════════════
✓ aws installed
✓ jq installed
✓ curl installed
✓ AWS credentials valid
✓ Configuration valid: API_ID=12mse3zde5, STAGE_NAME=Prod, REGION=ap-south-1

═══════════════════════════════════════════════════════════════
STEP 1: STAGE INFORMATION
═══════════════════════════════════════════════════════════════
ℹ Stage ARN: arn:aws:apigateway:ap-south-1::/restapis/12mse3zde5/stages/Prod
ℹ Endpoint: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com
⚠ Execution logging is OFF (will need to enable for CloudWatch diagnostics)

═══════════════════════════════════════════════════════════════
STEP 2: USAGE PLANS & API KEY BINDING
═══════════════════════════════════════════════════════════════
ℹ Found 1 usage plan(s)
✓ Found usage plan: formbridge-plan (abc123def456) containing API 12mse3zde5
✓ Stage Prod is associated with this plan
ℹ Fetching API keys from plan formbridge-plan...
ℹ Found 1 API key(s) in usage plan
ℹ   - formbridge-key (xyz789)
```

## Common 403 Causes & Solutions

### 1. **Missing X-Api-Key Header**
```bash
# WRONG - No API key
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit

# RIGHT - With API key
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "X-Api-Key: YOUR_API_KEY_VALUE"
```

### 2. **API Key Not Bound to Usage Plan**
The diagnostic will show this in Step 2. Fix:
```bash
# Add key to usage plan
aws apigateway create-usage-plan-key \
  --usage-plan-id <PLAN_ID> \
  --key-id <KEY_ID> \
  --key-type API_KEY \
  --region ap-south-1
```

### 3. **Restrictive Resource Policy**
Run with `--fix-permissive` flag to apply:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "execute-api:Invoke",
    "Resource": "arn:aws:execute-api:REGION:*:API_ID/*"
  }]
}
```

### 4. **apiKeyRequired Not Set**
Run with `--fix-permissive` to enable it:
```bash
aws apigateway put-method \
  --rest-api-id 12mse3zde5 \
  --resource-id <SUBMIT_RESOURCE_ID> \
  --http-method POST \
  --authorization-type NONE \
  --api-key-required \
  --region ap-south-1
```

### 5. **API Not Deployed After Changes**
The script auto-deploys if changes are made. Manual deploy:
```bash
aws apigateway create-deployment \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --region ap-south-1
```

## Testing with k6

Once diagnostics pass and you have your API key:

```bash
# Set environment
export BASE_URL="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod"
export API_KEY="<YOUR_API_KEY_VALUE>"
export FORM_ID="my-portfolio"
export HMAC_ENABLED="false"

# Run smoke test
k6 run loadtest/submit_smoke.js
```

## Idempotency Notes

- **Bash script**: All operations are checked before execution. Running multiple times is safe.
- **Audit-only mode** (default): No destructive changes, only diagnostics.
- **Fix mode** (`--fix-permissive`): Applies permissive policy, enables logging, redeploys.
- **Safe to run repeatedly**: Idempotent operations prevent duplicate changes.

## Requirements

- **AWS CLI** v2+ configured with valid credentials
- **jq** for JSON parsing
- **curl** for manual testing
- **Permissions**: `apigateway:*`, `logs:*` IAM actions

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Missing dependencies, invalid credentials, or resource not found |

## Troubleshooting

### "Stage not found"
Check `API_ID` and `STAGE_NAME` are correct:
```bash
aws apigateway get-rest-apis --region ap-south-1 | jq '.items[].name'
aws apigateway get-stages --rest-api-id 12mse3zde5 --region ap-south-1
```

### "AWS credentials not configured"
```bash
aws configure
# or
export AWS_PROFILE=your-profile
```

### Still getting 403 after fixes?
1. Enable execution logging (script will show how)
2. Check CloudWatch logs
3. Verify Lambda integration has correct role
4. Test with `test-invoke-method` (step 6)

## Support

For k6 load test issues after API is fixed, see `loadtest/README.md`.

---

**Created**: 2025-11-05  
**Script Version**: 1.0.0  
**Idempotent**: ✓ Yes
