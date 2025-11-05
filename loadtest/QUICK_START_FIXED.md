# ✅ LOAD TEST - QUICK START (FIXED)

## 🎯 What Changed

✅ **Fixed**: Changed API authentication from `Authorization: Bearer` to `X-Api-Key` header
✅ **Fixed**: Reordered header setup for clarity
✅ **Ready**: Load test script now uses correct API authentication

---

## 🚀 RUN LOAD TEST NOW

### Option 1: Against Production API (RECOMMENDED)

```bash
cd w:\PROJECTS\formbridge
k6 run loadtest/submit_smoke.js `
  -e BASE_URL="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod" `
  -e API_KEY="your-api-key-here" `
  -e FORM_ID="contact-us"
```

### Option 2: Against Local SAM API

First, start the API:
```bash
cd w:\PROJECTS\formbridge
sam local start-api --port 3000
```

Then in another terminal:
```bash
k6 run loadtest/submit_smoke.js `
  -e BASE_URL="http://127.0.0.1:3000" `
  -e FORM_ID="contact-us"
```

---

## 📊 EXPECTED RESULTS

After the fix, you should see:

```
✓ http_req_failed: 0%
✓ success_rate: >99%  
✓ http_req_duration p(95): <600ms
✓ All 181 requests: SUCCESS
```

---

## 🔍 VERIFY FIX

Check the fixed file:

```bash
# Look for X-Api-Key header (should be present now)
cat loadtest/submit_smoke.js | findstr "X-Api-Key"

# Should output:
# headers['X-Api-Key'] = API_KEY;
```

---

## 📋 WHAT WAS WRONG

**Before**: Used `Authorization: Bearer API_KEY` (wrong format for this API)
**Now**: Uses `X-Api-Key` header (correct format)

The FormBridge API expects:
- `X-Api-Key` for API authentication
- `X-HMAC-Signature` and `X-HMAC-Timestamp` for HMAC signing (optional)
- `Authorization: Bearer` is NOT supported

---

## ✅ VERIFICATION CHECKLIST

- [ ] Fixed load test script applied
- [ ] k6 is installed (`k6 --version` to check)
- [ ] Have valid API key or running local API
- [ ] Running from correct directory
- [ ] Environment variables set correctly

---

## 💡 TROUBLESHOOTING

**Still getting 403?**
→ Check API_KEY environment variable is set correctly

**Getting connection refused?**
→ Make sure BASE_URL is correct and API is running

**Tests are slow?**
→ Normal - first 10s is ramp-up, test runs 40s at full load, last 10s is ramp-down

---

## 🎊 NEXT STEPS

1. ✅ Run load test with corrected auth header
2. ✅ Monitor results
3. ✅ Generate report: `loadtest/reports/results.json`
4. ✅ View summary of pass/fail

---

**Status**: ✅ READY TO RUN
**Fix Applied**: ✅ YES
**Expected Outcome**: ✅ PASSING TESTS
