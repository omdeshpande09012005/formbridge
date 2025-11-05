# FormBridge Implementation - Step by Step

## 📋 What Has Been Done

✅ **Lambda function** (`contact_form_lambda.py`)
- Implements both `/submit` and `/analytics` endpoints
- Full validation, error handling, email notifications
- TTL support for 90-day auto-deletion
- IP and User-Agent tracking

✅ **SAM Template** (`template.yaml`)
- Updated with `/analytics` endpoint configuration
- DynamoDB table with TTL enabled
- API Gateway CORS configuration
- Output values for easy reference

✅ **Documentation**
- Comprehensive deployment guides
- API reference and testing guides
- Usage examples

---

## 🚀 IMPLEMENTATION TASKS

### TASK 1: Deploy Lambda & DynamoDB (5 minutes)

**What it does:**
- Creates Lambda function with both endpoints
- Creates DynamoDB table with TTL
- Sets up API Gateway
- Configures SES environment variables

**Step 1.1: Open Terminal**
```bash
cd w:\PROJECTS\formbridge\backend
```

**Step 1.2: Build Application**
```bash
sam build
```

Expected output:
```
Build Succeeded
Built Artifacts: .aws-sam/build
```

**Step 1.3: Deploy (Interactive)**
```bash
sam deploy --guided
```

**When prompted, enter:**
- Stack name: `formbridge-stack`
- AWS region: `us-east-1`
- DDBTableName: `contact-form-submissions`
- SesSender: **Your verified SES email** (e.g., admin@example.com)
- SesRecipients: **Email to receive notifications** (can be same as sender)
- FrontendOrigin: `https://omdeshpande09012005.github.io`
- Confirm changes: `y`
- Allow IAM role creation: `y`

**Expected output (takes 2-3 minutes):**
```
Successfully created/updated stack - formbridge-stack in us-east-1

Outputs:
┌──────────────────────┬─────────────────────────────────────────┐
│ Key                  │ Value                                   │
├──────────────────────┼─────────────────────────────────────────┤
│ AnalyticsUrl         │ https://abc123.execute-api.us-east...   │
│ ApiUrl               │ https://abc123.execute-api.us-east...   │
│ FunctionArn          │ arn:aws:lambda:us-east-1:123456...      │
│ DynamoDBTable        │ contact-form-submissions                │
└──────────────────────┴─────────────────────────────────────────┘
```

**✓ TASK 1 Complete!** You now have:
- ✅ Lambda function deployed
- ✅ DynamoDB table created
- ✅ `/submit` endpoint ready
- ✅ `/analytics` endpoint ready (without API key yet)

**Important:** Save the output values (especially the endpoint URLs)

---

### TASK 2: Set Up SES Verification (2 minutes)

**What it does:**
- Verifies your email so SES can send notifications

**Step 2.1: Check SES Status**
```bash
aws ses get-account-sending-enabled --region us-east-1
```

If output shows `"Enabled": true`, skip to TASK 3.

**Step 2.2: If SES is Disabled**

If the previous command shows `"Enabled": false`, you need to request production access:

1. Go to AWS SES Console: https://console.aws.amazon.com/ses/
2. Click on "Request production access"
3. Fill in the form and submit
4. Wait for approval (usually a few hours)

Or for testing, use the **Sandbox Mode** (emails only to verified addresses):

```bash
# Verify sender email
aws ses verify-email-identity \
  --email-address omdeshpande123456789@gmail.com \
  --region us-east-1

# Verify recipient email
aws ses verify-email-identity \
  --email-address yash.dharap@mitwpu.edu.in \
  --region us-east-1
```

You'll receive verification emails - click the confirmation links.

**✓ TASK 2 Complete!** Your emails are verified and ready.

---

### TASK 3: Set Up API Key for /analytics (3 minutes)

**What it does:**
- Creates an API key for protecting the `/analytics` endpoint
- Only users with the API key can query analytics

**Step 3.1: Get API ID**
```bash
# Save your API ID
API_ID=$(aws apigateway get-rest-apis \
  --region us-east-1 \
  --query "items[?name=='FormApi'].id" \
  --output text)

echo "API ID: $API_ID"
# Output: API ID: abc123def456
```

**Step 3.2: Create Usage Plan**
```bash
USAGE_PLAN_ID=$(aws apigateway create-usage-plan \
  --name "formbridge-usage-plan" \
  --api-stages "apiId=${API_ID},stage=Prod" \
  --region us-east-1 \
  --query 'id' \
  --output text)

echo "Usage Plan ID: $USAGE_PLAN_ID"
```

**Step 3.3: Create API Key**
```bash
API_KEY_ID=$(aws apigateway create-api-key \
  --name "formbridge-analytics-key" \
  --enabled \
  --region us-east-1 \
  --query 'id' \
  --output text)

echo "API Key ID: $API_KEY_ID"
```

**Step 3.4: Get API Key Value**
```bash
API_KEY_VALUE=$(aws apigateway get-api-key \
  --api-key "$API_KEY_ID" \
  --include-value \
  --region us-east-1 \
  --query 'value' \
  --output text)

echo "API Key Value: $API_KEY_VALUE"
# Save this securely!
```

**Step 3.5: Associate Key with Usage Plan**
```bash
aws apigateway create-usage-plan-key \
  --usage-plan-id "$USAGE_PLAN_ID" \
  --key-id "$API_KEY_ID" \
  --key-type API_KEY \
  --region us-east-1
```

**Step 3.6: Enable API Key Requirement**
```bash
# Get /analytics resource ID
ANALYTICS_RESOURCE=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --region us-east-1 \
  --query "items[?path=='/analytics'].id" \
  --output text)

# Enable API key requirement
aws apigateway update-method \
  --rest-api-id "$API_ID" \
  --resource-id "$ANALYTICS_RESOURCE" \
  --http-method POST \
  --patch-operations "op=replace,path=/apiKeyRequired,value=true" \
  --region us-east-1
```

**Step 3.7: Deploy Changes**
```bash
aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name Prod \
  --region us-east-1
```

**✓ TASK 3 Complete!** Your `/analytics` endpoint now requires an API key.

---

### TASK 4: Test All Endpoints (5 minutes)

**What it does:**
- Verify both endpoints work correctly

**Step 4.1: Save Your Values**
```bash
# Replace with your actual values
SUBMIT_URL="https://abc123.execute-api.us-east-1.amazonaws.com/Prod/submit"
ANALYTICS_URL="https://abc123.execute-api.us-east-1.amazonaws.com/Prod/analytics"
API_KEY="your-api-key-value"
```

**Step 4.2: Test /submit Endpoint**
```bash
curl -X POST "$SUBMIT_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "portfolio-contact",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message from FormBridge"
  }'
```

Expected response:
```json
{"id": "550e8400-e29b-41d4-a716-446655440000"}
```

✅ **Success!** A submission was created.

Check your email - you should receive a notification email!

**Step 4.3: Test /analytics Without API Key (Should Fail)**
```bash
curl -i -X POST "$ANALYTICS_URL" \
  -H "Content-Type: application/json" \
  -d '{"form_id": "portfolio-contact"}'
```

Expected response:
```
HTTP/1.1 403 Forbidden
```

✅ **Success!** The endpoint correctly rejects requests without API key.

**Step 4.4: Test /analytics With API Key (Should Succeed)**
```bash
curl -X POST "$ANALYTICS_URL" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"form_id": "portfolio-contact"}'
```

Expected response:
```json
{
  "form_id": "portfolio-contact",
  "total_submissions": 1,
  "last_7_days": [
    {"date": "2025-11-05", "count": 1},
    {"date": "2025-11-04", "count": 0},
    ...
  ],
  "latest_id": "550e8400-e29b-41d4-a716-446655440000",
  "last_submission_ts": "2025-11-05T12:34:56.789123Z"
}
```

✅ **Success!** Analytics endpoint is working!

**✓ TASK 4 Complete!** Both endpoints are working correctly.

---

### TASK 5: Update Your Portfolio (5 minutes)

**What it does:**
- Integrates the API endpoints into your React portfolio

**Step 5.1: Open Your Contact Form Component**

Navigate to: `c:\Users\Admin\dev-projects\my-portfolio-vite\src\components\Contact.jsx`

**Step 5.2: Update the API Endpoint**

Replace the API endpoint with your actual URL:

```javascript
const SUBMIT_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/submit";

// Your form submission code
const handleSubmit = async (e) => {
  e.preventDefault();
  
  try {
    const response = await fetch(SUBMIT_URL, {
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
      // Show success message
      setSuccess(true);
      // Clear form
      setFormData({ name: '', email: '', message: '' });
    } else {
      // Show error
      setError(data.error || 'Failed to send message');
    }
  } catch (error) {
    setError('Network error: ' + error.message);
  }
};
```

**Step 5.3: Test Locally**
```bash
cd c:\Users\Admin\dev-projects\my-portfolio-vite
npm run dev
```

Go to your portfolio contact page and test the form.

**✓ TASK 5 Complete!** Your portfolio is now connected to the backend.

---

### TASK 6: Monitor & Verify (2 minutes)

**What it does:**
- Check that everything is working correctly

**Step 6.1: View Lambda Logs**
```bash
aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1
```

You should see logs from your test submissions.

**Step 6.2: Check DynamoDB**
```bash
aws dynamodb scan \
  --table-name contact-form-submissions \
  --max-items 10 \
  --region us-east-1 | jq '.Items'
```

You should see your test submission stored.

**Step 6.3: Check API Gateway Metrics**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=FormApi \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region us-east-1
```

**✓ TASK 6 Complete!** Everything is monitored and working.

---

## ✅ SUMMARY

You've successfully:

1. ✅ Deployed Lambda function with both `/submit` and `/analytics` endpoints
2. ✅ Created DynamoDB table with TTL support
3. ✅ Configured SES for email notifications
4. ✅ Set up API Gateway with API key protection
5. ✅ Tested all endpoints
6. ✅ Integrated with your portfolio
7. ✅ Verified everything is working

## 📊 Cost

Your deployment costs approximately:
- **DynamoDB:** $0.25/month (on-demand)
- **Lambda:** Free tier + $0.20/million invocations
- **SES:** Free tier + $0.10/1000 emails
- **API Gateway:** $3.50/million requests

**Total: ~$1-5/month for portfolio-level traffic**

## 🔒 Security Checklist

- ✅ API key required for `/analytics` endpoint
- ✅ CORS headers restrict to your portfolio domain only
- ✅ Email verification prevents spoofing
- ✅ Lambda function has minimal IAM permissions
- ✅ DynamoDB encrypted at rest
- ✅ CloudWatch logs for audit trail

## 📞 Troubleshooting

| Problem | Solution |
|---------|----------|
| Lambda not found | Check stack name in CloudFormation |
| Email not received | Verify email in SES; check spam folder |
| CORS error in browser | Verify FRONTEND_ORIGIN matches your domain |
| API key not working | Make sure you used `--include-value` flag |
| High costs | Check CloudWatch for unexpected traffic |

## 📚 Files Reference

- `backend/template.yaml` - SAM configuration (updated ✓)
- `backend/contact_form_lambda.py` - Lambda code (ready ✓)
- `backend/DEPLOY.md` - Detailed deployment guide
- `IMPLEMENTATION_CHECKLIST.md` - Reference checklist
- `TESTING_GUIDE.md` - Complete test cases

---

**🎉 Your FormBridge backend is now production-ready!**

