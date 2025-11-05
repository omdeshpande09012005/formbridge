# FormBridge End-to-End Test Suite

Complete local and production testing framework for FormBridge with HTML reports and artifact collection.

## Overview

This test suite provides comprehensive end-to-end testing for FormBridge, covering all major features:

- ✅ Form submission
- ✅ Analytics retrieval
- ✅ CSV export
- ✅ HMAC signature validation
- ✅ Email branding (MailHog for local)
- ✅ DynamoDB queries
- ✅ SQS queue status monitoring
- ✅ AWS SES email statistics (production)

Each test step is independently recorded with timing, status, and details, producing:
- **HTML Report** - Visual dashboard with pass/fail status
- **JSON Summary** - Machine-readable test results
- **Artifacts** - CSV exports, email HTML, DynamoDB items, etc.

## Quick Start

### 1. Prerequisites

```bash
# Install required tools
# - Node.js 18+ (https://nodejs.org/)
# - jq (https://stedolan.org/jq/)
# - curl (https://curl.se/)
# - AWS CLI (https://aws.amazon.com/cli/)
# - k6 (optional, for load tests: https://k6.io/)

# Verify installation
node --version
jq --version
curl --version
aws --version
```

**macOS:**
```bash
brew install node jq curl awscli k6
```

**Ubuntu/Debian:**
```bash
sudo apt-get install nodejs jq curl awscli k6
```

**Windows (PowerShell):**
```powershell
choco install nodejs jq curl awscli k6
# or use winget
winget install OpenJS.NodeJS jqlang.jq curl.curl Amazon.AWSCLI Grafana.k6
```

### 2. Setup Configuration

```bash
# Copy environment templates
cp tests/.env.local.example tests/.env.local
cp tests/.env.prod.example tests/.env.prod

# Edit configuration files with your values
# tests/.env.local  - for local testing
# tests/.env.prod   - for production testing
```

**Example `.env.local`:**
```env
BASE_URL=http://127.0.0.1:3000
API_KEY=
FORM_ID=my-portfolio
FORM_IDS_ROUTED=contact-us,careers,support
HMAC_ENABLED=false
HMAC_SECRET=
MAILHOG_URL=http://localhost:8025
```

**Example `.env.prod`:**
```env
BASE_URL=https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod
API_KEY=your-actual-api-key-here
FORM_ID=my-portfolio
HMAC_ENABLED=true
HMAC_SECRET=your-hmac-secret-here
```

### 3. Run Tests

**Local Testing (Bash):**
```bash
bash tests/run_all_local.sh
```

**Local Testing (PowerShell):**
```powershell
pwsh tests/run_all_local.ps1
```

**Production Testing (Bash):**
```bash
bash tests/run_all_prod.sh
```

**Production Testing (PowerShell):**
```powershell
pwsh tests/run_all_prod.ps1
```

### 4. View Results

```bash
# Open HTML report in browser
open tests/report.html              # macOS
xdg-open tests/report.html          # Linux
start tests/report.html             # Windows PowerShell
```

The report shows:
- ✅ PASS/FAIL status for each test
- ⏱️ Duration in milliseconds
- 📊 Summary statistics
- 🔗 Links to artifacts (CSV, JSON, HTML)

## Test Workflow

### Local Environment Setup

```bash
# Terminal 1: Start Docker Compose
cd formbridge/local
docker compose up -d

# Verify services
docker compose ps
```

### Local Test Run

```bash
# Terminal 2: Run tests
bash tests/run_all_local.sh

# Expected output:
# ✓ PASS - sanity_checks (1234ms)
# ✓ PASS - submit (567ms)
# ✓ PASS - analytics (890ms)
# ✓ PASS - export (456ms)
# ⚠ SKIPPED - hmac (disabled)
# ✓ PASS - mailhog_email (123ms)
# ✓ PASS - dynamodb_query (234ms)
# ✓ PASS - sqs_depth (45ms)
```

### Production Test Run

```bash
# Configure API key first
export API_KEY="your-production-api-key"

# Run production tests
bash tests/run_all_prod.sh

# Expected output:
# ✓ PASS - sanity_checks (1234ms)
# ✓ PASS - submit (567ms)
# ✓ PASS - analytics (890ms)
# ✓ PASS - export (456ms)
# ✓ PASS - hmac (345ms)
# ✓ PASS - ses_status (67ms)
# ✓ PASS - dynamodb_query (234ms)
# ✓ PASS - sqs_depth (45ms)
```

## Test Steps Explained

### 1. Sanity Checks
- Verifies all required tools are installed
- Checks environment configuration
- Validates API connectivity
- Confirms AWS credentials (prod only)

**Status:** PASS if all tools found and API responds

### 2. Form Submission
- Sends POST request to `/submit` endpoint
- Includes form_id, name, email, message
- Optionally signs with HMAC if enabled
- Captures submission ID from response

**Status:** PASS if response contains `id` field

### 3. Analytics
- Retrieves submission count for form_id
- Queries `/analytics` endpoint
- Validates structure with totals, breakdown

**Status:** PASS if response contains `totals` field

### 4. CSV Export
- Exports last 7 days of submissions
- Saves to `artifacts/export_YYYYMMDD.csv`
- Validates CSV format (contains commas)

**Status:** PASS if response is valid CSV with > 1 line

### 5. HMAC Signature
- Tests HMAC-SHA256 signed request
- Uses X-Timestamp and X-Signature headers
- Format: `HMAC_SHA256(secret, timestamp\nrawBody)`

**Status:** PASS if signed request succeeds (skipped if disabled)

### 6. Email Branding (Local)
- Queries MailHog for latest email
- Checks HTML contains "FormBridge" branding
- Saves HTML to `artifacts/mailhog_latest.html`

**Status:** PASS if email found (skipped if MailHog unavailable)

### 7. SES Statistics (Production)
- Queries AWS SES send statistics
- Checks bounce and complaint rates
- Validates email infrastructure health

**Status:** PASS if SES data available

### 8. DynamoDB Query
- Queries most recent submission from DynamoDB
- Saves item to `artifacts/dynamo_latest.json`
- Validates table accessibility

**Status:** PASS if table responds (even if empty)

### 9. SQS Queue Status
- Checks webhook queue depth
- Monitors Dead Letter Queue
- Alerts if queue backing up

**Status:** PASS if queue depth < 5 messages

## Report Structure

### Summary Dashboard
```
Environment: LOCAL | PRODUCTION
Run Time: 2025-11-05 14:23:45
Total Duration: 4.5 seconds
Passed: 8/8
Failed: 0/8
Success Rate: 100%
```

### Test Steps Table
| Step Name | Status | Duration | Details |
|-----------|--------|----------|---------|
| sanity_checks | PASS | 1234ms | - |
| submit | PASS | 567ms | id: "sub_123abc" |
| analytics | PASS | 890ms | total: 42 |
| export | PASS | 456ms | file: export_20251105.csv |
| hmac | SKIPPED | 0ms | disabled |
| mailhog_email | PASS | 123ms | file: mailhog_latest.html |
| dynamodb_query | PASS | 234ms | file: dynamo_latest.json |
| sqs_depth | PASS | 45ms | depth: 2 |

### Artifacts Section
- 📎 export_20251105.csv
- 📎 mailhog_latest.html
- 📎 dynamo_latest.json
- 📎 last_submission_id.txt

## Artifact Files

All artifacts are saved to `tests/artifacts/`:

```
tests/artifacts/
├── summary.json                    # Test results in JSON format
├── export_20251105.csv             # Exported submissions CSV
├── mailhog_latest.html             # Latest email from MailHog
├── dynamo_latest.json              # Latest DynamoDB item
└── last_submission_id.txt          # Last submission ID (for reference)
```

## Troubleshooting

### "Missing required tools"

```bash
# Install missing tool
npm install -g node
brew install jq
brew install curl
pip install awscli
```

### API Key Authentication Failed

**Symptoms:**
- HTTP 403 Forbidden
- "Unauthorized" in response

**Solution:**
```bash
# Check API key is set
echo $API_KEY

# Update .env.prod with correct key
# Regenerate key in AWS console if needed
```

### HMAC Signature Validation Failed

**Symptoms:**
- HTTP 401 Unauthorized on HMAC test
- "Invalid signature" in response

**Cause:** Secret mismatch or incorrect format

**Solution:**
```bash
# Verify secret in .env.prod matches AWS
# Check timestamp format (Unix seconds)
# Verify message format: "timestamp\nrawBody"
```

### MailHog Not Available

**Symptoms:**
- Test marked SKIPPED
- "No emails found in MailHog"

**Solution:**
```bash
# Start MailHog if using local
docker run -p 1025:1025 -p 8025:8025 mailhog/mailhog

# Or verify MAILHOG_URL is correct in .env.local
# Default: http://localhost:8025
```

### DynamoDB Query Empty

**Symptoms:**
- "No DynamoDB items found"
- Table accessible but no records

**Solution:**
```bash
# This is expected if table is new
# Submit a form first to create records
bash tests/run_all_local.sh  # Creates test data

# Then re-run tests
bash tests/run_all_local.sh
```

### AWS Credentials Invalid (Production)

**Symptoms:**
- "AWS authentication failed"
- "AccessDenied" errors

**Solution:**
```bash
# Configure AWS credentials
aws configure --profile formbridge

# Or set environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="ap-south-1"
```

### SQS Queue Not Found

**Symptoms:**
- SQS test skipped
- "Queue not configured"

**Solution:**
```bash
# SQS queue is optional
# Update .env.prod with actual queue URL if you want to test:
WEBHOOK_QUEUE_URL="https://sqs.ap-south-1.amazonaws.com/..."
```

## Environment Variables Reference

### Local Configuration (`.env.local`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| BASE_URL | Yes | http://127.0.0.1:3000 | Local API endpoint |
| API_KEY | No | (empty) | API authentication key |
| FORM_ID | Yes | my-portfolio | Primary form to test |
| FORM_IDS_ROUTED | No | - | Routed form IDs (comma-sep) |
| HMAC_ENABLED | No | false | Enable HMAC signing |
| HMAC_SECRET | No | (empty) | HMAC signing secret |
| DDB_TABLE | Yes | contact-form-submissions-v2 | DynamoDB table name |
| REGION | Yes | ap-south-1 | AWS region |
| MAILHOG_URL | No | http://localhost:8025 | MailHog API endpoint |
| WEBHOOK_QUEUE_URL | No | (empty) | SQS webhook queue |
| WEBHOOK_DLQ_URL | No | (empty) | SQS Dead Letter Queue |
| TEST_EMAIL | No | test@example.com | Email for test submissions |

### Production Configuration (`.env.prod`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| BASE_URL | Yes | https://12mse3zde5.execute... | Production API endpoint |
| API_KEY | **YES** | REPLACE_ME | Production API key |
| FORM_ID | Yes | my-portfolio | Primary form to test |
| FORM_IDS_ROUTED | No | - | Routed form IDs (comma-sep) |
| HMAC_ENABLED | No | true | Enable HMAC signing (recommended) |
| HMAC_SECRET | No | REPLACE_IF_ENABLED | HMAC signing secret |
| DDB_TABLE | Yes | contact-form-submissions-v2 | DynamoDB table name |
| REGION | Yes | ap-south-1 | AWS region |
| WEBHOOK_QUEUE_URL | No | (empty) | SQS webhook queue (optional) |
| WEBHOOK_DLQ_URL | No | (empty) | SQS DLQ (optional) |
| TEST_EMAIL | No | test@example.com | Email for test submissions |

## File Structure

```
tests/
├── run_all_local.sh              # Bash runner for local tests
├── run_all_local.ps1             # PowerShell runner for local tests
├── run_all_prod.sh               # Bash runner for prod tests
├── run_all_prod.ps1              # PowerShell runner for prod tests
├── report.html                   # Generated HTML report
├── .env.local                    # Local config (copy from .example)
├── .env.prod                     # Prod config (copy from .example)
├── .env.local.example            # Local config template
├── .env.prod.example             # Prod config template
├── README.md                     # This file
├── lib/
│   ├── http_client.js            # Node.js HTTP client with HMAC
│   ├── aws_helpers.sh            # Bash AWS utility functions
│   ├── collect_summary.js        # Summary aggregation and HTML report
│   ├── init_summary.js           # Initialize summary JSON
│   ├── append_step.js            # Append test step result
│   ├── test_step_submit.js       # Submit form endpoint test
│   ├── test_step_analytics.js    # Analytics endpoint test
│   ├── test_step_export.js       # Export CSV endpoint test
│   └── test_step_hmac.js         # HMAC signing test
└── artifacts/
    ├── summary.json              # Test results (generated)
    ├── export_20251105.csv       # Exported submissions (generated)
    ├── mailhog_latest.html       # Latest email (generated)
    └── dynamo_latest.json        # DynamoDB item (generated)
```

## Advanced Usage

### Custom Test Duration

```bash
# Run with verbose output
VERBOSE=true bash tests/run_all_local.sh
```

### Selective Test Steps

Edit `run_all_local.sh` to comment out specific tests:

```bash
# Comment out HMAC test
# test_hmac || true

# Comment out MailHog test
# test_mailhog || true
```

### Extract Results Programmatically

```bash
# Read summary JSON
cat tests/artifacts/summary.json | jq '.steps[] | select(.status == "FAIL")'

# Count passed tests
cat tests/artifacts/summary.json | jq '.steps[] | select(.status == "PASS")' | jq -s 'length'

# Get total duration
cat tests/artifacts/summary.json | jq '[.steps[].ms] | add'
```

### Generate Report Only

```bash
# After tests run, regenerate report from existing summary
node tests/lib/collect_summary.js report tests/artifacts/summary.json tests/report.html
```

## Performance Baselines

Typical performance on local setup:
- Sanity checks: 100-200ms
- Submit: 50-100ms
- Analytics: 30-50ms
- Export: 100-200ms
- HMAC: 60-80ms
- MailHog: 50-100ms
- DynamoDB: 100-200ms
- SQS: 20-50ms
- **Total: 500-800ms**

Production with network latency:
- Sanity checks: 1-2s
- Submit: 200-500ms
- Analytics: 200-400ms
- Export: 500-1000ms
- HMAC: 200-400ms
- SES: 200-500ms
- DynamoDB: 200-500ms
- SQS: 100-300ms
- **Total: 3-5 seconds**

## Best Practices

1. **Environment Isolation**
   - Keep `.env.local` and `.env.prod` separate
   - Never commit `.env` files with real secrets
   - Use `.gitignore` to prevent accidental commits

2. **Regular Testing**
   - Run local tests during development
   - Run prod tests before deployments
   - Schedule weekly smoke tests

3. **Artifact Retention**
   - Keep artifacts for debugging
   - Archive successful reports monthly
   - Delete old artifacts to save space

4. **Error Handling**
   - Review failed test artifacts immediately
   - Check CloudWatch logs for Lambda errors
   - Verify DynamoDB and SQS queue status

5. **Security**
   - Store API_KEY in AWS Secrets Manager
   - Rotate HMAC secrets regularly
   - Use least-privilege IAM roles
   - Enable MFA for production access

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/test.yml`:

```yaml
name: FormBridge Tests

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: |
          sudo apt-get install jq curl
          aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          bash tests/run_all_prod.sh
      - uses: actions/upload-artifact@v3
        with:
          name: test-report
          path: tests/report.html
```

### GitLab CI

Create `.gitlab-ci.yml`:

```yaml
test:prod:
  stage: test
  image: node:18
  before_script:
    - apt-get update && apt-get install -y jq curl awscli
  script:
    - bash tests/run_all_prod.sh
  artifacts:
    paths:
      - tests/report.html
      - tests/artifacts/
    expire_in: 1 month
  only:
    - main
  variables:
    API_KEY: $PROD_API_KEY
    HMAC_SECRET: $PROD_HMAC_SECRET
```

## Support & Debugging

### Enable Verbose Logging

```bash
VERBOSE=true bash tests/run_all_local.sh
```

### Check Logs

```bash
# Local Lambda logs
docker logs formbridge_lambda

# Production CloudWatch logs
aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1
```

### Test Single Endpoint

```bash
# Direct HTTP test
curl -X POST http://127.0.0.1:3000/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"my-portfolio","name":"Test","email":"test@example.com","message":"Hello"}'
```

## Contributing

To add new test steps:

1. Create test file in `tests/lib/test_step_*.js`
2. Add step function to `run_all_*.sh`
3. Call `record_step` to log results
4. Update README with new step description

## License

Copyright © 2025 FormBridge. All rights reserved.

---

**Questions?** Check the artifacts in `tests/artifacts/` for detailed error information.
