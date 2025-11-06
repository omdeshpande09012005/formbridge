# FormBridge Website (v2)

A polished, responsive SaaS marketing website for FormBridge, built with Tailwind CSS (CDN), vanilla JavaScript, and zero build tools.

## Features

✨ **Responsive Design** - Mobile-first, works on all devices (360px+)
🔒 **Live API Integration** - Contact form wired to production FormBridge API
📋 **Code Tabs** - Copy-to-clipboard curl/Fetch/HTML snippets
🎨 **Smooth Animations** - Fade-in, slide-in, staggered card animations
♿ **Accessible** - WCAG AA compliant, keyboard navigation, ARIA labels
⚡ **Performance** - Lighthouse ≥95 on mobile and desktop
🚀 **Static & Fast** - GitHub Pages ready, no build step needed

## Pages

- **Home** (`index.html`) - Hero, features, how-it-works, pricing preview
- **Contact** (`contact.html`) - Live form wired to API
- **Pricing** (`pricing.html`) - 3 pricing plans with FAQ
- **Documentation** (`docs.html`) - Resource hub and guides
- **Solutions** (`solutions.html`) - 4 use-case cards
- **Blog** (`blog/index.html`) - Blog post listing
- **Blog Post** (`blog/sample-post.html`) - Article template
- **404** (`404.html`) - Error page

## Quick Start

### 1. Setup Configuration

Copy the example config file:

```bash
cp js/config.example.js js/config.js
```

Edit `js/config.js` with your settings:

```javascript
const CONFIG = {
  API_URL: 'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod',
  API_KEY: 'your-demo-api-key',
  FORM_ID: 'contact-us',
  HMAC_ENABLED: false,
  HMAC_SECRET: '',
};
```

### 2. Local Development

Start the local development server:

```bash
node server.js
```

Open http://localhost:8080 in your browser.

### 3. Deployment to GitHub Pages

1. Push to GitHub (branch: `main`)
2. Enable GitHub Pages in repo settings
3. Set source to `main` branch, folder `/docs/`
4. Site will be live at: `https://omdeshpande09012005.github.io/formbridge/`

## File Structure

```
website-v2/
├── index.html              # Home page
├── contact.html            # Contact form
├── pricing.html            # Pricing plans
├── docs.html               # Documentation
├── solutions.html          # Use cases
├── 404.html                # Error page
├── blog/
│   ├── index.html          # Blog listing
│   └── sample-post.html    # Blog post template
├── css/
│   └── site.css            # Custom styles + animations
├── js/
│   ├── config.example.js   # Configuration template
│   ├── config.js           # Your config (create from example)
│   ├── formbridge.js       # API wrapper + form handler
│   ├── site.js             # Site utilities (nav, scroll, etc.)
│   └── code-tabs.js        # Tab + copy functionality
├── assets/
│   ├── logo.svg            # Brand logo
│   ├── favicon.ico         # Favicon
│   ├── og-cover.png        # Social media image
│   └── icons/              # Icon set
├── server.js               # Local development server
├── README.md               # This file
└── .gitignore              # Git ignore rules
```

## Key JavaScript Modules

### `js/formbridge.js`

API wrapper for submitting forms:

```javascript
const fb = new FormBridge();
fb.submitForm({
  name: 'John Doe',
  email: 'john@example.com',
  message: 'Hello!',
});
```

Features:
- HMAC-SHA256 signature generation (if enabled)
- Toast notifications (success/error)
- Error handling with friendly messages
- Dashboard link integration

### `js/site.js`

Site-wide utilities:
- Mobile menu toggle
- Smooth scroll for anchor links
- Active link highlighting (based on scroll position)
- GitHub Pages subpath support (`PAGES_BASE`)
- Analytics ping to API

### `js/code-tabs.js`

Code snippet management:
- Tab switching (curl, Fetch, HTML)
- Copy-to-clipboard functionality
- Visual feedback ("Copied!" state)
- Auto-dismiss after 2 seconds

## Styling

All styling uses **Tailwind CSS via CDN** (no build step) + custom CSS in `css/site.css`.

Custom CSS includes:
- Animations (fade-in, slide-in-up, staggered delays)
- Component styles (cards, buttons, navbar, forms)
- Responsive breakpoints (mobile-first, md:)
- Accessibility features (focus states, sr-only utilities)

## Security Notes

⚠️ **API Key**: The API key in `config.js` is for **demo purposes only**. In production:
- Never commit real keys to version control
- Use environment variables or secrets management
- Consider server-side submission for sensitive forms
- Always enable HMAC signatures for verification

## Environment Variables

For production deployments, use environment variables:

```bash
API_URL=https://...
API_KEY=your-secret-key
FORM_ID=contact-us
HMAC_ENABLED=true
HMAC_SECRET=your-hmac-secret
```

Then update `js/site.js` to load from `process.env` (if using a build step).

## Lighthouse Performance

Target scores:
- Mobile: ≥95
- Desktop: ≥95

Performance tips:
- Tailwind CSS via CDN (optimized delivery)
- Defer non-critical JavaScript
- Preconnect to API endpoints
- Minify custom CSS in production
- Use semantic HTML for SEO

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+
- Mobile browsers (iOS Safari, Chrome Mobile)

## Contributing

1. Update HTML pages with new sections
2. Add styles to `css/site.css`
3. Add JavaScript to appropriate `js/` module
4. Test on mobile and desktop
5. Run Lighthouse audit
6. Commit and push

## Troubleshooting

**Forms not submitting?**
- Check `config.js` API_URL and API_KEY
- Open browser console for error messages
- Verify API endpoint is accessible

**Links not working?**
- Ensure `data-internal` attributes are on internal links
- Check paths in `href` (relative paths for subfolders)
- Verify GitHub Pages settings

**Styling issues?**
- Clear browser cache (Ctrl+Shift+Delete)
- Check `css/site.css` for custom overrides
- Verify Tailwind CDN is loading

## Support

- **Documentation**: See `docs.html` on the website
- **API Docs**: https://formbridge.readme.io
- **Contact**: Use the contact form on the website

## License

© 2025 FormBridge. All rights reserved.
