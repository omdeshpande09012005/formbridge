# FormBridge Full Test Pack - Implementation Guide

**Date:** November 5, 2025  
**Status:** ✅ COMPLETE  
**All components tested and ready for deployment**

---

## 📋 What Was Delivered

A comprehensive end-to-end test harness for FormBridge with:

### Test Infrastructure ✅

1. **Local Test Runner** (`tests/run_all_local.sh`)
   - Bash implementation for local environment
   - Tests against `http://127.0.0.1:3000` or configured URL
   - Includes MailHog email verification
   - Covers: submit, analytics, export, HMAC, DynamoDB, SQS

2. **Production Test Runner** (`tests/run_all_prod.sh`)
   - Bash implementation for production API Gateway
   - Tests against actual production endpoint
   - AWS credential validation
   - SES email statistics verification
   - Includes all local tests + production-specific checks

3. **PowerShell Versions** (`run_all_local.ps1`, `run_all_prod.ps1`)
   - Windows compatibility
   - Feature parity with Bash versions
   - Native PowerShell error handling

### Test Libraries ✅

1. **HTTP Client** (`lib/http_client.js`)
   - HMAC-SHA256 signature computation
   - JSON POST with custom headers
   - X-Api-Key authentication
   - X-Timestamp and X-Signature headers
   - Error handling and timeouts

2. **AWS Helpers** (`lib/aws_helpers.sh`)
   - DynamoDB query functions
   - SQS queue depth checking
   - SES send statistics
   - CloudWatch logs querying
   - CloudFormation stack inspection

3. **Test Step Executors** (`lib/test_step_*.js`)
   - `test_step_submit.js` - Form submission
   - `test_step_analytics.js` - Analytics retrieval
   - `test_step_export.js` - CSV export
   - `test_step_hmac.js` - HMAC signature validation

4. **Summary Tools** (`lib/*.js`)
   - `init_summary.js` - Initialize test summary
   - `append_step.js` - Record individual test results
   - `collect_summary.js` - Aggregate results and generate HTML

### Configuration ✅

1. **Environment Templates**
   - `tests/.env.local.example` - Local configuration template
   - `tests/.env.prod.example` - Production configuration template
   - Both include all required and optional variables
   - Clear documentation for each setting

### Documentation ✅

1. **README** (`tests/README.md`)
   - 500+ lines of comprehensive documentation
   - Quick start guide (5 minutes to first test)
   - Detailed step-by-step instructions
   - Troubleshooting section with solutions
   - Environment variable reference
   - Best practices and security guidance
   - CI/CD integration examples
   - Advanced usage patterns

### CI/CD Integration ✅

1. **GitHub Actions Workflow** (`.github/workflows/full_test.yml`)
   - Scheduled production tests (every 6 hours)
   - Manual dispatch trigger
   - PR comments with test results
   - Artifact upload and retention
   - CloudWatch integration
   - Failure notifications

---

## 📁 File Structure

```
tests/
├── run_all_local.sh                 ← Run tests locally (Bash)
├── run_all_local.ps1                ← Run tests locally (PowerShell)
├── run_all_prod.sh                  ← Run tests in production (Bash)
├── run_all_prod.ps1                 ← Run tests in production (PowerShell)
├── report.html                      ← Generated test report
├── README.md                        ← Comprehensive guide (this document)
├── .env.local                       ← Local config (created from .example)
├── .env.local.example               ← Local config template
├── .env.prod                        ← Prod config (created from .example)
├── .env.prod.example                ← Prod config template
│
├── lib/
│   ├── http_client.js               ← HTTP client with HMAC support
│   ├── aws_helpers.sh               ← AWS utility functions
│   ├── collect_summary.js           ← Summary aggregation + HTML report
│   ├── init_summary.js              ← Initialize summary.json
│   ├── append_step.js               ← Append test step to summary
│   ├── test_step_submit.js          ← Submit form test
│   ├── test_step_analytics.js       ← Analytics test
│   ├── test_step_export.js          ← Export CSV test
│   └── test_step_hmac.js            ← HMAC signature test
│
└── artifacts/
    ├── summary.json                 ← Test results (generated)
    ├── export_20251105.csv          ← Exported data (generated)
    ├── mailhog_latest.html          ← Email sample (generated)
    ├── dynamo_latest.json           ← DynamoDB item (generated)
    └── last_submission_id.txt       ← Submission reference (generated)

.github/workflows/
└── full_test.yml                    ← GitHub Actions CI/CD workflow
```

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Copy Configuration Files

```bash
cp tests/.env.local.example tests/.env.local
cp tests/.env.prod.example tests/.env.prod
```

### Step 2: Fill in Configuration

**For Local Testing:**
```bash
# Edit tests/.env.local
BASE_URL=http://127.0.0.1:3000
FORM_ID=my-portfolio
MAILHOG_URL=http://localhost:8025
# API_KEY not needed for local
```

**For Production Testing:**
```bash
# Edit tests/.env.prod
BASE_URL=https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod
API_KEY=your-actual-api-key
FORM_ID=my-portfolio
HMAC_SECRET=your-hmac-secret
```

### Step 3: Ensure Prerequisites

```bash
# Verify all tools are installed
node --version        # Should be 18+
jq --version          # Should be 1.6+
curl --version        # Should be 7.0+
aws --version         # For production tests

# For local testing, start services:
cd formbridge/local
docker compose up -d
```

### Step 4: Run Tests

```bash
# Local tests (Bash)
bash tests/run_all_local.sh

# Or with PowerShell
pwsh tests/run_all_local.ps1

# Production tests (Bash)
bash tests/run_all_prod.sh

# Or with PowerShell
pwsh tests/run_all_prod.ps1
```

### Step 5: View Results

```bash
# Open HTML report
open tests/report.html              # macOS
xdg-open tests/report.html          # Linux
start tests/report.html             # Windows
```

---

## 🧪 Test Coverage

### Local Environment Tests

| Test | Endpoint | Validates | Logs |
|------|----------|-----------|------|
| **Sanity** | N/A | Tools, config, connectivity | version info |
| **Submit** | POST /submit | 200 response, id field | submission ID |
| **Analytics** | POST /analytics | totals count, structure | count value |
| **Export** | POST /export | CSV format, > 1 line | file path |
| **HMAC** | POST /submit (signed) | Signature validation | sign status |
| **Email** | MailHog API | FormBridge branding | HTML file |
| **DynamoDB** | Query table | Table accessible, latest item | JSON file |
| **SQS** | Get queue depth | Queue depth < 5 | message count |

### Production Environment Tests

All local tests **plus:**

| Test | Endpoint | Validates | Logs |
|------|----------|-----------|------|
| **AWS Creds** | STS | Valid credentials | ARN |
| **SES Stats** | SES API | Send stats, bounces | stats |
| **HMAC (Prod)** | API Gateway | HMAC with real secret | sign status |

---

## 📊 Example Report Output

The generated `report.html` includes:

```
╔════════════════════════════════════════════════╗
║         FormBridge Test Report                 ║
╠════════════════════════════════════════════════╣
║ Environment:    PRODUCTION                     ║
║ Run Time:       2025-11-05 14:23:45            ║
║ Duration:       4.5 seconds                    ║
║ Status:         ✅ ALL TESTS PASSED            ║
╠════════════════════════════════════════════════╣
║ Passed:         8/8 (100%)                     ║
║ Failed:         0/8 (0%)                       ║
╠════════════════════════════════════════════════╣
║ Test Steps:                                    ║
║ ✓ sanity_checks         PASS      1.2s         ║
║ ✓ submit                PASS      0.6s         ║
║ ✓ analytics             PASS      0.9s         ║
║ ✓ export                PASS      0.5s         ║
║ ✓ hmac                  PASS      0.3s         ║
║ ✓ ses_status            PASS      0.1s         ║
║ ✓ dynamodb_query        PASS      0.2s         ║
║ ✓ sqs_depth             PASS      0.05s        ║
╠════════════════════════════════════════════════╣
║ Artifacts:                                     ║
║ 📎 export_20251105.csv                        ║
║ 📎 dynamo_latest.json                         ║
╚════════════════════════════════════════════════╝
```

---

## 🔧 Implementation Details

### HMAC Signature Format

When HMAC_ENABLED=true, the HTTP client:

1. Creates message: `${timestamp}\n${rawBody}`
2. Computes: `HMAC-SHA256(secret, message)`
3. Sends headers:
   - `X-Timestamp: 1234567890`
   - `X-Signature: abc123def456...`

**Example:**
```javascript
const timestamp = Math.floor(Date.now() / 1000).toString();
const message = `${timestamp}\n${JSON.stringify(payload)}`;
const signature = crypto
  .createHmac('sha256', secret)
  .update(message)
  .digest('hex');
```

### Summary JSON Structure

Each test result in `artifacts/summary.json`:

```json
{
  "run_at": "2025-11-05T14:23:45.123Z",
  "env": "prod",
  "base_url": "https://api.example.com",
  "steps": [
    {
      "name": "submit",
      "status": "PASS",
      "ms": 567,
      "info": { "id": "sub_123abc" },
      "timestamp": "2025-11-05T14:23:45.789Z"
    }
  ],
  "metrics": {
    "k6": {
      "p95_ms": null,
      "p99_ms": null,
      "success_rate": null,
      "total_requests": 0
    }
  },
  "links": {
    "export_csv": "artifacts/export_20251105.csv",
    "mailhog_html": "artifacts/mailhog_latest.html",
    "dynamo_json": "artifacts/dynamo_latest.json"
  }
}
```

### Error Handling

All test steps use **non-blocking error handling**:

```bash
# ✅ GOOD: Continue on failure
test_submit || true
test_analytics || true

# ❌ BAD: Exit on first failure
set -e
test_submit
test_analytics
```

This ensures:
- All tests run even if one fails
- Report shows which tests failed
- Artifacts are collected for debugging

---

## 🔐 Security Best Practices

### API Key Management

```bash
# ❌ DON'T: Store in .env file
API_KEY=sk_live_abc123

# ✅ DO: Use environment variables
export API_KEY="$(aws ssm get-parameter --name /formbridge/api-key --query Parameter.Value --output text)"
```

### HMAC Secret Protection

```bash
# ❌ DON'T: Log secrets
echo "HMAC_SECRET=$HMAC_SECRET"

# ✅ DO: Mask in logs
export HMAC_SECRET="***masked***"
```

### AWS Credentials

```bash
# ✅ Use IAM roles for production
aws sts assume-role --role-arn arn:aws:iam::123456:role/test-role

# ✅ Restrict to read-only operations
# Policy: dynamodb:GetItem, sqs:GetQueueAttributes, etc.
```

### Git Security

```bash
# Add to .gitignore
tests/.env.local
tests/.env.prod
tests/artifacts/

# Prevent accidental commits
git config core.hooksPath .git/hooks
```

---

## 📈 CI/CD Integration

### GitHub Actions Setup

1. **Create secrets** in repository:
   ```
   FORMBRIDGE_API_KEY = sk_live_...
   FORMBRIDGE_HMAC_SECRET = hmac_secret_...
   AWS_ACCESS_KEY_ID = ...
   AWS_SECRET_ACCESS_KEY = ...
   ```

2. **Workflow runs automatically:**
   - Every 6 hours (scheduled)
   - On manual trigger
   - After deployments (if configured)

3. **Results posted to:**
   - GitHub Actions dashboard
   - PR comments (if PR context)
   - GitHub Pages (artifacts)

### Manual Trigger

```bash
# From GitHub UI: Actions → FormBridge Full Test Suite → Run workflow

# Or from CLI:
gh workflow run full_test.yml -f environment=prod
```

---

## 🛠️ Customization Guide

### Adding New Test Steps

1. **Create test file** `lib/test_step_custom.js`:
```javascript
#!/usr/bin/env node
const { postJson } = require('./http_client.js');

const url = process.argv[2];
const apiKey = process.argv[3];

(async () => {
  try {
    const result = await postJson(url, {}, { apiKey });
    if (result.status === 200) {
      console.log(JSON.stringify({ success: true }));
    } else {
      process.exit(1);
    }
  } catch (err) {
    console.error(JSON.stringify({ error: err.message }));
    process.exit(1);
  }
})();
```

2. **Add to run script** `run_all_*.sh`:
```bash
test_custom() {
  print_step "TEST: Custom"
  
  local start_time=$(date +%s%N)
  local response=$(node "$SCRIPT_DIR/lib/test_step_custom.js" "$BASE_URL/custom" "$API_KEY")
  local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
  
  record_step "custom" "PASS" $duration_ms ""
}

# In main():
test_custom || true
```

### Changing Test Thresholds

```bash
# Edit run_all_*.sh

# SQS queue warning threshold
if [[ "$queue_depth" -le 10 ]]; then  # Changed from 5
  echo "SQS queue healthy"
fi

# API timeout
options={
  timeout = 20000  # Changed from 10000
}

# DynamoDB query limit
aws dynamodb query --limit 5  # Changed from 1
```

### Disabling Specific Tests

```bash
# Comment out in run_all_*.sh

# test_hmac || true
# test_sqs || true
# test_mailhog || true
```

---

## 📝 Logging & Debugging

### Enable Verbose Output

```bash
VERBOSE=true bash tests/run_all_local.sh
```

Output includes:
- HTTP request/response headers
- Full request/response bodies
- Timing breakdowns
- AWS API calls

### Check Artifacts

```bash
# View last submission ID
cat tests/artifacts/last_submission_id.txt

# View exported CSV
head -10 tests/artifacts/export_*.csv

# View DynamoDB item
jq . tests/artifacts/dynamo_latest.json

# View email HTML
open tests/artifacts/mailhog_latest.html

# View test summary
jq . tests/artifacts/summary.json
```

### Debug Failed Tests

```bash
# Get all failed steps
jq '.steps[] | select(.status == "FAIL")' tests/artifacts/summary.json

# Count failures
jq '[.steps[] | select(.status == "FAIL")] | length' tests/artifacts/summary.json

# Extract error info
jq '.steps[] | select(.status == "FAIL") | .info' tests/artifacts/summary.json
```

---

## 🚨 Common Issues & Solutions

### "Missing required tools"

```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install jq
brew install jq          # macOS
apt-get install jq       # Ubuntu/Debian
choco install jq         # Windows
```

### "API_KEY not configured"

```bash
# Set in .env.prod
echo "API_KEY=sk_live_..." >> tests/.env.prod

# Or export as environment variable
export API_KEY="sk_live_..."
bash tests/run_all_prod.sh
```

### "HMAC Signature Invalid"

Check:
1. Secret matches API configuration
2. Timestamp format is Unix seconds
3. Message format: `timestamp\nrawBody` (newline between)
4. Using SHA256 (not MD5 or SHA1)

```bash
# Debug HMAC
node -e "
const crypto = require('crypto');
const secret = 'test_secret';
const timestamp = Math.floor(Date.now() / 1000).toString();
const msg = timestamp + '\\n' + JSON.stringify({test: true});
const sig = crypto.createHmac('sha256', secret).update(msg).digest('hex');
console.log('Timestamp:', timestamp);
console.log('Message:', msg);
console.log('Signature:', sig);
"
```

### "DynamoDB table not found"

```bash
# Check table exists
aws dynamodb list-tables --region ap-south-1

# Check table name in .env
grep DDB_TABLE tests/.env.prod

# Verify table has items
aws dynamodb scan --table-name contact-form-submissions-v2 --limit 1 --region ap-south-1
```

---

## ✅ Acceptance Criteria Met

- [x] All test files created and documented
- [x] Environment templates provided (.env.*.example)
- [x] Local test runner (run_all_local.sh + .ps1)
- [x] Production test runner (run_all_prod.sh + .ps1)
- [x] HTTP client with HMAC support
- [x] AWS helper functions
- [x] Summary aggregation and HTML report
- [x] GitHub Actions workflow
- [x] Comprehensive README documentation
- [x] Error handling (non-blocking)
- [x] Artifact collection
- [x] Idempotent scripts
- [x] Cross-platform support (Bash + PowerShell)
- [x] No business logic changes
- [x] All steps log PASS/FAIL + duration

---

## 🎯 Next Steps

1. **Setup Environment**
   ```bash
   cp tests/.env.*.example tests/.env.*
   # Fill in your actual values
   ```

2. **Test Locally**
   ```bash
   bash tests/run_all_local.sh
   open tests/report.html
   ```

3. **Test Production**
   ```bash
   bash tests/run_all_prod.sh
   open tests/report.html
   ```

4. **Setup CI/CD**
   - Add GitHub secrets (FORMBRIDGE_API_KEY, etc.)
   - Workflow runs automatically

5. **Monitor Regularly**
   - Schedule tests (every 6 hours default)
   - Review HTML reports weekly
   - Archive successful reports

---

## 📞 Support

For issues or questions:
1. Check `tests/README.md` troubleshooting section
2. Review artifact files in `tests/artifacts/`
3. Enable verbose logging: `VERBOSE=true bash tests/run_all_local.sh`
4. Check CloudWatch logs for Lambda errors

---

## Commit Message

```
test(e2e): full local/prod test harness with HTML report, artifacts, and env templates

Add comprehensive end-to-end test suite for FormBridge:

- tests/run_all_local.sh: Local environment test runner (bash)
- tests/run_all_local.ps1: Local environment test runner (PowerShell)
- tests/run_all_prod.sh: Production environment test runner (bash)
- tests/run_all_prod.ps1: Production environment test runner (PowerShell)

Test libraries:
- lib/http_client.js: HTTP client with HMAC-SHA256 support
- lib/aws_helpers.sh: AWS helper functions (DynamoDB, SQS, SES, CloudWatch)
- lib/test_step_*.js: Individual test step executors
- lib/collect_summary.js: Test result aggregation and HTML report generation

Configuration:
- tests/.env.local.example: Local environment template
- tests/.env.prod.example: Production environment template

Documentation:
- tests/README.md: Comprehensive 500+ line guide
- Full troubleshooting, environment variables, CI/CD integration

CI/CD:
- .github/workflows/full_test.yml: GitHub Actions workflow
  - Scheduled runs (every 6 hours)
  - Manual dispatch trigger
  - PR comments with results
  - Artifact upload and retention

Features:
✓ Tests: submit, analytics, export, HMAC, email, DynamoDB, SQS
✓ Both local and production environments
✓ Non-blocking error handling (all steps run)
✓ HTML report with status and timing
✓ Artifact collection (CSV, JSON, HTML)
✓ HMAC signature validation
✓ AWS credential validation
✓ SES email statistics (production)
✓ Cross-platform support (Bash + PowerShell)
✓ Comprehensive logging and debugging

No business logic changes.
```

---

**Status:** ✅ IMPLEMENTATION COMPLETE AND READY FOR USE

All files created, tested, and ready for deployment. Start with `bash tests/run_all_local.sh` to verify your setup.
