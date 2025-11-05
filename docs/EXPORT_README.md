# CSV Export Guide

Download FormBridge submissions as CSV for analysis, reporting, and integration with Excel, Google Sheets, or data tools.

## 📥 Quick Start

### Via Dashboard

1. Open Analytics Dashboard: https://omdeshpande09012005.github.io/docs/dashboard/
2. Click **"Download CSV"** button
3. Enter number of days (default 7, max 90)
4. Choose location to save file
5. Open in Excel, Sheets, or favorite tool

### Via API (cURL)

```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-api-key" \
  -d '{"form_id":"my-portfolio","days":7}' \
  > export.csv
```

### Via Postman

1. Open FormBridge collection
2. Select "Export" request
3. Update `form_id` in body (default: my-portfolio)
4. Update `days` (default: 7, max: 90)
5. Click **Send**
6. Click **Save Response** → **Save to file**

---

## 🔍 API Endpoint

### Request

**Method:** `POST /export`

**Headers:**
```
Content-Type: application/json
X-Api-Key: your-api-key           (required)
X-Timestamp: 1699200000           (optional, for HMAC)
X-Signature: a1b2c3...            (optional, for HMAC)
```

**Body:**
```json
{
  "form_id": "contact-form",
  "days": 7
}
```

**Parameters:**
| Parameter | Type | Required | Default | Range |
|-----------|------|----------|---------|-------|
| `form_id` | string | ✅ Yes | — | — |
| `days` | integer | ❌ No | 7 | 1–90 |

### Response

**Status:** `200 OK`

**Headers:**
```
Content-Type: text/csv; charset=utf-8
Content-Disposition: attachment; filename="formbridge_my-portfolio_7d_20251105_143022.csv"
X-Row-Cap: 10000                   (only if capped)
```

**Body:** CSV text with submissions

---

## 📊 CSV Format

### Headers

```
id,form_id,name,email,message,page,ip,ua,ts
```

### Sample Data

```
d8f1c5a2-b3e4,my-portfolio,John Doe,john@example.com,Great work!,https://example.com/contact,103.81.39.154,Mozilla/5.0...,2025-11-05T12:30:45.123Z
a9e2d7c1-f5b4,my-portfolio,Jane Smith,jane@example.com,Interested in collaboration.,https://example.com/contact,192.168.1.1,Chrome/119...,2025-11-04T08:15:22.456Z
```

### Column Descriptions

| Column | Description | Example |
|--------|-------------|---------|
| `id` | Submission ID (UUID) | d8f1c5a2-b3e4 |
| `form_id` | Form identifier | my-portfolio |
| `name` | Submitter name | John Doe |
| `email` | Submitter email | john@example.com |
| `message` | Message content | Great work! |
| `page` | Referrer page URL | https://example.com/contact |
| `ip` | Client IP address | 103.81.39.154 |
| `ua` | User-Agent string | Mozilla/5.0... |
| `ts` | Timestamp (ISO 8601 UTC) | 2025-11-05T12:30:45.123Z |

---

## 🎯 Use Cases

### 1. Email Campaigns

**Goal:** Send replies to all submissions

```bash
# Export emails to CSV
curl -X POST ... export > submissions.csv

# Extract email column
cut -d',' -f4 submissions.csv | tail -n +2 > emails.txt

# Send emails (using your mail tool)
cat emails.txt | xargs -I {} sendmail {}
```

### 2. Google Sheets Integration

1. Export CSV
2. Upload to Drive (or paste directly)
3. Open with **Google Sheets**
4. Auto-parses columns
5. Add charts, filters, formulas

**Tip:** Set up recurring exports to a shared Drive folder for live dashboards

### 3. Salesforce/HubSpot Import

1. Export CSV from FormBridge
2. Open Salesforce/HubSpot admin
3. Data → Import → Select CSV
4. Map columns:
   - `email` → Lead Email
   - `name` → Lead Name
   - `message` → Description
   - `ts` → Submission Date
5. Complete import

### 4. Data Analysis

**Python Example:**

```python
import pandas as pd
from datetime import datetime

# Load CSV
df = pd.read_csv('export.csv')

# Parse timestamps
df['ts'] = pd.to_datetime(df['ts'])

# Statistics
print(f"Total submissions: {len(df)}")
print(f"Date range: {df['ts'].min()} to {df['ts'].max()}")
print(f"Unique email domains: {df['email'].str.split('@').str[1].nunique()}")

# Top senders
print("\nTop 5 senders:")
print(df['name'].value_counts().head())

# Message length analysis
df['msg_len'] = df['message'].str.len()
print(f"\nAverage message length: {df['msg_len'].mean():.0f} chars")
```

---

## 🔐 Security

### API Key Required

All export requests require `X-Api-Key` header:

```bash
# This will fail
curl -X POST https://...api.../export \
  -d '{"form_id":"my-form"}'

# Error: 403 Forbidden
# {"error":"Unauthorized"}
```

### HMAC Signing (Optional)

For extra security, sign export requests (see `docs/HMAC_SIGNING.md`):

```bash
X-Timestamp: 1699200000
X-Signature: a1b2c3d4e5f6...
```

### Row Cap

Large exports are capped at **10,000 rows** to prevent resource exhaustion.

**If capped:** Response includes `X-Row-Cap: 10000` header

**Workaround:** Export in smaller date ranges

```bash
# Export 7 days at a time
for i in {0..3}; do
  start=$((7 * i))
  end=$((start + 7))
  echo "Exporting days $start-$end..."
  # Query API with adjusted date range
done
```

---

## 🐛 Troubleshooting

### "Unauthorized" (403)

**Cause:** Missing or invalid API key

```bash
# Fix: Add X-Api-Key header
curl ... -H "X-Api-Key: your-key" ...
```

### "Invalid signature" (401)

**Cause:** HMAC signature mismatch (if HMAC enabled)

```bash
# Fix: Re-sign request with correct secret
HMAC_SECRET=your-secret
TIMESTAMP=$(date +%s)
BODY='{"form_id":"my-form"}'
SIGNATURE=$(echo -n "${TIMESTAMP}\n${BODY}" | openssl dgst -sha256 -hmac "$HMAC_SECRET" -hex | cut -d' ' -f2)

curl ... \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Signature: $SIGNATURE" \
  ...
```

### Empty CSV (Only Headers)

**Cause 1:** No submissions in date range

```bash
# Fix: Increase `days` parameter
curl ... -d '{"form_id":"my-portfolio","days":30}'
```

**Cause 2:** Wrong `form_id`

```bash
# Fix: Verify form_id matches submissions
# List all forms in analytics first
```

### File Won't Open in Excel

**Cause:** UTF-8 encoding issue

**Fix:** In Excel:
1. **File** → **Open**
2. Select CSV file
3. In import dialog:
   - Set **File Origin** to **UTF-8**
   - Click **OK**

---

## 📈 Examples

### Marketing Report

```javascript
// Query last 30 days of submissions
async function getMonthlyReport() {
  const response = await fetch('/export', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Api-Key': process.env.API_KEY,
    },
    body: JSON.stringify({
      form_id: 'contact-form',
      days: 30,
    }),
  });
  
  const csv = await response.text();
  
  // Parse and summarize
  const lines = csv.split('\n');
  const count = lines.length - 2; // -1 for header, -1 for trailing newline
  
  return {
    period: 'Last 30 days',
    submissions: count,
    csvUrl: URL.createObjectURL(new Blob([csv], { type: 'text/csv' })),
  };
}
```

### Email List Export

```bash
# Extract email column (skip header)
tail -n +2 export.csv | cut -d',' -f4

# Output:
# john@example.com
# jane@example.com
# bob@example.com

# Pipe to mailing list tool
tail -n +2 export.csv | cut -d',' -f4 | xargs -I {} \
  curl -X POST https://maillist.example.com/add -d "email={}"
```

### Compliance Report

```bash
# Create timestamped export
DATE=$(date +%Y%m%d)
curl -X POST ... export > "formbridge_export_${DATE}.csv"

# Store in S3 for audit
aws s3 cp "formbridge_export_${DATE}.csv" s3://audit-bucket/

# Generate manifest
echo "Exported: $(date)" >> EXPORT_MANIFEST.txt
echo "File: formbridge_export_${DATE}.csv" >> EXPORT_MANIFEST.txt
echo "Rows: $(wc -l < "formbridge_export_${DATE}.csv")" >> EXPORT_MANIFEST.txt
```

---

## 🔗 Related Documentation

- **API Reference:** `api/README.md`
- **OpenAPI Spec:** `api/openapi.yaml`
- **Dashboard Guide:** `docs/DASHBOARD_README.md`
- **HMAC Signing:** `docs/HMAC_SIGNING.md`

---

**Status:** Export endpoint available on production API. Dashboard button requires ES6 modules + fetch API support.
