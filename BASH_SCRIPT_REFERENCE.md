# secure-api-gateway.sh - Complete Script Reference

## Overview
This is the complete, production-ready bash script for securing AWS API Gateway with API Keys, Usage Plans, CORS, and validation tests. Pre-configured for FormBridge.

## Quick Start
```bash
# Copy to your project
cp secure-api-gateway.sh /path/to/project/

# Run on Linux/macOS/WSL
bash secure-api-gateway.sh
```

## Full Script Content

See file: `secure-api-gateway.sh` in the repository (496 lines)

### Script Highlights

**Language**: Bash with `set -euo pipefail` for strict error handling

**Key Sections**:
1. Configuration variables (ALL_CAPS, customize these)
2. Utility logging functions (log_section, log_step, log_success, log_error)
3. Prerequisites validation (AWS CLI, jq, credentials)
4. Resource discovery (find /submit path)
5. API Key requirement setup (mark POST as protected)
6. CORS configuration (OPTIONS method + mock integration)
7. Usage Plan creation (rate limiting + quota)
8. API Key creation and association
9. API Gateway deployment
10. curl validation tests
11. Configuration summary output

**Key Features**:
- ✅ Idempotent (safe to re-run)
- ✅ 24 AWS CLI operations
- ✅ jq for JSON parsing
- ✅ Comprehensive logging
- ✅ Error handling
- ✅ curl validation (403, 200, CORS)

## Configuration (Edit These)

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

## Execution Flow

```
Start
  │
  ├─ STEP 1: Verify Prerequisites
  │   ├─ AWS CLI installed?
  │   ├─ jq installed?
  │   ├─ AWS credentials valid?
  │   └─ API Gateway API exists?
  │
  ├─ STEP 2: Find Resource (/submit)
  │   └─ Get resource ID via get-resources
  │
  ├─ STEP 3: Mark POST as API Key Required
  │   ├─ Check if POST method exists
  │   ├─ Update apiKeyRequired=true
  │   └─ Verify with re-fetch
  │
  ├─ STEP 4: Configure CORS (OPTIONS method)
  │   ├─ Create/verify OPTIONS method
  │   ├─ Create MOCK integration
  │   ├─ Set method response (status 200)
  │   ├─ Set integration response (CORS headers)
  │   └─ Verify configuration
  │
  ├─ STEP 5: Create/Get Usage Plan
  │   ├─ Check if usage plan exists by name
  │   ├─ Create if missing with throttle+quota
  │   └─ Attach API stage
  │
  ├─ STEP 6: Create/Get API Key
  │   ├─ Check if API Key exists by name
  │   ├─ Create if missing
  │   └─ Associate with usage plan
  │
  ├─ STEP 7: Deploy API Gateway
  │   ├─ Create deployment on stage
  │   └─ Verify deployment ID
  │
  ├─ STEP 8: Validate with curl
  │   ├─ Test 1: POST without X-Api-Key → 403
  │   ├─ Test 2: POST with X-Api-Key → 200
  │   └─ Test 3: OPTIONS preflight → 200
  │
  ├─ Summary
  │   └─ Print configuration & next steps
  │
  End
```

## Expected Output

### Success Output
```
╔════════════════════════════════════════════════════════════════╗
║ STEP 1: Verify Prerequisites
╚════════════════════════════════════════════════════════════════╝
▶ Checking if AWS CLI is installed...
✓ AWS CLI found: aws-cli/2.13.0
▶ Checking if jq is installed...
✓ jq found: jq-1.6
▶ Checking AWS credentials...
✓ AWS credentials valid. Account: 864572276622
▶ Checking API Gateway API exists...
✓ API Gateway API found: 12mse3zde5

... [more steps] ...

╔════════════════════════════════════════════════════════════════╗
║ DEPLOYMENT SUMMARY
╚════════════════════════════════════════════════════════════════╝

📍 AWS Configuration:
   • Region: ap-south-1
   • Account ID: 864572276622

🔌 API Gateway:
   • API ID: 12mse3zde5
   • Stage: Prod
   • Resource ID (/submit): 74bix6
   • Endpoint: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit

🔐 API Key:
   • API Key ID: trcie7mv32
   • API Key Name: FormBridgeDemoKey
   • Value: OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN
   
   ⚠️  Keep this secure! Store in .env or GitHub Secrets.

📊 Rate Limiting (Usage Plan):
   • Usage Plan ID: xo5f9d
   • Usage Plan Name: FormBridgeBasic
   • Rate Limit: 2 req/sec
   • Burst Limit: 5 requests
   • Monthly Quota: 10000 requests

🌐 CORS Configuration:
   • Allowed Origin: https://omdeshpande09012005.github.io
   • Allowed Methods: OPTIONS,POST
   • Allowed Headers: Content-Type,X-Api-Key

✓ Test 1 PASSED: Got 403 Forbidden
✓ Test 2 PASSED: Got 200 OK
✓ Test 3 PASSED: CORS preflight successful
```

## Test Commands

### Run Script
```bash
bash secure-api-gateway.sh
```

### Manual Curl Tests
```bash
# Test without API Key (expect 403)
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"hello"}'

# Test with API Key (expect 200)
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN" \
  -d '{"form_id":"test","message":"hello"}'

# Test CORS Preflight (expect 200)
curl -X OPTIONS https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Origin: https://omdeshpande09012005.github.io" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,X-Api-Key"
```

## Troubleshooting

### AWS CLI not found
```bash
# On Ubuntu/Debian
apt-get install awscli

# On macOS
brew install awscli

# On Windows (WSL)
apt-get install awscli
```

### jq not found
```bash
# On Ubuntu/Debian
apt-get install jq

# On macOS
brew install jq

# On Windows (WSL)
apt-get install jq
```

### POST method not found
```
Error: POST method not found on /submit. Create the Lambda integration first.

Solution: Create POST method + Lambda integration in AWS console or terraform first
```

### Resource not found
```
Error: Resource /submit not found. Create the integration first...

Solution: Create /submit resource in API Gateway console first
```

### Invalid region
```bash
# Set AWS credentials
aws configure

# Or set region in script
REGION="us-east-1"  # Change this
```

## Idempotency Examples

### First Run - Creates Resources
```bash
$ bash secure-api-gateway.sh
▶ Creating usage plan: FormBridgeBasic...
✓ Usage plan created: xo5f9d
▶ Creating API Key: FormBridgeDemoKey...
✓ API Key created: trcie7mv32
```

### Second Run - Reuses Resources
```bash
$ bash secure-api-gateway.sh
▶ Checking if usage plan named 'FormBridgeBasic' exists...
✓ Usage plan already exists: xo5f9d (idempotent)
▶ Checking if API Key named 'FormBridgeDemoKey' exists...
✓ API Key already exists: trcie7mv32 (idempotent)
```

### Update Configuration - Only Updates
```bash
# Edit script: RATE_LIMIT="5"

$ bash secure-api-gateway.sh
▶ Checking if usage plan named 'FormBridgeBasic' exists...
✓ Usage plan already exists: xo5f9d (idempotent)
✓ Usage plan updated with new rate limit
```

## FormBridge Configuration

Default values are pre-configured:

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

Just run: `bash secure-api-gateway.sh`

## Key Output Values

After running the script, you'll see:

```
API Key ID: trcie7mv32
API Key Value: OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN
Usage Plan ID: xo5f9d
Resource ID: 74bix6
Endpoint: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit
```

**Store these securely!**

## Integration with Frontend

```javascript
// index.html
const API_KEY = "OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN";
const API_ENDPOINT = "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit";

const response = await fetch(API_ENDPOINT, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Api-Key': API_KEY  // ← Required!
  },
  body: JSON.stringify(payload)
});
```

## Security Notes

⚠️ **API Keys in Frontend**:
- ✅ Acceptable for demo/personal projects
- ❌ Not recommended for production SaaS
- 🔒 Better: Use backend proxy or environment variables
- 🔄 Rotate every 90 days

## Next Steps

1. ✅ Run: `bash secure-api-gateway.sh`
2. ✅ Verify: Check curl test results
3. ✅ Store API Key in `.env` file (not git!)
4. ✅ Update frontend with API Key header
5. ✅ Deploy to production
6. ✅ Monitor CloudWatch logs
7. ✅ Rotate key every 90 days

## Documentation

- **Main Guide**: BASH_SCRIPT_GUIDE.md
- **Quick Ref**: BASH_SCRIPT_QUICK_REF.md
- **Analysis**: BASH_IMPLEMENTATION_SUMMARY.md
- **API Docs**: API_REFERENCE.md

---

**Status**: ✅ Production Ready  
**Version**: 1.0  
**Last Updated**: 2025-11-05
