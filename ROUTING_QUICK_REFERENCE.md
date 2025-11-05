# FormBridge Per-Form Routing - Quick Reference

## 🎯 What It Does

Each form gets its own **recipients**, **subject prefix**, **brand color**, and **dashboard URL**.

```
Form Submission (form_id: "careers")
        ↓
Lambda queries DynamoDB config table
        ↓
Found: FORM#careers → CONFIG#v1
{
  "recipients": ["hr@example.com"],
  "subject_prefix": "[Careers]",
  "brand_primary_hex": "#0EA5E9",
  "dashboard_url": "https://..."
}
        ↓
Email sent to hr@example.com with:
- Subject: [Careers] [FormBridge] New submission...
- Badge: "FORM: CAREERS" (blue color)
- CTA: Link to careers dashboard
```

---

## 📦 New DynamoDB Table

**Name:** `formbridge-config`

**Item Format:**
```json
{
  "pk": "FORM#form-id-here",
  "sk": "CONFIG#v1",
  "recipients": ["email1@example.com", "email2@example.com"],
  "subject_prefix": "[Optional Prefix]",
  "brand_primary_hex": "#0EA5E9",
  "dashboard_url": "https://example.com/dashboard"
}
```

---

## 🚀 Quick Start

### 1. Deploy Infrastructure
```bash
cd backend
sam build && sam deploy
```

### 2. Seed Form Configs (Local)
```bash
make route-seed-local
```

### 3. Seed Form Configs (Production)
```bash
./scripts/seed_form_config.sh --region ap-south-1
```

### 4. Submit Test Form
```bash
curl -X POST https://api.example.com/submit \
  -d '{
    "form_id": "careers",
    "name": "Jane",
    "email": "jane@example.com",
    "message": "Test",
    "page": "https://example.com"
  }'
```

---

## 📧 Sample Configurations

### Contact Form
```bash
FORM_ID="contact-us"
RECIPIENTS="admin@example.com,support@example.com"
PREFIX="[Contact]"
COLOR="#6D28D9"
```

### Careers Form
```bash
FORM_ID="careers"
RECIPIENTS="hr@example.com,hiring@example.com"
PREFIX="[Careers]"
COLOR="#0EA5E9"
```

### Support Form
```bash
FORM_ID="support"
RECIPIENTS="support@example.com"
PREFIX="[Support]"
COLOR="#10B981"
```

---

## 🔄 Fallback Behavior

If no form config found → Use environment defaults:
- `SES_RECIPIENTS` env var
- `BRAND_PRIMARY_HEX` env var
- `DASHBOARD_URL` env var
- No subject prefix

**Gracefully handles:** Missing table, missing item, permission errors

---

## 📧 Email Changes

### Subject Line
```
[Contact] [FormBridge] New submission on contact-us — John Doe
           ↑
        Prefix (from config)
```

### Email Header Badge
```
┌─────────────────────────────────┐
│  New FormBridge Submission      │
│  You have a new submission      │
│  ┌─────────────────────────────┤
│  │  FORM: CONTACT-US           │ ← Badge with color
│  └─────────────────────────────┤
└─────────────────────────────────┘
```

---

## ✅ Verification Checklist

- [ ] formbridge-config table created
- [ ] Form configs seeded (3+ forms)
- [ ] Lambda function deployed
- [ ] Lambda has dynamodb:GetItem permission
- [ ] Submit test form with form_id
- [ ] Email goes to correct recipients
- [ ] Subject has custom prefix
- [ ] Badge shows correct form_id and color
- [ ] Dashboard link works
- [ ] Plain-text fallback present
- [ ] Logs show "Found form config"

---

## 🆘 Common Issues

| Issue | Fix |
|-------|-----|
| Wrong recipients | Check `recipients` array in DynamoDB |
| Missing prefix | Check `subject_prefix` field (not empty) |
| Wrong badge color | Check `brand_primary_hex` is valid hex |
| Config not found | Verify table name matches `FORM_CONFIG_TABLE` env var |
| No emails sent | Check Lambda logs for "Found form config" message |

---

## 📍 Files Changed

| File | What Changed |
|------|--------------|
| `backend/template.yaml` | Added FormConfigTable resource + IAM |
| `backend/samconfig.toml` | Added FormConfigTableName parameter |
| `backend/contact_form_lambda.py` | Added get_form_config() + routing logic |
| `email_templates/base.html` | Added form badge |
| `docs/FORM_ROUTING.md` | NEW - Complete routing guide |
| `docs/EMAIL_BRANDING.md` | Added routing section |
| `scripts/seed_form_config.sh` | NEW - AWS CLI seeding script |
| `api/README.md` | Added routing overview |
| `Makefile` | Added route-seed-local target |

---

## 🎯 Example Workflow

```bash
# 1. Deploy infrastructure
cd backend && sam build && sam deploy

# 2. Seed configs
./scripts/seed_form_config.sh

# 3. Website submits form_id: "careers"

# 4. Lambda:
#    - Stores in DynamoDB
#    - Queries config table
#    - Finds FORM#careers config
#    - Merges with template context
#    - Sends email to hr@example.com with [Careers] prefix

# 5. Recipient gets branded email with:
#    - Subject: [Careers] [FormBridge] New submission...
#    - Badge: "FORM: CAREERS" (blue)
#    - Dashboard link to: /dashboard?form=careers
```

---

## 📞 For More Info

- **Full Guide:** `docs/FORM_ROUTING.md` (650+ lines)
- **Implementation Details:** `ROUTING_IMPLEMENTATION_SUMMARY.md`
- **Email Branding:** `docs/EMAIL_BRANDING.md` (updated)
- **API Info:** `api/README.md` (updated)

---

**Last Updated:** November 5, 2025 | **Status:** ✅ Ready to Deploy
