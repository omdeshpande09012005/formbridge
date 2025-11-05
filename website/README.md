# FormBridge Website

Static marketing website for FormBridge. Features a home page, documentation hub, blog, and live contact form demo.

## 🎨 Features

- **Responsive Design**: Mobile-first, works on all devices
- **Tailwind CDN**: No build step required
- **Live Contact Form**: Real form submission to FormBridge API
- **Dark Mode Ready**: Uses CSS variables for theming
- **Accessibility**: WCAG 2.1 compliant (ARIA labels, contrast ratios, keyboard navigation)
- **Fast**: Pure static HTML/CSS/JS, zero dependencies
- **SEO Friendly**: Open Graph tags, meta descriptions, structured data

## 📁 Structure

```
website/
├── index.html              # Home page (hero, features, CTA)
├── contact.html            # Live contact form demo
├── docs.html               # Documentation hub
├── blog/
│   ├── index.html         # Blog listing
│   └── sample-post.html   # Sample article (template)
├── assets/
│   ├── logo.svg           # FormBridge logo
│   ├── favicon.ico        # Favicon
│   └── og-cover.png       # Social preview
├── css/
│   └── site.css           # Custom styles (animations, colors)
├── js/
│   ├── config.example.js  # Configuration template
│   ├── config.js          # Generated config (git-ignored)
│   └── site.js            # Nav, forms, smooth scroll, HMAC signing
├── server.js              # Node.js static server
└── README.md              # This file
```

## 🚀 Quick Start

### 1. Copy Configuration

```bash
cp js/config.example.js js/config.js
```

### 2. Update Config for Your Environment

**For Development (local Lambda):**

```javascript
window.CONFIG = {
  API_URL: "http://127.0.0.1:3000",
  API_KEY: "",  // Optional for dev
  FORM_ID: "website-contact",
  HMAC_ENABLED: false,
  HMAC_SECRET: ""
};
```

**For Production:**

```javascript
window.CONFIG = {
  API_URL: "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod",
  API_KEY: "your_api_key_here",
  FORM_ID: "website-contact",
  HMAC_ENABLED: true,  // Optional
  HMAC_SECRET: "your_hmac_secret"  // Only if HMAC_ENABLED
};
```

### 3. Start Local Lambda (in another terminal)

```bash
cd ..  # Go back to project root
sam build
sam local start-api
```

### 4. Start Website Server

```bash
cd website
node server.js
```

### 5. Open in Browser

```
http://127.0.0.1:8080
```

## 🧪 Testing

### Test the Contact Form

1. Go to http://127.0.0.1:8080/contact.html
2. Fill in the form (name, email, message)
3. Click "Send Message"
4. You should see a success toast with a submission ID
5. Check your local Lambda logs to verify submission

### Test with HMAC Signing

1. Set `HMAC_ENABLED: true` in `js/config.js`
2. Set `HMAC_SECRET: "test-secret"` (must match your Lambda config)
3. Submit the form again
4. The site will automatically compute X-Timestamp and X-Signature headers

### Test API Directly with Curl

```bash
# Without API key (dev)
curl -X POST http://127.0.0.1:3000/submit \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Testing FormBridge"
  }'

# With API key (prod)
curl -X POST https://api.formbridge.dev/submit \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: your_api_key" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Testing FormBridge"
  }'
```

## 🎯 Pages

### index.html (Home)

- **Navbar**: Navigation with mobile menu
- **Hero**: Headline, subheading, CTA buttons
- **Features**: 6 feature cards
- **How it Works**: 4-step architecture explanation
- **Code Samples**: Tabs for curl, JavaScript, Python
- **CTA Section**: Call-to-action for getting started
- **Footer**: Links and social

### contact.html (Live Demo)

- **Form**: Name, email, message fields
- **Left Panel**: How it works explanation
- **Right Panel**: Contact form with client-side validation
- **Response Example**: Shows JSON response format
- **Error Handling**: User-friendly error messages
- **Success Toast**: Shows submission ID on success

### docs.html (Documentation Hub)

- **Doc Cards**: Links to OpenAPI, Postman, Swagger, etc.
- **Quick Examples**: JavaScript and HTML form examples
- **FAQ**: Collapsible questions and answers

### blog/ (Blog)

- **Listing**: Grid of blog posts
- **Sample Post**: Full article with:
  - Title, author, date, reading time
  - Table of contents
  - Code blocks with syntax highlighting
  - Author bio
  - Related articles

## 🔐 Security

### API Key on Frontend (Development)

In development, you can leave `API_KEY` empty (no authentication) or use a test key. This is fine for local testing.

### Production Security

For production, API keys will be exposed in the browser. This is a limitation of static sites. **Recommendations:**

1. Use HMAC signing for additional request validation
2. Implement rate limiting on the API Gateway
3. Use IP allowlisting if hosting behind a specific domain
4. Rotate API keys regularly
5. Consider a backend proxy to sign requests server-side

## 🎨 Customization

### Colors

Edit `website/css/site.css`:

```css
:root {
  --color-primary: #6D28D9;    /* Purple */
  --color-accent: #EC4899;     /* Pink */
  --color-dark: #0F172A;       /* Slate */
}
```

### Tailwind Config

Tailwind is loaded via CDN (no build), so custom config is limited to CSS variables and inline `<style>` tags.

For complex customization, consider setting up a build pipeline:

```bash
npm init -y
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss -i ./css/input.css -o ./css/tailwind.css
```

### Analytics

Add Google Analytics or Plausible Analytics in `<head>`:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_ID');
</script>
```

## 📦 Deployment

### Deploy to GitHub Pages

```bash
# Copy website folder to docs/
cp -r website/* docs/

# Update js/config.js with production API URL
# Commit and push
git add docs/
git commit -m "Deploy website to GitHub Pages"
git push origin main

# Enable GitHub Pages in repo settings (source: /docs folder)
```

Then your site will be available at: `https://omdeshpande09012005.github.io/`

### Deploy to Vercel / Netlify

Both Vercel and Netlify support static sites:

**Vercel:**
```bash
npm i -g vercel
vercel
```

**Netlify:**
```bash
npm i -g netlify-cli
netlify deploy
```

### Deploy to AWS S3 + CloudFront

```bash
# Upload to S3
aws s3 sync website/ s3://my-formbridge-site/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
```

## 🛠️ Development

### Add a New Page

1. Create `website/my-page.html`
2. Include navbar and footer from existing pages (copy/paste)
3. Link from navbar in `index.html`
4. Reload `http://127.0.0.1:8080/my-page.html`

### Add a Blog Post

1. Copy `website/blog/sample-post.html` to `website/blog/my-post.html`
2. Update title, content, metadata
3. Add card to `website/blog/index.html`

### Test on Mobile

```bash
# Find your machine IP
ipconfig getifaddr en0  # macOS
hostname -I             # Linux
ipconfig                # Windows

# Then visit: http://<YOUR_IP>:8080
```

## 🐛 Troubleshooting

### Port 8080 Already in Use

```bash
# Find process using port 8080
lsof -i :8080  # macOS/Linux
netstat -ano | findstr :8080  # Windows

# Use different port
PORT=3333 node server.js
```

### Contact Form Not Submitting

1. Check `js/config.js` - is `API_URL` correct?
2. Open browser DevTools (F12), go to Network tab
3. Try submitting the form and check the request/response
4. Look for CORS errors or 403 Forbidden
5. Verify Lambda is running: `sam local start-api`

### Mixed Content Error (http/https)

If hosted on HTTPS, ensure `API_URL` is also HTTPS (not http://).

### HMAC Signing Errors

1. Verify `HMAC_SECRET` matches your Lambda environment variable
2. Check browser console for crypto errors
3. Try disabling HMAC first (`HMAC_ENABLED: false`) to isolate the issue

## 📚 Resources

- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [MDN: Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
- [Web Crypto API (HMAC)](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto)
- [GitHub Pages](https://pages.github.com/)

## 📄 License

Same as the main FormBridge project.

---

**Questions?** Check the main [FormBridge README](../README.md) or [open an issue](https://github.com/omdeshpande09012005/formbridge/issues).
