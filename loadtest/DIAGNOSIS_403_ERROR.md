# 🔴 LOAD TEST 403 ERROR DIAGNOSIS

**Issue**: Load test (submit_smoke.js) is getting 403 Forbidden responses
**Root Cause**: Missing or incorrect API authentication headers

---

## 📊 TEST OUTPUT SUMMARY

```
Running 1m0s test with 2 VUs (virtual users)
✗ FAILED: All 181 requests returned 403 Forbidden
✗ Thresholds breached:
  - p(95) latency: 795ms (threshold: <600ms)
  - success_rate: 32.59% (threshold: >99%)
```

---

## 🔍 ROOT CAUSE ANALYSIS

### What the test is doing wrong:

1. **Wrong Auth Header Format**
   - Current: `Authorization: Bearer API_KEY`
   - Expected: `X-Api-Key: YOUR_API_KEY`

2. **HMAC Requirements**
   - API expects HMAC-SHA256 signatures on all requests
   - Headers needed: `X-HMAC-Timestamp`, `X-HMAC-Signature`
   - Currently: Only added if HMAC_ENABLED=true (not set by default)

3. **Configuration Issue**
   - API_KEY environment variable not passed to load test
   - HMAC_ENABLED not set to true
   - BASE_URL points to local (127.0.0.1:3000) but API may not be running

---

## ✅ SOLUTION: Fix Load Test Configuration

### Step 1: Check if API is running

```bash
# Test if local API is accessible
curl -I http://127.0.0.1:3000/submit

# Expected response: Should work or error with actual response (not 403)
```

### Step 2: Set proper environment variables for load test

```bash
# For LOCAL testing (SAM local API):
k6 run loadtest/submit_smoke.js \
  --vus 2 \
  --duration 1m \
  -e BASE_URL="http://127.0.0.1:3000" \
  -e API_KEY="your-demo-api-key" \
  -e FORM_ID="contact-us" \
  -e HMAC_ENABLED="false"

# For PRODUCTION testing (AWS API Gateway):
k6 run loadtest/submit_smoke.js \
  --vus 2 \
  --duration 1m \
  -e BASE_URL="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod" \
  -e API_KEY="your-production-api-key" \
  -e FORM_ID="contact-us" \
  -e HMAC_ENABLED="true" \
  -e HMAC_SECRET="your-hmac-secret"
```

### Step 3: Fix the load test script (submit_smoke.js)

The script needs to use the correct header format for API key:

**Current (WRONG):**
```javascript
if (API_KEY) {
  headers['Authorization'] = 'Bearer ' + API_KEY;
}
```

**Should be:**
```javascript
if (API_KEY) {
  headers['X-Api-Key'] = API_KEY;
}
```

---

## 🛠️ QUICK FIX: Run Load Test Against Production API

If your production API is live, run:

```bash
k6 run loadtest/submit_smoke.js \
  -e BASE_URL="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod" \
  -e API_KEY="your-api-key" \
  -e FORM_ID="contact-us"
```

This should work because:
- Production API is fully configured
- API Gateway is handling authentication
- No 403 errors (assuming API key is valid)

---

## 🔐 AUTHENTICATION OPTIONS

### Option A: No Authentication (LOCAL DEV)
```bash
k6 run loadtest/submit_smoke.js \
  -e BASE_URL="http://127.0.0.1:3000" \
  -e FORM_ID="test-form"
```

### Option B: API Key Only
```bash
k6 run loadtest/submit_smoke.js \
  -e BASE_URL="https://api.example.com" \
  -e API_KEY="test-key" \
  -e HMAC_ENABLED="false"
```

### Option C: HMAC Signing (Recommended for Production)
```bash
k6 run loadtest/submit_smoke.js \
  -e BASE_URL="https://api.example.com" \
  -e API_KEY="test-key" \
  -e HMAC_ENABLED="true" \
  -e HMAC_SECRET="your-secret"
```

---

## 📋 DEBUGGING STEPS

1. **Verify API is running**
   ```bash
   curl -X POST http://127.0.0.1:3000/submit \
     -H "Content-Type: application/json" \
     -d '{"form_id":"test","name":"Test"}'
   ```

2. **Check if local SAM API is running**
   ```bash
   sam local start-api --port 3000
   ```

3. **Test with valid API key**
   ```bash
   curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
     -H "Content-Type: application/json" \
     -H "X-Api-Key: YOUR_API_KEY" \
     -d '{"form_id":"contact-us","name":"Test"}'
   ```

---

## 🎯 NEXT STEPS

1. ✅ Start local SAM API or use production URL
2. ✅ Get valid API key
3. ✅ Run load test with correct environment variables
4. ✅ Monitor results

---

## 📊 EXPECTED SUCCESS CRITERIA

After fix, the test should show:
```
✓ http_req_failed: 0% (no 403 errors)
✓ success_rate: >99%
✓ p(95) latency: <600ms
✓ All 181 requests successful
```

---

**Status**: 🔴 NEEDS FIX
**Priority**: HIGH
**Action**: Run load test against production API or start local SAM API with proper auth
