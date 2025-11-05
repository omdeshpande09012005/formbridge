# FormBridge Per-Form Routing Guide

**Last Updated:** November 5, 2025  
**Status:** ✅ Production Ready

---

## 📋 Overview

FormBridge now supports **per-form routing configuration**, allowing each form (identified by `form_id`) to have its own:

✅ **Recipients** - Which email addresses receive the notification  
✅ **Subject Prefix** - Custom prefix for email subject line  
✅ **Brand Color** - Form-specific badge and accent color (hex)  
✅ **Dashboard URL** - Form-specific dashboard or redirect link  
✅ **Webhooks** - Optional webhook endpoints (Slack, Discord, custom HTTP) for real-time integrations  

Configuration is stored in a DynamoDB table (`formbridge-config`) and automatically merged with global defaults. If no form-specific config exists, the system gracefully falls back to environment variable defaults.

**For webhook-specific documentation, see:** [docs/WEBHOOKS.md](WEBHOOKS.md)

---

## 🗂️ Architecture

### DynamoDB Config Table

**Table Name:** `formbridge-config` (customizable via CloudFormation parameter)

**Primary Key:**
- **PK (Partition Key):** `FORM#{form_id}` (string)
- **SK (Sort Key):** `CONFIG#v1` (string)

### Item Schema

```json
{
  "pk": "FORM#contact-us",
  "sk": "CONFIG#v1",
  "recipients": ["owner@example.com", "support@example.com"],
  "subject_prefix": "[Contact]",
  "brand_primary_hex": "#6D28D9",
  "dashboard_url": "https://example.com/analytics/?form_id=contact-us",
  "webhooks": [
    {"type": "slack", "url": "https://hooks.slack.com/services/..."},
    {"type": "generic", "url": "https://webhook.site/...", "hmac_secret": "secret-key"}
  ]
}
```

**Field Descriptions:**

| Field | Type | Required | Example | Notes |
|-------|------|----------|---------|-------|
| `pk` | String | Yes | `FORM#contact-us` | Partition key (form ID) |
| `sk` | String | Yes | `CONFIG#v1` | Sort key (version) |
| `recipients` | List<String> | No | `["admin@example.com"]` | Email addresses; if missing, uses `SES_RECIPIENTS` env var |
| `webhooks` | List<Object> | No | `[{type:"slack",...}]` | Optional webhook endpoints; see [WEBHOOKS.md](WEBHOOKS.md) for details |
| `subject_prefix` | String | No | `[Careers]` | Added before `[FormBridge]` in subject; if missing, no prefix |
| `brand_primary_hex` | String | No | `#0EA5E9` | Hex color code for badge; if missing, uses `BRAND_PRIMARY_HEX` env var |
| `dashboard_url` | String | No | `https://...` | Dashboard link in CTA; if missing, uses `DASHBOARD_URL` env var |

### Email Subject Format

**With subject prefix:**
```
[Careers] [FormBridge] New submission on job-apply — Jane Smith
```

**Without subject prefix (no config or empty prefix):**
```
[FormBridge] New submission on contact-us — John Doe
```

---

## 🌐 Fallback Behavior

The system uses a **graceful degradation** model:

```
Per-Form Config (DynamoDB)
        ↓
   If not found or field missing
        ↓
Global Environment Defaults
        ↓
   Hardcoded Fallbacks
```

### Example: Recipients Fallback

1. **First Priority:** Check `formbridge-config` table for form-specific recipients
2. **Second Priority:** If not found, use `SES_RECIPIENTS` env var (comma-separated)
3. **Third Priority:** If still empty, don't send email (log warning)

### Env Vars (Global Defaults)

```bash
SES_RECIPIENTS="admin@formbridge.example.com"
BRAND_PRIMARY_HEX="#6D28D9"
BRAND_LOGO_URL="https://omdeshpande09012005.github.io/website/assets/logo.svg"
DASHBOARD_URL="https://omdeshpande09012005.github.io/docs/"
```

---

## 📧 Email Template Changes

The email header now includes a **form badge** with the form ID:

```
┌─────────────────────────────────────────┐
│  [Logo]  New FormBridge Submission     │
│  You have a new contact form submission │
│  ┌─────────────────────────────────────┤
│  │  FORM: CONTACT-US                   │
│  └─────────────────────────────────────┤
│  (Badge color from brand_primary_hex)  │
└─────────────────────────────────────────┘
```

The badge displays the `form_id` and uses the configured `brand_primary_hex` color.

---

## 🚀 Setup & Deployment

### 1. Infrastructure (CloudFormation/SAM)

The `formbridge-config` table is already defined in `backend/template.yaml`:

```yaml
FormConfigTable:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: !Ref FormConfigTableName
    AttributeDefinitions:
      - AttributeName: pk
        AttributeType: S
      - AttributeName: sk
        AttributeType: S
    KeySchema:
      - AttributeName: pk
        KeyType: HASH
      - AttributeName: sk
        KeyType: RANGE
    BillingMode: PAY_PER_REQUEST
```

Deploy with `sam deploy`:

```bash
cd backend
sam build
sam deploy
```

### 2. Seed Form Configs

Use the provided AWS CLI script to seed form configurations:

```bash
# Source the script (fills in placeholders)
source scripts/seed_form_config.sh

# Or run directly with AWS CLI
aws dynamodb put-item \
  --table-name formbridge-config \
  --item '{
    "pk": {"S": "FORM#contact-us"},
    "sk": {"S": "CONFIG#v1"},
    "recipients": {"L": [{"S": "admin@example.com"}]},
    "subject_prefix": {"S": "[Contact]"},
    "brand_primary_hex": {"S": "#6D28D9"},
    "dashboard_url": {"S": "https://example.com/dashboard?form_id=contact-us"}
  }' \
  --region ap-south-1
```

---

## 📍 Seed Form Configurations

### Example 1: Contact Form

```bash
FORM_ID="contact-us"
RECIPIENTS=["contact-admin@example.com"]
PREFIX="[Contact]"
COLOR="#6D28D9"  # Purple
DASHBOARD_URL="https://example.com/dashboard?form=contact-us"
```

**DynamoDB Item:**
```json
{
  "pk": "FORM#contact-us",
  "sk": "CONFIG#v1",
  "recipients": ["contact-admin@example.com"],
  "subject_prefix": "[Contact]",
  "brand_primary_hex": "#6D28D9",
  "dashboard_url": "https://example.com/dashboard?form=contact-us"
}
```

### Example 2: Careers Form

```bash
FORM_ID="careers"
RECIPIENTS=["hr@example.com", "hiring@example.com"]
PREFIX="[Careers]"
COLOR="#0EA5E9"  # Blue
DASHBOARD_URL="https://example.com/dashboard?form=careers"
```

**DynamoDB Item:**
```json
{
  "pk": "FORM#careers",
  "sk": "CONFIG#v1",
  "recipients": ["hr@example.com", "hiring@example.com"],
  "subject_prefix": "[Careers]",
  "brand_primary_hex": "#0EA5E9",
  "dashboard_url": "https://example.com/dashboard?form=careers"
}
```

### Example 3: Support Form

```bash
FORM_ID="support"
RECIPIENTS=["support@example.com"]
PREFIX="[Support]"
COLOR="#10B981"  # Green
DASHBOARD_URL="https://example.com/dashboard?form=support"
```

**DynamoDB Item:**
```json
{
  "pk": "FORM#support",
  "sk": "CONFIG#v1",
  "recipients": ["support@example.com"],
  "subject_prefix": "[Support]",
  "brand_primary_hex": "#10B981",
  "dashboard_url": "https://example.com/dashboard?form=support"
}
```

---

## 🛠️ LocalStack Development

### Setup LocalStack Config Table

```bash
# Start LocalStack
docker-compose up -d

# Create config table
aws dynamodb create-table \
  --table-name formbridge-config \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:4566 \
  --region ap-south-1

# Seed sample forms
aws dynamodb put-item \
  --table-name formbridge-config \
  --item '{
    "pk": {"S": "FORM#contact-us"},
    "sk": {"S": "CONFIG#v1"},
    "recipients": {"L": [{"S": "admin@mailhog.local"}]},
    "subject_prefix": {"S": "[Contact]"},
    "brand_primary_hex": {"S": "#6D28D9"},
    "dashboard_url": {"S": "http://localhost:8000/dashboard?form=contact-us"}
  }' \
  --endpoint-url http://localhost:4566 \
  --region ap-south-1
```

### Or Use Make Target

```bash
make route-seed-local
```

This will:
1. Check if LocalStack is running
2. Create the `formbridge-config` table
3. Seed three sample forms (contact-us, careers, support)

---

## 📋 AWS CLI Seeding Script

**File:** `scripts/seed_form_config.sh`

```bash
#!/bin/bash

# Configuration - Customize these
REGION="ap-south-1"
TABLE_NAME="formbridge-config"
FORM_ID="${FORM_ID:-contact-us}"
RECIPIENTS_JSON='["admin@example.com"]'
SUBJECT_PREFIX="${SUBJECT_PREFIX:-}"
BRAND_COLOR="${BRAND_COLOR:-#6D28D9}"
DASHBOARD_URL="${DASHBOARD_URL:-https://example.com/dashboard}"

# Helper function to convert recipients array
build_recipients_list() {
  local recipients_str="$1"
  local list_json="["
  
  IFS=',' read -ra emails <<< "$recipients_str"
  for i in "${!emails[@]}"; do
    email=$(echo "${emails[$i]}" | xargs)  # trim whitespace
    if [ $i -gt 0 ]; then list_json+=","; fi
    list_json+="{\"S\": \"$email\"}"
  done
  
  list_json+="]"
  echo "$list_json"
}

# Put item in DynamoDB
put_form_config() {
  local form_id="$1"
  local recipients="$2"
  local prefix="$3"
  local color="$4"
  local dashboard="$5"
  
  # Build recipient list JSON
  recipients_json=$(build_recipients_list "$recipients")
  
  # Build prefix attribute (optional)
  local prefix_attr=""
  if [ -n "$prefix" ]; then
    prefix_attr=", \"subject_prefix\": {\"S\": \"$prefix\"}"
  fi
  
  # Put item
  aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item "{
      \"pk\": {\"S\": \"FORM#$form_id\"},
      \"sk\": {\"S\": \"CONFIG#v1\"},
      \"recipients\": {\"L\": $recipients_json},
      \"brand_primary_hex\": {\"S\": \"$color\"},
      \"dashboard_url\": {\"S\": \"$dashboard\"}
      $prefix_attr
    }" \
    --region "$REGION" \
    2>&1
  
  if [ $? -eq 0 ]; then
    echo "✓ Seeded form config: $form_id"
  else
    echo "✗ Failed to seed form config: $form_id"
  fi
}

# Seed sample forms
echo "Seeding FormBridge form configurations..."

put_form_config \
  "contact-us" \
  "admin@example.com,support@example.com" \
  "[Contact]" \
  "#6D28D9" \
  "https://example.com/dashboard?form=contact-us"

put_form_config \
  "careers" \
  "hr@example.com,hiring@example.com" \
  "[Careers]" \
  "#0EA5E9" \
  "https://example.com/dashboard?form=careers"

put_form_config \
  "support" \
  "support@example.com" \
  "[Support]" \
  "#10B981" \
  "https://example.com/dashboard?form=support"

echo "Done!"
```

---

## 🧪 Testing

### Local Testing with MailHog

```bash
# Terminal 1: Start MailHog
mailhog

# Terminal 2: Start LocalStack
docker-compose up

# Terminal 3: Seed config
make route-seed-local

# Terminal 4: Build & start Lambda
cd backend
sam build
sam local start-api

# Submit three forms with different form_ids
curl -X POST http://localhost:8080/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-us",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Hello from contact form",
    "page": "https://example.com/contact"
  }'

curl -X POST http://localhost:8080/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "careers",
    "name": "Jane Smith",
    "email": "jane@example.com",
    "message": "I would like to apply",
    "page": "https://example.com/careers"
  }'

# Check MailHog at http://localhost:8025
# Verify:
# - Different subject prefixes ([Contact] vs [Careers])
# - Different badge colors in email
# - Different dashboard URLs in CTA
```

### Production Testing with SES

```bash
# 1. Deploy with sam deploy
sam deploy

# 2. Seed form configs
./scripts/seed_form_config.sh

# 3. Update website form to send different form_ids
# Edit website/contact.html to include form_id in request

# 4. Submit three forms and verify emails in production inbox
```

---

## 🔒 Security & Best Practices

### DynamoDB Permissions

Lambda role has least-privilege access:
- `dynamodb:GetItem` on `formbridge-config` table (read-only)
- `dynamodb:PutItem`, `dynamodb:Query` on `contact-form-submissions` table

### No Breaking Changes

- ✅ If form config table missing, system continues with env defaults
- ✅ If form config for a form_id missing, system uses global defaults
- ✅ Plain-text email always sent (never breaks due to HTML rendering)
- ✅ Existing forms without config entries work seamlessly

### Configuration Best Practices

1. **Test in LocalStack first** - Verify config before production deploy
2. **Use script for seeding** - Reduces manual errors
3. **Store secrets in Secrets Manager** - Not in config table
4. **Version configs** - Use `CONFIG#v1` sort key for future updates
5. **Monitor logs** - Watch Lambda CloudWatch for config lookup failures

---

## 📝 Lambda Code Reference

### Get Form Config

```python
def get_form_config(form_id):
    """
    Get per-form routing configuration from DynamoDB.
    
    Returns merged config (form-specific overrides global defaults):
    {
        "recipients": ["email1@..."],
        "subject_prefix": "[Prefix]",
        "brand_primary_hex": "#6D28D9",
        "dashboard_url": "https://..."
    }
    """
    config = {
        "recipients": RECIPIENTS,  # env defaults
        "subject_prefix": "",
        "brand_primary_hex": BRAND_PRIMARY_HEX,
        "dashboard_url": DASHBOARD_URL,
    }
    
    try:
        response = config_table.get_item(
            Key={
                "pk": f"FORM#{form_id}",
                "sk": "CONFIG#v1"
            }
        )
        item = response.get("Item", {})
        if item:
            # Merge config-table values
            if "recipients" in item:
                config["recipients"] = item["recipients"]
            # ... merge other fields ...
            print(f"Found form config for {form_id}")
        else:
            print(f"No config for {form_id}, using defaults")
    except Exception as e:
        print(f"Warning: Config lookup failed: {e}. Using defaults.")
    
    return config
```

### Using in handle_submit()

```python
# In handle_submit()
form_config = get_form_config(form_id)
configured_recipients = form_config.get("recipients", RECIPIENTS)
subject_prefix = form_config.get("subject_prefix", "")
configured_brand_hex = form_config.get("brand_primary_hex", BRAND_PRIMARY_HEX)

# Build subject with prefix
subject_prefix_str = f"{subject_prefix} " if subject_prefix else ""
email_subject = f"{subject_prefix_str}[{BRAND_NAME}] New submission on {form_id}"

# Pass to template
template_context = {
    'brand_primary_hex': configured_brand_hex,
    'dashboard_url': configured_dashboard_url,
    'subject_prefix': subject_prefix,
    # ... other fields ...
}
```

---

## 🆘 Troubleshooting

### Form config not found

**Symptom:** Email goes to global `SES_RECIPIENTS` instead of form-specific recipients

**Solution:**
1. Check table name matches `FORM_CONFIG_TABLE` env var
2. Verify item key format: `pk=FORM#{form_id}`, `sk=CONFIG#v1`
3. Verify IAM role has `dynamodb:GetItem` permission

### Wrong badge color

**Symptom:** Badge shows wrong color in email

**Solution:**
1. Check `brand_primary_hex` in DynamoDB item (must be valid hex, e.g. `#0EA5E9`)
2. Verify email client supports CSS colors
3. Test in multiple clients (Gmail, Outlook, Apple Mail)

### Subject prefix not showing

**Symptom:** Email subject missing custom prefix

**Solution:**
1. Check `subject_prefix` field in DynamoDB item
2. Verify prefix value is not empty string (empty means no prefix)
3. Check email client subject line display (some truncate long subjects)

### Recipients not routing correctly

**Symptom:** Email sent to global recipients instead of form-specific

**Solution:**
1. Check `recipients` list in DynamoDB item (array of strings)
2. Verify email addresses are valid and verified in SES
3. Check Lambda CloudWatch logs for "Found form config" message

---

## 📞 Support

For issues or questions:
1. Check this guide's Troubleshooting section
2. Review Lambda CloudWatch logs
3. Verify DynamoDB item schema with examples above
4. Test locally with MailHog before production deploy

---

## 📚 Related Documentation

- `docs/EMAIL_BRANDING.md` - Email template customization
- `backend/template.yaml` - SAM template with table definitions
- `backend/samconfig.toml` - Deployment configuration
- `scripts/seed_form_config.sh` - AWS CLI seeding script

---

**Last Updated:** November 5, 2025  
**Version:** 1.0.0  
**Status:** Production Ready ✅
