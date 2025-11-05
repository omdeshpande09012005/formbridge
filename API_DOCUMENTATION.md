# FormBridge Lambda API Documentation

## Base URL
```
https://<api-gateway-id>.execute-api.<region>.amazonaws.com/prod
```

---

## Endpoints

### 1. POST /submit

Submit a new contact form entry.

#### Request Headers
```
Content-Type: application/json
```

#### Request Body
```json
{
  "form_id": "contact-form",          // optional (default: "default")
  "name": "John Doe",                 // required, string
  "email": "john@example.com",        // required, valid email format
  "message": "Your message here",     // required, string
  "page": "https://example.com/page"  // optional, string
}
```

#### Field Validation
| Field | Type | Required | Rules |
|-------|------|----------|-------|
| `form_id` | string | No | Default: "default". Trimmed. |
| `name` | string | **Yes** | Non-empty after trim. |
| `email` | string | **Yes** | Valid format (must contain @ and .). Normalized to lowercase. |
| `message` | string | **Yes** | Non-empty after trim. |
| `page` | string | No | URL of referring page. Trimmed. |

#### Response (Success - 200)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Headers:**
```
Access-Control-Allow-Origin: https://omdeshpande09012005.github.io
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
Content-Type: application/json
```

#### Response (Error - 400)
```json
{
  "error": "name required"
}
```

**Possible Errors:**
| Error | Status | Cause |
|-------|--------|-------|
| "Invalid JSON payload" | 400 | Malformed JSON in request body |
| "name required" | 400 | Name field missing or empty |
| "email required" | 400 | Email field missing or empty |
| "message required" | 400 | Message field missing or empty |
| "invalid email format" | 400 | Email doesn't contain @ or valid domain |

#### Response (Error - 500)
```json
{
  "error": "internal error storing submission"
}
```

**Causes:**
- DynamoDB write failed
- SES email delivery failed (non-fatal; submission still stored)

#### Side Effects
1. **DynamoDB:** Item stored with:
   - `pk`: `FORM#{form_id}`
   - `sk`: `SUBMIT#{timestamp}#{submission_id}`
   - `ttl`: Unix timestamp (90 days from now) for auto-deletion
   - All fields: `name`, `email`, `message`, `page`, `ip`, `ua` (user-agent), `ts` (ISO timestamp)

2. **SES:** Email sent to configured recipients with:
   - Subject: `New contact form submission from {name}`
   - Reply-To: Submitter's email
   - Body: HTML + plain-text with all fields

#### Example cURL
```bash
curl -X POST https://<api-url>/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-us",
    "name": "Jane Smith",
    "email": "jane@example.com",
    "message": "I would like to inquire about your services.",
    "page": "https://example.com/contact"
  }'
```

---

### 2. POST /analytics

Retrieve submission statistics for a form.

#### Request Headers
```
Content-Type: application/json
```

#### Request Body
```json
{
  "form_id": "contact-form"  // required, string
}
```

#### Response (Success - 200)
```json
{
  "form_id": "contact-form",
  "total_submissions": 42,
  "last_7_days": [
    {"date": "2025-10-29", "count": 5},
    {"date": "2025-10-30", "count": 3},
    {"date": "2025-10-31", "count": 8},
    {"date": "2025-11-01", "count": 2},
    {"date": "2025-11-02", "count": 1},
    {"date": "2025-11-03", "count": 4},
    {"date": "2025-11-04", "count": 7}
  ],
  "latest_id": "550e8400-e29b-41d4-a716-446655440001",
  "last_submission_ts": "2025-11-04T18:32:15.123456Z"
}
```

#### Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `form_id` | string | The form ID queried |
| `total_submissions` | integer | Total count of all submissions for this form (up to 10K) |
| `last_7_days` | array | Array of 7 objects with `date` (YYYY-MM-DD) and `count` |
| `latest_id` | string or null | UUID of most recent submission (or null if no submissions) |
| `last_submission_ts` | string or null | ISO timestamp of most recent submission (or null) |

#### Response (Error - 400)
```json
{
  "error": "form_id required"
}
```

**Possible Errors:**
| Error | Status | Cause |
|-------|--------|-------|
| "Invalid JSON payload" | 400 | Malformed JSON in request body |
| "form_id required" | 400 | form_id field missing or empty |

#### Response (Error - 500)
```json
{
  "error": "internal error querying analytics"
}
```

**Causes:**
- DynamoDB query failed
- Timestamp parsing error (recoverable; continues)

#### Behavior
- Returns 200 even if form has zero submissions
- Queries up to 10,000 most recent submissions
- Dates are UTC calendar days
- `last_7_days` array is sorted chronologically (oldest first)
- Timestamps are ISO 8601 format with 'Z' suffix

#### Example cURL
```bash
curl -X POST https://<api-url>/analytics \
  -H "Content-Type: application/json" \
  -d '{"form_id":"contact-us"}'
```

---

## CORS Policy

All responses include CORS headers allowing requests from:
- **Origin:** `https://omdeshpande09012005.github.io`
- **Methods:** `POST`, `OPTIONS`
- **Headers:** `Content-Type`

**Note:** Update `FRONTEND_ORIGIN` environment variable to change allowed origin.

---

## Data Model

### DynamoDB Item Structure

**Table:** `contact-submissions-{stage}` (e.g., `contact-submissions-dev`, `contact-submissions-prod`)

**Partition Key (pk):** `FORM#{form_id}`  
**Sort Key (sk):** `SUBMIT#{timestamp}#{submission_id}`

**Example Item:**
```json
{
  "pk": "FORM#contact-us",
  "sk": "SUBMIT#2025-11-04T18:32:15.123456Z#550e8400-e29b-41d4-a716-446655440001",
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "form_id": "contact-us",
  "name": "Jane Smith",
  "email": "jane@example.com",
  "message": "I would like to inquire...",
  "page": "https://example.com/contact",
  "ip": "203.0.113.42",
  "ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)...",
  "ts": "2025-11-04T18:32:15.123456Z",
  "ttl": 1733376735
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `pk` | String | Partition key: `FORM#{form_id}` |
| `sk` | String | Sort key: `SUBMIT#{iso-timestamp}#{uuid}` |
| `id` | String | Submission ID (UUID) |
| `form_id` | String | Form identifier (e.g., "contact-us", "support-request") |
| `name` | String | Submitter's name (trimmed) |
| `email` | String | Submitter's email (trimmed, lowercase) |
| `message` | String | Submission message (trimmed) |
| `page` | String | Referring page URL (trimmed, optional) |
| `ip` | String | Submitter's IP address (extracted from headers) |
| `ua` | String | Submitter's User-Agent string |
| `ts` | String | ISO 8601 timestamp (UTC, 'Z' suffix) |
| `ttl` | Number | Unix timestamp for TTL-based auto-deletion (90 days) |

---

## Error Handling

### HTTP Status Codes

| Status | Meaning |
|--------|---------|
| **200** | Success |
| **400** | Bad Request (invalid input) |
| **409** | Conflict (duplicate submission, rare) |
| **500** | Internal Server Error (DynamoDB/SES failure) |

### Error Response Format
All errors return JSON with `error` field:
```json
{
  "error": "Description of what went wrong"
}
```

### Retry Logic
- **4xx errors:** Don't retry (client error)
- **5xx errors:** Retry with exponential backoff (3 attempts recommended)

---

## Rate Limiting

**Current:** No explicit rate limiting. Consider adding:
1. API Gateway throttling
2. WAF rules
3. Lambda concurrent execution limits

**Recommendation:** Implement token bucket or sliding window at API Gateway level for production.

---

## Performance

### DynamoDB Capacity
- **Write:** 1 submission = ~1.5 KB ≈ 1.5 WCU
- **Read:** 1 analytics query = 100 items/page × 7 pages max = 700 RCU worst-case

### Latency
- Submit: ~200-500ms (DynamoDB + SES)
- Analytics: ~100-300ms (DynamoDB query)

### Scaling
- Adjust DynamoDB provisioned capacity or use On-Demand billing
- Consider caching popular form_ids (e.g., 5-minute TTL in Redis/ElastiCache)

---

## Security Considerations

### Input Validation
- ✅ Required fields enforced
- ✅ Email format validated
- ✅ Whitespace trimmed
- ⚠️ No XSS protection (HTML entities not escaped in emails)
- ⚠️ No rate limiting

### Data Privacy
- ⚠️ IP addresses stored (PII) — consider GDPR implications
- ⚠️ User-Agent stored
- ✅ Email addresses normalized to lowercase (consistent hashing possible)
- ✅ TTL set for auto-deletion (90 days)

### Recommendations
1. Add IP anonymization (last octet masked)
2. Implement rate limiting per IP
3. Add request signing (SigV4) for analytics endpoint
4. Encrypt sensitive data at rest (DynamoDB encryption)

---

## Monitoring & Observability

### CloudWatch Metrics
- Lambda invocations, duration, errors
- DynamoDB read/write capacity consumed
- SES send attempts/failures

### CloudWatch Logs
All operations logged to Lambda CloudWatch Logs group:
```
/aws/lambda/ContactFormFunction
```

**Log Format:**
```
[timestamp] Received event: {...}
[timestamp] Route: POST /submit
[timestamp] Storing submission [id] for form [form_id]
[timestamp] Successfully stored submission [id] to DynamoDB
[timestamp] Email sent successfully for submission [id]
```

### Debugging
Enable debug logging by setting Lambda environment variable:
```
DEBUG=true
```

---

## Examples

### Frontend Integration (JavaScript)
```javascript
async function submitForm(formData) {
  try {
    const response = await fetch('https://<api-url>/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        form_id: 'contact-us',
        name: formData.name,
        email: formData.email,
        message: formData.message,
        page: window.location.href,
      }),
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error);
    }
    
    const { id } = await response.json();
    console.log('Submission ID:', id);
    return id;
  } catch (error) {
    console.error('Submission failed:', error.message);
    throw error;
  }
}
```

### Analytics Dashboard (Python)
```python
import requests
import matplotlib.pyplot as plt

API_URL = "https://<api-url>/analytics"

def get_form_stats(form_id):
    response = requests.post(
        API_URL,
        json={"form_id": form_id},
        timeout=10
    )
    response.raise_for_status()
    return response.json()

# Fetch stats
stats = get_form_stats("contact-us")

# Plot 7-day trend
dates = [d['date'] for d in stats['last_7_days']]
counts = [d['count'] for d in stats['last_7_days']]

plt.plot(dates, counts, marker='o')
plt.xlabel('Date')
plt.ylabel('Submissions')
plt.title(f"Form Analytics: {stats['form_id']}")
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()

print(f"Total: {stats['total_submissions']} submissions")
print(f"Latest: {stats['last_submission_ts']}")
```

---

## Changelog

### v1.0 (Current)
- ✅ `/submit` endpoint with full validation
- ✅ `/analytics` endpoint with 7-day stats
- ✅ DynamoDB storage with TTL
- ✅ SES email notifications
- ✅ CORS support
- ✅ Request logging

### Future (v2.0)
- 🔄 Rate limiting
- 🔄 Request signing / API keys
- 🔄 Advanced analytics (hourly, weekly, monthly)
- 🔄 Email template customization
- 🔄 Webhooks for integrations

