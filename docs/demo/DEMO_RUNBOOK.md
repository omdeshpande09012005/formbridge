# FormBridge Demo Runbook

**Purpose**: Step-by-step operator guide for live demo  
**Duration**: 5–8 minutes  
**Prerequisites**: Laptop with Docker, AWS CLI configured, API key, internet connection

---

## ✅ Pre-Flight Checklist (5 min before demo)

Run this checklist to ensure everything is ready:

- [ ] **AWS Credentials**: `aws sts get-caller-identity` returns your account (ap-south-1)
- [ ] **API Key**: Postman environment has `X-Api-Key` value set
- [ ] **Docker Running**: `docker ps` shows no errors
- [ ] **GitHub Pages**: Dashboard URL accessible in browser
- [ ] **Production Endpoint**: Copy/paste URL from `README_PRODUCTION.md`
- [ ] **Local Services**: LocalStack, MailHog, DynamoDB Admin ports noted (8000, 8025, 8001)
- [ ] **Email Inbox**: Check that test account is logged in and accessible
- [ ] **Postman Collections**: `FormBridge.postman_collection.json` imported, environments set
- [ ] **Terminal Windows**: Open 2–3 terminal tabs; name them (Docker, Lambda, Tests)
- [ ] **Browser Tabs**: Pre-open (1) localhost:8080 (2) localhost:8025 (MailHog) (3) localhost:8001 (DynamoDB Admin) (4) Production dashboard (5) Swagger/OpenAPI viewer

---

## 🚀 Demo Phase 1: Local Environment Setup (1 min)

**Objective**: Show that FormBridge runs locally with zero AWS costs.

### Step 1: Start Local Services

**[Terminal 1: Docker tab]**

```bash
cd w:\PROJECTS\formbridge
make local-up
```

**[Output to expect]:**

```
✓ LocalStack running (4566)
✓ MailHog running (8025)
✓ DynamoDB Admin running (8001)
✓ Frontend running (8080)
```

**[Narrate]:**

> "Docker Compose is spinning up LocalStack (mock AWS), MailHog (local SMTP), and DynamoDB Admin. This mimics production locally—no AWS charges."

**[Wait 10–15 seconds]**

### Step 2: Bootstrap Local Environment

**[Terminal 1: Docker tab]**

```bash
make local-bootstrap
```

**[Output to expect]:**

```
✓ DynamoDB table created
✓ Test data seeded (2 submissions)
✓ Ready for SAM deployment
```

**[Narrate]:**

> "Creating DynamoDB table schema and seeding with test data. Same structure as production."

**[Wait 5 seconds]**

### Step 3: Start Local Lambda API

**[Terminal 2: Lambda tab]**

```bash
cd w:\PROJECTS\formbridge
make sam-api
```

**[Output to expect]:**

```
Running on http://127.0.0.1:3000
Press CTRL+C to quit
```

**[Narrate]:**

> "SAM is now serving Lambda locally on port 3000. Same API as production, but fast local iteration."

---

## 🎬 Demo Phase 2: Local Form Submission (1.5 min)

**Objective**: Show form → database → email loop locally.

### Step 1: Open Dashboard

**[Browser: Tab 1]**

Navigate to `http://localhost:8080` (or localhost:8080/dashboard)

**[Visual]:**
- Dashboard loads, shows "0 submissions" (local fresh start)

**[Narrate]:**

> "Here's the analytics dashboard running locally. No submissions yet."

### Step 2: Submit a Test Form

**[If there's a form page]:**

1. Scroll to contact form
2. Fill in:
   - Name: "Demo User"
   - Email: "demo@example.com"
   - Message: "Testing FormBridge locally"
3. Click "Submit"

**[Or use cURL]:**

```bash
curl -X POST http://127.0.0.1:3000/submit \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: local-test-key" \
  -d '{
    "form_id": "my-portfolio",
    "name": "Demo User",
    "email": "demo@example.com",
    "message": "Testing FormBridge locally"
  }'
```

**[Expected response]:**

```json
{
  "id": "my-portfolio#1731800000000",
  "message": "Submission recorded and email queued"
}
```

**[Narrate]:**

> "Submission successful. Returned an ID. Form data is now in DynamoDB, and SES has queued an email."

### Step 3: Verify in DynamoDB Admin

**[Browser: Tab 3 - DynamoDB Admin]**

Navigate to `http://localhost:8001`

1. Select table: `contact-form-submissions-v2`
2. Click "Scan"
3. **[Point to the new row]**: "Here's the submission: UUID, form_id, email, timestamp, IP address, user agent."

**[Narrate]:**

> "DynamoDB stores every submission with metadata: who, when, where, what browser. Perfect for analytics and compliance."

### Step 4: Verify Email in MailHog

**[Browser: Tab 2 - MailHog]**

Navigate to `http://localhost:8025`

**[Visual]:**
- Inbox shows 1 message
- Sender: notification@formbridge.local
- Subject: "New form submission from demo@example.com"

**[Click to open email]**

**[Narrate]:**

> "Email was delivered instantly to the local MailHog service. In production, this goes to real AWS SES and reaches your actual inbox."

### Step 5: Check Dashboard Update

**[Browser: Tab 1 - Dashboard]**

Refresh or wait 30 seconds (auto-refreshes)

**[Visual]:**
- KPI shows "1 submission"
- 7-day chart shows 1 data point

**[Narrate]:**

> "Dashboard updated automatically. The analytics pipeline works: submission → stored → counted → displayed. Complete feedback loop in <5 seconds."

---

## 🌐 Demo Phase 3: Production Test (1.5 min)

**Objective**: Show the same flow on AWS (production endpoint).

### Step 1: Open Postman (Prod Environment)

**[Postman window]**

1. Select environment: **FormBridge.Prod**
2. Select request: **Submit** (in Forms folder)
3. **[Visual]**: Show that `{{base_url}}` resolves to production endpoint
4. Show `X-Api-Key` header is set

**[Narrate]:**

> "Switching to production. Postman is configured to hit the AWS API Gateway endpoint. Same request format, real endpoint."

### Step 2: Send Submission to Production

**[Postman]**

Click **Send**

**[Expected response]:**

```
Status: 200 OK
{
  "id": "my-portfolio#<unix-timestamp>",
  "message": "Submission recorded and email queued"
}
```

**[Narrate]:**

> "Status 200. Submission was recorded in production DynamoDB and SES queued the email. Let's verify it arrived."

### Step 3: Check Real Email (Dev Inbox)

**[Browser or email client]**

Open your email (Gmail, etc.)

**[Wait 3–5 seconds, refresh]**

**[Visual]:**
- New email from notification@formbridge.local or your configured sender
- Subject: "New form submission from [test email]"
- **[Click to open]**: Show submission details in email body

**[Narrate]:**

> "Email arrived in production. FormBridge sent it via AWS SES. The whole loop: form → API Gateway → Lambda → DynamoDB + SES → your inbox. End-to-end, <1 second."

---

## 📊 Demo Phase 4: Analytics & CSV Export (1 min)

**Objective**: Show data retrieval and export.

### Step 1: Production Dashboard

**[Browser: Production Dashboard tab]**

Navigate to your production dashboard URL  
(e.g., `https://omdeshpande09012005.github.io/dashboard/`)

**[Visual]:**
- KPI tiles: "Total submissions", "Today", "7-day breakdown"
- Line chart: 7-day trend
- If data exists: shows recent submissions

**[Narrate]:**

> "Production dashboard pulls analytics via the `/analytics` endpoint. Real data from DynamoDB. Updates automatically every 30 seconds."

### Step 2: CSV Export

**[Browser: Dashboard]**

1. **[Click "Download CSV"]** (if button exists)
2. Or use cURL:

```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export \
  -H "X-Api-Key: your-api-key" \
  -d '{"form_id":"my-portfolio","days":7}' \
  -o submissions.csv
```

**[Visual]:**
- File downloads: `formbridge_my-portfolio_7d_20251105.csv`
- Open in Excel/Google Sheets
- Show columns: id, form_id, name, email, message, page, ip, ua, ts

**[Narrate]:**

> "CSV export is useful for reports, importing to Sheets or Salesforce, or compliance. One-click download of all submissions."

---

## 🔐 Demo Phase 5: Security Verification (1 min)

**Objective**: Show that security layers work.

### Test 1: Request Without API Key

**[Postman or cURL]**

```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "my-portfolio",
    "message": "test"
  }'
```

**[Expected response]:**

```
Status: 403 Forbidden
{
  "message": "Forbidden"
}
```

**[Narrate]:**

> "No API key → 403 Forbidden. API Gateway blocks it. This prevents unauthorized use."

### Test 2: Request With Valid API Key

**[Postman]**

Same request but with `X-Api-Key` header set

**[Click Send]**

**[Expected response]:**

```
Status: 200 OK
```

**[Narrate]:**

> "With the key → 200 OK. Accepted. Security is working as designed: valid key = access, no key = denied."

### Test 3: View OpenAPI Spec

**[Browser: Swagger/OpenAPI tab]**

Navigate to `https://omdeshpande09012005.github.io/swagger/` (or local deployment)

**[Visual]:**
- Shows `/submit`, `/analytics`, `/export` endpoints
- Highlights required headers (X-Api-Key, Content-Type)
- Shows request/response schemas

**[Narrate]:**

> "This is the OpenAPI specification—machine-readable API documentation. Useful for code generation, testing, and integrations."

---

## ⚠️ Failure Drills (Optional, 1 min)

**Objective**: Demonstrate graceful error handling.

### Drill 1: Force HMAC Failure (if HMAC enabled)

**[If HMAC_ENABLED=true in Lambda]:**

```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "X-Api-Key: your-key" \
  -H "X-Timestamp: 1234567890" \
  -H "X-Signature: invalid-signature" \
  -d '{"form_id":"test","message":"hi"}'
```

**[Expected response]:**

```
Status: 401 Unauthorized
{
  "error": "invalid signature"
}
```

**[Narrate]:**

> "Invalid HMAC signature → 401. Request rejected. This prevents tampering."

### Drill 2: Rate Limit (Usage Plan)

**[Send 10+ requests rapidly]:**

```bash
for i in {1..15}; do
  curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
    -H "X-Api-Key: your-key" \
    -d '{"form_id":"test","message":"'$i'"}' &
done
```

**[After quota exceeded]:**

```
Status: 429 Too Many Requests
{
  "message": "Throttling limit exceeded"
}
```

**[Narrate]:**

> "After hitting rate limit → 429. Usage plan is enforcing quotas. Protects against spam and DDoS."

### Drill 3: CloudWatch Alarm Trigger (Optional)

**[AWS Console or CLI]:**

```bash
aws cloudwatch test-alarm-actions \
  --alarm-names FormBridge-Lambda-Errors \
  --state-reason "Demo test" \
  --region ap-south-1
```

**[Expected]:**
- SNS notification sent to configured email
- **[Check email]**: Alarm notification arrived

**[Narrate]:**

> "Alarms are configured to notify on Lambda errors, API Gateway 5XX, and DynamoDB throttles. Proactive monitoring."

---

## 📋 Troubleshooting During Demo

| Issue | Quick Fix |
|-------|-----------|
| Local services won't start | `docker system prune`, then `make local-up` |
| Lambda API won't start | Kill existing process: `lsof -i :3000` → kill PID |
| MailHog not receiving email | Check Lambda logs: `sam logs -t` |
| Postman 403 on all requests | Verify `X-Api-Key` is in environment variables |
| Production dashboard shows no data | Check API endpoint in dashboard config matches prod URL |
| DynamoDB Admin page won't load | Ensure LocalStack is running: `docker ps` |
| Email not arriving in inbox | Check SES sandbox/production status, verify sender domain |

---

## 🎬 Live Demo Quick Reference

**Copy/paste commands:**

```bash
# Local setup
make local-up
make local-bootstrap
make sam-api

# Local test
curl -X POST http://127.0.0.1:3000/submit \
  -H "X-Api-Key: local-key" \
  -d '{"form_id":"test","message":"hi"}'

# Prod test (use Postman)
# Or:
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "X-Api-Key: <your-key>" \
  -d '{"form_id":"my-portfolio","message":"demo"}'

# CSV export
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export \
  -H "X-Api-Key: <your-key>" \
  -d '{"form_id":"my-portfolio","days":7}' \
  -o submissions.csv

# No API key (expect 403)
curl https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit
```

---

**Status**: ✅ Ready for Live Demo  
**Last Updated**: November 5, 2025

