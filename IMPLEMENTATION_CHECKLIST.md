# FormBridge Analytics Implementation Checklist

## ✅ Current Status: LAMBDA FUNCTION COMPLETE

The `contact_form_lambda.py` file is **fully implemented** with:
- ✅ `/submit` endpoint for form submissions
- ✅ `/analytics` endpoint for form statistics
- ✅ Smart routing between endpoints
- ✅ Validation (name, email, message required)
- ✅ TTL support (90-day auto-deletion)
- ✅ Email notifications via SES
- ✅ DynamoDB integration
- ✅ CORS headers
- ✅ IP & User-Agent tracking

---

## 📋 STEP 1: Deploy Lambda Function to AWS

### 1.1 Build & Package
```bash
cd w:\PROJECTS\formbridge\backend

# Build with SAM
sam build --use-container

# Or build locally if you have dependencies installed
sam build
```

### 1.2 Deploy to AWS
```bash
# Deploy interactively (first time)
sam deploy --guided

# Or deploy with existing config
sam deploy
```

**What to provide during `sam deploy --guided`:**
- Stack name: `formbridge-stack` (or your choice)
- Region: `us-east-1` (or your preferred region)
- DynamoDB table name: `FormSubmissions`
- SES sender email: your verified SES email
- SES recipients: comma-separated emails to notify
- Frontend origin: `https://omdeshpande09012005.github.io`

### 1.3 Capture Output Values
After deployment, note these values:
```
✓ Lambda Function Name: (e.g., formbridge-stack-contactFormProcessor-XXX)
✓ Lambda Function ARN: (e.g., arn:aws:lambda:us-east-1:123456789:function:...)
✓ DynamoDB Table Name: (e.g., FormSubmissions)
✓ API Endpoint URL: (from CloudFormation outputs)
```

---

## 📋 STEP 2: Set Up DynamoDB Table

The SAM template should create this automatically, but verify:

### 2.1 Check Table Exists
```bash
aws dynamodb describe-table \
  --table-name FormSubmissions \
  --region us-east-1
```

### 2.2 Expected Table Schema
```
Partition Key (pk): String
Sort Key (sk): String
TTL Attribute: ttl
```

### 2.3 Manual Creation (if needed)
```bash
aws dynamodb create-table \
  --table-name FormSubmissions \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Enable TTL
aws dynamodb update-time-to-live \
  --table-name FormSubmissions \
  --time-to-live-specification "AttributeName=ttl,Enabled=true" \
  --region us-east-1
```

---

## 📋 STEP 3: Configure SES (Email Sending)

### 3.1 Verify Email Address
```bash
# Request verification
aws ses verify-email-identity \
  --email-address your-email@example.com \
  --region us-east-1

# Check verification status
aws ses list-verified-email-addresses --region us-east-1
```

### 3.2 Set Environment Variables
Update Lambda function environment variables:
```bash
# DDB_TABLE
FormSubmissions

# SES_SENDER
your-verified-email@example.com

# SES_RECIPIENTS
recipient1@example.com,recipient2@example.com

# FRONTEND_ORIGIN
https://omdeshpande09012005.github.io
```

Command to update:
```bash
aws lambda update-function-configuration \
  --function-name contactFormProcessor \
  --environment "Variables={DDB_TABLE=FormSubmissions,SES_SENDER=your-email@example.com,SES_RECIPIENTS=recipient@example.com,FRONTEND_ORIGIN=https://omdeshpande09012005.github.io}" \
  --region us-east-1
```

---

## 📋 STEP 4: Set Up API Gateway

### 4.1 Create REST API (if not exists)
```bash
# Check if API exists
aws apigateway get-rest-apis --region us-east-1

# If not, create new API
aws apigateway create-rest-api \
  --name FormBridgeAPI \
  --description "Contact form API with analytics" \
  --region us-east-1
```

### 4.2 Add /submit Endpoint (if not exists)
This should already exist from your initial setup.

### 4.3 **Run the Analytics Endpoint Script** ⭐
```bash
cd w:\PROJECTS\formbridge

# 1. Edit the script with your values
nano add_analytics_endpoint.sh

# Or use Windows editor:
notepad add_analytics_endpoint.sh
```

**Edit these values:**
```bash
API_ID="API_ID"                    # Your REST API ID
REGION="REGION"                    # us-east-1
LAMBDA_NAME="LAMBDA_NAME"          # Your Lambda function name
STAGE_NAME="STAGE_NAME"            # prod or dev
USAGE_PLAN_NAME="USAGE_PLAN_NAME"  # Your usage plan name
API_KEY_NAME="API_KEY_NAME"        # Your API key name
FRONTEND_ORIGIN="FRONTEND_ORIGIN"  # https://omdeshpande09012005.github.io
```

**Find your values:**
```bash
# API ID
aws apigateway get-rest-apis --region us-east-1 | jq '.items[] | select(.name=="FormBridgeAPI") | .id'

# Lambda name
aws lambda list-functions --region us-east-1 | jq '.Functions[] | select(.FunctionName | contains("contactFormProcessor")) | .FunctionName'

# Usage plan name
aws apigateway get-usage-plans --region us-east-1 | jq '.items[0].name'

# API key name
aws apigateway get-api-keys --region us-east-1 | jq '.items[0].name'
```

**Run the script:**
```bash
# Make executable (PowerShell)
# (Already executable on Unix-like systems)

# Run it
bash add_analytics_endpoint.sh

# Or on Windows with WSL:
wsl bash add_analytics_endpoint.sh
```

---

## 📋 STEP 5: Test the Endpoints

### 5.1 Get Your Values
```bash
# API ID
$API_ID = "your-api-id"

# Region
$REGION = "us-east-1"

# Stage
$STAGE = "prod"

# API Key
$API_KEY = "your-api-key-value"

# Base URL
$BASE_URL = "https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE"
```

### 5.2 Test /submit Endpoint
```bash
# Submit a form
curl -X POST "$BASE_URL/submit" `
  -H "Content-Type: application/json" `
  -d '{
    "form_id": "portfolio-contact",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message",
    "page": "https://omdeshpande09012005.github.io/contact"
  }'

# Expected response:
# {"id": "uuid-here"}
```

### 5.3 Test /analytics Endpoint (without API Key - should fail)
```bash
curl -i -X POST "$BASE_URL/analytics" `
  -H "Content-Type: application/json" `
  -d '{"form_id": "portfolio-contact"}'

# Expected: 403 Forbidden
```

### 5.4 Test /analytics Endpoint (with API Key - should succeed)
```bash
curl -i -X POST "$BASE_URL/analytics" `
  -H "X-Api-Key: $API_KEY" `
  -H "Content-Type: application/json" `
  -d '{"form_id": "portfolio-contact"}'

# Expected response:
# {
#   "form_id": "portfolio-contact",
#   "total_submissions": 1,
#   "last_7_days": [...],
#   "latest_id": "uuid",
#   "last_submission_ts": "2025-11-05T..."
# }
```

---

## 📋 STEP 6: Update Frontend Code

### 6.1 Update Your React Portfolio

**File:** `c:\Users\Admin\dev-projects\my-portfolio-vite\src\components\Contact.jsx` (or similar)

```javascript
import { useState } from 'react';

export default function Contact() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    message: ''
  });
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const API_ENDPOINT = "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/prod/submit";

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      const response = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          form_id: 'portfolio-contact',
          name: formData.name,
          email: formData.email,
          message: formData.message,
          page: window.location.href
        })
      });

      const data = await response.json();
      
      if (response.ok) {
        setSuccess(true);
        setFormData({ name: '', email: '', message: '' });
        setTimeout(() => setSuccess(false), 3000);
      } else {
        console.error('Error:', data.error);
      }
    } catch (error) {
      console.error('Network error:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {/* Your form fields */}
      <button type="submit" disabled={loading}>
        {loading ? 'Sending...' : 'Send Message'}
      </button>
      {success && <p>Message sent successfully!</p>}
    </form>
  );
}
```

### 6.2 Create Analytics Dashboard (Optional)

```javascript
import { useState, useEffect } from 'react';

export default function AnalyticsDashboard() {
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);

  const API_ENDPOINT = "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/prod/analytics";
  const API_KEY = "YOUR_API_KEY";  // Store securely in env vars

  useEffect(() => {
    fetchAnalytics();
  }, []);

  const fetchAnalytics = async () => {
    try {
      const response = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': API_KEY
        },
        body: JSON.stringify({ form_id: 'portfolio-contact' })
      });

      const data = await response.json();
      if (response.ok) {
        setAnalytics(data);
      }
    } catch (error) {
      console.error('Error fetching analytics:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div>Loading...</div>;
  if (!analytics) return <div>No data</div>;

  return (
    <div>
      <h2>Form Analytics</h2>
      <p>Total Submissions: {analytics.total_submissions}</p>
      <h3>Last 7 Days</h3>
      <ul>
        {analytics.last_7_days.map(day => (
          <li key={day.date}>
            {day.date}: {day.count} submissions
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

## 📋 STEP 7: Monitor & Verify

### 7.1 Check CloudWatch Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1

# Or get recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/contactFormProcessor \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### 7.2 Check DynamoDB Submissions
```bash
# Scan for submissions
aws dynamodb scan \
  --table-name FormSubmissions \
  --region us-east-1 \
  --limit 5 | jq '.Items'
```

### 7.3 Monitor API Usage
```bash
# Check API Gateway request metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=FormBridgeAPI Name=Stage,Value=prod \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region us-east-1
```

---

## 📋 STEP 8: Production Deployment

### 8.1 Set Up CI/CD (Optional but Recommended)
See `CICD_DEPLOYMENT.md` for GitHub Actions setup.

### 8.2 Cost Estimation
```
DynamoDB:     ~$0-1/month  (On-demand pricing, light usage)
Lambda:       ~$0-2/month  (Free tier + minimal overages)
SES:          ~$0.10/month (1000 free emails/month)
API Gateway:  ~$1-2/month  (1M free requests/month + minimal overages)
Total:        ~$2-5/month for portfolio usage
```

### 8.3 Security Checklist
- ✅ API key required for /analytics endpoint
- ✅ CORS headers restricted to your domain
- ✅ SES verified email only
- ✅ Lambda execution role with minimal permissions
- ✅ DynamoDB encrypted at rest
- ✅ CloudWatch logs for audit trail

---

## ✨ SUCCESS CRITERIA

You'll know everything is working when:

1. ✅ Form submission appears in DynamoDB
2. ✅ Notification email received
3. ✅ `/analytics` requires API key (403 without it)
4. ✅ `/analytics` returns stats (200 with valid key)
5. ✅ Frontend form submits successfully
6. ✅ No errors in CloudWatch logs
7. ✅ Portfolio website displays confirmation message

---

## 📞 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Function not found" | Check function name matches `LAMBDA_NAME` in script |
| "InvalidParameterValueException" | Verify environment variables are set correctly |
| "Invalid API key" | Double-check API key value in curl command |
| "CORS error in browser" | Verify FRONTEND_ORIGIN matches your domain exactly |
| "Email not received" | Check SES verified emails and sandbox mode status |
| "DynamoDB scan returns empty" | Wait for data to appear after first submission |

---

## 📂 Files Reference

```
w:\PROJECTS\formbridge\
├── backend/
│   ├── contact_form_lambda.py          ✅ READY (implemented)
│   ├── template.yaml                   ← Check this for SAM config
│   └── requirements.txt                ✅ COMPLETE
├── add_analytics_endpoint.sh            ✅ READY (run this)
├── API_GATEWAY_SCRIPT_GUIDE.md          📖 Reference
├── SCRIPT_USAGE_EXAMPLES.md             📖 Examples
├── QUICK_REFERENCE.txt                  📖 Quick lookup
└── This file (IMPLEMENTATION_CHECKLIST.md)
```

---

**Next Action:** Start with STEP 1 - Deploy Lambda Function!

