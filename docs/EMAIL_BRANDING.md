# FormBridge Email Branding Guide

Complete guide to branded HTML email notifications for AWS SES with customization, local preview, and accessibility.

---

## 📧 Overview

FormBridge sends branded HTML emails for contact form submissions with:

- ✅ **Responsive mobile-first design** (works on all devices)
- ✅ **Inline CSS** (safe for SES and all email clients)
- ✅ **Dark mode support** (respects user preference)
- ✅ **Configurable branding** (logo, colors, CTA link)
- ✅ **Text fallback** (accessibility and fallback rendering)
- ✅ **Graceful degradation** (works in Outlook, Gmail, Apple Mail, etc.)

### Tech Stack

- **Template**: Pure HTML5 with inline CSS
- **Image Hosting**: GitHub Pages or CDN (HTTPS required)
- **Fonts**: System font stack (no external requests)
- **Email Client Support**: Gmail, Outlook, Apple Mail, Yahoo, Mobile clients

---

## 🎨 Why Inline CSS?

**AWS SES and email clients strip external stylesheets.** This template uses inline styles to ensure:

1. **Compatibility**: Works in all major email clients
2. **Reliability**: Styles don't get blocked
3. **Performance**: No external requests needed
4. **Security**: No injection vectors

### What's NOT Used

❌ External stylesheets (`<link>` tags)  
❌ Web fonts (`@font-face`)  
❌ JavaScript  
❌ Animated GIFs or videos  
❌ Transparent PNGs over colored backgrounds (Outlook issue)

### What IS Used

✅ Inline `<style>` tags (for media queries and responsive)  
✅ Inline `style` attributes (for cell styling)  
✅ System fonts (Arial, Helvetica, Segoe, etc.)  
✅ Static images (HTTPS URLs)  
✅ HTML tables (most reliable for email layouts)

---

## 🖼️ Image Hosting (Logo & Branding)

### GitHub Pages (Recommended for Open Source)

1. **Add logo to your site repo:**
   ```
   website/assets/logo.svg
   website/assets/logo-dark.svg  (optional)
   ```

2. **GitHub Pages URL format:**
   ```
   https://[username].github.io/website/assets/logo.svg
   ```

3. **For FormBridge:**
   ```
   https://omdeshpande09012005.github.io/website/assets/logo.svg
   ```

4. **Verify it's public:**
   ```bash
   curl -I https://omdeshpande09012005.github.io/website/assets/logo.svg
   # Should return: HTTP/1.1 200 OK
   ```

### Alternative Hosting Options

| Provider | URL Format | Cost | SSL | Reliability |
|----------|-----------|------|-----|-------------|
| GitHub Pages | `https://user.github.io/path/image.svg` | Free | ✅ Yes | ⭐⭐⭐⭐⭐ |
| AWS S3 + CloudFront | `https://cdn.example.com/logo.svg` | $$ | ✅ Yes | ⭐⭐⭐⭐⭐ |
| Cloudinary | `https://res.cloudinary.com/.../logo.svg` | $$ | ✅ Yes | ⭐⭐⭐⭐⭐ |
| Imgur | `https://imgur.com/abc123.png` | Free | ✅ Yes | ⭐⭐⭐ |

**⚠️ Requirements:**
- Must be **HTTPS** (not HTTP)
- Must be **publicly accessible** (no authentication)
- Should be **stable** (long-lived URL)
- Recommended: **CDN** (fast global delivery)

---

## 🎯 Customization

### 1. Brand Colors

Edit `backend/contact_form_lambda.py` environment variables:

```python
# Default: Purple → Pink gradient
BRAND_PRIMARY_HEX = "#6D28D9"     # Primary color (header gradient start)
BRAND_SECONDARY_HEX = "#EC4899"   # Secondary color (gradient end)

# Or customize in template_manifest.json
```

In the email template, these are applied to:
- Header gradient: `linear-gradient(135deg, {{brand_primary_hex}} 0%, #EC4899 100%)`
- Accent elements: Buttons, links, borders

### 2. Logo & Branding

Set environment variables:

```python
BRAND_NAME = "FormBridge"
BRAND_LOGO_URL = "https://your-domain/assets/logo.svg"
```

**Logo Requirements:**
- **Format**: SVG (preferred) or PNG
- **Size**: Display as 60×60px (set actual dimensions)
- **Aspect Ratio**: Square or slightly wider is best
- **Background**: Transparent (will display on purple gradient)
- **Style**: Clean, recognizable at small sizes

### 3. CTA Link (Dashboard)

```python
DASHBOARD_URL = "https://your-analytics-dashboard.com"
```

The "Open Dashboard" button links here in every email.

### 4. Custom Subject Line

Template manifest defines the subject:

```json
"subject_template": "[FormBridge] New submission on {{form_id}} — {{name}}"
```

To customize:
- Edit `email_templates/template_manifest.json`
- Update `subject_template` field
- Available placeholders: `{{form_id}}`, `{{name}}`, `{{email}}`, etc.

---

## � Per-Form Routing (Form-Specific Configuration)

FormBridge supports **per-form routing** with form-specific recipients, subject prefixes, brand colors, and dashboard URLs.

### How It Works

1. **Form Config Table**: `formbridge-config` DynamoDB table stores per-form configuration
2. **Form Badge**: Email header displays a form badge (e.g., "FORM: contact-us")
3. **Badge Color**: Uses form-specific `brand_primary_hex` if configured, else global default
4. **Graceful Fallback**: If no form config exists, uses global environment defaults

### Form-Specific Config

Each form can override:

```json
{
  "pk": "FORM#contact-us",
  "sk": "CONFIG#v1",
  "recipients": ["admin@example.com"],
  "subject_prefix": "[Contact]",
  "brand_primary_hex": "#6D28D9",
  "dashboard_url": "https://example.com/dashboard?form=contact-us"
}
```

### Email Subject with Prefix

If form has `subject_prefix` configured:
```
[Contact] [FormBridge] New submission on contact-us — John Doe
```

Without prefix (or no config):
```
[FormBridge] New submission on contact-us — John Doe
```

### Badge in Email Header

Email template displays a form badge with the form ID:

```
┌─────────────────────────────────────┐
│  [Logo]  New FormBridge Submission │
│  You have a new submission         │
│  FORM: CONTACT-US                  │  ← Colored badge
└─────────────────────────────────────┘
```

Badge background color comes from form-specific `brand_primary_hex`.

### Setup Per-Form Routing

**See:** `docs/FORM_ROUTING.md` for complete setup instructions:
- Table schema and item format
- LocalStack seeding
- AWS CLI seeding
- Examples (contact-us, careers, support)
- Testing and validation

**Quick Start:**
```bash
# Seed form configs locally
make route-seed-local

# Or in production
./scripts/seed_form_config.sh --region ap-south-1 --table formbridge-config
```

---

## �🚀 Deployment

### Backend Integration

The Lambda function automatically sends HTML emails:

```python
from contact_form_lambda import render_email_html

# Build context from submission
context = {
    'form_id': 'website-contact',
    'name': 'John Doe',
    'email': 'john@example.com',
    'message': 'Full message here...',
    'excerpt': 'First 240 chars...',
    # ... etc
}

# Render HTML
html_body = render_email_html(context)

# Send via SES with HTML + Text fallback
response = ses.send_email(
    Source='noreply@example.com',
    Destination={'ToAddresses': ['contact@example.com']},
    Message={
        'Subject': {'Data': 'New FormBridge Submission'},
        'Body': {
            'Html': {'Data': html_body, 'Charset': 'UTF-8'},
            'Text': {'Data': plaintext_fallback, 'Charset': 'UTF-8'}
        }
    }
)
```

### Environment Variables

Set these in AWS Lambda console or `samconfig.toml`:

```toml
[default.build.parameters]
BRAND_NAME = "FormBridge"
BRAND_LOGO_URL = "https://omdeshpande09012005.github.io/website/assets/logo.svg"
BRAND_PRIMARY_HEX = "#6D28D9"
DASHBOARD_URL = "https://omdeshpande09012005.github.io/docs/"
```

---

## 🔍 Local Preview

### Using the Email Preview Tool

1. **Open the previewer:**
   ```bash
   # Open in browser (from project root)
   file:///path/to/tools/email_preview.html
   # or with Python server
   python -m http.server 8000
   # Then: http://localhost:8000/tools/email_preview.html
   ```

2. **Features:**
   - ✏️ Edit fields live (name, email, message, etc.)
   - 📱 Toggle mobile/desktop view
   - 🌙 Preview dark mode rendering
   - 📋 Copy HTML to clipboard
   - ⬇️ Download rendered HTML
   - 🔄 Live preview updates

3. **Mobile Testing:**
   - Click "📱 Mobile" button
   - Preview shows 375px width (iPhone 8)
   - Test message truncation and layout wrapping

### Using MailHog (Local SMTP)

1. **Start MailHog:**
   ```bash
   mailhog
   # MailHog UI: http://localhost:8025
   # SMTP: localhost:1025
   ```

2. **Configure Lambda locally:**
   ```bash
   export BRANCH=local
   export MAIL_PROVIDER=mailhog
   export MAILHOG_HOST=localhost
   export MAILHOG_PORT=1025
   
   sam build && sam local start-api
   ```

3. **Submit contact form:**
   - Go to http://localhost:8080/contact.html
   - Fill and submit form
   - Check MailHog: http://localhost:8025
   - Click email → "HTML" tab to see rendered

4. **What to check:**
   - Logo appears and loads
   - Gradient header displays correctly
   - Text is readable
   - Links are clickable
   - Button has correct gradient
   - Meta information formats correctly
   - Dark mode (if enabled) looks good

---

## 📊 Production Deployment (AWS SES)

### Prerequisites

1. **Verify Sender Email:**
   ```bash
   # AWS Console → SES → Verified Identities
   # Or via AWS CLI:
   aws ses verify-email-identity --email-address noreply@yourco.com
   ```

2. **Verify Recipient Emails (Sandbox Mode):**
   ```bash
   # In SES sandbox, recipients must be verified
   aws ses verify-email-identity --email-address contact@example.com
   ```

3. **Request Production Access:**
   - Submit SES sandbox exit request in AWS Console
   - Amazon reviews (usually takes 24-48 hours)
   - Once approved, can send to any email address

### Sending HTML Emails

```python
import boto3
from contact_form_lambda import render_email_html

ses = boto3.client('ses', region_name='ap-south-1')

# Build context
context = {
    'form_id': 'website-contact',
    'name': 'Sarah Chen',
    'email': 'sarah@company.com',
    'message': 'Your full message...',
    'excerpt': 'First 240 chars...',
    'page': 'https://example.com/contact',
    'id': 'sub_1234567890',
    'ts': '2025-11-05T14:30:00Z',
    'ip': '192.0.2.1',
    'ua': 'Mozilla/5.0...',
    'dashboard_url': os.getenv('DASHBOARD_URL'),
    'brand_name': os.getenv('BRAND_NAME', 'FormBridge'),
    'brand_logo_url': os.getenv('BRAND_LOGO_URL'),
    'brand_primary_hex': os.getenv('BRAND_PRIMARY_HEX', '#6D28D9')
}

# Render HTML
html_body = render_email_html(context)

# Send email with HTML + Text fallback
try:
    response = ses.send_email(
        Source='noreply@yourco.com',
        Destination={'ToAddresses': [context['email']]},
        Message={
            'Subject': {
                'Data': f"[FormBridge] New submission on {context['form_id']} — {context['name']}",
                'Charset': 'UTF-8'
            },
            'Body': {
                'Html': {
                    'Data': html_body,
                    'Charset': 'UTF-8'
                },
                'Text': {
                    'Data': plaintext_fallback,
                    'Charset': 'UTF-8'
                }
            }
        }
    )
    print(f"Email sent! MessageId: {response['MessageId']}")
except Exception as e:
    print(f"Error sending email: {e}")
    # Fall back to text-only if HTML fails
    send_text_only(context)
```

---

## ♿ Accessibility

### WCAG 2.1 Compliance

Our template meets WCAG AA standards:

| Criterion | Implementation |
|-----------|------------------|
| **Color Contrast** | Text: 4.5:1+ ratio for body text, 3:1+ for large text |
| **Alt Text** | Logo has descriptive alt text: "{{brand_name}} Logo" |
| **Text Size** | Minimum 14px for body, 28px for headlines |
| **Line Height** | 1.5+ (improved readability) |
| **Link Targets** | 44px minimum tap target (buttons) |
| **Semantic HTML** | Tables for layout structure, headings for content |
| **Color Usage** | Not sole differentiator (text + styling) |
| **Font Stack** | System fonts (no custom fonts that may fail to load) |

### Best Practices

1. **Alt Text for Images:**
   ```html
   <img src="{{brand_logo_url}}" alt="{{brand_name}} Logo">
   ```

2. **High Contrast Colors:**
   - Text on dark backgrounds: white/light gray
   - Text on light backgrounds: dark gray/black
   - Links: Distinct color (#6D28D9) with underline

3. **Readable Typography:**
   - Base size: 14px (body text)
   - Heading: 28px (hero)
   - Labels: 12px (with increased letter-spacing)
   - Line-height: 1.6 (comfortable spacing)

4. **Keyboard Navigation:**
   - All links and buttons are tab-accessible
   - Buttons have visible focus states (in supported clients)
   - Email clients don't support full keyboard nav, but links work

5. **Screen Reader Friendly:**
   - Semantic HTML tables with `<thead>`, `<tbody>`
   - Descriptive link text ("Open Dashboard" vs "Click here")
   - Headings indicate content structure

---

## 🐛 Troubleshooting

### Images Not Loading

**Problem:** Logo appears broken in email client.

**Solutions:**
1. **Verify URL is HTTPS:**
   ```bash
   curl -I https://omdeshpande09012005.github.io/website/assets/logo.svg
   ```

2. **Check image is public (no auth required):**
   - Open URL directly in browser
   - Should load without login

3. **Verify image format:**
   - SVG works best
   - PNG/JPG also supported
   - Avoid WebP (not universally supported in emails)

4. **Check file size:**
   - Keep under 100KB (logos should be <20KB)
   - Compress SVGs with `svgo`

5. **Use CDN:**
   - GitHub Pages sometimes has latency
   - Consider CloudFront or Cloudinary

### Gradient Not Showing

**Problem:** Header gradient appears as solid color in some clients (Outlook).

**Solution:** This is expected. We include fallback colors:
```css
background: linear-gradient(135deg, #6D28D9 0%, #EC4899 100%);
/* Older clients will show purple (#6D28D9) */
```

To verify gradient renders:
- Test in Gmail, Apple Mail, Thunderbird
- Check if primary color (#6D28D9) displays as fallback

### Text Overlapping or Cut Off

**Problem:** Message excerpt or metadata text appears cut off.

**Solutions:**
1. **Check long values:**
   - Very long email addresses
   - Very long user agent strings
   - Check `word-break: break-all` CSS is applied

2. **Test with real data:**
   - Use `tools/email_preview.html`
   - Paste actual long values
   - See how they render at mobile width

3. **Adjust excerpt length:**
   - Edit `render_email_html()` excerpt calculation
   - Reduce from 240 chars if needed

### SES Sending Fails

**Problem:** Email doesn't send or returns error.

**Solutions:**
1. **Check sender email verified:**
   ```bash
   aws ses list-verified-email-addresses
   ```

2. **Check recipient email verified (sandbox mode):**
   ```bash
   aws ses list-verified-email-addresses
   ```

3. **Check HTML is valid:**
   - Use `tools/email_preview.html` to verify
   - Look for unclosed tags or syntax errors

4. **Check AWS region:**
   - Verify SES client uses correct region
   - Verified addresses are region-specific

5. **Enable SES logs:**
   ```python
   import logging
   logging.basicConfig(level=logging.DEBUG)
   ```

### Dark Mode Issues

**Problem:** Email doesn't render correctly in dark mode clients.

**Solution:** We include dark mode media query:
```css
@media (prefers-color-scheme: dark) {
    body { background-color: #0f172a; color: #e2e8f0; }
    /* etc. */
}
```

Clients that support it (Apple Mail, Gmail): Dark backgrounds + light text  
Clients that don't: Light backgrounds + dark text (still readable)

To test dark mode:
1. Open `tools/email_preview.html`
2. Check "🌙 Dark" checkbox
3. Should see dark backgrounds with light text

---

## 📝 Template Manifest

File: `email_templates/template_manifest.json`

Defines:
- ✅ Template metadata (name, version, description)
- ✅ Subject line template with placeholders
- ✅ Required placeholders and their descriptions
- ✅ Default values for optional fields
- ✅ Email format settings (charset, encoding)
- ✅ Feature flags (responsive, dark-mode, etc.)
- ✅ Accessibility checklist
- ✅ Usage examples for Python/SES
- ✅ Environment variables reference
- ✅ Changelog

Use this as reference when:
- Adding new placeholders
- Changing default values
- Updating feature flags
- Integrating with other systems

---

## 📚 API Reference

### Placeholders

All placeholders are required in context dict:

| Placeholder | Type | Example | Notes |
|-------------|------|---------|-------|
| `form_id` | string | "website-contact" | Unique form identifier |
| `name` | string | "Sarah Chen" | Submitter name |
| `email` | string | "sarah@company.com" | Submitter email (clickable) |
| `message` | string | "Full message body..." | Complete message text |
| `excerpt` | string | "First 240 chars..." | Message preview (no newlines) |
| `page` | URL | "https://example.com/contact" | Page URL where form was submitted |
| `id` | string | "sub_1234567890abc" | Unique submission ID |
| `ts` | ISO 8601 | "2025-11-05T14:30:00Z" | Submission timestamp |
| `ip` | string | "192.0.2.1" | Submitter IP address |
| `ua` | string | "Mozilla/5.0..." | Submitter user agent |
| `dashboard_url` | URL | "https://example.com/dashboard" | CTA button link |
| `brand_name` | string | "FormBridge" | Your brand name |
| `brand_logo_url` | URL | "https://example.com/logo.svg" | Logo image URL (HTTPS) |
| `brand_primary_hex` | hex | "#6D28D9" | Primary brand color |

### Sections

The template includes:

1. **Header**
   - Logo image
   - Brand name
   - "New {{brand_name}} Submission" title
   - Gradient background

2. **Submission Details**
   - Name
   - Email (clickable)
   - Message excerpt

3. **Technical Details**
   - Form ID
   - Submission ID
   - Timestamp
   - Page URL
   - IP address
   - User agent

4. **CTA Button**
   - "📊 Open Dashboard" button
   - Links to `{{dashboard_url}}`
   - Gradient styling

5. **Footer**
   - Brand name + tagline
   - Automated notification disclaimer
   - Support link

---

## 🔗 Related Files

- `email_templates/base.html` - Main template file
- `email_templates/template_manifest.json` - Metadata and configuration
- `tools/email_preview.html` - Browser-based previewer
- `backend/contact_form_lambda.py` - Lambda function integration
- `docs/EMAIL_BRANDING.md` - This file

---

## 📞 Support & Questions

### Local Testing Checklist

- [ ] Previewer loads at `tools/email_preview.html`
- [ ] Can edit fields and see live updates
- [ ] Mobile view shows proper layout (375px)
- [ ] Dark mode checkbox toggles colors
- [ ] "Copy HTML" button works
- [ ] Can download rendered HTML

### MailHog Testing Checklist

- [ ] MailHog running at http://localhost:8025
- [ ] Lambda configured for MailHog (env vars)
- [ ] Contact form submission successful
- [ ] Email appears in MailHog inbox
- [ ] HTML tab shows rendered template
- [ ] Logo loads (if on public URL)
- [ ] Colors display correctly
- [ ] Text is readable

### SES Production Checklist

- [ ] Sender email verified in SES
- [ ] Recipient emails verified (sandbox mode)
- [ ] Environment variables set in Lambda
- [ ] Test submission successful
- [ ] Email received in inbox
- [ ] HTML renders in email client
- [ ] Logo loads (HTTPS public URL)
- [ ] Links are clickable
- [ ] Mobile view readable (narrow width)

---

## 📄 License

FormBridge email templates are provided as-is for use in your FormBridge deployments.

---

## 🚀 Quick Reference

### Environment Variables

```bash
BRAND_NAME="FormBridge"
BRAND_LOGO_URL="https://omdeshpande09012005.github.io/website/assets/logo.svg"
BRAND_PRIMARY_HEX="#6D28D9"
DASHBOARD_URL="https://omdeshpande09012005.github.io/docs/"
```

### Preview Tool Usage

```bash
# 1. Open in browser
open tools/email_preview.html

# 2. Edit fields (live update)
# 3. Toggle mobile/dark mode
# 4. Copy HTML or download
```

### SES Send Example

```python
html = render_email_html(context)
ses.send_email(
    Source='noreply@example.com',
    Destination={'ToAddresses': [email]},
    Message={
        'Subject': {'Data': subject},
        'Body': {
            'Html': {'Data': html, 'Charset': 'UTF-8'},
            'Text': {'Data': plaintext, 'Charset': 'UTF-8'}
        }
    }
)
```

---

**Last Updated:** November 5, 2025  
**Template Version:** 1.0.0  
**Status:** ✅ Production Ready
