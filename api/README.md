# FormBridge API Documentation

Welcome to the FormBridge API! This folder contains everything you need to understand, test, and integrate with the FormBridge form submission service.

## � Automatic Per-Form Routing

FormBridge now supports **automatic form routing** based on `form_id`:

- ✅ Different email recipients per form
- ✅ Custom subject prefixes per form  
- ✅ Form-specific brand colors and dashboard URLs
- ✅ Graceful fallback to global defaults if no form config

When you submit a form with `form_id: "careers"`, FormBridge automatically routes it to the configured recipients and applies form-specific branding.

**For setup details, see:** `docs/FORM_ROUTING.md`

## �📋 Contents

- **`openapi.yaml`** — Complete OpenAPI 3.0 specification (machine-readable, human-readable)
- **`postman/`** — Postman collection and environment configurations

## 🔍 Viewing the OpenAPI Specification

### Option 1: Online Swagger Editor
Visit [swagger.io/tools/swagger-editor](https://editor.swagger.io/) and paste the contents of `openapi.yaml`.

### Option 2: Local Swagger UI with Docker
```bash
docker run -p 80:8080 \
  -e SWAGGER_JSON=/openapi.yaml \
  -v $(pwd)/api/openapi.yaml:/openapi.yaml \
  swaggerapi/swagger-ui
# Open http://localhost:80
```

### Option 3: GitHub Pages (via docs/swagger.html)
If deployed, visit the project's Swagger UI page for interactive documentation.

## 🔑 Security: API Keys

### Development Environment
- **API Key:** Optional
- **Header:** `X-Api-Key` (leave empty or omit)
- **Examples:** 
  - DEV server at `http://127.0.0.1:3000`
  - No authentication required for local testing

### Production Environment
- **API Key:** Required
- **Header:** `X-Api-Key: your-secret-key-here`
- **Examples:**
  - AWS API Gateway: `https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod`
  - Always include your API key

### Obtaining Your API Key
Contact the FormBridge team or check your AWS secrets manager.

## 🚀 Testing the API

### Method 1: Using Postman (Recommended)
1. Download [Postman](https://www.postman.com/downloads/)
2. Import the collection: `postman/FormBridge.postman_collection.json`
3. Import environment:
   - **For DEV:** `postman/FormBridge.Dev.postman_environment.json`
   - **For PROD:** `postman/FormBridge.Prod.postman_environment.json`
4. Select your environment (top-right dropdown)
5. Click "Submit" or "Analytics" request
6. Click **Send**

### Method 2: Using cURL
```bash
# Submit a form
curl -X POST http://127.0.0.1:3000/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "my-portfolio",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Great portfolio!"
  }'

# Get analytics
curl -X POST http://127.0.0.1:3000/analytics \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "my-portfolio"
  }'
```

### Method 3: Using Insomnia
1. Download [Insomnia](https://insomnia.rest/)
2. Click **Create** → **Import from File**
3. Select `postman/FormBridge.postman_collection.json`
4. Update variables in environment settings (or use provided environment files)

## 📡 API Endpoints

### POST /submit
Submit a new form entry.

**Request:**
```json
{
  "form_id": "my-portfolio",
  "name": "Alice",
  "email": "alice@example.com",
  "message": "Hello!",
  "page": "https://example.com/contact"
}
```

**Response (200):**
```json
{
  "id": "my-portfolio#1731800000000"
}
```

**Errors:**
- `400` — Validation error (missing fields, invalid email, etc.)
- `401` — Missing API key (PROD only)
- `403` — Invalid API key
- `500` — Server error

### POST /analytics
Get analytics for a form.

**Request:**
```json
{
  "form_id": "my-portfolio"
}
```

**Response (200):**
```json
{
  "form_id": "my-portfolio",
  "total_submissions": 42,
  "last_7_days": [
    { "date": "2025-11-05", "count": 13 },
    { "date": "2025-11-04", "count": 8 }
  ],
  "latest_id": "my-portfolio#1731800000000",
  "last_submission_ts": 1731800000000
}
```

## 🔄 Switching Between Dev and Prod

### In Postman
1. Environment dropdown (top-right) → select **FormBridge.Dev** or **FormBridge.Prod**
2. All requests automatically use the correct `base_url` and `api_key`

### Manual Setup
Update variables:
- **Dev:** `base_url = http://127.0.0.1:3000`, `api_key = (empty)`
- **Prod:** `base_url = https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod`, `api_key = your-key`

## 📚 Resources

- **OpenAPI Spec:** `openapi.yaml` (machine-readable)
- **Postman Collection:** `postman/FormBridge.postman_collection.json`
- **Full Documentation:** See `../README_PRODUCTION.md`
- **GitHub:** https://github.com/omdeshpande09012005/formbridge

## 🐛 Troubleshooting

### "Invalid API key" (403)
- Check that you've set the correct API key in your environment
- Ensure the header name is exactly `X-Api-Key` (case-sensitive)
- In DEV, leave the API key empty

### "Missing required field" (400)
- `message` is always required
- `form_id` defaults to "default" if omitted
- Email must be a valid email format (e.g., user@domain.com)

### "Connection refused"
- Check that your dev server is running: `sam local start-api`
- Verify the URL matches your server (default: `http://127.0.0.1:3000`)

### CORS errors
- Development server has CORS enabled
- Production (AWS) requires proper CORS configuration

---

**Need help?** Open an issue on [GitHub](https://github.com/omdeshpande09012005/formbridge/issues)
