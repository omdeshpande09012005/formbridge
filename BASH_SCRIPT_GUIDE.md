# API Gateway Security - Bash Script Implementation Guide

This directory contains a comprehensive bash script for securing AWS API Gateway with API Keys, Usage Plans, and CORS.

## Script: `secure-api-gateway.sh`

### Overview
Idempotent bash script that:
- ✅ Validates AWS CLI + jq prerequisites
- ✅ Finds or creates resources for SUBMIT_PATH
- ✅ Marks POST method as API Key required
- ✅ Configures CORS via OPTIONS method + mock integration
- ✅ Creates or gets Usage Plan with rate limiting
- ✅ Creates or gets API Key and associates with Usage Plan
- ✅ Deploys API Gateway changes
- ✅ Validates with curl (403 w/o key, 200 w/ key, CORS preflight)

### Usage

#### On Linux/macOS/WSL:
```bash
cd /path/to/formbridge

# Edit placeholders in the script
nano secure-api-gateway.sh

# Replace:
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

# Run the script
bash secure-api-gateway.sh
```

#### Configuration Placeholders (ALL_CAPS)
| Variable | Example | Description |
|----------|---------|-------------|
| `REGION` | `ap-south-1` | AWS region where API Gateway is deployed |
| `ACCOUNT_ID` | `864572276622` | AWS Account ID |
| `API_ID` | `12mse3zde5` | API Gateway REST API ID |
| `STAGE_NAME` | `Prod` | Deployment stage name |
| `SUBMIT_PATH` | `/submit` | Resource path to secure |
| `USAGE_PLAN_NAME` | `FormBridgeBasic` | Usage Plan name for rate limiting |
| `API_KEY_NAME` | `FormBridgeDemoKey` | API Key name |
| `FRONTEND_ORIGIN` | `https://omdeshpande09012005.github.io` | CORS allowed origin |
| `RATE_LIMIT` | `2` | Requests per second |
| `BURST_LIMIT` | `5` | Burst capacity |
| `MONTHLY_QUOTA` | `10000` | Monthly request quota |

### Script Flow

```
1. PRECHECKS
   ├─ AWS CLI installed?
   ├─ jq installed?
   ├─ AWS credentials configured?
   └─ API Gateway API exists?

2. FIND RESOURCE
   └─ Get resource ID for /submit path

3. MARK POST AS KEY-REQUIRED
   ├─ Check if POST method exists
   ├─ Set apiKeyRequired=true
   └─ Verify with re-fetch

4. CONFIGURE CORS
   ├─ Ensure OPTIONS method exists
   ├─ Create/verify MOCK integration
   ├─ Set method response (status 200 + headers)
   └─ Set integration response (CORS headers with values)

5. CREATE/GET USAGE PLAN
   ├─ Check if usage plan exists by name
   ├─ Create if missing (rate limit + quota)
   └─ Attach API stage if not already attached

6. CREATE/GET API KEY
   ├─ Check if API Key exists by name
   ├─ Create if missing
   └─ Associate with Usage Plan

7. DEPLOY
   └─ Create deployment on stage

8. VALIDATE WITH CURL
   ├─ Test 1: POST without X-Api-Key → 403
   ├─ Test 2: POST with X-Api-Key → 200
   └─ Test 3: OPTIONS preflight → 200
```

### Key Features

#### Idempotent
- Safe to re-run multiple times
- Detects existing resources by name
- Only creates/updates if necessary
- Uses jq to parse JSON responses

#### Error Handling
- Fails fast on missing prerequisites
- Checks for required resources before operations
- Clear error messages for troubleshooting
- Verifies each step with re-fetch

#### Logging
- Echo banners for each step
- ✓ Success messages
- ✗ Error messages to stderr
- Detailed curl output with HTTP status codes

#### Validation
```bash
# Test without API Key (403 Forbidden)
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"test"}'
# → 403 Forbidden

# Test with API Key (200 OK)
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN" \
  -d '{"form_id":"test","message":"test"}'
# → 200 OK with JSON response

# Test CORS Preflight (200 OK with headers)
curl -X OPTIONS https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Origin: https://omdeshpande09012005.github.io" \
  -H "Access-Control-Request-Method: POST"
# → 200 OK with Access-Control-Allow-* headers
```

### Expected Outcomes

✅ **Without API Key**
```
HTTP/1.1 403 Forbidden
{"message":"Forbidden"}
```

✅ **With Valid API Key**
```
HTTP/1.1 200 OK
{"id":"550e8400-e29b-41d4-a716-446655440000"}
```

✅ **CORS Preflight**
```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://omdeshpande09012005.github.io
Access-Control-Allow-Methods: OPTIONS,POST
Access-Control-Allow-Headers: Content-Type,X-Api-Key
```

✅ **Rate Limiting (Burst)**
```
# First 5 requests in rapid succession: 200 OK
# 6th request within 1 second: 429 Too Many Requests
```

### Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `AWS CLI not found` | AWS CLI not installed | Install: `apt-get install awscli` or `brew install awscli` |
| `jq not found` | jq not installed | Install: `apt-get install jq` or `brew install jq` |
| `set: command not found` | Wrong shell (csh/zsh) | Use bash: `bash secure-api-gateway.sh` |
| `POST method not found` | Lambda integration not created | Create Lambda integration in AWS console first |
| `403 Forbidden` in test | API Key missing from header | Add `-H "X-Api-Key: <KEY>"` to curl |
| `429 Too Many Requests` | Rate limit exceeded | Wait > 1 second before next request |

### Output Example

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

...

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
```

### FormBridge Integration

For FormBridge specifically:
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

Then update frontend `index.html`:
```javascript
const API_KEY = "OU6iPqehCs94cbpttxIKH2cJ7UhQDbuX73zTgSyN";

const resp = await fetch(API_ENDPOINT, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Api-Key': API_KEY
  },
  body: JSON.stringify(payload)
});
```

### Security Notes

⚠️ **API Keys in Frontend**
- ✅ Acceptable for demo/personal projects
- ❌ Not recommended for production applications
- 🔒 Better: Use backend proxy or environment-based secrets
- 🔄 Rotate every 90 days

### Re-running the Script

The script is fully idempotent. Safe to re-run:
```bash
# Re-run after configuration changes
bash secure-api-gateway.sh

# Update rate limits
# (Modify RATE_LIMIT, BURST_LIMIT, MONTHLY_QUOTA in script)
# Then re-run - it will preserve existing resources and update limits

# Add new origin (requires manual step to modify CORS response)
# Edit FRONTEND_ORIGIN and re-run - OPTIONS method will be reconfigured
```

### Next Steps

1. ✅ Run script: `bash secure-api-gateway.sh`
2. ✅ Verify curl tests pass
3. ✅ Store API Key in `.env` file
4. ✅ Update frontend with X-Api-Key header
5. ✅ Deploy and test end-to-end
6. ✅ Monitor CloudWatch logs
7. ✅ Schedule API key rotation (90 days)

---

**Last Updated**: 2025-11-05  
**Status**: Production Ready  
**Script Version**: 1.0
