# FormBridge Status Page

Public real-time health monitoring for FormBridge API with automated checks every 15 minutes.

## 📊 Overview

The Status Page provides:

- **Real-time Status Badge**: UP / DEGRADED / DOWN with color indicators
- **Live Metrics**: HTTP response code, latency, region, endpoint
- **History Sparkline**: Last 20 API health checks visualized as interactive chart
- **Automatic Updates**: GitHub Actions workflow pings API every 15 minutes
- **Zero Downtime**: Fully static site hosted on GitHub Pages

**Status Page URL**: `https://omdeshpande09012005.github.io/formbridge/docs/status/`

---

## 🚀 Quick Setup

### 1. Add GitHub Secret

Add your Prod API key as a GitHub Secret so the workflow can authenticate:

```bash
# In GitHub UI: Settings → Secrets and variables → Actions
# Name: STATUS_API_KEY
# Value: (your Prod API key, see below)
```

**Getting your API Key**:

```bash
# Option 1: From AWS Systems Manager (SSM)
aws ssm get-parameter --name /formbridge/prod/api-key --with-decryption --query 'Parameter.Value' --output text

# Option 2: From the lambda environment variables (if you have access)
aws lambda get-function-configuration --function-name contactFormProcessor --query 'Environment.Variables.API_KEY_PROD' --output text
```

### 2. Verify Workflow Runs

```bash
# Option A: Wait for next scheduled run (15-min cron)
# Check: GitHub → Actions → "FormBridge Status Check"

# Option B: Trigger manually
# Click: Actions → "FormBridge Status Check" → Run workflow
```

### 3. Check Status Page

Navigate to: `https://omdeshpande09012005.github.io/formbridge/docs/status/`

Expected output:
```
✓ UP badge with green color
✓ HTTP 200 displayed
✓ Latency: ~100-300ms
✓ Region: ap-south-1
✓ History sparkline with green bars
```

---

## ⚙️ Configuration

### Status Thresholds

The workflow determines status based on:

| Condition | Status | Color |
|-----------|--------|-------|
| HTTP 200 + Latency < 700ms | **UP** | 🟢 Green |
| HTTP 200 + Latency ≥ 700ms | **DEGRADED** | 🟡 Amber |
| HTTP 429 (rate limit) | **DEGRADED** | 🟡 Amber |
| Any other HTTP code | **DOWN** | 🔴 Red |
| Connection timeout | **DOWN** | 🔴 Red |

### Adjusting Thresholds

Edit `.github/workflows/status.yml`:

```yaml
# Current: line ~75
if [ "$HTTP_CODE" = "200" ] && [ "$LATENCY_MS" -lt 700 ]; then
  STATUS="UP"

# Example: Make stricter (500ms = more alerts)
if [ "$HTTP_CODE" = "200" ] && [ "$LATENCY_MS" -lt 500 ]; then
  STATUS="UP"
```

### History Retention

Max entries kept in `docs/status/status.json`:

```yaml
# Current: line ~2
MAX_HISTORY_ENTRIES: 200
```

At 15-minute intervals, this retains **50 hours** of history.

---

## 📂 Files

| File | Purpose |
|------|---------|
| `docs/status/index.html` | Static status page UI |
| `docs/status/status.json` | Machine-readable status data (auto-updated by workflow) |
| `.github/workflows/status.yml` | Health check automation |
| `docs/STATUS_README.md` | This documentation |

### status.json Structure

```json
{
  "updated_at": "2025-11-05T12:34:56Z",
  "endpoint": "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/analytics",
  "region": "ap-south-1",
  "status": "UP|DEGRADED|DOWN",
  "http_code": 200,
  "latency_ms": 125,
  "history": [
    {
      "t": "2025-11-05T12:30:00Z",
      "code": 200,
      "lat": 110,
      "s": "UP"
    },
    ...
  ]
}
```

---

## 🛠️ Troubleshooting

### Status Page shows "Failed to load status data"

**Cause**: `status.json` not accessible or workflow hasn't run yet.

**Fix**:
```bash
# 1. Verify file exists and is valid JSON
cat docs/status/status.json | jq '.'

# 2. Run workflow manually
# GitHub → Actions → "FormBridge Status Check" → Run workflow

# 3. Check for errors
# GitHub → Actions → Last run → View logs
```

### Workflow fails with "403" or "404"

**Cause**: API key invalid or endpoint wrong.

**Fix**:
```bash
# 1. Verify API key in GitHub Secrets
# GitHub → Settings → Secrets → STATUS_API_KEY

# 2. Test endpoint manually
curl -X POST \
  "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/analytics" \
  -H "X-Api-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"analytics","test":true}'

# Expected: 200 response with analytics data or error
```

### Status shows "DOWN" when API is UP

**Cause**: 
- Timeout (default 10s)
- Rate limiting (HTTP 429)
- Latency > 700ms

**Fix**:
```bash
# Check actual latency
time curl -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/analytics" \
  -H "X-Api-Key: YOUR_KEY" \
  -d '{"action":"analytics","test":true}'

# If latency > 700ms consistently, adjust threshold in workflow
# If 429 errors, workflow is treating as DEGRADED (correct behavior)
```

### Page shows outdated timestamp

**Cause**: Workflow hasn't run in 15+ minutes (scheduled, not running).

**Fix**:
```bash
# 1. Check workflow schedule is enabled
# GitHub → Actions → "FormBridge Status Check" → Enable

# 2. Trigger manually
# Actions tab → "FormBridge Status Check" → Run workflow

# 3. Check for errors in logs
# Actions → Last run → Logs
```

---

## 🔒 Security

### Secrets Protection

❌ **Never** commit `STATUS_API_KEY` to repository
❌ **Never** hardcode keys in workflow files
✅ Use GitHub Secrets (`${{ secrets.STATUS_API_KEY }}`)
✅ Keys are masked in logs automatically

### Network Security

- Workflow uses HTTPS only
- Timeout: 10 seconds (prevents hanging)
- Connection timeout: 5 seconds
- No secrets logged (GitHub masks them)

---

## 📈 Monitoring the Monitor

To check if the workflow itself is working:

```bash
# View all workflow runs
gh run list --workflow=status.yml

# View latest run details
gh run list --workflow=status.yml --limit 5

# View logs of specific run
gh run view <RUN_ID> --log
```

Or via GitHub UI:
- GitHub → Actions tab
- Select "FormBridge Status Check"
- Click any run to see logs

---

## 🔄 Manual Testing

Test the health check locally before relying on automation:

```bash
# 1. Get your API key
API_KEY=$(aws ssm get-parameter --name /formbridge/prod/api-key --with-decryption --query 'Parameter.Value' --output text)

# 2. Run health check
curl -v -X POST \
  "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/analytics" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"action":"analytics","test":true}'

# Expected output:
# < HTTP/1.1 200 OK
# (followed by analytics data)
```

---

## ⏸️ Pausing Checks

To temporarily disable status checks:

### Option 1: Disable Workflow (Fastest)
```bash
# GitHub → Actions → "FormBridge Status Check" → (⋮) → Disable workflow
```

### Option 2: Edit Schedule
```bash
# Edit .github/workflows/status.yml
# Change cron to less frequent or commented out:
# - cron: '0 0 * * *'  # Daily instead of every 15 min
```

### Option 3: Remove Schedule
```bash
# Keep workflow_dispatch only (manual trigger only):
on:
  workflow_dispatch:
```

---

## 📊 Expected Behavior

### First Run
```
1. Workflow triggers (scheduled or manual)
2. Pings API endpoint → Gets 200 response
3. Measures latency: ~100-300ms
4. Computes status: UP
5. Appends to history
6. Commits status.json
7. Page refreshes and shows new data
```

### Subsequent Runs (Every 15 minutes)
```
1. Workflow pings API
2. Appends new history entry
3. Keeps last 200 entries (~50 hours)
4. Only commits if data changed
5. Page auto-refreshes every 30 seconds
```

---

## 🔗 Related Links

- [FormBridge API Docs](https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/swagger/)
- [Analytics Dashboard](../dashboard/)
- [Main README](../../README_PRODUCTION.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

## ✅ Checklist

Before deploying to production:

- [ ] GitHub Secret `STATUS_API_KEY` added
- [ ] API key has valid Prod permissions
- [ ] Endpoint is accessible (test with curl)
- [ ] Workflow runs successfully (manual trigger works)
- [ ] Status page displays data
- [ ] History sparkline appears
- [ ] Links (Swagger, Dashboard) work
- [ ] Page auto-refreshes (30s interval)
- [ ] Mobile responsive (test on phone)

---

## 🐛 Debugging

### Enable debug output
```bash
# Add to workflow (temporary)
name: enable debug output
run: echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
```

### Test JSON parsing
```bash
# Verify status.json is valid
jq '.' docs/status/status.json

# Extract specific fields
jq '.status, .http_code, .latency_ms' docs/status/status.json

# Count history entries
jq '.history | length' docs/status/status.json
```

---

## 📞 Support

For issues:

1. Check this guide's Troubleshooting section
2. View workflow logs: GitHub → Actions → Status Check → Latest run
3. Test endpoint manually with provided curl commands
4. Review status.json for most recent data
5. Check GitHub Secrets configuration

---

**Status Page Created**: November 5, 2025  
**Last Updated**: November 5, 2025  
**Maintenance**: Automated via GitHub Actions
