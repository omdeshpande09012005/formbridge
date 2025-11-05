# FormBridge Viva Script

**Total Duration**: 6–8 minutes  
**Presenter**: [Your Name]  
**Date**: November 5, 2025

---

## 📋 Script Overview

| Section | Duration | Talk Track | Timings |
|---------|----------|-----------|---------|
| Opening | 0:30 | Problem/Solution pitch | 0:00–0:30 |
| Architecture | 1:00 | System design + DevOps | 0:30–1:30 |
| Security | 1:00 | Auth, HMAC, CORS, IAM | 1:30–2:30 |
| Observability | 0:45 | Alarms, logs, SES events | 2:30–3:15 |
| Demo Flow | 2:30 | Live demo walkthrough | 3:15–5:45 |
| ROI/Cost | 0:30 | Free-tier strategy | 5:45–6:15 |
| Future Work | 0:30 | Next steps/roadmap | 6:15–6:45 |
| Q&A | 1:00+ | Prepared answers | 6:45–7:45+ |

---

## 🎬 Detailed Script

### **OPENING (0:30)** — Problem → Solution

**[Visual: Show portfolio with broken contact form OR MailChimp/Typeform price screen]**

**You say:**

> "Hi, I'm [Name]. You've probably seen portfolio websites that use services like Typeform or Mailchimp for contact forms. They charge per submission or require their hosting. 
>
> FormBridge solves that: a **serverless contact form API** that you deploy on AWS for **~$0/month** on the free tier, handles HTTPS submissions, sends emails, and gives you **complete analytics**—no vendor lock-in, no middleman.
>
> It's production-ready, secure, scalable, and costs-optimized."

**[Visual: Show dashboard screenshot with 7-day chart]**

**Key points to emphasize:**
- ✅ Vendor-independent
- ✅ Free-tier eligible (no RDS, no EC2)
- ✅ Secure (API keys, HMAC, CORS)
- ✅ Complete observability
- ✅ Analytics + CSV export

---

### **ARCHITECTURE (1:00)** — System Design + DevOps

**[Visual: Show architecture diagram or draw on whiteboard]**

**You say:**

> "FormBridge uses a **serverless event-driven architecture**:
>
> 1. **Frontend** (React/vanilla JS) posts JSON to an API Gateway endpoint.
>
> 2. **API Gateway** validates requests—enforces API keys, rate-limits via usage plans (e.g., 10k requests/day free), and CORS.
>
> 3. **Lambda** (Python) does the heavy lifting: validates payload, looks up the submission's form_id in DynamoDB, logs IP/User-Agent/timestamp, and triggers SES email notifications.
>
> 4. **DynamoDB** (on-demand pricing) stores submissions with a composite key: `pk = FORM#{form_id}`, `sk = SUBMIT#{uuid}` for efficient filtering by form.
>
> 5. **SES** sends emails—I've pre-verified sender addresses in sandbox mode; moving to production requires AWS approval (usually <1 hour).
>
> On the **DevOps side**: SAM template defines everything (IaC), GitHub Actions auto-deploys on push, CloudWatch logs and alarms monitor health."

**Key architectural wins:**
- ✅ No servers to manage
- ✅ Auto-scales to millions of requests
- ✅ On-demand DynamoDB = pay only for what you use
- ✅ SES: $0.10 per 1000 emails; free tier 200/day
- ✅ API Gateway: free tier 1M calls/month

---

### **SECURITY (1:00)** — Auth, HMAC, CORS, IAM

**[Visual: Show OpenAPI spec security section or API key diagram]**

**You say:**

> "Security is layered:
>
> **Layer 1 – API Keys & Usage Plans:**
> Every request must include `X-Api-Key` header. API Gateway validates it. I've created a usage plan that rate-limits clients—free tier allows 10k requests/day. This prevents spam and DDoS.
>
> **Layer 2 – CORS:**
> I've locked CORS to the portfolio domain. Only requests from `https://omdeshpande09012005.github.io` are accepted; browsers reject others.
>
> **Layer 3 – HMAC-SHA256 (Optional):**
> For extra security, clients can sign requests with a shared secret using HMAC. Lambda verifies the signature and timestamp (5-minute window to prevent replays). Disabled by default but available if you need it.
>
> **Layer 4 – IAM:**
> Lambda has least-privilege permissions: read/write to ONE DynamoDB table, send email via SES. No S3, no EC2, no secrets manager access. Lambda execution role is tightly scoped."

**Key security features:**
- ✅ API key authentication
- ✅ Rate limiting (usage plan)
- ✅ CORS origin validation
- ✅ HMAC optional signature verification
- ✅ IAM least-privilege
- ✅ No hardcoded secrets (env vars only)

---

### **OBSERVABILITY (0:45)** — Alarms, Logs, SES Events

**[Visual: Show CloudWatch Alarms dashboard]**

**You say:**

> "I don't ship code blind. FormBridge has **three types of monitoring**:
>
> **Alarms:**
> - Lambda error rate > 1% → SNS alert
> - API Gateway 5XX errors → SNS alert
> - DynamoDB write throttles → SNS alert
> - SES bounce/complaint rate > 5% → SNS alert (ensures email reputation stays clean)
>
> **Logs:**
> Lambda logs every submission to CloudWatch: timestamp, form_id, validation results, error messages. Retention is 30 days to balance compliance and cost.
>
> **Dashboard:**
> I built a React analytics dashboard that polls the `/analytics` endpoint every 30 seconds, shows 7-day submission trends, KPIs (today's count, total count), and a 'Download CSV' button for data export.
>
> All of this is **cost-aware**: CloudWatch Logs free tier covers ~5GB/month, which is plenty for typical usage."

**Key observability features:**
- ✅ Multi-channel alarms (SNS, email)
- ✅ CloudWatch Logs for audit trail
- ✅ React dashboard with real-time updates
- ✅ CSV export for data analysis
- ✅ Cost-conscious retention policies

---

### **DEMO FLOW (2:30)** — Live Walkthrough

**[Visual: Open terminal, Postman, browser tabs]**

**You say:**

> "Let me show you FormBridge in action. I'll walk through the happy path and a few edge cases."

---

#### **Demo Part 1: Local Dev (0:45)**

**Setup (say while executing):**

> "First, I'll spin up the local environment using Docker Compose. This runs DynamoDB locally, a mock SES service (MailHog), and a Lambda simulator—identical to production."

**Execute:**

```bash
make local-up          # Starts LocalStack, MailHog, DynamoDB Admin, Frontend
make local-bootstrap   # Creates DynamoDB table, seeds test data
make sam-api           # Starts local Lambda API on port 3000
```

**[Wait ~10 seconds for services to start]**

> "Services are up. Now I'll submit a contact form from the local frontend."

**Open browser** → `http://localhost:8080/dashboard/` (or test form page if available)

**Fill out form:**
- Name: "Jane Doe"
- Email: "jane@example.com"
- Message: "Demo submission"

**Click Submit**

**[Visual: Show form success message]**

> "✓ Form submitted. Let's verify it reached the database."

**Open DynamoDB Admin** → `http://localhost:8001`
- Select `contact-form-submissions-v2` table
- **[Click Scan]**
- **[Point to the new row]** → "Here's the submission: UUID, form_id, email, timestamp, IP, browser."

> "And the email?"

**Open MailHog** → `http://localhost:8025`
- **[Show inbox with test email]**
- **[Click to view email content]**

> "Perfect. Local loop works: form → DynamoDB → email. That's the core product."

---

#### **Demo Part 2: Production Test (0:45)**

**[Say while executing]**

> "Now let's hit production on AWS. I'll use the Postman collection with my API key."

**Open Postman**
- Select environment: `FormBridge.Prod`
- Select request: `Submit`
- **[Click Send]**

**[Visual: Show 200 OK response with submission ID]**

> "Status 200, submission ID returned. The Lambda executed, validated the payload, stored it in DynamoDB, and queued an SES email."

**[Wait 3 seconds]**

> "Let me check my actual email inbox..."

**[Open email inbox (Gmail/corporate email)]**

**[Scroll to find FormBridge notification email]**

> "There it is—delivered in seconds. Form submission + email confirmation working end-to-end."

---

#### **Demo Part 3: Analytics Dashboard (0:30)**

> "The dashboard shows real-time metrics. Let me pull it up."

**Open browser** → Production dashboard URL  
(e.g., `https://omdeshpande09012005.github.io/dashboard/` with production config)

**[Show or narrate]:**
- "KPI tiles: total submissions, today's count, last 7 days"
- "7-day trend line chart"
- "Recent submissions table"

**[Click 'Download CSV']**

> "One click exports all submissions as a CSV file—useful for reporting, Sheets, or Salesforce integration."

**[Show file dialog or downloaded CSV]**

---

#### **Demo Part 4: Security (0:30)**

> "Let's verify the security layers work."

**Test 1: No API Key**

```bash
curl -X POST https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"hi"}'
```

**[Visual: Show 403 Unauthorized response]**

> "Without an API key, API Gateway blocks it. 403 Forbidden."

**Test 2: With API Key**

**[Open Postman, select the same request with API key in environment]**

**[Click Send]**

**[Visual: Show 200 OK]**

> "With the key, it goes through. Security working as intended."

---

### **ROI/COST (0:30)** — Free-Tier Strategy

**[Visual: Show pricing comparison table or cost sheet]**

**You say:**

> "Let's talk money. A typical contact form on Typeform or Mailchimp costs $20–50/month. FormBridge is **free on AWS free tier**:
>
> - **API Gateway**: 1M calls/month free → plenty for small/medium sites
> - **Lambda**: 1M invocations/month free → each form submission = 1 invocation
> - **DynamoDB**: 25 GB storage + 25 write/read capacity units free
> - **SES**: 200 emails/day free → 6k/month
> - **CloudWatch**: 5GB logs free → covers ~1k submissions/day
>
> If you scale beyond free tier, costs are predictable:
> - Excess Lambda: $0.20 per million invocations
> - Excess DynamoDB write: $1.25 per million writes
> - SES overages: $0.10 per 1000 emails
>
> At 10k submissions/month (500 per day), you'd still be **fully within free tier**.
>
> No RDS database to manage. No EC2 instances. No NAT gateway. Just Lambda + DynamoDB. It's the **most cost-efficient** architecture for a form API."

**Key cost wins:**
- ✅ Free tier covers typical use
- ✅ Predictable pay-as-you-go
- ✅ No fixed infrastructure cost
- ✅ Scales automatically

---

### **FUTURE WORK (0:30)** — Roadmap

**[Visual: Show GitHub Issues or roadmap diagram]**

**You say:**

> "FormBridge is production-ready today, but here's what's on the roadmap:
>
> 1. **Multi-tenant Dashboard**: Manage multiple forms from one UI
> 2. **Webhooks**: Trigger external workflows (Zapier, Make, n8n)
> 3. **WAF Integration**: AWS WAF to block malicious IPs
> 4. **Quota Management**: Per-form submission limits
> 5. **Custom Email Templates**: HTML emails, dynamic content
> 6. **Advanced Analytics**: Funnel analysis, geo-tagging, conversion tracking
> 7. **Authentication**: Protect dashboard with OAuth2
>
> All of these are achievable without major architecture changes—just Lambda, DynamoDB, and additional SES capabilities."

**Key future features:**
- ✅ Multi-tenant support
- ✅ Webhooks for integrations
- ✅ WAF for DDoS protection
- ✅ Custom email templates
- ✅ Advanced analytics

---

### **Q&A (1:00+)** — Prepared Answers

**[Pause and invite questions; refer to answers below]**

---

## ❓ Q&A Prepared Answers

### **Design & Architecture**

**Q1: Why DynamoDB over relational DB?**

> "DynamoDB is ideal for high-throughput, low-latency access to unstructured data (submissions). It auto-scales, has no connection limits, and on-demand pricing means I pay only for what I use. A traditional RDS PostgreSQL would require provisioned capacity (costly) and connection pooling (complex). DynamoDB is simpler and cheaper at this scale."

**Q2: Why Lambda over a traditional server?**

> "Lambda eliminates server management. I don't patch OS, manage SSH keys, or scale instances manually. It's event-driven: a request comes in, a container spins up, Lambda runs, container exits. Billed per millisecond. For a contact form with bursty traffic, it's perfect."

**Q3: Composite key design—why `pk = FORM#{form_id}`, `sk = SUBMIT#{uuid}`?**

> "This design lets me efficiently query all submissions for a form in order. `pk` is the partition key (what form?), `sk` is the sort key (which submission?). The `SUBMIT#` prefix on the sort key allows me to add other record types later—e.g., `METADATA#...` or `ANALYTICS#...`—all in one table. It's a single-table design pattern; scales better than multi-table."

**Q4: How do you handle traffic spikes?**

> "DynamoDB on-demand mode auto-scales. If 1000 submissions arrive at once, DynamoDB spins up write capacity; I'm billed proportionally. Lambda is the same—concurrent executions scale to 1000 by default. No manual intervention needed. The only bottleneck is API Gateway rate limiting (configurable via usage plan)."

---

### **Security**

**Q5: Is HMAC signing overkill for a contact form?**

> "It's optional. For a public portfolio, API key + CORS is sufficient. HMAC is useful if you're integrating with a third-party system and want proof that requests came from your backend (not a replay or MITM attack). It adds ~10ms latency per request but ensures request authenticity. I implemented it as an opt-in feature via env var."

**Q6: Why not use AWS Cognito for authentication?**

> "Cognito is for user identity (sign-in). FormBridge doesn't need user login—it's an anonymous form API. API keys + usage plans are simpler and don't require managing user pools."

**Q7: How do you prevent spam/abuse?**

> "Multi-layered: (1) API key requirement means I can revoke a key if abused, (2) usage plan rate-limit enforces a cap (e.g., 10k/day), (3) Lambda validation catches malformed payloads early, (4) SES bounce/complaint monitoring prevents email list degradation."

**Q8: What about GDPR/privacy?**

> "Submissions are stored in DynamoDB with configurable retention (I set 30 days for logs, indefinite for submissions—configurable). Users can request deletion; I'd query and delete by uuid. No third-party data processors are involved—everything stays on AWS."

---

### **Operations & Cost**

**Q9: How do you monitor health? What if Lambda fails?**

> "CloudWatch Alarms monitor Lambda error rate, API Gateway 5XX, DynamoDB throttles. If Lambda error rate > 1%, an SNS alert triggers (email notification). I also log every submission with timestamp, so audit trails are retained. In the unlikely event of repeated failures, I'd roll back via GitHub Actions or manually redeploy a known-good version."

**Q10: What's your SES strategy? Sandbox vs. Production?**

> "SES starts in sandbox mode (limited to verified addresses). For production, you request a limit increase with AWS. Once approved, you can send to any email. I've pre-verified the sender email; requests are pending production approval. Sandbox is fine for demos and testing."

**Q11: How much does it really cost?**

> "At 1k submissions/month: ~$0 (free tier covers it). At 10k/month: still $0. At 100k/month: ~$5–10 (Lambda + DynamoDB overages). At 1M/month: ~$50–100. Compare to Typeform: $25–50/month fixed. FormBridge is cheaper until you hit very high volume, and even then, costs scale gradually with usage."

**Q12: How do you handle spam emails (bounces, complaints)?**

> "SES automatically tracks bounces and complaints. If bounce rate > 5% or complaint rate > 0.1%, SES rate-limits sending. I've set CloudWatch alarms to alert if these thresholds are crossed. I also store bounce/complaint events and can implement auto-cleanup (remove bounced emails from future sends)."

---

### **Technical Details**

**Q13: Why use SAM (Serverless Application Model) over raw CloudFormation?**

> "SAM is a higher-level DSL for serverless apps. It auto-generates boilerplate CloudFormation, making templates 50% shorter and more readable. `sam build` and `sam deploy` handle packaging and deployment. I prefer SAM for rapid iteration."

**Q14: How is CI/CD structured?**

> "GitHub Actions workflow: on every push to `main`, it runs `sam build`, deploys to AWS, and runs smoke tests (sends a test submission, verifies response). If tests fail, deployment is rolled back. This ensures zero-downtime updates."

**Q15: How does the CSV export work? Any performance risks?**

> "The `/export` endpoint queries DynamoDB with pagination (max 10k rows). It streams rows into a CSV in memory, then returns it as a file download. For very large datasets (100k+ submissions), I'd implement streaming CSV or S3 upload; for now, 10k rows is reasonable and completes in <1 second."

**Q16: What's the analytics computation? Real-time or batch?**

> "Real-time. The `/analytics` endpoint queries DynamoDB with a date range filter (last 7 days), counts submissions per day, and returns the breakdown. It's O(n) where n = submissions in last 7 days. For small/medium volume (<100k submissions), this is <100ms. I could optimize with a pre-computed DynamoDB Global Secondary Index (GSI) if needed."

**Q17: How do you handle timezone issues in the 7-day analytics?**

> "Timestamps are stored as Unix seconds (UTC). The `/analytics` endpoint receives the client's current date and computes: `ts >= now - (7 * 86400)`. It returns counts per date in UTC. The dashboard converts to local timezone for display. This avoids timezone complexity server-side."

**Q18: Why Postman collection + OpenAPI + Swagger? Aren't they redundant?**

> "Not really. OpenAPI is the spec (single source of truth). Swagger UI displays it (read-only documentation for APIs). Postman is for testing and development (executable requests with variables, tests, scripts). Together, they provide spec → docs → testing workflow."

---

### **Product & Business**

**Q19: How is FormBridge different from Formspree, Basin, or Webhooks.cool?**

> "Those are SaaS—you send data to their servers. FormBridge is open-source, self-hosted on YOUR AWS account. You own your data, no vendor lock-in, and it's cheaper at scale. The tradeoff: you manage the deployment (easy with SAM + GitHub Actions)."

**Q20: Could FormBridge be monetized?**

> "Yes. Potential models: (1) Managed hosting (we deploy/manage for others), (2) Enterprise plugins (webhooks, advanced analytics, custom templates), (3) Analytics SaaS (aggregating data across multiple FormBridge instances). For now, it's a portfolio project showcasing AWS + DevOps skills."

---

## 🎯 Delivery Tips

1. **Timing**: Practice once at 1.2x speed to stay within 6–8 min.
2. **Visual Aids**: Use architecture diagrams, screenshots, or live demos—don't just talk.
3. **Tone**: Confident but conversational; avoid jargon unless asked.
4. **Demo Fallback**: If live demo fails, have screenshots/videos ready.
5. **Q&A**: Pause every 1–2 sections to invite questions.

---

**Last Updated**: November 5, 2025  
**Status**: Ready for Delivery

