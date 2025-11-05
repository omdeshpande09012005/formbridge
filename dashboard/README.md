# Analytics Dashboard Files

This directory contains the FormBridge Analytics Dashboard - a static, single-page application for viewing form submission metrics.

## 📄 Files in This Directory

### `index.html` (382 lines)
Main dashboard UI with responsive design and accessibility features.

**Features:**
- Header with environment badge (DEV/PROD)
- Form ID input and refresh button
- 3 KPI tiles (total submissions, latest ID, last time)
- 7-day trend chart (powered by Chart.js)
- Daily breakdown table
- Toast notification system
- Mobile-responsive CSS Grid layout

**Open in browser:**
```bash
open index.html
# Or use a web server:
python -m http.server 8000
# Visit: http://localhost:8000/
```

### `app.js` (410 lines)
Vanilla JavaScript application logic - no frameworks or npm packages needed.

**Key Functions:**
- `loadConfig()` - Load configuration from config.js
- `loadAnalytics()` - Fetch data from API
- `updateDashboard()` - Update all UI elements
- `updateChart()` - Render Chart.js line chart
- `showToast()` - Display notifications

**Dependencies:**
- Chart.js (loaded via CDN in index.html)
- No npm packages required

### `config.example.js`
Configuration template - copy this to `config.js` and customize.

**Example Configuration:**
```javascript
const CONFIG = {
    // Development (local):
    API_URL: 'http://127.0.0.1:3000',
    
    // Production (AWS):
    // API_URL: 'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod',
    
    API_KEY: '',  // Optional: leave empty for dev, add for production
    DEFAULT_FORM_ID: 'portfolio-contact'
};
```

**⚠️ IMPORTANT:**
- Copy this file to `config.js` to use the dashboard
- `config.js` is NOT in version control (for security)
- Only use read-only API keys in the dashboard

### `setup.sh` (macOS/Linux)
Quick setup script for macOS and Linux.

```bash
bash setup.sh
```

Automatically:
1. Creates `config.js` from template
2. Opens it in your default editor
3. Shows next steps

### `setup.bat` (Windows)
Quick setup script for Windows.

```cmd
setup.bat
```

Automatically:
1. Creates `config.js` from template
2. Opens it in VS Code
3. Shows next steps

## 🚀 Quick Start

### 1. Setup Configuration
```bash
# macOS/Linux:
bash setup.sh

# Windows:
setup.bat

# Or manual:
cp config.example.js config.js
# Edit config.js with your API URL
```

### 2. Open Dashboard
```bash
# Method 1: Direct (may have CORS issues)
open index.html

# Method 2: With HTTP server (recommended)
python -m http.server 8000
# Visit: http://localhost:8000/
```

### 3. Use Dashboard
1. Enter a form ID (or use default)
2. Click **Refresh** (or press Enter)
3. View your analytics!

## 📖 Documentation

See `../docs/DASHBOARD_README.md` for:
- Detailed configuration guide
- CORS troubleshooting
- GitHub Pages deployment
- Security best practices
- Full troubleshooting section

## 🔒 Security

### Protect Your API Key
```bash
# Add to .gitignore
echo "config.js" >> .gitignore

# If already committed, remove it
git rm --cached config.js
git commit -m "Remove config.js from version control"
```

### Best Practices
- Use read-only API keys in static sites
- API keys are visible to users - limit scope
- Consider IP whitelisting at API Gateway
- Monitor CloudWatch for unusual activity

## 🆘 Troubleshooting

### "No data" / Shows "—" everywhere
1. Check form ID spelling
2. Verify API_URL in config.js
3. Open browser console (F12 > Console)
4. Look for error messages

### CORS Error
1. Verify API_URL is correct
2. Check backend CORS configuration
3. For AWS API Gateway: Enable CORS in console

### Chart doesn't display
1. Check internet (CDN access needed)
2. Check browser console for errors
3. Verify `last_7_days` in API response

## 📱 Responsive Design

Dashboard works on:
- ✅ Mobile (360px width minimum)
- ✅ Tablet (768px and up)
- ✅ Desktop (1200px and up)

Test mobile view:
```bash
# Chrome: F12 > Toggle device toolbar (Ctrl+Shift+M)
# Firefox: Ctrl+Shift+M
```

## 🌐 Browser Support

| Browser | Status |
|---------|--------|
| Chrome 90+ | ✅ Full support |
| Firefox 88+ | ✅ Full support |
| Safari 14+ | ✅ Full support |
| Edge 90+ | ✅ Full support |
| IE 11 | ❌ Not supported |

## 📊 Dashboard Features

| Feature | Details |
|---------|---------|
| KPI Tiles | Total submissions, latest ID, last submission time |
| Chart | 7-day trend line chart with Chart.js |
| Table | Daily breakdown (date and count) |
| Environment | DEV (local) or PROD (AWS) badge |
| Error Handling | CORS, 403, 404, 500 with toast notifications |
| Accessibility | ARIA labels, keyboard support, semantic HTML |
| Responsive | Mobile (360px+), tablet, desktop |

## 💾 API Integration

### Request Format
```javascript
POST /analytics
Content-Type: application/json
X-Api-Key: optional-api-key

{
    "form_id": "portfolio-contact"
}
```

### Response Format
```json
{
    "form_id": "portfolio-contact",
    "total_submissions": 45,
    "last_7_days": [
        { "date": "2024-01-02", "count": 9 },
        { "date": "2024-01-03", "count": 6 },
        ...
    ],
    "latest_id": "sub_1234567890",
    "last_submission_ts": "2024-01-08T14:35:22Z"
}
```

## 🚀 Deploy to GitHub Pages

```bash
# 1. Copy files
mkdir -p ../docs/analytics
cp index.html app.js config.example.js ../docs/analytics/

# 2. Create config
cp ../docs/analytics/config.example.js ../docs/analytics/config.js
# Edit with production API URL

# 3. Add to .gitignore
echo "../docs/analytics/config.js" >> ../.gitignore

# 4. Push
git add ../docs/analytics/
git commit -m "Add analytics dashboard"
git push

# 5. Access
# https://yourusername.github.io/analytics/
```

## 📞 Support

For help:
1. Check `../docs/DASHBOARD_README.md` (comprehensive guide)
2. Open browser console (F12 > Console tab)
3. Check CloudWatch logs for backend errors
4. See `../local/scripts/setup-observability.sh` for monitoring

---

**Version:** 1.0  
**Last Updated:** November 5, 2025  
**Status:** Production Ready ✅
