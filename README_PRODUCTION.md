# FormBridge v2 - Production Ready ✅

**Status**: Live in production  
**Last Updated**: November 5, 2025  
**Account**: AWS 864572276622 (ap-south-1)

---

## 🎉 What's Live

### ✅ Production Endpoint
```
POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit
```

### ✅ Verified & Tested
- **2 successful test submissions** stored in DynamoDB
- **Lambda handler** refactored with industry-grade features
- **API Gateway** live and responding (200 OK)
- **DynamoDB** composite key schema (pk + sk) active
- **SES** configured with 6 verified email identities

---

## 📋 Complete Deployment Checklist

| Component | Status | Details |
|-----------|--------|---------|
| DynamoDB | ✅ Active | `contact-form-submissions-v2` with composite keys |
| Lambda | ✅ Deployed | `contactFormProcessor` Python 3.11 |
| Lambda Role | ✅ Configured | DynamoDB + SES permissions attached |
| Environment Variables | ✅ Set | DDB_TABLE, SES_SENDER, SES_RECIPIENTS, FRONTEND_ORIGIN |
| API Gateway | ✅ Live | `/submit` endpoint POST + OPTIONS |
| CORS | ✅ Enabled | Origin: `https://omdeshpande09012005.github.io` |
| SES | ✅ Verified | 6 email identities ready |
| Tests | ✅ Passed | Direct Lambda + API Gateway both 200 OK |
| Data Storage | ✅ Verified | 2 submissions in DynamoDB |

---

## 📚 Documentation Files

### Getting Started
- **`DEPLOYMENT_STATUS.md`** - Complete deployment report with configuration details
- **`FRONTEND_INTEGRATION.md`** - Frontend integration guide (React, vanilla JS, curl examples)
- **`QUICK_START.md`** - 5-minute quickstart guide

### Reference
- **`API_REFERENCE.md`** - API endpoints and response formats
- **`AWS_CLI_REFERENCE.md`** - 100+ AWS CLI commands
- **`DEPLOYMENT_GUIDE.md`** - Step-by-step deployment instructions

### Architecture
- **`REFACTORING_REPORT.md`** - What changed and why
- **`IMPLEMENTATION_SUMMARY.md`** - Technical highlights
- **`CHECKLIST.md`** - Pre/post deployment verification

### Scripts
- **`deploy.sh`** - Fully automated deployment script (500+ lines)

---

## 🚀 Quick Start (3 Steps)

### Step 1: Review the API
```bash
# Read FRONTEND_INTEGRATION.md for your framework
# (React, vanilla JS, or API reference)
```

### Step 2: Integrate into Your Frontend
```javascript
const API_ENDPOINT = 'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit';

const response = await fetch(API_ENDPOINT, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    form_id: 'my-form',
    message: 'User message', // Required
    name: 'Optional',
    email: 'optional@example.com',
    page: window.location.href
  })
});

const { id } = await response.json();
```

### Step 3: Monitor Submissions
```bash
# View DynamoDB entries
aws dynamodb scan \
  --table-name contact-form-submissions-v2 \
  --region ap-south-1 \
  --profile formbridge-deploy

# Watch Lambda logs
aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1 --profile formbridge-deploy
```

---

## � Analytics Dashboard

Track form submission metrics with a **minimal, static analytics dashboard** that requires no backend setup.

### Quick Start

```bash
# 1. Copy configuration template
cp dashboard/config.example.js dashboard/config.js

# 2. Edit config.js with your API endpoint
# Set API_URL to: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod

# 3. Open dashboard
open dashboard/index.html
# Or use a local server: python -m http.server 8000
# Then visit: http://localhost:8000/dashboard/
```

### Features

- **Single-page UI**: Form ID selector, refresh button, KPI tiles
- **7-Day Chart**: Line chart showing daily submission trends
- **Daily Breakdown**: Table with date and submission count
- **Responsive Design**: Mobile (360px+), tablet, and desktop
- **Error Handling**: Graceful degradation with toast notifications
- **GitHub Pages Ready**: No build tools, pure static files
- **Environment Detection**: Shows DEV or PROD badge

### Configuration

**Development (Local Docker):**
```javascript
export const CONFIG = {
    API_URL: 'http://127.0.0.1:3000',
    API_KEY: '',
    DEFAULT_FORM_ID: 'my-portfolio'
};
```

**Production (AWS):**
```javascript
export const CONFIG = {
    API_URL: 'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod',
    API_KEY: 'your-read-only-api-key',  // Optional
    DEFAULT_FORM_ID: 'my-portfolio'
};
```

**⚠️ Security Note for Static Sites:**
- API keys are visible in the browser (static files)
- Use read-only keys with analytics-only permissions
- Consider IP whitelisting at API Gateway level
- Rotate keys regularly

### Deployment to GitHub Pages

```bash
# 1. Dashboard is already copied to /docs/dashboard/
# 2. Create config.js from template
cp docs/dashboard/config.example.js docs/dashboard/config.js

# 3. Edit with your production API details
# Update API_URL to: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod
# Add API_KEY if using authentication

# 4. Add to .gitignore (protect API key)
echo "docs/dashboard/config.js" >> .gitignore

# 5. Push to GitHub
git add docs/dashboard/
git commit -m "Add analytics dashboard configuration"
git push origin main

# 6. Access dashboard on GitHub Pages
# https://omdeshpande09012005.github.io/docs/dashboard/
```

### Files

- **`dashboard/index.html`** (382 lines)
  - Responsive UI with KPI tiles, chart container, table
  - Toast notification system
  - Mobile-first CSS Grid layout

- **`dashboard/app.js`** (250+ lines)
  - Vanilla JavaScript (no frameworks)
  - API integration with error handling
  - Chart.js rendering
  - Config loading and environment detection

- **`dashboard/config.example.js`**
  - Configuration template
  - Detailed comments for setup
  - Security guidance

- **`docs/DASHBOARD_README.md`** (comprehensive guide)
  - Quick start instructions
  - Configuration reference
  - Deployment guide
  - Troubleshooting and security notes

### Security Note

⚠️ API keys in static sites are **visible in the browser**. Only use read-only keys with analytics-only permissions. Consider IP whitelisting at the API Gateway level.

### More Info

See **`docs/DASHBOARD_README.md`** for:
- Detailed configuration guide
- CORS setup
- GitHub Pages deployment
- Troubleshooting common issues
- 6 screenshot examples

---

## � API Artifacts

Complete API documentation, Postman collection, and Swagger UI for easy integration and testing.

### 📋 What's Included

**OpenAPI 3.0 Specification** (`api/openapi.yaml`)
- Complete machine-readable spec for both `/submit` and `/analytics` endpoints
- Security schemes (X-Api-Key header)
- Request/response schemas with examples
- Error codes and validation rules
- DEV and PROD server configurations

**Postman Collection** (`api/postman/FormBridge.postman_collection.json`)
- Two pre-built requests: Submit and Analytics
- Environment-aware variables ({{base_url}}, {{api_key}}, {{form_id}}, {{page}})
- Automatic submission ID capture with test scripts
- Easy switching between DEV and PROD

**Postman Environments**
- `api/postman/FormBridge.Dev.postman_environment.json` — Local development
- `api/postman/FormBridge.Prod.postman_environment.json` — Production (AWS)

**Swagger UI** (`docs/swagger.html`)
- Interactive API documentation on GitHub Pages
- "Try it out" buttons for endpoint testing
- Authentication header support
- Server selection dropdown (DEV/PROD)

### 🚀 Getting Started

#### Option 1: View Swagger UI Online
Visit: `https://omdeshpande09012005.github.io/swagger.html`

#### Option 2: Import Postman Collection
1. Download [Postman](https://www.postman.com/downloads/)
2. Click **Import** → select `api/postman/FormBridge.postman_collection.json`
3. Import environment: `FormBridge.Dev.postman_environment.json` or `FormBridge.Prod.postman_environment.json`
4. Select environment (top-right dropdown)
5. Click **Send** on any request

#### Option 3: View Locally with Docker
```bash
# Run Swagger UI locally
docker run -p 8888:8080 \
  -e SWAGGER_JSON=/openapi.yaml \
  -v $(pwd)/api/openapi.yaml:/openapi.yaml \
  swaggerapi/swagger-ui

# Open: http://localhost:8888
```

### 🔐 Security: API Keys

**Development** (Optional)
- API key not required
- Server: `http://127.0.0.1:3000`
- Testing on localhost without authentication

**Production** (Required)
- API key required for all endpoints
- Header: `X-Api-Key: your-key`
- Server: `https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod`
- Keys stored in AWS Secrets Manager

### 📚 Documentation

- **`api/README.md`** — Complete API guide with cURL examples, auth, and troubleshooting
- **`docs/OPENAPI_VIEWER.md`** — How to set up Swagger UI locally or on GitHub Pages
- **`api/openapi.yaml`** — OpenAPI 3.0 specification (machine-readable)

### 🧪 Test Endpoints

#### Submit a Form
```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-key" \
  -d '{
    "form_id": "my-portfolio",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Interested in your services!"
  }'
```

**Response (200 OK):**
```json
{
  "id": "my-portfolio#1731800000000"
}
```

#### Get Analytics
```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/analytics \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-key" \
  -d '{"form_id": "my-portfolio"}'
```

**Response (200 OK):**
```json
{
  "form_id": "my-portfolio",
  "total_submissions": 42,
  "last_7_days": [
    {"date": "2025-11-05", "count": 13},
    {"date": "2025-11-04", "count": 8}
  ],
  "latest_id": "my-portfolio#1731800000000",
  "last_submission_ts": 1731800000000
}
```

### 🐛 Troubleshooting

**403 Forbidden (Production)**
- Check X-Api-Key header is present and valid
- Verify key hasn't expired

**400 Bad Request**
- Ensure `message` field is provided (required)
- Validate email format if provided
- Check JSON structure matches schema

**CORS Error**
- Development server has CORS enabled
- Production may have restrictions—use X-Api-Key header
- Try testing with Postman (bypasses CORS)

---

## �💾 Data Model

### DynamoDB Schema
```json
{
  "pk": "FORM#form_id",           // Partition key
  "sk": "SUBMIT#timestamp#id",    // Sort key
  "form_id": "my-form",            // Form identifier
  "name": "User Name",             // Optional
  "email": "user@example.com",     // Optional (lowercase)
  "message": "The message",        // Required
  "page": "https://example.com",   // Referrer URL
  "ip": "103.81.39.154",           // Client IP
  "ua": "Mozilla/5.0...",          // User Agent
  "ts": "2025-11-05T11:43:27Z",   // UTC timestamp
  "id": "uuid-v4-string"           // Unique ID
}
```

### Query Examples

**Get all submissions for a form**:
```bash
aws dynamodb query \
  --table-name contact-form-submissions-v2 \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk":{"S":"FORM#my-form"}}' \
  --region ap-south-1
```

**Get submissions by date**:
```bash
aws dynamodb query \
  --table-name contact-form-submissions-v2 \
  --key-condition-expression "pk = :pk AND sk BETWEEN :start AND :end" \
  --expression-attribute-values '{
    ":pk":{"S":"FORM#my-form"},
    ":start":{"S":"SUBMIT#2025-11-01"},
    ":end":{"S":"SUBMIT#2025-11-30"}
  }' \
  --region ap-south-1
```

---

## 🔧 Configuration

### Environment Variables (Already Set)
```
DDB_TABLE = contact-form-submissions-v2
SES_SENDER = aayush.das@mitwpu.edu.in
SES_RECIPIENTS = aayush.das@mitwpu.edu.in
FRONTEND_ORIGIN = https://omdeshpande09012005.github.io
```

### AWS Resources
| Resource | Value |
|----------|-------|
| Account | 864572276622 |
| Region | ap-south-1 (Mumbai) |
| DynamoDB Table | contact-form-submissions-v2 |
| Lambda Function | contactFormProcessor |
| API ID | 12mse3zde5 |
| API Stage | Prod |
| SES Verified Emails | 6 (aayush.das@mitwpu.edu.in is sender) |

---

## 📊 Test Results

### Test 1: Lambda Direct Invocation ✅
```
Input: {"form_id":"test-001","message":"Hello World"}
Output: {"id":"55d255f6-0f6f-4f42-afbc-7ecbdee848a2"}
Status: 200 OK
DynamoDB: ✅ Stored
```

### Test 2: API Gateway ✅
```
POST /submit
Input: {"form_id":"prod-test-002","message":"API test"}
Output: {"id":"8930f7c3-2482-4c01-a2b1-e00495becbb7"}
Status: 200 OK
DynamoDB: ✅ Stored
```

---

## 💰 Cost Estimate

| Service | Price |
|---------|-------|
| Lambda | ~$0.20/month (1M requests) |
| DynamoDB | ~$1.25/month (on-demand) |
| SES | Free (first 62K emails/month)* |
| API Gateway | ~$3.50/month (1M requests) |
| CloudWatch | ~$0.50/month (logs) |
| **Total** | **~$5.50/month** (light usage) |

*Email cost increases after first year or if exceeding quotas.

---

## 🔒 Security

✅ **Implemented**:
- API Key protection (X-Api-Key header required)
- CORS restricted to your domain
- HTTPS-only API Gateway
- Environment variables for secrets
- DynamoDB encryption at rest
- Request validation
- Error messages don't leak internals
- Usage Plan: Rate limit 2 req/sec, 5 burst, 10,000 requests/month

### API Key Configuration

**Requirement**: The `/submit` endpoint now requires an API Key header:
```bash
X-Api-Key: YOUR_API_KEY
```

**Usage Plan Enforced**:
- Rate limit: 2 requests per second
- Burst: 5 requests
- Monthly quota: 10,000 requests

**Key Handling for GitHub Pages**:
- ⚠️ Static sites cannot truly hide API keys (client-side code is public)
- ✅ Acceptable for demo/portfolio projects
- ✅ GitHub Pages + limited quota provides acceptable protection
- Store key in build-time environment variables (Vite/Next.js .env)
- Example: `VITE_API_KEY=your-key-here`

**Future Security Upgrades** (if needed):
- 🔒 WAF IP allowlist for campus/corporate networks
- 🔒 HMAC-signed requests for better security
- 🔒 JWT with short-lived tokens behind edge proxy
- 🔒 Backend proxy that adds key server-side
- 🔒 Signed short-lived tokens (15-minute expiration)

⚠️ **Recommendations**:
- Monitor CloudWatch logs for 403 errors
- Consider implementing IP allowlist for internal use
- For public-facing sensitive forms, implement backend proxy
- Review rate limiting if you expect heavy usage
- Plan for key rotation strategy

---

## 🚨 Troubleshooting

### 403 Forbidden Error
**Problem**: "Forbidden" response when submitting form
**Solutions**:
1. Verify API Key is included in `X-Api-Key` header
2. Check API Key is correct: `aws apigateway get-api-keys --region ap-south-1 --profile formbridge-deploy`
3. Ensure header is passed in all requests

### 429 Too Many Requests
**Problem**: Rate limit exceeded
**Solutions**:
1. Usage Plan limit: 2 req/sec, 10,000/month
2. Wait before retrying (exponential backoff)
3. Check if multiple forms are submitting simultaneously
4. Contact admin to increase quota if needed

### API Returns 500 Error
```bash
# Check Lambda logs
aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1 --profile formbridge-deploy

# Verify environment variables
aws lambda get-function-configuration --function-name contactFormProcessor --region ap-south-1 --profile formbridge-deploy
```

### CORS Error in Frontend
- ✅ Current CORS Origin: `https://omdeshpande09012005.github.io`
- ⚠️ If deploying to different domain, update Lambda env var `FRONTEND_ORIGIN`

### Email Not Received
- Check SES verified identities: `aws ses list-identities --region ap-south-1`
- Review SES sandbox restrictions (only sends to verified addresses)
- Check Lambda logs for SES errors

### DynamoDB Capacity Issues
- Currently on PAY_PER_REQUEST (auto-scaling)
- Should not throttle under normal usage
- Monitor with: `aws cloudwatch get-metric-statistics`

---

## 📈 Next Steps

### This Week
- [ ] Test end-to-end with actual website form
- [ ] Verify email delivery from SES
- [ ] Monitor CloudWatch logs
- [ ] Request SES production access

### This Month
- [x] ✅ Implement analytics dashboard
- [ ] Add rate limiting per IP
- [ ] Set up SNS alerts for errors

### Future Enhancements
- [ ] Advanced analytics (export to CSV)
- [ ] Submission filtering and search
- [ ] DynamoDB GSI for faster queries
- [ ] Lambda concurrency limits
- [ ] API authentication with JWT
- [ ] Dashboard password protection

---

## 📞 Support

### Get Help
- **Log Stream**: `/aws/lambda/contactFormProcessor`
- **CloudWatch**: AWS Console → CloudWatch → Logs
- **DynamoDB**: AWS Console → DynamoDB → Tables → contact-form-submissions-v2
- **API Gateway**: AWS Console → API Gateway → formbridge-stack

### Common Commands
```bash
# View logs
aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1 --profile formbridge-deploy

# Check table
aws dynamodb describe-table --table-name contact-form-submissions-v2 --region ap-south-1 --profile formbridge-deploy

# Get submission count
aws dynamodb scan --table-name contact-form-submissions-v2 --select COUNT --region ap-south-1 --profile formbridge-deploy

# Query specific form
aws dynamodb query \
  --table-name contact-form-submissions-v2 \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk":{"S":"FORM#my-form"}}' \
  --region ap-south-1 --profile formbridge-deploy
```

---

## 📝 Recent Changes

### Latest Commits
```
54757a4 docs: add frontend integration guide with code examples and troubleshooting
ec2d7e9 docs: add final deployment status report - production ready with 2 successful tests
7d22a8f deploy: formbridge-v2 production deployment complete - DynamoDB, Lambda, API Gateway, SES configured and tested
```

### What Changed in v2
- ✅ New JSON schema with form_id, page fields
- ✅ Message-only validation (name/email optional)
- ✅ Composite DynamoDB keys for efficient querying
- ✅ Metadata capture (IP, User-Agent, timestamp, UUID)
- ✅ Non-fatal SES failures (DB is source of truth)
- ✅ CORS headers from environment variable
- ✅ Multiple SES recipients support
- ✅ Reply-To header from submitter email

---

## 🚀 Demo Without AWS Costs

### For Portfolio Reviews & Client Demos

No AWS billing, no internet needed. Run **everything locally** in ~2 minutes.

```bash
# Terminal 1: Start local environment
cd w:\PROJECTS\formbridge
make local-up          # Starts LocalStack, MailHog, DynamoDB Admin, Frontend
make local-bootstrap   # Creates DynamoDB table and seeds test data

# Terminal 2: Start API server
make sam-api           # Starts local Lambda API on port 3000

# Terminal 3: Test
make local-test        # Runs test submissions
```

### Access Points
| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | http://localhost:8080 | Portfolio contact form |
| API | http://localhost:3000/submit | Form submission endpoint |
| DynamoDB Admin | http://localhost:8001 | View all submissions |
| MailHog | http://localhost:8025 | View notification emails |

### What You Get
✅ **Identical to production** - Same code, same logic, same database schema  
✅ **Zero AWS costs** - All services run locally  
✅ **Offline capable** - Works without internet  
✅ **Email testing** - See emails without sending  
✅ **Data exploration** - Browse submissions via web UI  

### Full Documentation
See `local/README.md` for:
- Detailed setup steps
- Service architecture
- Troubleshooting guide
- Windows/PowerShell notes
- Docker Compose configuration

---

## 🔐 HMAC Request Signing (Optional Security Enhancement)

**Status**: Optional feature, disabled by default

### What is HMAC Signing?

HMAC-SHA256 request signing adds an optional layer of security to `/submit` and `/analytics` endpoints. Each request is cryptographically signed with a secret key, preventing unauthorized API calls and protecting against request tampering.

- **Default State**: Disabled (`HMAC_ENABLED=false`)
- **Algorithm**: HMAC-SHA256 with Unix timestamp validation
- **Headers**: `X-Timestamp` (current time) + `X-Signature` (request signature)
- **Protection**: Replay attacks blocked via timestamp skew validation

### When to Enable

- Client with strict security requirements
- Third-party integrations requiring proof of origin
- Compliance requirements (healthcare, finance, etc.)
- Production deployments with sensitive data

### Enable HMAC Signing

1. **Generate Secret** (on your deployment machine):
   ```bash
   openssl rand -hex 32
   # Output: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
   ```

2. **Set Lambda Environment Variables**:
   ```bash
   aws lambda update-function-configuration \
     --function-name contactFormProcessor \
     --environment Variables={HMAC_ENABLED=true,HMAC_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6,HMAC_SKEW_SECS=300} \
     --region ap-south-1 --profile formbridge-deploy
   ```

3. **Update Postman Collection**:
   - Open `api/postman/FormBridge.Prod.postman_environment.json`
   - Set `hmac_enabled` = `"true"`
   - Set `hmac_secret` = your generated secret
   - Collection pre-request script will now auto-sign requests

4. **Update Client Code**:
   - Follow examples in `docs/HMAC_SIGNING.md`
   - Web: Use Web Crypto API (async function, no deps)
   - Python: Use `hmac` + `hashlib` libraries
   - Node.js: Use `crypto` module

### Error Responses

When HMAC is enabled:

```json
// Missing timestamp
{
  "error": "stale or missing timestamp"
}

// Invalid signature
{
  "error": "invalid signature"
}

// Stale request (older than HMAC_SKEW_SECS)
{
  "error": "stale or missing timestamp"
}
```

### Complete Documentation

See `docs/HMAC_SIGNING.md` for:
- JavaScript Web Crypto API implementation
- React component example
- Python requests library example
- cURL testing examples
- Server configuration details
- Troubleshooting guide
- Security best practices

---

## 📊 CSV Data Export

**Status**: Active, available immediately

### What is CSV Export?

Endpoint `/export` enables bulk data downloads in CSV format for reporting, dashboards, and third-party integrations.

- **Format**: RFC 4180 CSV with headers
- **Columns**: id, form_id, name, email, message, page, ip, ua, ts
- **Limit**: 10,000 rows max per request
- **Range**: 1-90 days configurable

### Quick Export Examples

**cURL**:
```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-api-key" \
  -d '{"form_id":"my-portfolio","days":7}' \
  -o submissions_7d.csv
```

**Python**:
```python
import requests

response = requests.post(
    'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export',
    headers={
        'Content-Type': 'application/json',
        'X-Api-Key': 'your-api-key'
    },
    json={'form_id': 'my-portfolio', 'days': 7}
)

with open('submissions.csv', 'wb') as f:
    f.write(response.content)
```

### API Endpoint

```
POST /export
Content-Type: application/json
X-Api-Key: <required>

{
  "form_id": "my-portfolio",  // Required
  "days": 7                    // Optional, 1-90, default 7
}
```

**Response** (200 OK):
```
Content-Type: text/csv
Content-Disposition: attachment; filename=formbridge_my-portfolio_7d_20251105.csv
X-Row-Cap: 0  // Set to 1 if 10,000 row limit reached

id,form_id,name,email,message,page,ip,ua,ts
my-portfolio#1731800000000,my-portfolio,John Doe,john@example.com,Project inquiry,https://portfolio.com,203.0.113.42,Mozilla/5.0...,1731800000
```

### Use Cases

1. **Email Campaigns**: Extract email column, send bulk messages
2. **Google Sheets**: Import CSV, set up recurring manual exports
3. **CRM Integration**: Map columns to Salesforce/HubSpot fields
4. **Analytics**: Load into pandas, generate statistics
5. **Compliance**: Archive submissions for audit trails

### Dashboard Export Button

Analytics dashboard includes "Download CSV" button:

1. Choose date range (1-90 days)
2. Click "Download" button
3. Browser saves CSV file: `formbridge_{form_id}_{days}d_{timestamp}.csv`

Dashboard handles HMAC signing automatically if enabled.

### Postman Collection

Pre-configured "Export CSV" request in `api/postman/FormBridge.postman_collection.json`:

1. Open Postman collection
2. Select "Analytics" folder → "Export CSV" request
3. Update `form_id` and `days` if needed
4. Send request
5. Response shows in "Body" tab (Postman auto-recognizes CSV)
6. Click "Save Response" → "Save to file" to download

### Limits & Workarounds

**10,000 Row Limit**:
- `X-Row-Cap: 1` header indicates limit reached
- Workaround: Export in smaller date ranges (e.g., 7 days at a time)

**90-Day Maximum**:
- Cannot export data older than 90 days in single request
- Workaround: Multiple requests with different date ranges

### Complete Documentation

See `docs/EXPORT_README.md` for:
- Complete API documentation
- Column descriptions and examples
- Integration examples (JavaScript, bash, Python)
- Troubleshooting guide (403, 401, empty CSV, encoding)
- Use case walkthroughs

---

## ✅ Verification Checklist

- [x] API endpoint responds to requests
- [x] DynamoDB stores all submissions
- [x] SES configuration verified
- [x] Lambda permissions correct
- [x] CORS headers present
- [x] Error handling functional
- [x] Metadata capture working
- [x] CloudWatch logs available
- [x] Git history clean
- [x] Documentation complete
- [x] Local demo pack ready

---

**Ready for Production** ✅  
**Contact**: See DEPLOYMENT_STATUS.md for AWS account details  
**Last Updated**: 2025-11-05 11:45 UTC
