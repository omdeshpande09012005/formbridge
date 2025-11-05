# FormBridge Analytics Dashboard

A minimal, static analytics dashboard for viewing FormBridge contact form submission metrics. Built with vanilla JavaScript and Chart.js—no build tools or backend required.

## Quick Start

### 1. Setup Configuration

```bash
# Copy example config to active config
cp dashboard/config.example.js dashboard/config.js

# Edit config.js with your settings
```

**For Development:**
```javascript
const CONFIG = {
    API_URL: 'http://127.0.0.1:3000',      // Your local FormBridge API
    API_KEY: '',                             // Leave empty (no auth in dev)
    DEFAULT_FORM_ID: 'portfolio-contact'    // Auto-load this form
};
```

**For Production:**
```javascript
const CONFIG = {
    API_URL: 'https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod',
    API_KEY: 'your-read-only-api-key',
    DEFAULT_FORM_ID: 'portfolio-contact'
};
```

### 2. Open Dashboard

**Development:**
- Open `dashboard/index.html` in your browser
- Or use a local server: `python -m http.server 8000` then visit `http://localhost:8000/dashboard/`

**Production:**
- Deploy to GitHub Pages (see "Deployment" section)
- Or self-host the `dashboard/` folder

### 3. View Metrics

1. Enter or select a form ID
2. Click **Refresh** (or press Enter)
3. View:
   - **Total Submissions**: Cumulative count
   - **Latest ID**: Most recent submission ID
   - **Last Submission**: Timestamp of last submission
   - **7-Day Chart**: Line chart of daily submissions
   - **Daily Breakdown**: Table with date and count

## Features

### ✅ What's Included
- **Responsive Design**: Works on mobile (360px+), tablet, and desktop
- **Vanilla JavaScript**: No frameworks or build tools needed
- **Chart.js Integration**: Beautiful 7-day trend chart with Chart.js CDN
- **Error Handling**: Graceful degradation for network, CORS, and API errors
- **Toast Notifications**: Success/error/info messages with animations
- **Accessibility**: ARIA labels, semantic HTML, keyboard support (Enter to submit)
- **Static Deployment**: GitHub Pages compatible, no backend needed
- **Environment Detection**: Shows DEV or PROD badge based on API URL

### 🎨 Screenshots

**1. Dashboard Loaded (Development)**
```
┌─────────────────────────────────────────────┐
│  FormBridge Analytics               [DEV]   │
│                                             │
│  Form ID: [ portfolio-contact ]  [Refresh] │
│                                             │
│  Total: 45    Latest ID: #1234    Last: ... │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ Submissions (7-day)                 │   │
│  │   ↗️                                  │   │
│  │ 45 ─────────────────────────────    │   │
│  │ 30 ──╱                               │   │
│  │ 15 ╱                                │   │
│  │  0 ├──┬──┬──┬──┬──┬──┬──┤           │   │
│  │    Mon Tue Wed Thu Fri Sat Sun      │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Date      │ Count                         │
│  ────────────────────                      │
│  2024-01-08│ 5                             │
│  2024-01-07│ 8                             │
│  ...       │ ...                           │
└─────────────────────────────────────────────┘
```

**2. Mobile View (360px)**
```
┌──────────────────┐
│ FormBridge       │
│ Analytics [DEV]  │
│                  │
│ Form ID [input]  │
│ [Refresh]        │
│                  │
│ Total: 45        │
│ Latest: #1234    │
│ Last: 2024-...   │
│                  │
│ [Chart area]     │
│                  │
│ [Table area]     │
└──────────────────┘
```

**3. Error Toast (Invalid API Key)**
```
┌──────────────────────────────────────┐
│ ⚠️  API key required/invalid.       │
│     Check your config.js            │
└──────────────────────────────────────┘
```

**4. Empty State (No Submissions)**
```
Form ID: [ unknown-form ]  [Refresh]

Total: —    Latest ID: —    Last: —

[Empty chart]

Date      │ Count
──────────────────
No data. Check your form ID...
```

**5. Chart with Data**
```
Line chart showing:
- X-axis: Last 7 days (Mon-Sun)
- Y-axis: Submission count (0-max)
- Blue line with dots: Daily submissions
- Hover: Show exact count
```

**6. Daily Breakdown Table**
```
Date       │ Count
───────────┼──────
2024-01-08 │ 5
2024-01-07 │ 8
2024-01-06 │ 3
2024-01-05 │ 12
2024-01-04 │ 7
2024-01-03 │ 6
2024-01-02 │ 9
```

## Configuration

### Environment Variables

**API_URL**
- Development: `http://127.0.0.1:3000` (local Docker)
- Production: `https://api.example.com` (AWS API Gateway)
- Must include protocol (http/https)

**API_KEY** (Optional)
- Leave empty for development
- For production: Use read-only API key from API Gateway
- Header: `X-Api-Key: YOUR_KEY`

**DEFAULT_FORM_ID** (Optional)
- Form ID to auto-load on page load
- Leave empty to require manual selection
- Used for quick dashboard reloads

### CORS Configuration

If you see "Network error. Check your API URL and CORS settings":

**AWS API Gateway:**
1. Go to your API in AWS Console
2. Click "Enable CORS" in the dashboard
3. Ensure your dashboard origin is whitelisted
4. Example: `https://yourusername.github.io`

**Local Development:**
- Docker Compose handles CORS automatically
- If issues persist, check the `contact-form` Lambda's CORS headers

## API Response Format

The `/analytics` endpoint returns:

```json
{
  "form_id": "portfolio-contact",
  "total_submissions": 45,
  "last_7_days": [
    { "date": "2024-01-02", "count": 9 },
    { "date": "2024-01-03", "count": 6 },
    { "date": "2024-01-04", "count": 7 },
    { "date": "2024-01-05", "count": 12 },
    { "date": "2024-01-06", "count": 3 },
    { "date": "2024-01-07", "count": 8 },
    { "date": "2024-01-08", "count": 5 }
  ],
  "latest_id": "sub_1234567890",
  "last_submission_ts": "2024-01-08T14:35:22Z"
}
```

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| Network error | API URL unreachable | Check API_URL and ensure backend is running |
| CORS error | Cross-origin request blocked | Verify backend CORS configuration |
| 403 Forbidden | API key missing/invalid | Add API_KEY to config.js |
| 404 Not Found | Form ID not found | Check form ID spelling and ensure submissions exist |
| 500 Server Error | Backend issue | Check CloudWatch logs (see Observability setup) |
| Config not loaded | config.js missing | Run `cp dashboard/config.example.js dashboard/config.js` |

## Deployment

### GitHub Pages

1. **Create GitHub Pages Repository**
   ```bash
   # Create repo: yourusername/yourusername.github.io
   # Or add to existing Pages repo
   ```

2. **Copy Dashboard Files**
   ```bash
   cp -r dashboard/* docs/analytics/
   mkdir -p docs/analytics
   cp dashboard/index.html docs/analytics/
   cp dashboard/app.js docs/analytics/
   cp dashboard/config.example.js docs/analytics/
   ```

3. **Create config.js**
   ```bash
   cp docs/analytics/config.example.js docs/analytics/config.js
   # Edit with your production API details
   ```

4. **Update .gitignore**
   ```
   # Analytics dashboard (secrets)
   docs/analytics/config.js
   ```

5. **Push to GitHub**
   ```bash
   git add docs/analytics/index.html docs/analytics/app.js docs/analytics/config.example.js
   git commit -m "Add analytics dashboard"
   git push origin main
   ```

6. **Access Dashboard**
   ```
   https://yourusername.github.io/analytics/
   ```

### Self-Hosted

1. **Copy Files**
   ```bash
   cp -r dashboard /var/www/analytics/
   cd /var/www/analytics
   cp config.example.js config.js
   # Edit config.js
   ```

2. **Serve with HTTP Server**
   ```bash
   # Python 3
   python -m http.server 8080

   # Node.js
   npx http-server

   # Nginx (production)
   # Configure for /analytics path
   ```

3. **Access Dashboard**
   ```
   http://localhost:8080/analytics/
   ```

## Security Considerations

### ⚠️ API Keys in Static Sites

This dashboard is a **static single-page application**. API keys placed in `config.js` are **visible in the browser**:

```javascript
// DON'T: Don't use admin/full-access keys
API_KEY: 'sk-admin-full-access-key' // ❌ Dangerous!

// DO: Use read-only analytics keys
API_KEY: 'sk-read-only-analytics'   // ✅ Limited scope
```

### Recommended Practices

1. **Create Read-Only API Key in AWS**
   - Go to API Gateway > Your API > API Keys
   - Create new key with "analytics" in the name
   - Create Usage Plan limiting to analytics operations only
   - Associate key with plan

2. **IP Whitelisting**
   - Use API Gateway resource policies to allow only expected origins
   - Example: Whitelist your GitHub Pages domain

3. **Monitor Access**
   - CloudWatch logs track all `/analytics` requests
   - Set up alarms for unusual access patterns
   - See `local/scripts/setup-observability.sh` for examples

4. **Rotate Keys Regularly**
   - Generate new API keys quarterly
   - Disable old keys
   - Update config.js in GitHub Pages

## 📸 Screenshot Verification Checklist

Use this checklist to verify your dashboard is working correctly. Take screenshots at each step for documentation.

### ✅ 1. Dashboard Homepage Screenshot
**What to verify:**
- [ ] FormBridge Analytics title visible
- [ ] Environment badge shows "DEV" or "PROD"
- [ ] Form ID input field is empty/shows default
- [ ] Refresh button is visible
- [ ] KPI tiles show "—" (empty state)
- [ ] Chart area is visible
- [ ] Table area is visible

**Steps:**
1. Open dashboard at http://localhost:8080/dashboard/
2. Take screenshot of initial state

---

### ✅ 2. KPI Metrics Visible
**What to verify:**
- [ ] Total Submissions shows a number (not "—")
- [ ] Latest ID shows a submission ID
- [ ] Last Submission shows a timestamp
- [ ] Success toast shows "Loaded data for form"

**Steps:**
1. In dashboard, enter form ID: `my-portfolio`
2. Click Refresh
3. Wait for data to load (2-3 seconds)
4. Take screenshot showing loaded data

---

### ✅ 3. 7-Day Submission Chart
**What to verify:**
- [ ] Line chart displays with purple line
- [ ] X-axis shows last 7 dates
- [ ] Y-axis shows submission counts
- [ ] Chart has dots at each data point
- [ ] Hover shows tooltip with count

**Steps:**
1. On loaded dashboard with data
2. Hover over chart points
3. Verify tooltips appear
4. Take screenshot of chart with data

---

### ✅ 4. Daily Breakdown Table
**What to verify:**
- [ ] Table has 2 columns: Date, Count
- [ ] Shows last 7 days of data
- [ ] Dates are in YYYY-MM-DD format
- [ ] Counts match chart data
- [ ] Table rows are properly formatted

**Steps:**
1. Scroll down on dashboard
2. View daily breakdown table
3. Verify data matches chart
4. Take screenshot of table

---

### ✅ 5. API Error Handling (403 Forbidden)
**What to verify:**
- [ ] Error toast appears with message
- [ ] Toast says "API key required/invalid"
- [ ] Dashboard clears showing "—"

**Steps:**
1. Update config.js with wrong API_KEY: `wrong-key-123`
2. Refresh dashboard
3. Enter form ID and click Refresh
4. Take screenshot showing error toast

---

### ✅ 6. Mobile Responsiveness (360px)
**What to verify:**
- [ ] Dashboard displays on small screens
- [ ] KPI tiles stack vertically
- [ ] Chart scales to screen width
- [ ] Table is readable
- [ ] Buttons are touch-friendly

**Steps:**
1. Open DevTools (F12)
2. Toggle device toolbar (Ctrl+Shift+M)
3. Select iPhone SE or 360px width
4. Reload dashboard
5. Verify all elements are visible
6. Take screenshot of mobile view

---

## Troubleshooting

### Dashboard Shows "—" for All Values

**Possible Causes:**
1. Form ID doesn't exist
2. No submissions for this form yet
3. API URL is wrong
4. CORS is blocked

**Solutions:**
1. Check form ID spelling
2. Verify form has submissions (check DynamoDB or CloudWatch)
3. Test API directly: `curl -X POST http://API_URL/analytics -H 'Content-Type: application/json' -d '{"form_id":"test"}'`
4. Check browser console (F12 > Console tab) for error details

### "Config not loaded" Error

**Solution:**
```bash
# Ensure config.js exists
cp dashboard/config.example.js dashboard/config.js

# Verify file is in correct location
ls -la dashboard/config.js
```

### Chart Doesn't Render

**Possible Causes:**
1. Chart.js CDN not accessible
2. No 7-day data returned
3. Browser console errors

**Solutions:**
1. Check internet connection (CDN needs to be reachable)
2. Check API response has `last_7_days` array
3. Open browser console (F12 > Console) for errors

### CORS Error on Production

**Solution:**
```bash
# Update backend CORS configuration
# In backend/contact_form_lambda.py:

CORS_HEADERS = {
    'Access-Control-Allow-Origin': 'https://yourusername.github.io',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Api-Key'
}

# Redeploy: sam deploy
```

## Performance Tips

1. **Enable Chart.js Caching**
   - Browser caches CDN scripts automatically
   - First load may be slower; subsequent loads are fast

2. **Optimize API Response**
   - Only fetch needed form ID (don't load all forms)
   - 7-day data is lightweight (~1 KB per response)

3. **Use HTTPS in Production**
   - GitHub Pages uses HTTPS automatically
   - AWS API Gateway supports HTTPS

## Browser Support

| Browser | Status |
|---------|--------|
| Chrome 90+ | ✅ Full support |
| Firefox 88+ | ✅ Full support |
| Safari 14+ | ✅ Full support |
| Edge 90+ | ✅ Full support |
| IE 11 | ❌ Not supported |

## File Structure

```
dashboard/
├── index.html          # Main dashboard UI (responsive, accessible)
├── app.js              # Application logic (vanilla JS)
├── config.example.js   # Configuration template
├── config.js           # Active configuration (not in git)
└── README.md           # This file
```

## Dependencies

- **Chart.js** (via CDN): Rendering line charts
- **Vanilla JavaScript**: All application logic
- **No npm packages**: Works in any environment

## Support

For issues or questions:

1. Check this README's Troubleshooting section
2. Review browser console for error messages (F12)
3. Check CloudWatch logs for backend errors
4. See `local/scripts/setup-observability.sh` for monitoring setup

## Next Steps

1. ✅ Copy config: `cp dashboard/config.example.js dashboard/config.js`
2. ✅ Edit config.js with your API details
3. ✅ Open dashboard: `open dashboard/index.html` (or use a server)
4. ✅ Test with your form IDs
5. ✅ Deploy to production (GitHub Pages or self-hosted)
6. ✅ Set up monitoring (see Observability guide)
