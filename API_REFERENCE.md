# FormBridge API Reference v2

## Endpoint

```
POST /submit
```

## Request

### Headers
```
Content-Type: application/json
```

### Body (JSON)

```json
{
  "form_id": "homepage-contact",
  "name": "John Doe",
  "email": "john@example.com",
  "message": "I'd like to discuss partnership opportunities.",
  "page": "https://example.com/contact"
}
```

### Field Details

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `form_id` | string | No (default: "default") | Identifier to group submissions by form instance |
| `name` | string | No | Submitter's name |
| `email` | string | No | Submitter's email (used for Reply-To in notifications) |
| `message` | string | **Yes** | The contact message (only truly required field) |
| `page` | string | No | URL of the page where form was submitted |

### Minimal Request
```json
{
  "message": "Hello, I have a question."
}
```

## Response

### Success (200 OK)

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

### Client Error (400 Bad Request)

```json
{
  "error": "message required"
}
```

**Triggered by:**
- Missing or empty `message` field
- Invalid JSON in request body

### Server Error (500 Internal Server Error)

```json
{
  "error": "internal error storing submission"
}
```

**Triggered by:**
- DynamoDB write failure (rare)

## Notes

- **SES Email Failures:** If email fails to send, you still get a 200 response. The submission is stored in DynamoDB. Check CloudWatch logs for SES errors.
- **Metadata Auto-Capture:** IP address and User-Agent are automatically captured from the request context and headers.
- **Idempotency:** Each request generates a new `id`. If you need to retry safely, store the returned `id` and implement client-side deduplication.

## Deployment Environment Variables

```bash
# Required
DDB_TABLE=contact-form-submissions
SES_SENDER=noreply@formbridge.com
SES_RECIPIENTS=admin@formbridge.com

# Optional
FRONTEND_ORIGIN=https://omdeshpande09012005.github.io  # defaults to this
```

## JavaScript Client Example

```javascript
async function submitForm(data) {
  const response = await fetch(
    'https://<api-id>.execute-api.<region>.amazonaws.com/Prod/submit',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        form_id: 'homepage-contact',
        name: data.name,
        email: data.email,
        message: data.message,
        page: window.location.href,
      }),
    }
  );

  const result = await response.json();

  if (response.ok) {
    console.log(`Submission ${result.id} sent successfully`);
  } else {
    console.error(`Error: ${result.error}`);
  }
}
```

## Stored Data

Once submitted, each contact form submission is stored in DynamoDB with:

```json
{
  "pk": "FORM#homepage-contact",
  "sk": "SUBMIT#2025-11-05T14:32:10.123456Z#550e8400-e29b-41d4-a716-446655440000",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "form_id": "homepage-contact",
  "name": "John Doe",
  "email": "john@example.com",
  "message": "I'd like to discuss partnership opportunities.",
  "page": "https://example.com/contact",
  "ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...",
  "ip": "203.0.113.42",
  "ts": "2025-11-05T14:32:10.123456Z"
}
```

## Querying Submissions

### Get all submissions for a form

```bash
aws dynamodb query \
  --table-name contact-form-submissions \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk": {"S": "FORM#homepage-contact"}}' \
  --region us-east-1
```

### Get submissions within a time range

```bash
aws dynamodb query \
  --table-name contact-form-submissions \
  --key-condition-expression "pk = :pk AND sk BETWEEN :sk1 AND :sk2" \
  --expression-attribute-values '{
    ":pk": {"S": "FORM#homepage-contact"},
    ":sk1": {"S": "SUBMIT#2025-11-01T00:00:00Z"},
    ":sk2": {"S": "SUBMIT#2025-11-05T23:59:59Z"}
  }' \
  --region us-east-1
```
