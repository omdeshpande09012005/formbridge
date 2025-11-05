# FormBridge v2 - Frontend Integration Guide

**Status**: ✅ Production Ready  
**API Endpoint**: `https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit`  
**Region**: ap-south-1 (Mumbai)

---

## Quick Integration (5 minutes)

### 1. Basic HTML Form + JavaScript

```html
<!DOCTYPE html>
<html>
<head>
    <title>Contact Form</title>
</head>
<body>
    <form id="contactForm">
        <input type="text" id="name" placeholder="Your Name" />
        <input type="email" id="email" placeholder="Your Email" />
        <textarea id="message" placeholder="Your Message" required></textarea>
        <button type="submit">Send</button>
    </form>

    <script>
        const API_ENDPOINT = 'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit';
        const FORM_ID = 'contact-form'; // Unique identifier for this form

        document.getElementById('contactForm').addEventListener('submit', async (e) => {
            e.preventDefault();

            const payload = {
                form_id: FORM_ID,
                name: document.getElementById('name').value,
                email: document.getElementById('email').value,
                message: document.getElementById('message').value,
                page: window.location.href
            };

            try {
                const response = await fetch(API_ENDPOINT, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });

                if (response.ok) {
                    const data = await response.json();
                    alert(`✅ Submission received! ID: ${data.id}`);
                    document.getElementById('contactForm').reset();
                } else {
                    const error = await response.json();
                    alert(`❌ Error: ${error.error}`);
                }
            } catch (err) {
                alert(`❌ Network error: ${err.message}`);
            }
        });
    </script>
</body>
</html>
```

---

## Advanced Integration

### React Component Example

```jsx
import { useState } from 'react';

export default function ContactForm() {
    const [isLoading, setIsLoading] = useState(false);
    const [message, setMessage] = useState('');

    const handleSubmit = async (e) => {
        e.preventDefault();
        setIsLoading(true);

        try {
            const response = await fetch(
                'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit',
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        form_id: 'my-portfolio-contact',
                        name: e.target.name.value,
                        email: e.target.email.value,
                        message: e.target.message.value,
                        page: window.location.href
                    })
                }
            );

            if (response.ok) {
                const { id } = await response.json();
                setMessage(`✅ Sent! Reference: ${id}`);
                e.target.reset();
            } else {
                const { error } = await response.json();
                setMessage(`❌ Error: ${error}`);
            }
        } catch (err) {
            setMessage(`❌ Failed to send: ${err.message}`);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <form onSubmit={handleSubmit}>
            <input type="text" name="name" placeholder="Name" required />
            <input type="email" name="email" placeholder="Email" required />
            <textarea name="message" placeholder="Message" required />
            <button type="submit" disabled={isLoading}>
                {isLoading ? 'Sending...' : 'Send'}
            </button>
            {message && <p>{message}</p>}
        </form>
    );
}
```

---

## API Reference

### Request Format

```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Hello! This is a test message.",
    "page": "https://example.com/contact"
  }'
```

### Response Format (200 OK)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Error Responses

**400 Bad Request** (missing required field)
```json
{
  "error": "message required"
}
```

**500 Internal Server Error**
```json
{
  "error": "internal error storing submission"
}
```

---

## Field Specifications

| Field | Type | Required | Max Length | Notes |
|-------|------|----------|-----------|-------|
| `form_id` | string | Optional | 255 | Identifies which form instance (default: "default") |
| `name` | string | Optional | 255 | User's name |
| `email` | string | Optional | 255 | Email address (converted to lowercase) |
| `message` | string | **Required** | 10000 | Main message content |
| `page` | string | Optional | 2048 | Referring page URL |

---

## CORS Configuration

✅ CORS is enabled for: `https://omdeshpande09012005.github.io`

If your frontend is on a different domain, you'll need to:
1. Contact AWS account admin
2. Update Lambda environment variable: `FRONTEND_ORIGIN=your-domain.com`
3. Redeploy Lambda

---

## Response Handling

### Success Example
```javascript
const response = await fetch(apiUrl, { method: 'POST', body });
if (response.ok) {
    const { id } = await response.json();
    console.log('Submission saved with ID:', id);
    // Show success message to user
}
```

### Error Handling
```javascript
if (!response.ok) {
    const { error } = await response.json();
    console.error('Submission failed:', error);
    // Show error message to user
}
```

---

## Testing the Integration

### 1. Test in Browser Console
```javascript
fetch('https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        form_id: 'test',
        message: 'Test message from browser',
        name: 'Test User',
        email: 'test@example.com'
    })
}).then(r => r.json()).then(console.log);
```

### 2. Test with curl
```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"Hello from curl"}'
```

### 3. Verify in DynamoDB
```bash
aws dynamodb scan \
  --table-name contact-form-submissions-v2 \
  --filter-expression "contains(#msg, :msg)" \
  --expression-attribute-names '{"#msg":"message"}' \
  --expression-attribute-values '{":msg":{"S":"Hello"}}' \
  --region ap-south-1
```

---

## User Metadata Captured

Your Lambda automatically captures and stores:

```json
{
  "id": "UUID v4 - unique submission identifier",
  "ts": "2025-11-05T11:43:27.024880Z - UTC timestamp",
  "ip": "103.81.39.154 - client IP address",
  "ua": "Mozilla/5.0... - user agent string",
  "form_id": "which form was submitted",
  "page": "referring page URL"
}
```

This enables future analytics like:
- Form performance by source
- Browser/device distribution
- Geographic submission patterns
- Peak submission times

---

## Troubleshooting

### CORS Error in Browser
```
Access to XMLHttpRequest blocked by CORS policy
```
**Solution**: Ensure frontend is served from `https://omdeshpande09012005.github.io`

### 400 Bad Request
```json
{"error": "message required"}
```
**Solution**: Include `message` field in your request

### 500 Internal Server Error
**Solutions**:
1. Check Lambda logs: `aws logs tail /aws/lambda/contactFormProcessor --follow`
2. Verify Lambda has DynamoDB permissions
3. Check if `contact-form-submissions-v2` table exists

### Network Timeout
**Solutions**:
1. Lambda timeout is 30 seconds
2. Check AWS region connectivity
3. Consider retrying with exponential backoff

---

## Performance Tips

### 1. Add Request Timeout
```javascript
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout

fetch(apiUrl, {
    signal: controller.signal,
    // ... other options
}).finally(() => clearTimeout(timeoutId));
```

### 2. Implement Retries
```javascript
async function submitWithRetry(data, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            const response = await fetch(apiUrl, {
                method: 'POST',
                body: JSON.stringify(data)
            });
            if (response.ok) return await response.json();
        } catch (err) {
            if (i === maxRetries - 1) throw err;
            await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000));
        }
    }
}
```

### 3. Debounce Form Submission
```javascript
const debounce = (fn, delay) => {
    let timeoutId;
    return (...args) => {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => fn(...args), delay);
    };
};

const handleSubmit = debounce(async (e) => {
    // Submit form
}, 500);
```

---

## Security Best Practices

✅ **Already Implemented**:
- CORS validation (only your domain)
- HTTPS-only (API Gateway enforces)
- Message content validation
- Request logging
- DynamoDB encryption (at rest)

⚠️ **Recommendations**:
- Don't expose API endpoint in client-side code (use environment variables)
- Sanitize user input before display
- Implement rate limiting on frontend
- Monitor for suspicious patterns
- Consider implementing request signing (future)

---

## Monitoring & Analytics

### View Recent Submissions
```bash
aws dynamodb query \
  --table-name contact-form-submissions-v2 \
  --key-condition-expression "pk = :form" \
  --expression-attribute-values '{":form":{"S":"FORM#my-form"}}' \
  --region ap-south-1 \
  --profile formbridge-deploy
```

### Get Submissions by Date Range
```bash
aws dynamodb query \
  --table-name contact-form-submissions-v2 \
  --key-condition-expression "pk = :form AND sk BETWEEN :start AND :end" \
  --expression-attribute-values '{
    ":form":{"S":"FORM#my-form"},
    ":start":{"S":"SUBMIT#2025-11-01"},
    ":end":{"S":"SUBMIT#2025-11-30"}
  }' \
  --region ap-south-1 \
  --profile formbridge-deploy
```

---

## Support

- **API Status**: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit (POST test)
- **Region**: ap-south-1 (Mumbai)
- **Account**: 864572276622
- **Documentation**: See `DEPLOYMENT_STATUS.md` for full details
- **Logs**: `aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1 --profile formbridge-deploy`

---

**Last Updated**: 2025-11-05  
**Status**: ✅ Production Ready
