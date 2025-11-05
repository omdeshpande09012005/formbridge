# secure-api-gateway.sh - Quick Reference

## One-Liner Setup
```bash
# On Linux/macOS/WSL, navigate to formbridge directory and run:
bash secure-api-gateway.sh
```

## What It Does (In Order)

| Step | Action | Validates |
|------|--------|-----------|
| 1 | Checks AWS CLI, jq, credentials | Fails if missing |
| 2 | Finds /submit resource in API Gateway | Exits if not found |
| 3 | Marks POST method as API Key required | Verifies apiKeyRequired=true |
| 4 | Configures CORS via OPTIONS method | Sets 5 CORS headers |
| 5 | Creates/gets Usage Plan with rate limit | Links to Prod stage |
| 6 | Creates/gets API Key | Associates with plan |
| 7 | Deploys API Gateway | Updates Prod stage |
| 8 | Validates with curl | Tests 403/200/CORS |

## Configuration (Edit These in Script)

```bash
REGION="ap-south-1"              # AWS region
ACCOUNT_ID="864572276622"        # AWS account
API_ID="12mse3zde5"              # API Gateway ID
STAGE_NAME="Prod"                # Stage name
SUBMIT_PATH="/submit"            # Resource path to secure
USAGE_PLAN_NAME="FormBridgeBasic" # Rate limit plan name
API_KEY_NAME="FormBridgeDemoKey"  # API Key name
FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
RATE_LIMIT="2"                   # Requests/second
BURST_LIMIT="5"                  # Burst requests
MONTHLY_QUOTA="10000"            # Monthly requests
```

## Expected Output

✅ **Success looks like:**
```
╔════════════════════════════════════════════════════════════════╗
║ STEP 1: Verify Prerequisites
...
✓ AWS CLI found: aws-cli/2.13.0
✓ jq found: jq-1.6
✓ AWS credentials valid. Account: 864572276622
...
✓ Test 1 PASSED: Got 403 Forbidden
✓ Test 2 PASSED: Got 200 OK
✓ Test 3 PASSED: CORS preflight successful
...
╔════════════════════════════════════════════════════════════════╗
║                 DEPLOYMENT SUMMARY
╚════════════════════════════════════════════════════════════════╝
```

❌ **Failure looks like:**
```
✗ AWS CLI not found. Please install it first.
✗ POST method not found on /submit. Create the Lambda integration first.
✗ Resource /submit not found. Create the integration first...
```

## Test Commands (Output by Script)

```bash
# Without API Key → 403 Forbidden
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"hello"}'

# With API Key → 200 OK
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN" \
  -d '{"form_id":"test","message":"hello"}'

# CORS Preflight → 200 OK with headers
curl -X OPTIONS https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Origin: https://omdeshpande09012005.github.io" \
  -H "Access-Control-Request-Method: POST"
```

## Outcome Checklist

- [ ] Step 1: Prerequisites verified (AWS CLI, jq, credentials)
- [ ] Step 2: Resource found (/submit path exists)
- [ ] Step 3: POST marked as API Key required (apiKeyRequired=true)
- [ ] Step 4: CORS configured (OPTIONS method with mock integration)
- [ ] Step 5: Usage Plan created (rate limit: 2 req/sec, quota: 10K/month)
- [ ] Step 6: API Key created (linked to usage plan)
- [ ] Step 7: Deployment successful (new stage revision)
- [ ] Step 8: Tests passed
  - [ ] Test 1: 403 without API Key
  - [ ] Test 2: 200 with API Key
  - [ ] Test 3: 200 CORS preflight

## Error Messages & Fixes

| Message | Fix |
|---------|-----|
| `AWS CLI not found` | Install: `apt-get install awscli` |
| `jq not found` | Install: `apt-get install jq` |
| `POST method not found on /submit` | Create Lambda integration first in console |
| `Resource /submit not found` | Create resource in API Gateway console |
| `Expected 403, got 200` | Usage Plan/key may not be enforced yet |

## Idempotent = Safe to Re-Run

The script is fully idempotent:
- Detects existing resources
- Only creates what's missing
- Safe to run multiple times
- Updates configuration without breaking changes

```bash
# Can run this as many times as needed
bash secure-api-gateway.sh
bash secure-api-gateway.sh  # Second run skips creates, verifies config
bash secure-api-gateway.sh  # Third run same as second
```

## Real FormBridge Example

Using these values for FormBridge:
```bash
REGION="ap-south-1"
ACCOUNT_ID="864572276622"
API_ID="12mse3zde5"
STAGE_NAME="Prod"
SUBMIT_PATH="/submit"
USAGE_PLAN_NAME="FormBridgeBasic"
API_KEY_NAME="FormBridgeDemoKey"
FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
RATE_LIMIT="2"
BURST_LIMIT="5"
MONTHLY_QUOTA="10000"
```

Results in:
- ✅ API Key: `OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN`
- ✅ Usage Plan: 2 req/sec, 5 burst, 10K/month
- ✅ CORS: Allows `https://omdeshpande09012005.github.io`
- ✅ Rate Limiting: Enforced on POST /submit
- ✅ All curl tests passing

## Next Steps After Running Script

1. ✅ Script validates everything
2. 📝 Store API Key in `.env` file (not in git!)
3. 🚀 Update frontend `index.html` with X-Api-Key header
4. 🧪 Test end-to-end from browser
5. 📊 Monitor CloudWatch logs
6. 🔄 Rotate API Key every 90 days

---

**Last Updated**: 2025-11-05  
**Status**: Production Ready  
**FormBridge Integration**: Complete ✅
