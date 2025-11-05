# HMAC Request Signing

Optional security enhancement for FormBridge API requests using HMAC-SHA256 signatures to protect request integrity.

## 🔒 What is HMAC Signing?

HMAC (Hash-Based Message Authentication Code) protects requests from tampering by signing the request body with a shared secret. The server verifies the signature before processing.

**Features:**
- ✅ Protects request body integrity (prevents tampering)
- ✅ Timestamp validation (prevents replay attacks)
- ✅ Optional (disabled by default; can be enabled per-deployment)
- ✅ Constant-time comparison (prevents timing attacks)

**Limitations:**
- ⚠️ In browser-based clients: secret is visible (use read-only key)
- ⚠️ In production: only use with trusted servers or edge workers
- ✅ No secrets in production dashboard (verified separately)

---

## 🚀 Client-Side Implementation

### JavaScript (Web Crypto API - No Dependencies)

```javascript
/**
 * Sign a request with HMAC-SHA256
 * @param {string} secret - HMAC secret key (hex lowercase)
 * @param {string} body - JSON request body
 * @returns {Promise<{timestamp: string, signature: string}>}
 */
async function hmacSignRequest(secret, body) {
  // Get current timestamp (Unix seconds)
  const timestamp = Math.floor(Date.now() / 1000).toString();
  
  // Message to sign: timestamp + newline + body
  const message = `${timestamp}\n${body}`;
  
  // Encode secret and message
  const encoder = new TextEncoder();
  const secretData = encoder.encode(secret);
  const messageData = encoder.encode(message);
  
  // Import secret as HMAC key
  const key = await crypto.subtle.importKey(
    'raw',
    secretData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  // Sign the message
  const signatureBuffer = await crypto.subtle.sign('HMAC', key, messageData);
  
  // Convert to hex lowercase
  const signatureArray = Array.from(new Uint8Array(signatureBuffer));
  const signature = signatureArray
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  
  return { timestamp, signature };
}

/**
 * Make a signed POST request
 */
async function makeSignedRequest(url, body, secret) {
  const bodyJson = JSON.stringify(body);
  const { timestamp, signature } = await hmacSignRequest(secret, bodyJson);
  
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    },
    body: bodyJson,
  });
  
  return response.json();
}

// Usage
const formData = {
  form_id: 'my-form',
  name: 'John Doe',
  email: 'john@example.com',
  message: 'Hello!',
};

const result = await makeSignedRequest(
  'http://127.0.0.1:3000/submit',
  formData,
  'my-secret-key'
);

console.log(result); // { id: "..." }
```

---

### Example: React Component

```javascript
import { useState } from 'react';

export function SignedFormSubmit() {
  const [status, setStatus] = useState('ready');
  
  async function handleSubmit(e) {
    e.preventDefault();
    setStatus('signing...');
    
    try {
      const formData = {
        form_id: 'contact-us',
        name: e.target.name.value,
        email: e.target.email.value,
        message: e.target.message.value,
      };
      
      const result = await makeSignedRequest(
        'https://api.example.com/submit',
        formData,
        process.env.REACT_APP_HMAC_SECRET
      );
      
      setStatus(`sent: ${result.id}`);
    } catch (err) {
      setStatus(`error: ${err.message}`);
    }
  }
  
  return (
    <form onSubmit={handleSubmit}>
      <input name="name" required />
      <input name="email" type="email" required />
      <textarea name="message" required />
      <button type="submit">Send (Signed)</button>
      <p>Status: {status}</p>
    </form>
  );
}
```

---

## ⚙️ Server-Side Configuration

### Lambda Environment Variables

Set these in AWS Lambda:

```bash
HMAC_ENABLED=true          # Enable signing (default: false)
HMAC_SECRET=your-secret    # Shared secret (generate with: openssl rand -hex 32)
HMAC_SKEW_SECS=300         # Timestamp tolerance (default: 300 seconds)
```

### Generating a Secure Secret

```bash
# Generate 32-byte (256-bit) hex secret
openssl rand -hex 32
# Output: a1b2c3d4e5f6... (64 hex chars)
```

### Security Notes

- ✅ Store secret in AWS Secrets Manager, not in code
- ✅ Rotate secrets regularly
- ✅ Use different secrets for different forms/environments
- ✅ In development, use weak secrets (e.g., "dev-secret")
- ✅ In production, generate with `openssl rand -hex 32`

---

## 📋 Request Format

### Headers Required

When `HMAC_ENABLED=true`, all requests must include:

```http
POST /submit HTTP/1.1
Content-Type: application/json
X-Timestamp: 1699200000
X-Signature: a1b2c3d4e5f6... (hex lowercase)

{"form_id":"my-form","name":"John","email":"john@example.com","message":"Hi"}
```

### Header Descriptions

| Header | Description | Example |
|--------|-------------|---------|
| `X-Timestamp` | Unix seconds (current time) | `1699200000` |
| `X-Signature` | HMAC-SHA256(secret, timestamp + '\n' + body) in hex | `a1b2c3...` |

### Signature Computation

```
message = X-Timestamp + '\n' + raw_body
signature = lowercase(hex(HMAC_SHA256(secret, message)))
```

**Example:**

```javascript
secret = 'my-secret'
timestamp = '1699200000'
body = '{"form_id":"my-form"}'

message = '1699200000\n{"form_id":"my-form"}'
signature = 'a1b2c3d4e5f6g7h8...' (lowercase hex)
```

---

## 🧪 Testing with cURL

```bash
# Generate timestamp and signature
SECRET='my-secret'
TIMESTAMP=$(date +%s)
BODY='{"form_id":"test","message":"Hello"}'
SIGNATURE=$(echo -n "${TIMESTAMP}\n${BODY}" | openssl dgst -sha256 -hmac "$SECRET" -hex | cut -d' ' -f2)

# Make signed request
curl -X POST http://127.0.0.1:3000/submit \
  -H "Content-Type: application/json" \
  -H "X-Timestamp: $TIMESTAMP" \
  -H "X-Signature: $SIGNATURE" \
  -d "$BODY"
```

---

## 🔍 Server Verification Flow

When a request arrives:

1. **Extract headers** → X-Timestamp, X-Signature
2. **Check timestamp** → If |now - ts| > HMAC_SKEW_SECS → 401 (stale)
3. **Compute expected signature** → HMAC_SHA256(secret, timestamp + '\n' + body)
4. **Constant-time compare** → Against X-Signature
5. **If mismatch** → 401 (invalid signature)
6. **If valid** → Continue with business logic

---

## 📊 Error Responses

### Missing Timestamp

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{"error":"stale or missing timestamp"}
```

### Stale Timestamp

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{"error":"stale or missing timestamp"}
```

**Cause:** `|current_time - X-Timestamp| > HMAC_SKEW_SECS`

### Invalid Signature

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{"error":"invalid signature"}
```

**Cause:** Computed signature doesn't match X-Signature

---

## 🔄 Integration Examples

### Postman (Pre-Request Script)

See Postman collection: `api/postman/FormBridge.postman_collection.json`

Pre-request script auto-generates:
- X-Timestamp header
- X-Signature header (using HMAC_SECRET variable)

### Python Requests

```python
import hmac
import hashlib
import json
import time
import requests

def make_signed_request(url, body, secret):
    timestamp = str(int(time.time()))
    body_json = json.dumps(body)
    
    message = f"{timestamp}\n{body_json}".encode()
    signature = hmac.new(
        secret.encode(),
        message,
        hashlib.sha256
    ).hexdigest()
    
    headers = {
        'Content-Type': 'application/json',
        'X-Timestamp': timestamp,
        'X-Signature': signature,
    }
    
    response = requests.post(url, json=body, headers=headers)
    return response.json()

# Usage
result = make_signed_request(
    'http://127.0.0.1:3000/submit',
    {
        'form_id': 'my-form',
        'name': 'Jane',
        'email': 'jane@example.com',
        'message': 'Interested!',
    },
    'my-secret'
)
```

---

## 🐛 Troubleshooting

### 401 "invalid signature"

**Cause 1: Secret mismatch**
- Client secret != server secret
- Fix: Verify HMAC_SECRET in Lambda env vars

**Cause 2: Wrong message format**
- Should be `timestamp\n` + `body` (with newline)
- Fix: Ensure newline is included in signature message

**Cause 3: Body encoding**
- Body must be valid UTF-8 JSON
- Fix: Don't modify body after signing

### 401 "stale or missing timestamp"

**Cause 1: Clock skew**
- Client time != server time by > 300 seconds
- Fix: Sync system clocks (NTP)

**Cause 2: Old cached request**
- Request sent 5+ minutes after signing
- Fix: Re-sign before resending

---

## 🎯 Security Best Practices

| Practice | Benefit |
|----------|---------|
| Use HTTPS always | Encrypts headers + body |
| Rotate secrets regularly | Limits exposure window |
| Use strong secrets (256-bit) | Resistant to brute force |
| Different secrets per form | Compartmentalizes risk |
| Monitor logs for 401 errors | Detects tampering attempts |
| Use edge worker for signing | Keeps secret off client |

---

## ⚠️ When NOT to Use HMAC in Browser

- ❌ **Highly sensitive data** → Move signing to backend/edge worker
- ❌ **Production secrets** → Only use read-only/limited keys
- ❌ **OAuth/payment** → Use proper authentication (OAuth2, mTLS)

**Better approach:**
- Client → HTTPS → Backend → Signs with secret → API
- Backend keeps secret; client never sees it

---

## 📚 Resources

- **FormBridge API:** `api/openapi.yaml`
- **Postman Collection:** `api/postman/FormBridge.postman_collection.json`
- **HMAC RFC:** https://tools.ietf.org/html/rfc2104
- **Web Crypto API:** https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API

---

**Status:** Optional feature, enabled per-deployment. Disabled by default.
