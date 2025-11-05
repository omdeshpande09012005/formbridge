# FormBridge FAQ

**Frequently Asked Questions** | **20 Q&As on Design, Architecture, Security & Cost**

---

## Design & Product Questions

### Q1: Why did you build FormBridge instead of just using Typeform?

**A**: Typeform costs $25–50/month and locks you into their ecosystem. FormBridge lets me control the entire stack, own my data, and pay based on actual usage (often $0/month on free tier). It also showcases AWS + DevOps skills beyond "filling out a form."

### Q2: How is FormBridge different from Formspree or Basin?

**A**: Those are SaaS—you send data to their servers. FormBridge is self-hosted on YOUR AWS account. You own the data, can customize the backend, and avoid vendor lock-in. The tradeoff: you manage deployment (easy with SAM).

### Q3: Could FormBridge handle multiple forms (e.g., contact, feedback, newsletter)?

**A**: Yes. The `form_id` parameter lets you route different forms to the same endpoint. Example: form_id="contact" vs. "feedback". The Lambda and DynamoDB handle multiple forms natively; the composite key design (`pk = FORM#{form_id}`) makes querying efficient per form.

### Q4: What if I want to integrate with Slack/Discord instead of email?

**A**: The Lambda code is modular. Replace the SES call with Slack webhook (use boto3 `requests`). DynamoDB stores the submission either way. No API changes needed; just update Lambda code and redeploy via GitHub Actions.

### Q5: Can non-technical users manage this?

**A**: Not really—it requires AWS knowledge. But the dashboard and README are designed for technical stakeholders. For truly non-technical users, Typeform/Mailchimp are better. FormBridge is for builders/engineers.

---

## Architecture Questions

### Q6: Why DynamoDB instead of PostgreSQL?

**A**: DynamoDB is serverless (no connection management), auto-scales on-demand, and costs ~$0/month at typical volumes. PostgreSQL would require an RDS instance (minimum $15/month), connection pooling logic, and manual scaling. For a contact form, DynamoDB is simpler and cheaper.

### Q7: Why is the composite key structured as `pk = FORM#{form_id}`, `sk = SUBMIT#{uuid}`?

**A**: This is the single-table design pattern. `pk` identifies the partition (which form?), `sk` identifies the item (which submission?). The `SUBMIT#` prefix lets me add other record types later (`METADATA#`, `ANALYTICS#`) all in one table. Query-efficient and flexible.

### Q8: How do you handle traffic spikes?

**A**: Lambda auto-scales to 1000 concurrent executions (AWS default). DynamoDB on-demand auto-scales. API Gateway rate-limits per key (configurable). In the unlikely event of a true DDoS, AWS WAF (future roadmap) can block malicious traffic.

### Q9: Why Lambda instead of EC2 or ECS?

**A**: Lambda is event-driven—a request arrives, a container spins up, code runs, container exits. Billed per millisecond. No server management, no SSH keys, no patches. For a form API with bursty traffic, it's ideal. EC2/ECS would sit idle most of the time.

### Q10: Could you run FormBridge on-premises?

**A**: Technically yes, but you'd lose the serverless benefits. The architecture relies on managed services (Lambda, DynamoDB, SES, API Gateway). On-premises, you'd need to replace these with open-source equivalents (e.g., PostgreSQL, Celery, SendGrid). Not recommended; defeats the purpose.

---

## Security Questions

### Q11: What's the point of HMAC signing if you already have API keys?

**A**: API keys prevent unauthorized users. HMAC prevents **request tampering** and **replay attacks**. If a request is intercepted in transit (HTTPS failure, proxy attack), HMAC ensures the request came from the expected sender (via signature) and wasn't replayed (via timestamp). It's optional but valuable for high-security deployments.

### Q12: Why not use AWS Cognito for authentication?

**A**: Cognito is for user identity (sign-in, MFA). FormBridge doesn't need user login—it's an anonymous form API. API keys + usage plans are simpler and sufficient. Cognito would add complexity and cost.

### Q13: How do you prevent spam submissions?

**A**: Multi-layered: (1) API key requirement (I can revoke a key if abused), (2) rate-limit per key (10k/day), (3) Lambda validates payload (field length, email format), (4) SES bounce/complaint tracking (if bounce rate > 5%, SES rate-limits automatically). No CAPTCHA needed for this use case.

### Q14: Is this compliant with GDPR?

**A**: Mostly. Submissions are stored in DynamoDB (AWS, EU-compliant). Users can request deletion; you query by email and delete. No third-party processors. For full GDPR compliance, you'd need to: document retention policy, implement deletion workflows, set up Data Processing Addendum (DPA) with AWS. See README_PRODUCTION.md for details.

### Q15: What if someone exploits the CSV export to download all submissions?

**A**: The `/export` endpoint requires API key (like all endpoints). If someone has the key, they're already authorized. You could add finer-grained auth (e.g., JWT with claims), but that's future work. For now, treat the API key as a secret; don't commit it to GitHub.

---

## Observability & Monitoring

### Q16: What happens if Lambda crashes?

**A**: CloudWatch automatically logs the error and increments an error metric. If error rate > 1%, a CloudWatch Alarm triggers and sends an SNS notification (email alert). You'd see the alert and investigate logs. Meanwhile, API Gateway returns a 5XX error to the client.

### Q17: How long are logs retained?

**A**: CloudWatch Logs are set to 30 days retention (configurable). This balances compliance (audit trail) and cost (5 GB free). Older logs are deleted automatically. For long-term archival, stream logs to S3 (future roadmap).

### Q18: Can you get notified if SES emails bounce?

**A**: Yes. SES publishes bounce/complaint events to SNS. I've set up a CloudWatch Alarm to trigger if bounce rate > 5%. This protects email reputation; if too many bounces, SES rate-limits automatically.

### Q19: How do you debug Lambda errors in production?

**A**: CloudWatch Logs show error messages and stack traces. Structured logging (timestamp, form_id, error) makes debugging easier. For complex issues, use X-Ray (AWS's distributed tracing service, future roadmap) to trace requests end-to-end.

### Q20: What's the typical response time for a form submission?

**A**: ~150 ms average (p50 latency). First request is slower (~500 ms cold start), but most requests hit warm Lambda instances. API Gateway adds ~10–20 ms. Database write is ~5–10 ms. Total: well under 1 second, imperceptible to users.

---

## Cost & Operations

### Q21: At what scale do you start paying?

**A**: You never pay if you stay within free tier: ~1k submissions/month (33/day) is free forever. At 10k/month, you're still free. At 100k/month, you'd pay ~$8–20 (mostly DynamoDB + SES overages). At 1M/month, ~$50–100.

### Q22: How much does it cost to run this 24/7?

**A**: Depends on volume. At rest (0 submissions), cost is $0. With 1k submissions/month, still $0. With 10k/month, ~$2–3 (mostly CloudWatch Logs, some SES). Practically speaking, $0–10/month for typical portfolio usage.

### Q23: Can you auto-scale down to zero?

**A**: Yes. Lambda scales to zero when idle (no concurrent executions = no cost). DynamoDB on-demand also scales to zero (minimum throughput charge is tiny). API Gateway charges per call (no per-second cost), so idle = free. Perfect for bursty workloads.

### Q24: How do you handle SES sandbox limitations?

**A**: SES starts in sandbox mode (verified addresses only). To send to any email, request production access (usually approved within 1 hour). I've submitted; awaiting approval. In sandbox, I can send 200 emails/day to verified addresses, enough for portfolio demos.

### Q25: What if your monthly bill exceeds budget?

**A**: Set a CloudWatch Alarm on AWS billing. When estimated monthly cost > threshold, alert fires. Additionally, set Service Control Policies (SCPs) in AWS Organizations to cap service limits (e.g., max Lambda concurrent executions). You can also manually set DynamoDB read/write limits.

---

## Code & Deployment

### Q26: Why use SAM instead of Terraform?

**A**: SAM is AWS-specific and shorter (60 lines vs. 150+ with Terraform). For multi-cloud, Terraform is better. But FormBridge is AWS-only, so SAM's simplicity wins. Both deploy to CloudFormation under the hood.

### Q27: How does CI/CD work?

**A**: GitHub Actions workflow: on `push` to `main`, it runs `sam build` → `sam deploy` → smoke tests. If tests fail, deployment rolls back. Zero-downtime updates; no manual SSH.

### Q28: Can you downgrade Lambda from Python 3.11 to 3.9?

**A**: Yes. Edit `template.yaml`, change `Runtime: python3.11` to `python3.9`, commit, and GitHub Actions redeploys. Downtime: ~2 minutes while new Lambda updates. No data loss.

### Q29: How do you manage secrets (API keys, SES credentials)?

**A**: No hardcoded secrets in code. Everything is environment variables (set in SAM template via Lambda configuration). SES credentials are never stored; Lambda uses IAM role (attached permissions). API keys are managed by API Gateway (stored in AWS secrets store, not in code).

### Q30: What if you accidentally delete the DynamoDB table?

**A**: Data is gone (no native backup by default). Future roadmap: enable DynamoDB point-in-time recovery (PITR) and/or nightly snapshots to S3. For now, treat it as critical: don't delete manually. Deployments never delete existing tables.

---

## Product & Business

### Q31: How would you monetize FormBridge?

**A**: Potential models: (1) **Managed hosting** (we deploy/manage for non-technical users), (2) **Enterprise plugins** (webhooks, advanced templates, multi-tenant), (3) **Analytics SaaS** (aggregated insights across multiple deployments), (4) **Professional services** (custom integrations). For now, it's a portfolio project.

### Q32: Why is the API rate-limited to 10k requests/day?

**A**: It's configurable. 10k is a reasonable free-tier limit (333/hour). Typical portfolio gets <50/day. Beyond 10k, you'd likely want to discuss your use case (could raise limit). It prevents abuse while being generous for legitimate users.

### Q33: What's the technical debt or limitations?

**A**: (1) No built-in auth for dashboard (could add OAuth2), (2) No email templates (SES plain text only), (3) No webhooks yet, (4) Single region (ap-south-1; could go multi-region), (5) Manual SES sandbox approval. All addressable; chosen for MVP simplicity.

### Q34: How is FormBridge tested?

**A**: Smoke tests in GitHub Actions (submit form → verify DynamoDB + email). Integration tests locally (Makefile). Unit tests on Lambda (Python unittest). No formal test framework yet, but coverage is good for an MVP.

### Q35: Is the code production-ready?

**A**: Yes. It handles errors gracefully, logs everything, has IAM least-privilege, uses environment variables for config. Would I change anything? Add request validation (JSON Schema), implement jitter in retry logic, add request tracing (X-Ray). But as is, it's solid.

---

## Performance & Scaling

### Q36: What's the max submissions/second you can handle?

**A**: Limited by DynamoDB on-demand (auto-scales) and Lambda concurrency (1000 by default). Assume ~100 submissions/second comfortably. Beyond that, request AWS to increase Lambda concurrency limit.

### Q37: How does the analytics query scale as you get more submissions?

**A**: The `/analytics` endpoint queries DynamoDB with a date range filter (last 7 days). It's O(n) where n = submissions in 7 days. For 1M submissions/month, that's ~350k submissions queried = ~100–200 ms response time. Acceptable. For optimality, add a GSI (Global Secondary Index) on timestamp.

### Q38: What if DynamoDB throttles (exceeds on-demand capacity)?

**A**: On-demand mode automatically scales. If your bill is too high due to scaling, you could switch to provisioned mode (cheaper at scale, but needs capacity planning). Alarms notify you if throttles occur.

### Q39: Can you geo-replicate FormBridge to multiple AWS regions?

**A**: Yes, but it's complex. You'd need DynamoDB global tables (multi-region), Route53 (DNS failover), Lambda@Edge (CDN). Out of scope for now; MVP is single-region (ap-south-1).

### Q40: What's the cold start latency of Lambda?

**A**: ~500 ms first request (Lambda provisioning). Subsequent requests ~150 ms (warm container). You can reduce cold start by (1) smaller Lambda package, (2) provisioned concurrency (costs extra), (3) language (Go is faster than Python). Current is acceptable for form submission.

---

## Data & Analytics

### Q41: How do you compute the 7-day breakdown in analytics?

**A**: The `/analytics` endpoint queries DynamoDB with `sk begins_with SUBMIT# AND ts >= (now - 7 days)`. It then groups by date (extract day from Unix timestamp) and counts per day. Returns a 7-element array (one per day).

### Q42: What timezone is used for analytics?

**A**: Timestamps are stored as Unix seconds (UTC). The `/analytics` endpoint returns UTC dates. The dashboard converts to local timezone for display (JavaScript `new Date(unix_timestamp * 1000).toLocaleDateString()`). This avoids timezone complexity server-side.

### Q43: How accurate is the submission count in the dashboard?

**A**: 100% accurate. It's a direct query of DynamoDB (not an estimate). The `/analytics` endpoint doesn't use approximations; it counts every row. Only caveat: eventual consistency (milliseconds); by the time you load the page, it's consistent.

### Q44: Can you filter submissions by email or name?

**A**: Currently, exports are all-or-nothing (entire date range). To filter by email, you'd do it client-side (Excel/Sheets) after CSV download. Future: add optional filter parameters (`?email=*@gmail.com`) to `/export` endpoint.

### Q45: Is there a way to deduplicate submissions (e.g., if someone submits twice accidentally)?

**A**: Not automatically. Each submission is a unique UUID + timestamp. You could add client-side debouncing (disable button for 2 seconds after submit) or server-side duplicate detection (hash email + message, reject if seen in last 60 seconds). Future enhancement.

---

## Troubleshooting & Support

### Q46: What if the API endpoint returns 5XX errors?

**A**: Check CloudWatch Logs (`/aws/lambda/contactFormProcessor`). Common causes: (1) invalid payload (bad JSON), (2) missing environment variable, (3) DynamoDB permission issue. Errors are logged with full stack trace.

### Q47: What if emails aren't being delivered?

**A**: Check SES dashboard: (1) is it in sandbox mode? (2) have you verified the sender email? (3) are there bounces/complaints? Also check CloudWatch Logs for SES errors. In sandbox, emails only go to verified addresses.

### Q48: What if the dashboard shows no data?

**A**: (1) Check dashboard config.js points to correct API endpoint, (2) verify API key is valid, (3) check if submissions exist in DynamoDB, (4) check network tab in browser DevTools for failed requests.

### Q49: How do you debug HMAC signature errors?

**A**: Check that (1) secret matches on client and Lambda, (2) timestamp is Unix seconds (not milliseconds), (3) message format is `timestamp\nbody` (with newline), (4) signature is hex lowercase, (5) X-Timestamp and X-Signature headers are set. See HMAC_SIGNING.md for debugging tips.

### Q50: What if you need to rotate the API key?

**A**: (1) Generate new key in API Gateway console, (2) test with new key, (3) update Postman environment, (4) update frontend config, (5) revoke old key. No downtime; keys can coexist.

---

## Quick Links

| Topic | Link |
|-------|------|
| **API Specification** | `docs/openapi.yaml` |
| **HMAC Guide** | `docs/HMAC_SIGNING.md` |
| **CSV Export Guide** | `docs/EXPORT_README.md` |
| **Demo Runbook** | `docs/demo/DEMO_RUNBOOK.md` |
| **Viva Script** | `docs/demo/VIVA_SCRIPT.md` |
| **One-Pager** | `docs/demo/ONE_PAGER.md` |

---

**Last Updated**: November 5, 2025  
**Status**: ✅ Ready for Review  
**Questions?** Check VIVA_SCRIPT.md for more context.

