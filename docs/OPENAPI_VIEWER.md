# Swagger UI Documentation

This document explains how to view the FormBridge OpenAPI specification using Swagger UI.

## 📖 What is Swagger UI?

Swagger UI is an interactive API documentation tool that:
- **Visualizes** the OpenAPI specification in a user-friendly interface
- **Generates** executable "Try it out" buttons to test endpoints
- **Supports** both local and online deployment

## 🚀 Viewing Options

### Option 1: Online Swagger Editor (Quickest)

Visit [editor.swagger.io](https://editor.swagger.io/) and:

1. Click **File** → **Import URL**
2. If the spec is hosted, paste: `https://omdeshpande09012005.github.io/openapi.yaml`
3. Or manually paste the contents of `api/openapi.yaml`

**Pros:** No installation, works in browser
**Cons:** Requires internet, read-only (unless you copy/paste)

---

### Option 2: Docker Swagger UI (Recommended for Local)

Run Swagger UI in a container with local file mounting:

#### On Windows (PowerShell)
```powershell
# Navigate to formbridge directory
cd w:\PROJECTS\formbridge

# Run Docker container with your openapi.yaml
docker run -p 8888:8080 `
  -e SWAGGER_JSON=/openapi.yaml `
  -v "$(Get-Location)\api\openapi.yaml:/openapi.yaml" `
  swaggerapi/swagger-ui

# Then open: http://localhost:8888
```

#### On Linux/Mac
```bash
cd /path/to/formbridge

docker run -p 8888:8080 \
  -e SWAGGER_JSON=/openapi.yaml \
  -v $(pwd)/api/openapi.yaml:/openapi.yaml \
  swaggerapi/swagger-ui

# Then open: http://localhost:8888
```

**Features:**
- ✅ Live reload when you edit `openapi.yaml`
- ✅ Full "Try it out" functionality
- ✅ Local-only (no internet required after startup)
- ✅ Supports authentication headers (X-Api-Key)

**Troubleshooting:**
- Port already in use? Change `-p 8888:8080` to `-p 9999:8080` and visit `http://localhost:9999`
- Docker not installed? [Install Docker Desktop](https://www.docker.com/products/docker-desktop)

---

### Option 3: GitHub Pages (Swagger on Your Site)

If you've deployed the dashboard with GitHub Pages, you can add an embedded Swagger UI:

#### Step 1: Copy OpenAPI to docs/
```bash
cp api/openapi.yaml docs/openapi.yaml
```

#### Step 2: Create docs/swagger.html
```html
<!DOCTYPE html>
<html>
<head>
  <title>FormBridge API - Swagger UI</title>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@3/swagger-ui.css">
  <style>
    html {
      box-sizing: border-box;
      overflow: -moz-scrollbars-vertical;
      overflow-y: scroll;
    }
    * {
      box-sizing: inherit;
    }
    body {
      margin: 0;
      padding: 0;
    }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@3/swagger-ui-bundle.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@3/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: "./openapi.yaml",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "BaseLayout"
      })
    }
  </script>
</body>
</html>
```

#### Step 3: Add Link to docs/index.html
In the navigation or footer, add:
```html
<a href="./swagger.html">📖 API Documentation</a>
```

Then push to GitHub:
```bash
git add docs/
git commit -m "docs: add Swagger UI to GitHub Pages"
git push origin main
```

Access at: `https://omdeshpande09012005.github.io/swagger.html`

---

## 🧪 Testing Endpoints with Swagger

Once Swagger UI is open:

1. **Expand an endpoint** (e.g., `POST /submit`)
2. Click **Try it out**
3. Modify the request body if needed
4. Click **Execute**
5. View the response below

### Example: Testing /submit endpoint

1. Click `POST /submit` to expand
2. Click **Try it out**
3. Replace the body with:
```json
{
  "form_id": "test-form",
  "name": "Your Name",
  "email": "you@example.com",
  "message": "Testing the API!",
  "page": "https://example.com"
}
```
4. Add header (if testing PROD): `X-Api-Key: your-key-here`
5. Click **Execute**
6. See the response (should be `200` with an `id`)

---

## 🔒 Security Headers in Swagger

To include authentication in Swagger requests:

1. Locate the **Authorize** button (top-right in Swagger UI)
2. Click it
3. Select **ApiKeyAuth**
4. Enter your API key: `X-Api-Key: your-secret-key`
5. All subsequent requests will include the header

---

## 🌍 Server Selection in Swagger

Swagger UI has a **Servers** dropdown to switch between environments:

- **Local Development:** `http://127.0.0.1:3000`
- **Production:** `https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod`

Select the server before testing!

---

## 📝 Editing the Specification

To modify the OpenAPI spec (`api/openapi.yaml`):

1. Edit the file in your text editor or VS Code
2. If running Docker Swagger UI, **refresh the browser**—it will auto-reload
3. Changes appear immediately in the UI

---

## 🐛 Troubleshooting

### "Failed to fetch spec"
- Check that the URL or file path is correct
- Ensure Docker is running (if using Docker)
- Verify CORS is enabled on your server

### Swagger UI shows "Download the specification"
- The spec file wasn't found
- Verify `api/openapi.yaml` exists and is valid YAML
- Try copying the spec URL directly

### "Try it out" returns CORS error
- Local dev server has CORS enabled
- Production may have CORS restrictions
- Use Postman (which bypasses CORS) if needed

### Docker container won't start
```bash
# Check Docker is running
docker ps

# Rebuild the image
docker pull swaggerapi/swagger-ui

# Try with absolute paths
docker run -p 8888:8080 -v C:\path\to\openapi.yaml:/openapi.yaml swaggerapi/swagger-ui
```

---

## 📚 Resources

- **OpenAPI Specification:** `api/openapi.yaml`
- **Postman Collection:** `api/postman/FormBridge.postman_collection.json`
- **API README:** `api/README.md`
- **Official Swagger Docs:** https://swagger.io/
- **OpenAPI 3.0 Guide:** https://spec.openapis.org/oas/v3.0.3

---

## ✅ Checklist: Setting Up Swagger UI

- [ ] Have Docker installed (or use online editor)
- [ ] Located `api/openapi.yaml` in project
- [ ] Opened Swagger UI (Docker or online)
- [ ] Can see `/submit` and `/analytics` endpoints
- [ ] "Try it out" buttons are available
- [ ] Can switch between Dev and Prod servers
- [ ] Authorization header (X-Api-Key) is recognized

---

**Next Step:** Open Swagger UI and test a /submit or /analytics request!
