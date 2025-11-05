# FormBridge Screenshot Shot List

**Purpose**: Precise shots to capture for demo pack  
**Resolution**: 1080p landscape (1920×1080 recommended)  
**Theme**: Consistent with portfolio (light or dark, pick one)  
**Location**: Save to `/docs/screenshots/`

---

## 📸 Naming Convention

**Format**: `NN_category_description.png`

Example: `01_dashboard_kpis_overview.png`, `02_api_postman_success_200.png`

---

## 📋 Shot List (14 Essential Captures)

### **Category: Dashboard (4 shots)**

| # | Shot | Where to Click | What to Show | Notes |
|---|------|--------|-------------|-------|
| **01** | Dashboard Overview | Navigate to prod dashboard URL | KPI tiles visible: "Total", "Today", "7-Day" | Light background, full screen, no tooltips |
| **02** | 7-Day Chart | (Same screen, scroll down) | Line chart showing 7-day trend | Ensure data points visible (at least 5 days with submissions) |
| **03** | Recent Submissions Table | (Same screen, scroll down) | Table showing last 5 submissions (id, date, email) | Timestamps and emails visible |
| **04** | CSV Download Button | (Same screen) | Highlight the "Download CSV" button or export icon | Show button is interactive (cursor hover state) |

---

### **Category: API & Postman (4 shots)**

| # | Shot | Where to Click | What to Show | Notes |
|---|------|--------|-------------|-------|
| **05** | Postman Success (200 OK) | Open Postman, select "Submit" request, send with API key | Response shows 200 OK, JSON body with submission ID | Show Headers + Body tabs, highlight status code |
| **06** | Postman Failure (403 No Key) | Same request, but remove X-Api-Key header, send | Response shows 403 Forbidden, error message | Show status clearly, demonstrate security |
| **07** | OpenAPI/Swagger UI | Navigate to https://omdeshpande09012005.github.io/swagger/ | Full page showing endpoints: /submit, /analytics, /export | Light/dark theme consistent, endpoints expanded |
| **08** | Postman Environment Variables | Open "Manage Environments" → "FormBridge.Prod" | Show variables: base_url, api_key, form_id, hmac_enabled, hmac_secret | Ensure sensitive values are shown (or masked for security) |

---

### **Category: Data & Storage (3 shots)**

| # | Shot | Where to Click | What to Show | Notes |
|---|------|--------|-------------|-------|
| **09** | DynamoDB Table Items | DynamoDB Admin or AWS Console → contact-form-submissions-v2 table, Scan | Items visible with pk, sk, name, email, message, timestamp, ip, ua | Show 3–5 items, column headers visible |
| **10** | CSV File (Excel/Sheets) | Open downloaded CSV in Excel or Google Sheets | Spreadsheet with columns: id, form_id, name, email, message, page, ip, ua, ts | Data populated, rows visible, no errors |
| **11** | Email Notification | Open email client or MailHog | Email from FormBridge sender, subject line, body showing submission details | Show "From", "To", "Subject", and body preview |

---

### **Category: Monitoring & Alarms (2 shots)**

| # | Shot | Where to Click | What to Show | Notes |
|---|------|--------|-------------|-------|
| **12** | CloudWatch Alarms Dashboard | AWS Console → CloudWatch → Alarms | List of alarms: Lambda Errors, API Gateway 5XX, DynamoDB Throttles, SES Bounce/Complaint | Show alarm states (OK or breached), status visible |
| **13** | CloudWatch Logs | AWS Console → Logs → /aws/lambda/contactFormProcessor, view recent entries | Log entries showing recent submissions, success messages, timestamps | Scroll to show multiple entries, no sensitive data exposed |

---

### **Category: Infrastructure (1 shot)**

| # | Shot | Where to Click | What to Show | Notes |
|---|------|--------|-------------|-------|
| **14** | API Gateway Usage Plan | AWS Console → API Gateway → API Keys or Usage Plans | Show rate limit: 10000 requests/day (or configured value), API key status (ACTIVE) | Highlight quota and throttle settings |

---

## 🎨 Framing Tips

### **General**
- ✅ **Resolution**: 1920×1080 (full HD landscape)
- ✅ **Zoom Level**: 100% (no browser zoom-in/out)
- ✅ **Theme**: Consistent throughout (light OR dark, not mixed)
- ✅ **Cursor**: Remove if possible; or ensure it's not blocking content
- ✅ **Notifications**: Close OS notifications/banners
- ✅ **Background**: Use a neutral color; no distracting apps in background

### **Dashboard Screenshots** (01–04)
- Use light theme (white background)
- Show data: at least 5 submissions in history
- Ensure chart has multiple data points (7-day range)
- Highlight form ID (my-portfolio or similar)

### **Postman Screenshots** (05–06, 08)
- Close unnecessary tabs
- Expand the Response/Body sections
- Highlight status code (green 200, red 403)
- Show Headers tab to prove API key validation
- Blur API key value if visible (for security)

### **OpenAPI/Swagger Screenshot** (07)
- Expand at least 2 endpoint definitions (/submit, /export)
- Show "Try it out" button if visible
- Include request/response schemas
- Ensure text is readable (no tiny fonts)

### **DynamoDB Screenshot** (09)
- Show table name at top: `contact-form-submissions-v2`
- Highlight pk (FORM#...) and sk (SUBMIT#...) columns
- Show at least one full row with data
- Include timestamps and metadata (ip, ua)

### **CSV Screenshot** (10)
- Open in Excel or Google Sheets (both acceptable)
- Show all 9 columns: id, form_id, name, email, message, page, ip, ua, ts
- At least 3 data rows visible
- Include column headers
- No "#####" truncated columns (resize as needed)

### **Email Screenshot** (11)
- Show "From", "To", "Subject", "Date"
- Include body snippet (first 500 chars of message)
- Blur personal email address if sensitive
- Show timestamp (proof of delivery)

### **Alarms Screenshot** (12)
- Show dashboard or alarms list view
- At least 4 alarms visible:
  - Lambda Error Rate
  - API Gateway 5XX
  - DynamoDB Write Throttles
  - SES Bounce/Complaint
- Status columns visible (OK, BREACHED, INSUFFICIENT_DATA)

### **Logs Screenshot** (13)
- Show log group name: `/aws/lambda/contactFormProcessor`
- Include timestamp column (showing recent entries)
- Show at least 5 log entries
- Highlight a successful submission log entry

### **API Gateway Screenshot** (14)
- Show Usage Plan name (if exists)
- Show Rate Limit: 10000 / day
- Show API Key Status: ACTIVE
- Include Creation Date for reference

---

## 📸 Capture Instructions (per OS)

### **Windows (PowerShell)**

```powershell
# Capture region (e.g., entire screen)
# Option 1: Use built-in Snip & Sketch
# Win + Shift + S → Select region → Save to file

# Option 2: Use Python/PIL (if installed)
# python -c "from PIL import ImageGrab; ImageGrab.grab().save('screenshot.png')"

# Option 3: Use ShareX (recommended for screenshots)
# Download: https://getsharex.com/
# Capture → Save to /docs/screenshots/
```

### **macOS**

```bash
# Capture region (interactive)
screencapture -i ~/Desktop/screenshot.png

# Or use Cmd + Shift + 4 (default Mac shortcut)
```

### **Linux**

```bash
# Capture entire screen
gnome-screenshot -f /path/to/screenshot.png

# Or use scrot (if installed)
scrot ~/screenshot.png
```

---

## 📦 Verification Checklist

After capturing all 14 shots:

- [ ] All 14 screenshots exist in `/docs/screenshots/`
- [ ] Filenames follow naming convention (`NN_category_description.png`)
- [ ] All images are 1920×1080 (or 1080p)
- [ ] Theme is consistent (all light OR all dark)
- [ ] No sensitive data exposed (API keys blurred, emails masked if needed)
- [ ] Text is readable (no tiny fonts)
- [ ] Content is visible (no truncated columns or hidden data)
- [ ] All screenshots are in PNG or JPG format
- [ ] Total folder size < 50 MB (should be ~20–30 MB)

---

## 📋 Shot Dependency Tree

**Prerequisite Data:**

Before taking shots, ensure:

1. **Dashboard screenshots (01–04)**: At least 5 test submissions in DynamoDB
   - Run: `make local-test` or manual Postman requests
   - Wait 30 seconds for dashboard to refresh

2. **Postman screenshots (05–06)**: Postman collection imported, environments configured
   - Import: `api/postman/FormBridge.postman_collection.json`
   - Select environment: FormBridge.Prod

3. **Email screenshot (11)**: Recent form submission sent
   - Use Postman → Send Submit request
   - Check email inbox (3–5 seconds)

4. **Alarms screenshot (12)**: Alarms are active in CloudWatch
   - AWS Console → Alarms → Verify status

---

## 🎬 Suggested Shot Order (For Efficiency)

1. Start with **Dashboard** (01–04) — takes ~2 min, ensures data exists
2. Open **Postman** and take shots (05–06, 08) — takes ~3 min
3. Open **Swagger UI** and take shot (07) — ~1 min
4. Check **Email inbox** and take shot (11) — ~1 min (while email arrives)
5. Open **DynamoDB Admin** and take shot (09) — ~1 min
6. Open **CSV file** and take shot (10) — ~1 min
7. Open **AWS Console** and take shots (12–14) — ~3 min

**Total time**: ~12–15 minutes

---

## 📄 Screenshot Reference Sheet

Print or bookmark this for easy reference during capture:

```
DASHBOARD SHOTS (01–04):
01 — Dashboard KPIs + Overview
02 — 7-day Trend Chart
03 — Recent Submissions Table
04 — Download CSV Button

POSTMAN SHOTS (05–08):
05 — Success Response (200 OK with ID)
06 — Failure Response (403 Forbidden without key)
07 — OpenAPI/Swagger UI
08 — Environment Variables

STORAGE SHOTS (09–11):
09 — DynamoDB Table Items
10 — CSV File (Excel/Sheets)
11 — Email Notification

MONITORING SHOTS (12–14):
12 — CloudWatch Alarms Dashboard
13 — CloudWatch Logs (Lambda logs)
14 — API Gateway Usage Plan
```

---

**Status**: ✅ Ready for Screenshot Capture  
**Last Updated**: November 5, 2025

