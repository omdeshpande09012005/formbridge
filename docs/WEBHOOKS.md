# FormBridge Webhook Relay System

## Overview

FormBridge webhook relay allows form submissions to be automatically forwarded to third-party endpoints (Slack, Discord, custom HTTP APIs). The system uses **AWS SQS** for decoupling and reliable delivery with automatic retries and a **Dead Letter Queue (DLQ)** for failures.

**Key Benefits:**
- 🎯 **Decoupled delivery** - webhooks don't block form submission response
- 🔄 **Automatic retries** - up to 5 attempts before moving to DLQ
- 🔐 **HMAC-SHA256 signing** - optional request authentication
- 📨 **Multiple types** - Slack, Discord, or generic HTTP endpoints
- ✅ **Zero breaking changes** - webhooks optional per form
- 📊 **Structured logging** - CloudWatch insights-compatible logs

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Form Submission                                  │
│                      (via /submit endpoint)                              │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                    ┌───────────────▼────────────────┐
                    │  contactFormProcessor Lambda   │
                    │    (existing producer)         │
                    └───────────────┬────────────────┘
                                    │
                    ┌───────────────┼────────────────┐
                    │               │                │
          ┌─────────▼─────┐ ┌──────▼──────┐ ┌────────▼────────┐
          │  DynamoDB:    │ │    SES:    │ │      SQS:       │
          │ Submissions   │ │   Email    │ │  Webhook Queue  │
          └───────────────┘ └────────────┘ └────────┬────────┘
                                                     │
                                        ┌────────────▼────────────┐
                                        │ SQS Batch Messages (5-10)│
                                        └────────────┬────────────┘
                                                     │
                                    ┌────────────────▼────────────────┐
                                    │ formbridgeWebhookDispatcher     │
                                    │     (new consumer Lambda)       │
                                    └────────────────┬────────────────┘
                                                     │
                        ┌────────────────────────────┼────────────────────────────┐
                        │                            │                            │
              ┌─────────▼─────────┐      ┌──────────▼──────────┐      ┌──────────▼──────────┐
              │   Slack Webhook   │      │ Discord Webhook    │      │ Custom HTTP Endpoint│
              │  (Slack Channel)  │      │  (Discord Channel) │      │  (Any API)          │
              └───────────────────┘      └────────────────────┘      └─────────────────────┘

                                           Retries (5x) on 5xx/timeout
                                                   │
                                    ┌──────────────▼──────────────┐
                                    │   SQS Dead Letter Queue     │
                                    │  (max 5 receive attempts)   │
                                    └─────────────────────────────┘
```

---

## DynamoDB Configuration Schema

### Per-Form Config Item

Each form's configuration is stored in the `formbridge-config` table with an optional `webhooks` array:

```json
{
  "pk": "FORM#support",
  "sk": "CONFIG#v1",
  "recipients": ["owner@example.com", "support@example.com"],
  "subject_prefix": "[Support]",
  "brand_primary_hex": "#10B981",
  "dashboard_url": "https://example.com/dashboard/?form_id=support",
  "webhooks": [
    {
      "type": "slack",
      "url": "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
    },
    {
      "type": "discord",
      "url": "https://discordapp.com/api/webhooks/123456789/XXXXXXXXX"
    },
    {
      "type": "generic",
      "url": "https://webhook.site/unique-uuid-here",
      "hmac_secret": "my-secret-key",
      "hmac_header": "X-Webhook-Signature"
    }
  ]
}
```

### Webhook Object Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | ✅ | Webhook type: `"slack"`, `"discord"`, or `"generic"` |
| `url` | string | ✅ | HTTPS webhook endpoint URL |
| `hmac_secret` | string | ❌ | Secret key for HMAC-SHA256 signing (generic only) |
| `hmac_header` | string | ❌ | Header name for HMAC signature (default: `X-Webhook-Signature`) |

---

## Webhook Types

### Slack

Posts a formatted message to a Slack channel.

**Setup:**
1. Create a Slack workspace or use an existing one
2. Navigate to **Workspace Settings** → **API Apps**
3. Click **Create New App** → **From scratch**
4. Give it a name (e.g., "FormBridge") and select your workspace
5. Go to **Incoming Webhooks** and activate them
6. Click **Add New Webhook to Workspace**
7. Select the target channel and authorize
8. Copy the **Webhook URL**

**Payload Sent:**
```json
{
  "text": "[FormBridge] support — Jane Doe: Thank you for reaching out regarding our API integration. Can you provide more details..."
}
```

**Note:** Slack truncates text at ~150 chars; the dispatcher sends the first part of the message for brevity.

---

### Discord

Posts a formatted message to a Discord channel.

**Setup:**
1. Open your Discord server
2. Go to **Server Settings** → **Integrations** → **Webhooks**
3. Click **Create Webhook**
4. Name it "FormBridge" and select the target channel
5. Click **Copy Webhook URL**
6. Optionally upload an avatar via the webhook settings

**Payload Sent:**
```json
{
  "username": "FormBridge",
  "avatar_url": "https://...",
  "embeds": [
    {
      "title": "New Submission: support",
      "description": "Jane Doe (jane@example.com)",
      "fields": [
        {
          "name": "Message",
          "value": "Thank you for reaching out regarding our API integration. Can you provide more details..."
        }
      ],
      "color": 16711680
    }
  ]
}
```

---

### Generic (Custom HTTP)

Posts the full submission JSON to a custom endpoint. Useful for:
- Zapier, Make, IFTTT integrations
- Custom webhooks.site test endpoints
- In-house webhook receivers
- CRM/database webhooks

**Payload Sent:**
```json
{
  "form_id": "support",
  "id": "uuid-1234",
  "ts": 1699123456,
  "name": "Jane Doe",
  "email": "jane@example.com",
  "message": "Thank you for reaching out regarding our API integration. Can you provide more details...",
  "page": "https://example.com/contact",
  "ip": "192.0.2.1",
  "ua": "Mozilla/5.0...",
  "webhooks": [
    {
      "type": "generic",
      "url": "https://webhook.site/unique-uuid-here"
    }
  ]
}
```

**Optional: HMAC-SHA256 Signing**

If `hmac_secret` is configured, the dispatcher computes:

```
signature = hex(HMAC_SHA256(secret, raw_json_body))
```

And sends the header:
```
X-Webhook-Signature: a1b2c3d4e5f6... (or custom header name)
```

**Verification (Node.js example):**
```javascript
const crypto = require('crypto');

// In your webhook receiver:
const signature = req.headers['x-webhook-signature'];
const rawBody = req.rawBody; // must preserve exact bytes
const secret = process.env.WEBHOOK_SECRET;

const computed = crypto
  .createHmac('sha256', secret)
  .update(rawBody)
  .digest('hex');

if (crypto.timingSafeEqual(signature, computed)) {
  console.log('Webhook signature verified!');
} else {
  return res.status(401).json({ error: 'Unauthorized' });
}
```

---

## Setup & Configuration

### 1. AWS Infrastructure (SAM Deploy)

The IaC template (`backend/template.yaml`) automatically creates:

- **SQS Queue:** `formbridge-webhook-queue` (visibility timeout 60s, message retention 14 days)
- **SQS DLQ:** `formbridge-webhook-dlq` (for failed messages after 5 retries)
- **Lambda Consumer:** `formbridgeWebhookDispatcher` (triggered by SQS batches)
- **Permissions:** Producer Lambda can send to queue, Consumer can receive & read logs

**Deploy:**
```bash
cd backend
sam build --use-container
sam deploy
```

### 2. Seed Webhook Configurations

#### Option A: Using the provided script (Recommended)

```bash
# Production AWS
./scripts/seed_webhook_config.sh --region us-east-1 --table formbridge-config

# LocalStack (development)
make webhook-seed-local
```

#### Option B: AWS CLI (Manual)

```bash
aws dynamodb put-item \
  --table-name formbridge-config \
  --item '{
    "pk": {"S": "FORM#support"},
    "sk": {"S": "CONFIG#v1"},
    "recipients": {"L": [{"S": "owner@example.com"}]},
    "subject_prefix": {"S": "[Support]"},
    "brand_primary_hex": {"S": "#10B981"},
    "dashboard_url": {"S": "https://example.com/dashboard/?form_id=support"},
    "webhooks": {
      "L": [
        {
          "M": {
            "type": {"S": "slack"},
            "url": {"S": "https://hooks.slack.com/services/T.../B.../XX..."}
          }
        },
        {
          "M": {
            "type": {"S": "generic"},
            "url": {"S": "https://webhook.site/unique-id"},
            "hmac_secret": {"S": "my-secret"},
            "hmac_header": {"S": "X-Webhook-Signature"}
          }
        }
      ]
    }
  }' \
  --region us-east-1
```

#### Option C: DynamoDB Console

1. Open AWS DynamoDB → **formbridge-config** table
2. Click **Create item**
3. Switch to **JSON** view and paste:

```json
{
  "pk": {
    "S": "FORM#support"
  },
  "sk": {
    "S": "CONFIG#v1"
  },
  "webhooks": {
    "L": [
      {
        "M": {
          "type": {
            "S": "slack"
          },
          "url": {
            "S": "https://hooks.slack.com/services/YOUR_SLACK_URL"
          }
        }
      }
    ]
  }
}
```

---

## LocalStack Development

### Start LocalStack with SQS

```bash
make local-up
```

This starts:
- LocalStack (DynamoDB, SQS, Lambda, SES)
- MailHog (SMTP receiver)
- SAM local Lambda runtime

### Seed Webhook Configs

```bash
make webhook-seed-local
```

Creates three example forms with webhook configs pointing to **webhook.site** (for testing).

### Manual Seeding in LocalStack

```bash
aws dynamodb put-item \
  --endpoint-url http://localhost:4566 \
  --table-name formbridge-config \
  --item '...' \
  --region us-east-1
```

---

## Testing

### LocalStack Testing

1. **Start services:**
   ```bash
   make local-up
   make webhook-seed-local
   ```

2. **Start SAM local Lambda:**
   ```bash
   cd backend && sam local start-api --port 8080
   ```

3. **Submit a test form:**
   ```bash
   curl -X POST http://localhost:8080/submit \
     -H "Content-Type: application/json" \
     -d '{
       "form_id": "support",
       "name": "Jane Doe",
       "email": "jane@example.com",
       "message": "Test message for webhook",
       "page": "http://localhost:3000/contact"
     }'
   ```

4. **Verify webhook delivery:**
   - Check **webhook.site** for received payload (refresh the page)
   - Check **MailHog** at `http://localhost:8025` for emails
   - Check **CloudWatch Logs** in LocalStack:
     ```bash
     aws logs tail /aws/lambda/formbridgeWebhookDispatcher --follow \
       --endpoint-url http://localhost:4566
     ```

### AWS Production Testing

1. **Deploy and seed:**
   ```bash
   cd backend && sam deploy
   ./scripts/seed_webhook_config.sh --region us-east-1
   ```

2. **Submit via API:**
   ```bash
   curl -X POST https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/submit \
     -d '{"form_id":"support","name":"Jane","email":"jane@example.com","message":"Test"}'
   ```

3. **Verify:**
   - Check Slack/Discord channel for message
   - Check webhook.site for generic endpoint
   - Check **CloudWatch Logs** for `formbridgeWebhookDispatcher`:
     ```bash
     aws logs tail /aws/lambda/formbridgeWebhookDispatcher --follow
     ```

### Testing Failures & DLQ

1. **Force webhook failure:**
   - Update form config with invalid URL: `https://invalid-url-12345.example.com`
   - Submit a form

2. **Observe retries:**
   - Watch SQS metrics: `ApproximateNumberOfMessagesVisible` increases
   - Wait ~60 seconds between retries (5 total attempts)
   - After 5 failures, message moves to DLQ

3. **Inspect DLQ:**
   ```bash
   aws sqs receive-message \
     --queue-url <DLQ_URL> \
     --max-number-of-messages 10
   ```

---

## Security Best Practices

### Webhook URL Storage

⚠️ **Warning:** Webhook URLs are stored in plain text in DynamoDB. They should be treated as secrets.

**Recommendations:**
1. **Use IAM restricting DynamoDB access** to Lambda only
2. **Rotate webhook URLs regularly** (Slack/Discord allow multiple webhooks per channel)
3. **Use AWS Secrets Manager** for sensitive webhooks:
   - Store URL as `arn:aws:secretsmanager:region:account:secret:formbridge-slack-webhook`
   - Consumer Lambda retrieves it before POST

### HMAC-SHA256 Signing

For generic endpoints, always use HMAC signing:

```json
{
  "type": "generic",
  "url": "https://example.com/webhooks/inbox",
  "hmac_secret": "your-very-long-random-string-from-aws-secrets-manager",
  "hmac_header": "X-Webhook-Signature"
}
```

**Secret Generation:**
```bash
# Generate a secure random secret
openssl rand -hex 32
# Example output: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

### Network Security

- Consumer Lambda has no VPC (public egress only)
- Webhook endpoints should validate origin via HMAC
- Use HTTPS only (no HTTP)
- Implement IP whitelisting at your webhook receiver if possible

---

## Troubleshooting

### Messages not being delivered

**Check 1: Form config has webhooks array**
```bash
aws dynamodb get-item \
  --table-name formbridge-config \
  --key '{"pk": {"S": "FORM#support"}, "sk": {"S": "CONFIG#v1"}}'
```

**Check 2: SQS queue has messages**
```bash
aws sqs get-queue-attributes \
  --queue-url <WEBHOOK_QUEUE_URL> \
  --attribute-names All
```

**Check 3: Lambda consumer is invoked**
- Open CloudWatch Logs: `/aws/lambda/formbridgeWebhookDispatcher`
- Search for form_id: `{ form_id: support }`
- Look for `"dispatch_result": "success"` or error messages

**Check 4: Webhook endpoint is accessible**
```bash
curl -v https://hooks.slack.com/services/YOUR_URL \
  -X POST \
  -d '{"text": "test"}'
```

### Messages in DLQ

**Reason:** Webhook endpoint failed 5 times (5xx, timeout, invalid certificate, etc.)

**Action:**
1. Fix the webhook endpoint
2. Manually re-queue from DLQ:
   ```bash
   aws sqs receive-message --queue-url <DLQ_URL>
   # Copy message body
   aws sqs send-message --queue-url <WEBHOOK_QUEUE_URL> --message-body '<body>'
   ```

### High Lambda duration

**Cause:** Slow webhook endpoints (e.g., >10 second response time)

**Solution:**
- Increase Consumer Lambda timeout (default: 30s)
- Consider webhook endpoint performance
- Use async webhooks at your endpoint (fire and forget)

### HMAC signature not matching

**Check:**
1. Secret key matches between DynamoDB config and receiver code
2. Raw request body is used (not parsed JSON)
3. Using SHA256 (not MD5 or SHA1)

**Test locally:**
```bash
# Generate signature
echo -n '{"form_id":"support"}' | openssl dgst -sha256 -hmac "your-secret" -hex
# Should match header value
```

---

## Monitoring & Logs

### CloudWatch Logs - Producer

Lambda: `contactFormProcessor`

```
[INFO] Enqueuing webhook: form_id=support, webhooks=2, queue_url=https://...
[INFO] Webhook enqueue successful: MessageId=UUID
[WARN] Webhook queue URL not configured, skipping webhook enqueue
[ERROR] Failed to enqueue webhook: botocore.exceptions.ClientError: ...
```

### CloudWatch Logs - Consumer

Lambda: `formbridgeWebhookDispatcher`

```
[INFO] Processing SQS batch: batch_size=3
[INFO] Dispatching to webhook: type=slack, url_host=hooks.slack.com, form_id=support
[INFO] Webhook dispatch successful: url_host=hooks.slack.com, status_code=200, duration_ms=234
[WARN] Webhook dispatch timeout: url_host=example.com, form_id=support, timeout=10s
[ERROR] Webhook dispatch failed: url_host=example.com, status_code=500, error=...
```

### SQS Metrics

- **ApproximateNumberOfMessagesVisible:** Messages in queue (should be 0 if consumer is working)
- **ApproximateAgeOfOldestMessage:** Oldest message age (indicates backlog)
- **NumberOfMessagesDeleted:** Successfully processed
- **NumberOfMessagesSent:** Total enqueued

**Set Alarms:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name formbridge-webhook-queue-backlog \
  --alarm-description "Alert if webhook queue has >100 messages" \
  --metric-name ApproximateNumberOfMessagesVisible \
  --namespace AWS/SQS \
  --statistic Average \
  --period 300 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

---

## Cost Estimation (AWS)

Based on 1,000 form submissions/month with 2 webhooks per form:

| Service | Metric | Cost |
|---------|--------|------|
| **SQS** | 2,000 messages/month | ~$0.40 |
| **Lambda** (Consumer) | 2,000 invocations, 2 retries each | ~$0.50 |
| **CloudWatch Logs** | ~5 MB/month | ~$2.50 |
| **Total** | Per month | ~$3.40 |

All within **AWS Free Tier** for first 12 months.

---

## Examples

### Example 1: Slack + Email Routing (Support Form)

```json
{
  "pk": "FORM#support",
  "sk": "CONFIG#v1",
  "recipients": ["support@example.com"],
  "subject_prefix": "[Support]",
  "brand_primary_hex": "#10B981",
  "dashboard_url": "https://example.com/dashboard/?form_id=support",
  "webhooks": [
    {
      "type": "slack",
      "url": "https://hooks.slack.com/services/T123/B456/XXXX"
    }
  ]
}
```

**Flow:**
1. Form submitted
2. Saved to DynamoDB submissions table
3. Email sent to support@example.com
4. Message enqueued to SQS
5. Consumer POSTs to Slack with message format
6. Slack channel receives formatted notification

### Example 2: Generic Webhook with HMAC (CRM Integration)

```json
{
  "pk": "FORM#sales",
  "sk": "CONFIG#v1",
  "recipients": ["sales@example.com"],
  "subject_prefix": "[Sales Lead]",
  "brand_primary_hex": "#0EA5E9",
  "dashboard_url": "https://example.com/dashboard/?form_id=sales",
  "webhooks": [
    {
      "type": "generic",
      "url": "https://crm.example.com/api/webhooks/formbridge",
      "hmac_secret": "abc123def456...",
      "hmac_header": "X-CRM-Signature"
    }
  ]
}
```

**Flow:**
1. Form submitted
2. Saved to DynamoDB
3. Email sent to sales@example.com
4. Message enqueued to SQS with HMAC config
5. Consumer POSTs full JSON to CRM with signature header
6. CRM verifies signature and creates lead record

### Example 3: Multiple Webhooks (Discord + webhook.site + Slack)

```json
{
  "pk": "FORM#contact",
  "sk": "CONFIG#v1",
  "recipients": ["admin@example.com"],
  "subject_prefix": "[Contact]",
  "brand_primary_hex": "#6D28D9",
  "dashboard_url": "https://example.com/dashboard/?form_id=contact",
  "webhooks": [
    {
      "type": "discord",
      "url": "https://discordapp.com/api/webhooks/123/XXXX"
    },
    {
      "type": "slack",
      "url": "https://hooks.slack.com/services/T123/B456/YYYY"
    },
    {
      "type": "generic",
      "url": "https://webhook.site/12345-67890-abcde",
      "hmac_secret": "test-secret"
    }
  ]
}
```

**Flow:**
1. Single form submission
2. SQS receives message
3. Consumer processes 3 webhook dispatches:
   - POST to Discord
   - POST to Slack
   - POST to webhook.site with HMAC header
4. All 3 messages sent within single Lambda invocation

---

## FAQ

**Q: Do I need webhooks for every form?**
A: No. If a form has no `webhooks` array or empty array, no SQS messages are sent. Existing behavior is unchanged.

**Q: What if the webhook endpoint is slow?**
A: Consumer Lambda has a 10s timeout per webhook. If exceeded, message returns to SQS for retry. If it fails 5 times, it moves to DLQ.

**Q: Can I edit webhook URLs after deployment?**
A: Yes. Update the DynamoDB `formbridge-config` item directly. Next form submission will use the new URLs.

**Q: What if SQS is down?**
A: If `WEBHOOK_QUEUE_URL` is not set or SQS send fails, a warning is logged and form submission continues normally (no hard failure).

**Q: How do I test webhooks locally?**
A: Use **webhook.site** for free webhook testing. Just provide the unique URL in the config. Every POST is logged and visible in the browser.

**Q: Can I use the same webhook for multiple forms?**
A: Yes. Just include the same URL in multiple forms' `webhooks` arrays. Each form submission will trigger the webhook independently.

**Q: What's the maximum retry count?**
A: 5 retries (configurable in SAM template via `maxReceiveCount`). After 5 failures, the message moves to DLQ.

---

## Related Documentation

- **FORM_ROUTING.md** - Per-form recipients, subject prefixes, brand colors
- **EMAIL_BRANDING.md** - Email template customization
- **IMPLEMENTATION_PROGRESS.md** - Project status & checklist

---

**Version:** 1.0.0  
**Last Updated:** November 5, 2025  
**Status:** Production Ready ✅
