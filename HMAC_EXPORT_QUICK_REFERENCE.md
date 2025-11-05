# FormBridge HMAC & CSV Export - Quick Reference

## 🚀 Quick Start

### Enable HMAC Signing (Optional)
```bash
# Generate secret
SECRET=$(openssl rand -hex 32)

# Deploy to Lambda
aws lambda update-function-configuration \
  --function-name contactFormProcessor \
  --environment Variables={HMAC_ENABLED=true,HMAC_SECRET=$SECRET,HMAC_SKEW_SECS=300} \
  --region ap-south-1 --profile formbridge-deploy
```

### Export CSV (Already Active)
```bash
# 7-day export
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your-api-key" \
  -d '{"form_id":"my-portfolio","days":7}' \
  -o submissions.csv
```

---

## 📋 HMAC Request Signing

### Headers Required
```
X-Timestamp: 1731800000        # Unix seconds (current time)
X-Signature: abc123def456...   # HMAC-SHA256(secret, timestamp + '\n' + body)
```

### Message Format
```
timestamp\nbody

Example:
1731800000
{"form_id":"contact","message":"Hello"}
```

### Signature Computation
```python
import hmac, hashlib

message = f"{timestamp}\n{body}".encode('utf-8')
signature = hmac.new(secret.encode('utf-8'), message, hashlib.sha256).hexdigest()
```

### JavaScript (Web Crypto API)
```javascript
async function hmacSignRequest(secret, body) {
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const message = `${timestamp}\n${body}`;
  
  const key = await crypto.subtle.importKey(
    'raw', 
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false, 
    ['sign']
  );
  
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  const signature = Array.from(new Uint8Array(sig))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
  
  return { timestamp, signature };
}
```

### Error Responses (When HMAC Enabled)
```json
// Missing/stale timestamp
{ "error": "stale or missing timestamp" }

// Invalid signature
{ "error": "invalid signature" }
```

### Environment Variables
| Variable | Example | Purpose |
|----------|---------|---------|
| `HMAC_ENABLED` | `false` | Enable/disable (default: false) |
| `HMAC_SECRET` | hex string | 32-byte hex secret |
| `HMAC_SKEW_SECS` | `300` | Timestamp tolerance (default: 5 min) |

---

## 📊 CSV Export Endpoint

### API
```
POST /export
Content-Type: application/json
X-Api-Key: required

{
  "form_id": "my-portfolio",  // Required
  "days": 7                    // Optional, 1-90, default 7
}
```

### Response Headers
```
Content-Type: text/csv
Content-Disposition: attachment; filename=formbridge_my-portfolio_7d_20251105.csv
X-Row-Cap: 0  // 1 if 10,000 limit reached, else 0
```

### CSV Format
```
id,form_id,name,email,message,page,ip,ua,ts
my-portfolio#1731800000000,my-portfolio,John Doe,john@example.com,Hello,https://...,203.0.113.42,Mozilla/...,1731800000
```

### Python Example
```python
import requests

response = requests.post(
    'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/export',
    headers={
        'Content-Type': 'application/json',
        'X-Api-Key': 'your-key'
    },
    json={'form_id': 'my-portfolio', 'days': 7}
)

with open('submissions.csv', 'wb') as f:
    f.write(response.content)
```

### Error Codes
| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Missing form_id |
| 401 | Invalid API key or HMAC |
| 403 | Forbidden (API key verification failed) |
| 500 | Server error |

### Limits
| Limit | Value | Workaround |
|-------|-------|-----------|
| Max rows | 10,000 | Export in smaller date ranges |
| Max days | 90 | Multiple requests with different ranges |

---

## 🔗 Documentation Links

| Document | Purpose |
|----------|---------|
| `docs/HMAC_SIGNING.md` | Complete HMAC implementation guide |
| `docs/EXPORT_README.md` | Complete CSV export guide |
| `api/openapi.yaml` | API specification (OpenAPI 3.0) |
| `api/postman/FormBridge.postman_collection.json` | Postman requests (with HMAC pre-script) |
| `README_PRODUCTION.md` | Production deployment guide |

---

## 📝 Postman Quick Steps

1. **Import Collection**:
   - File → Import → Select `FormBridge.postman_collection.json`

2. **Select Environment**:
   - Top-right dropdown → Choose "FormBridge.Dev" or "FormBridge.Prod"

3. **For HMAC Signing** (Production only):
   - Edit environment → Set `hmac_enabled = "true"`
   - Edit environment → Set `hmac_secret = "<your-secret>"`
   - Pre-request script auto-signs all requests

4. **Export CSV**:
   - Expand "Analytics" folder → Click "Export CSV" request
   - Update `form_id` and `days` if needed
   - Click Send
   - Postman recognizes CSV and displays in formatted tab

---

## ⚙️ Lambda Code Locations

| Feature | File | Lines |
|---------|------|-------|
| HMAC verification | `backend/contact_form_lambda.py` | 166-210 |
| CSV export | `backend/contact_form_lambda.py` | 410-568 |
| Route handler | `backend/contact_form_lambda.py` | 245-255 |

---

## 🔐 Security Notes

- ✅ Constant-time signature comparison (prevents timing attacks)
- ✅ Timestamp validation (prevents replay attacks)
- ✅ Configurable skew tolerance (handles clock drift)
- ✅ HMAC disabled by default (zero breaking changes)
- ✅ CSV export requires API key (existing security)
- ✅ 10,000 row cap (prevents resource exhaustion)

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| "invalid signature" | Verify client & Lambda use same HMAC_SECRET |
| "stale or missing timestamp" | Check client clock is accurate |
| CSV export returns 403 | Verify X-Api-Key header is set |
| CSV export empty | Check form_id matches exactly (case-sensitive) |
| Postman script not working | Restart Postman; CryptoJS is built-in |

---

## 📞 Support Resources

- **HMAC Implementation**: See `docs/HMAC_SIGNING.md` - section "Client-Side Implementation"
- **CSV Use Cases**: See `docs/EXPORT_README.md` - section "Use Cases"
- **Error Handling**: See `docs/EXPORT_README.md` - section "Troubleshooting"
- **Server Config**: See `docs/HMAC_SIGNING.md` - section "Server Configuration"

---

**Last Updated**: 2025-11-05  
**Status**: ✅ Ready for Production  
**Version**: FormBridge v2 with HMAC & Export

