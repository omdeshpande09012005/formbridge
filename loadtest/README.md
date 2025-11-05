# FormBridge k6 Load Testing Suite

Comprehensive load testing suite for FormBridge using [k6](https://k6.io/). Tests validate API stability, latency, and behavior under load including throttling scenarios.

## 📋 Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Running Tests](#running-tests)
- [Understanding Reports](#understanding-reports)
- [SLOs & Performance Targets](#slos--performance-targets)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

## Installation

### macOS (Homebrew)

```bash
brew install k6
```

### Linux (Debian/Ubuntu)

```bash
sudo gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg < <(curl -s https://dl.k6.io/key.gpg)
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### Windows (Chocolatey)

```powershell
choco install k6
```

### Windows (Manual Download)

If Chocolatey has permission issues:

```powershell
# Download from GitHub Releases
$url = "https://github.com/grafana/k6/releases/download/v0.49.0/k6-v0.49.0-windows-amd64.zip"
Invoke-WebRequest -Uri $url -OutFile k6.zip
Expand-Archive -Path k6.zip -DestinationPath .
# k6.exe is now available in the extracted folder
```

### Verify Installation

```bash
k6 --version
# Output: k6 vX.XX.X (...)
```

## Configuration

### Step 1: Create .env file

```bash
cp loadtest/.env.example loadtest/.env
```

### Step 2: Set Environment Variables

**For Local Development (DEV):**

```env
BASE_URL=http://127.0.0.1:3000
API_KEY=
FORM_ID=my-portfolio
HMAC_ENABLED=false
HMAC_SECRET=
```

**For Production (PROD):**

```env
BASE_URL=https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod
API_KEY=your-api-key-here
FORM_ID=my-portfolio
HMAC_ENABLED=true
HMAC_SECRET=your-hmac-secret-here
```

### Step 3: Load Environment

```bash
# Linux/macOS
export $(cat loadtest/.env | grep -v '#' | xargs)

# Windows PowerShell
Get-Content loadtest/.env | Where-Object {$_ -notmatch '^#' -and $_ -match '='} | ForEach-Object {
    $key, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($key, $value)
}
```

## Running Tests

### Smoke Test (Sanity Check)

Quick 1-minute test with 1–2 virtual users. Perfect for CI/CD.

```bash
k6 run loadtest/submit_smoke.js
```

**Expected Output:**
- Success rate ≥ 99%
- P95 latency < 600ms
- All requests complete without timeout

**Report:** HTML and CSV files generated in `loadtest/reports/`

### Spike Test (Load Simulation)

Ramps up to 50 VUs to simulate traffic spike. Tests throttling behavior.

```bash
k6 run loadtest/submit_spike.js
```

**Expected Output:**
- Success rate ≥ 99% (429 responses counted as success)
- P95 latency < 600ms
- 429 (Too Many Requests) errors visible under load
- No 5xx errors

**Key Metrics:**
- `throttled_requests` counter: Number of 429 responses

### Analytics Read Test

Read-only test running 5 VUs constantly for 2 minutes. Verifies analytics endpoint stays fast.

```bash
k6 run loadtest/analytics_read.js
```

**Expected Output:**
- Success rate ≥ 99%
- P95 latency < 300ms (stricter than write tests)
- Consistent response times

### Running All Tests Sequentially

```bash
# Linux/macOS
#!/bin/bash
echo "Running Smoke Test..."
k6 run loadtest/submit_smoke.js

echo "Running Spike Test..."
k6 run loadtest/submit_spike.js

echo "Running Analytics Read Test..."
k6 run loadtest/analytics_read.js

# Windows PowerShell
Write-Host "Running Smoke Test..."
k6 run loadtest/submit_smoke.js

Write-Host "Running Spike Test..."
k6 run loadtest/submit_spike.js

Write-Host "Running Analytics Read Test..."
k6 run loadtest/analytics_read.js
```

## Understanding Reports

### HTML Reports

Located in `loadtest/reports/results-*.html`

**Sections:**
- **Success Rate:** Percentage of requests that returned 2xx/3xx (or 429 in spike)
- **P95/P99 Latency:** 95th and 99th percentile response times (milliseconds)
- **Response Codes Histogram:** Breakdown of all HTTP status codes received
- **Key Metrics:** Summary table of all performance metrics

**Color Coding:**
- 🟢 **Green:** Success (2xx/3xx)
- 🟡 **Yellow:** Throttling (429)
- 🔴 **Red:** Errors (5xx)

### CSV Reports

Located in `loadtest/reports/results-*.csv`

Tab-separated format for import into spreadsheets or monitoring systems.

### Understanding Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| **200-299** | Success | Expected for all smoke/spike submissions |
| **300-399** | Redirect | May occur in pre-flight checks |
| **429** | Too Many Requests | **Expected under heavy load** when exceeding API Gateway usage plan; indicates throttling is working correctly |
| **4xx** | Client Error | Investigate request format or authentication |
| **5xx** | Server Error | Critical; verify Lambda execution in CloudWatch |

### Expected Behavior

**Smoke Test (1–2 VUs, 1 min):**
- All 2xx/3xx responses
- Zero 429 errors
- P95 < 600ms

**Spike Test (0→50 VUs):**
- Mostly 2xx/3xx responses
- **Some 429 errors expected** (when API Gateway plan is exceeded)
- P95 < 600ms
- Zero or minimal 5xx errors

**Analytics Read (5 VUs, 2 min):**
- All 2xx responses
- P95 < 300ms

## SLOs & Performance Targets

### Submit Endpoint

- **Success Rate:** ≥ 99%
- **P95 Latency:** < 600ms (production)
- **P99 Latency:** < 1000ms
- **Error Budget:** ≤ 1% non-2xx (excluding 429)

### Analytics Endpoint

- **Success Rate:** ≥ 99%
- **P95 Latency:** < 300ms (stricter for read operations)
- **P99 Latency:** < 500ms
- **Error Budget:** ≤ 1% non-2xx

### Throttling (API Gateway)

- **Expected:** 429 responses appear beyond API Gateway usage plan (typically 10,000 requests/month on free tier)
- **Not an Error:** 429 is a throttling signal, not a failure
- **Action:** Configure usage plans in API Gateway if production traffic exceeds plan

## CI/CD Integration

### GitHub Actions

Smoke test runs automatically on every push to main. See `.github/workflows/loadtest.yml`

**Triggers:**
- Push to main branch
- Manual workflow dispatch

**Artifacts:**
- HTML report
- CSV report

**Duration:** ~60–90 seconds

**Example Workflow:**

```yaml
name: Load Test

on: [push]

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install k6
        run: sudo apt-get update && sudo apt-get install -y k6
      
      - name: Create .env
        run: |
          cat > loadtest/.env << EOF
          BASE_URL=${{ secrets.LOADTEST_BASE_URL }}
          API_KEY=${{ secrets.LOADTEST_API_KEY }}
          FORM_ID=my-portfolio
          HMAC_ENABLED=false
          EOF
      
      - name: Run Smoke Test
        run: k6 run loadtest/submit_smoke.js
      
      - name: Upload Reports
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: k6-reports
          path: loadtest/reports/
```

## Cost Considerations

### API Gateway (AWS)

- **Free Tier:** 1M requests/month (includes 429 throttles)
- **After Free Tier:** $3.50 per million requests
- **Usage Plan (Optional):** $10/month for usage plan quota

### CloudWatch Logs

- **Free Tier:** 5GB ingestion/month
- **k6 Tests Typical:** <100KB per test run

**Recommendation:** Keep local test runs short (1–2 minutes). Use CI smoke tests only; spike tests manually during staging.

## Troubleshooting

### Issue: "k6 command not found"

**Solution:** Reinstall k6 or add to PATH:

```bash
# macOS/Linux
export PATH=$PATH:/usr/local/bin

# Windows: Ensure k6.exe is in System32 or in PATH
```

### Issue: "Environmental variable not set"

**Solution:** Ensure .env file is sourced:

```bash
# Verify:
echo $BASE_URL

# If empty, source manually:
export $(cat loadtest/.env | xargs)
```

### Issue: "Cannot connect to endpoint"

**Solution:** Verify endpoint is running:

```bash
# Test endpoint
curl -X POST http://127.0.0.1:3000/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test"}'

# Expected: 2xx or 429, not connection error
```

### Issue: "High latency (P95 > 600ms)"

**Causes & Solutions:**
1. **Endpoint Overload:** Reduce concurrent VUs or run during off-peak
2. **Network Latency:** Check ping to endpoint
3. **Lambda Cold Start:** First requests may be slower; smoke test warms up

### Issue: "429 Errors in Spike Test"

**This is Expected!** Indicates:
- API Gateway usage plan is correctly limiting requests
- Throttling is protecting your backend

**Action:** Configure higher usage plan in AWS API Gateway if needed for production spike scenarios.

### Issue: "Reports not generating"

**Solution:** Check permissions on `loadtest/reports/` directory:

```bash
# Create if missing
mkdir -p loadtest/reports
chmod 755 loadtest/reports

# Re-run test
k6 run loadtest/submit_smoke.js
```

## Advanced Usage

### Custom Test Scenarios

Edit test files (e.g., `submit_spike.js`) to modify:
- Duration
- Virtual users
- Payload

### Monitoring in Real-Time

k6 integrates with Grafana Cloud for live dashboards:

```bash
k6 run --vus 10 --duration 1m loadtest/submit_smoke.js \
  --out cloud \
  -u USERNAME -p PASSWORD
```

### Running Tests Against Staging

```bash
BASE_URL=https://staging.example.com \
API_KEY=staging-key \
k6 run loadtest/submit_smoke.js
```

## FAQ

**Q: Can I run multiple tests simultaneously?**  
A: Not recommended. Each test reserves system resources. Run sequentially or on separate machines.

**Q: Should I run spike tests in production?**  
A: Only during maintenance windows or with AWS support. Use staging instead.

**Q: What if I exceed the API Gateway free tier?**  
A: Enable usage plan for $10/month or use AWS Lambda@Edge for request filtering.

**Q: Can I test authentication?**  
A: Yes! Set API_KEY and HMAC_ENABLED in .env.

**Q: How do I share reports with the team?**  
A: HTML reports are portable. Download from CI artifacts or email the .html file.

## References

- [k6 Documentation](https://k6.io/docs/)
- [k6 API Reference](https://k6.io/docs/javascript-api/)
- [AWS API Gateway Throttling](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html)
- [HTTP Status Codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)

## Support

For issues:
1. Check logs: `k6 run --verbose loadtest/submit_smoke.js`
2. Review AWS CloudWatch for Lambda errors
3. Check API Gateway throttling metrics in AWS Console

---

**Last Updated:** November 5, 2025  
**k6 Version:** v0.49.0+  
**Maintained by:** FormBridge Team
