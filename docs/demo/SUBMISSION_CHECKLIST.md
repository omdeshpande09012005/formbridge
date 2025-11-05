# FormBridge Submission Checklist

**Purpose**: Pre-submission verification for professors/examiners  
**Status**: ✅ Ready for Review  
**Date**: November 5, 2025

---

## 📋 Code & Repository

- [ ] **Code Pushed**: All changes committed to main branch
  - `git log` shows recent commits
  - No uncommitted changes: `git status` is clean

- [ ] **README Updated**: Root README.md is current
  - Describes FormBridge purpose
  - Links to demo docs (/docs/demo/)
  - Includes quick start (3–5 min)

- [ ] **Git History Clean**: No merge conflicts, linear history
  - `git log --oneline -10` is readable
  - Commit messages follow convention: `feat()`, `sec()`, `docs()`, `fix()`

- [ ] **.gitignore Correct**: Sensitive files excluded
  - `.venv/` not in repo
  - `.aws-sam/` not in repo
  - `.env` not in repo
  - AWS credentials not exposed

---

## 📚 Documentation Complete

- [ ] **OpenAPI Spec**: `api/openapi.yaml` is valid
  - Run: `npx @openapitools/openapi-generator-cli validate -i api/openapi.yaml`
  - Or check in Swagger Editor online
  - Includes `/submit`, `/analytics`, `/export` endpoints
  - Security schemes documented (API key, optional HMAC)

- [ ] **Postman Collection**: `api/postman/FormBridge.postman_collection.json`
  - Importable without errors
  - Includes Submit, Analytics, Export requests
  - Pre-request script functional (HMAC signing)
  - Tests configured

- [ ] **Postman Environments**: Dev & Prod environments defined
  - `api/postman/FormBridge.Dev.postman_environment.json`
  - `api/postman/FormBridge.Prod.postman_environment.json`
  - Variables: base_url, api_key, form_id, hmac_enabled, hmac_secret

- [ ] **Swagger UI Live**: Documentation viewable
  - Swagger accessible at: https://omdeshpande09012005.github.io/swagger/ (or `docs/swagger.html`)
  - "Try it out" buttons functional
  - Endpoint descriptions clear

- [ ] **Demo Documentation**: `/docs/demo/` complete
  - [ ] VIVA_SCRIPT.md (6–8 min script with Q&A)
  - [ ] DEMO_RUNBOOK.md (step-by-step operator guide)
  - [ ] SUBMISSION_CHECKLIST.md (this file)
  - [ ] SCREENSHOT_SHOTLIST.md (shot list for captures)
  - [ ] ONE_PAGER.md (1-page overview)
  - [ ] FAQ.md (20 Q&As)

---

## 🖼️ Screenshots & Media

- [ ] **Dashboard Screenshots**: Captured in `/docs/screenshots/`
  - [ ] Dashboard KPIs + 7-day chart (1080p landscape)
  - [ ] DynamoDB table view (items visible)
  - [ ] Email notification (prod inbox or MailHog)
  - [ ] Postman 403 response (no API key)
  - [ ] Postman 200 response (with API key)

- [ ] **API Documentation Screenshots**:
  - [ ] Swagger UI home page
  - [ ] OpenAPI spec (endpoints visible)
  - [ ] Postman collection (request/response)

- [ ] **Infrastructure Screenshots**:
  - [ ] CloudWatch Alarms (Dashboard view)
  - [ ] API Gateway Usage Plan (quota visible)
  - [ ] DynamoDB table (metrics)
  - [ ] IAM Role (permissions visible)

- [ ] **Screenshots Named Consistently**: e.g., `01_dashboard_overview.png`, `02_ddb_table.png`, etc.

---

## 🔐 Security & Permissions

- [ ] **API Gateway**: Usage plan + API key configured
  - Rate limit visible: `10000 requests/day` (or configured value)
  - API key is active and in Postman environment

- [ ] **CORS Configured**: 
  - Test with OPTIONS request: `curl -i -X OPTIONS https://...`
  - Response includes: `Access-Control-Allow-Origin: https://omdeshpande09012005.github.io`

- [ ] **IAM Role (Lambda)**: Least-privilege permissions
  - `lambda-execution-role` exists
  - Attached policies:
    - `AWSLambdaDynamoDBExecutionRole` (custom or AWS-managed)
    - `AmazonSESFullAccess` (or custom SES policy)
  - No `AdministratorAccess` or overly broad permissions

- [ ] **HMAC Optional**: 
  - [ ] `HMAC_ENABLED` env var in Lambda = false (default)
  - [ ] Lambda code includes `verify_hmac_signature()` function
  - [ ] Documentation provided: `docs/HMAC_SIGNING.md`

- [ ] **Secrets Not Hardcoded**:
  - [ ] No AWS keys in code
  - [ ] No SES credentials in GitHub
  - [ ] Environment variables used for `HMAC_SECRET`, `DDB_TABLE`, `SES_SENDER`

---

## ⚡ Observability & Monitoring

- [ ] **CloudWatch Alarms Configured**:
  - [ ] Lambda error rate alarm (threshold: >1%)
  - [ ] API Gateway 5XX alarm
  - [ ] DynamoDB write throttle alarm
  - [ ] SES bounce/complaint alarm
  - [ ] Alarms tested (SNS notifications working)

- [ ] **CloudWatch Logs**:
  - [ ] Log group exists: `/aws/lambda/contactFormProcessor`
  - [ ] Retention policy set (30 days recommended)
  - [ ] Sample logs visible: recent submissions logged

- [ ] **Dashboard Analytics**:
  - [ ] Dashboard refreshes automatically (every 30 seconds)
  - [ ] Shows 7-day trend chart
  - [ ] Shows KPI tiles (today, total, per-day breakdown)
  - [ ] CSV export button functional

---

## 🚀 Deployment & CI/CD

- [ ] **GitHub Actions Workflow**: `.github/workflows/` configured
  - [ ] Workflow file exists (e.g., `deploy.yml`)
  - [ ] Triggers on `push` to `main`
  - [ ] Runs `sam build` → `sam deploy`
  - [ ] Post-deploy smoke tests included

- [ ] **SAM Template**: `template.yaml` is valid
  - [ ] Globals defined (runtime: Python 3.11, region: ap-south-1)
  - [ ] Lambda function defined with environment variables
  - [ ] API Gateway + usage plan defined
  - [ ] DynamoDB table defined (with on-demand pricing)
  - [ ] Outputs section includes endpoint URL

- [ ] **Local Development**: Docker Compose + Makefile working
  - [ ] `make local-up` starts all services
  - [ ] `make sam-api` runs local Lambda
  - [ ] `make local-test` executes test submissions
  - [ ] `make local-down` cleans up

---

## 💰 Cost Verification

- [ ] **Free-Tier Eligibility Confirmed**:
  - [ ] Lambda: On-demand (1M invocations/month free)
  - [ ] DynamoDB: On-demand (25 GB storage + capacity units free)
  - [ ] API Gateway: 1M calls/month free
  - [ ] SES: 200 emails/day free

- [ ] **Cost Documentation**:
  - [ ] `README_PRODUCTION.md` includes cost section
  - [ ] Pricing table: Lambda, DynamoDB, API Gateway, SES
  - [ ] Comparison to competitors (Typeform, Mailchimp)

- [ ] **CloudWatch Cost Monitoring**:
  - [ ] Estimated monthly costs visible in AWS Console
  - [ ] No unexpected charges (e.g., data transfer, data at rest)

---

## ✅ Functionality Verification

- [ ] **Form Submission Flow**:
  - [ ] Submit form → 200 OK response
  - [ ] Submission ID returned in response
  - [ ] Data appears in DynamoDB (verify via admin UI or query)
  - [ ] Email sent (check inbox or MailHog)

- [ ] **Analytics Endpoint**:
  - [ ] `/analytics` returns 200 with submission count
  - [ ] 7-day breakdown returns correct data
  - [ ] Dashboard fetches and displays analytics

- [ ] **CSV Export Endpoint**:
  - [ ] `/export` returns 200 with CSV content-type
  - [ ] CSV file downloads and opens correctly
  - [ ] Columns correct: id, form_id, name, email, message, page, ip, ua, ts
  - [ ] Row count and date filtering work

- [ ] **Security Checks**:
  - [ ] No API key → 403 Forbidden
  - [ ] Invalid API key → 403 Forbidden
  - [ ] Valid API key → 200 OK
  - [ ] CORS violation (wrong origin) → blocked by browser

- [ ] **Error Handling**:
  - [ ] Missing required fields → 400 Bad Request with error message
  - [ ] Invalid JSON → 400 Bad Request
  - [ ] Server error → 500 Internal Server Error with CloudWatch logged
  - [ ] Rate limit exceeded → 429 Too Many Requests

---

## 📄 Demo Documentation Quality

- [ ] **VIVA_SCRIPT.md**:
  - [ ] 6–8 minutes duration (with timings)
  - [ ] Sections: Opening, Architecture, Security, Observability, Demo, ROI, Future, Q&A
  - [ ] Talk track is natural (not robotic)
  - [ ] Q&A section has 12+ prepared answers

- [ ] **DEMO_RUNBOOK.md**:
  - [ ] Step-by-step instructions (numbered)
  - [ ] Pre-flight checklist included
  - [ ] Copy-paste commands provided
  - [ ] Expected outputs documented
  - [ ] Troubleshooting section included

- [ ] **ONE_PAGER.md**:
  - [ ] Fits on 1 page (or 1 screen without scrolling too much)
  - [ ] Title, Problem, Solution clear
  - [ ] Architecture diagram or caption
  - [ ] Key features bulleted
  - [ ] Security/Cost highlights
  - [ ] Links to resources

- [ ] **FAQ.md**:
  - [ ] 20+ Q&As covering design, architecture, security, cost
  - [ ] Answers are 2–4 sentences (crisp, not verbose)
  - [ ] Addresses common concerns (GDPR, spam, monitoring)

- [ ] **SCREENSHOT_SHOTLIST.md**:
  - [ ] Lists every screenshot to capture (title + location)
  - [ ] Framing tips included (resolution, theme, consistency)
  - [ ] Example: "01_dashboard: KPIs visible, 7-day chart visible, light theme, 1080p"

---

## 📦 Packaging & Delivery

- [ ] **Submission Package**: `/dist/formbridge_submission_YYYYMMDD.zip`
  - [ ] Created by `scripts/package_submission.ps1` or `.sh`
  - [ ] Contains:
    - [ ] Source code (without `.venv`, `.aws-sam`, `.env`)
    - [ ] Docs (README, demo docs, API specs)
    - [ ] API artifacts (OpenAPI, Postman)
    - [ ] Dashboard folder
    - [ ] Screenshots folder (if exists)
    - [ ] `READ_ME_FIRST.txt` with quick start

- [ ] **File Structure** within zip:
  ```
  formbridge_submission_20251105/
  ├── backend/
  ├── dashboard/
  ├── docs/
  │   ├── demo/
  │   ├── screenshots/
  │   └── *.md (HMAC_SIGNING.md, EXPORT_README.md, etc.)
  ├── api/
  ├── scripts/
  ├── README.md
  ├── template.yaml
  ├── README_PRODUCTION.md
  ├── READ_ME_FIRST.txt
  └── ...
  ```

- [ ] **READ_ME_FIRST.txt**: Included in zip with:
  - [ ] 30-second project overview
  - [ ] Links to key documentation (VIVA_SCRIPT.md, DEMO_RUNBOOK.md)
  - [ ] Quick start instructions (5 min)
  - [ ] Where to find: API spec, Postman, dashboard, screenshots

---

## 🎓 Professor/Examiner Notes

**Pass Criteria** (check all):

- ✅ Code is clean, documented, no business logic changes
- ✅ API is working (test with Postman or cURL)
- ✅ Security layers in place (API key, CORS, IAM)
- ✅ Observability configured (alarms, logs, dashboard)
- ✅ Demo is smooth (practice script, runbook verified)
- ✅ Documentation is complete and professional
- ✅ Cost is within free tier
- ✅ Deployment is automated (CI/CD working)

**Bonus Points**:

- ✅ HMAC optional signing implemented
- ✅ CSV export endpoint functional
- ✅ Local dev environment with Docker
- ✅ Comprehensive Q&A prepared
- ✅ Screenshots of all key features
- ✅ Packaging script for easy submission

---

## 🎯 Pre-Viva Checklist (24 hours before)

1. [ ] Rerun entire demo locally and on production
2. [ ] Practice VIVA_SCRIPT.md at 1.1x speed (stay within 8 min)
3. [ ] Test all Postman requests (prod environment)
4. [ ] Verify email arrives (prod)
5. [ ] Check CloudWatch Alarms are active
6. [ ] Take final screenshots for proof
7. [ ] Create submission zip file
8. [ ] Print or have digital copy of ONE_PAGER.md
9. [ ] Have FAQ.md available for reference
10. [ ] Get good sleep 😴

---

**Status**: ✅ Ready for Submission  
**Last Verified**: November 5, 2025  
**Examiner**: [Professor Name]  
**Score**: [To be filled in]

