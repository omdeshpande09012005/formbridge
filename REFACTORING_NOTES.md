# FormBridge Lambda Refactoring - v2

## Overview
This refactoring upgrades the contact form handler to support an industry-grade submission contract with richer metadata, improved error handling, and support for future analytics.

## Key Changes

### 1. **Richer Submission Contract**
- **New Fields:**
  - `form_id` (default: "default"): Allows tracking submissions from different form instances
  - `page`: URL of the page where the form was submitted (referrer tracking)
  - `ua`: User-Agent string for device/browser analytics
  - `ip`: IP address (extracted from request context or X-Forwarded-For)
  
- **Validation:** Only `message` is now strictly required. `name` and `email` are optional but captured if provided.

### 2. **DynamoDB Schema Upgrade**
**Old Schema (single key):**
```
submissionId (PK): UUID
```

**New Schema (composite keys):**
```
pk (PK): "FORM#{form_id}"
sk (SK): "SUBMIT#{timestamp}#{id}"
id: UUIDv4 (submission ID)
form_id: Form identifier (default: "default")
ts: ISO-8601 UTC timestamp
name, email, message, page: Submission data
ua: User-Agent
ip: Client IP
```

**Benefits:**
- Query all submissions for a specific form: `Query pk = "FORM#{form_id}"`
- Range queries by timestamp for time-series analytics
- Partition isolation per form

### 3. **Email Enhancements**
- **Reply-To:** If submitter email is present, `ReplyToAddresses` is set in SES, enabling replies directly to the submitter
- **Sender Configuration:** Now uses `SES_SENDER` (verified sender) instead of using the form submitter's email
- **Multiple Recipients:** `SES_RECIPIENTS` supports comma-separated list of notification recipients
- **Richer Email Body:** Plain-text and HTML emails now include all metadata (form_id, timestamp, IP, etc.)

### 4. **Request Metadata Extraction**
**IP Detection (multi-strategy):**
- Try `requestContext.http.sourceIp` (API Gateway v2, ALB)
- Fall back to `X-Forwarded-For` header (CloudFront, proxies)
- Return empty string if unavailable

**User-Agent:** Extracted from request headers (case-insensitive)

### 5. **CORS & Response Handling**
- Centralized `response()` helper now embeds `FRONTEND_ORIGIN` in all responses
- All responses include proper CORS headers
- Supports dynamic origin via `FRONTEND_ORIGIN` environment variable

### 6. **Error Handling & Resiliency**
- **Validation errors** (e.g., missing message): Return 400 with JSON error
- **DynamoDB failures:** Return 500 (submission lost)
- **SES failures:** Log error but return 200 success if DynamoDB write succeeded
  - Rationale: Submission is persisted; email is best-effort notification

### 7. **Logging & Diagnostics**
- Log all events with structured, no-secret information
- Include submission ID in all logs for traceability
- Distinguish SES configuration issues from delivery failures

## Environment Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `DDB_TABLE` | string | DynamoDB table name | `contact-form-submissions` |
| `SES_SENDER` | string | Verified SES sender email | `noreply@formbridge.com` |
| `SES_RECIPIENTS` | string | Comma-separated recipients | `admin@formbridge.com,ops@formbridge.com` |
| `FRONTEND_ORIGIN` | string | CORS origin (optional) | `https://omdeshpande09012005.github.io` |

## SAM Template Updates

### DynamoDB Table
- Migrated to composite key schema (pk, sk)
- Added TODO comment for future GSI (e.g., `form_id-ts-index` for analytics)

### Lambda Function
- Updated environment variables: `SES_SENDER`, `SES_RECIPIENTS`, `FRONTEND_ORIGIN`
- Added IAM permission for `dynamodb:Query` (for future analytics endpoint)
- Added TODO for `/analytics` endpoint

### Parameters
- New parameters: `SesSender`, `SesRecipients`, `FrontendOrigin` for easy configuration

## Future Enhancements (TODOs)

1. **Analytics Endpoint** (`/analytics`)
   - Query submissions by `form_id` and time range
   - Aggregate metrics: submission count, unique IPs, user agents
   - Consider PII implications of storing IP/UA long-term

2. **DynamoDB GSI**
   - Index on `form_id-ts` for efficient time-series queries
   - LSI on `pk-id` for deduplication checks

3. **Form Idempotency**
   - Track duplicate submissions via content hash
   - Prevent accidental resubmissions

4. **Rate Limiting**
   - Per-IP rate limiting via Lambda cache or DynamoDB
   - Per-form rate limiting

## Backward Compatibility

⚠️ **Breaking Change:** The DynamoDB schema has changed from a single-key to composite-key design. Existing data is **not** automatically migrated. Options:

1. **Fresh Table:** Deploy with new SAM template → creates new table
2. **Migration Script:** Write Lambda or CLI script to scan old table and write to new
3. **Parallel Operation:** Keep old table, deploy new Lambda with new table name, switch DNS

## Testing Checklist

- [ ] Deploy SAM template with test environment variables
- [ ] POST to `/submit` with minimal payload: `{"message": "test"}`
- [ ] Verify submission stored in DynamoDB with new schema
- [ ] Verify email sent with Reply-To header
- [ ] Test with multiple recipients
- [ ] Test with missing SES configuration (should log warning, return 200)
- [ ] Verify CORS headers in response
- [ ] Test with `form_id`, `page`, `ua`, `ip` fields
- [ ] Validate error responses (400, 500 status codes)

## Commit Message

```
feat: richer submission contract + Reply-To and analytics fields

- Refactor Lambda handler for industry-grade submission processing
- Support form_id, page, ua, ip metadata capture
- Add composite DynamoDB key schema (pk: FORM#{form_id}, sk: SUBMIT#{ts}#{id})
- Implement Reply-To support in SES emails
- Support multiple SES recipients (comma-separated config)
- Extract client IP from requestContext or X-Forwarded-For header
- Centralize CORS handling via FRONTEND_ORIGIN env var
- Make SES failures non-fatal (tolerate email send failures)
- Add TODO comments for /analytics endpoint and GSI planning
- Update SAM template with new parameters and IAM permissions
```
