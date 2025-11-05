# 🎯 FormBridge - Copy & Paste Commands

**Complete ready-to-run commands for all 6 tasks**

---

## TASK 1: Deploy Lambda & DynamoDB

Open PowerShell at: `w:\PROJECTS\formbridge\backend`

```powershell
# Copy and paste this:
cd w:\PROJECTS\formbridge\backend
sam build
sam deploy --guided
```

**When prompted in the wizard:**
- Stack name: `formbridge-stack`
- Region: `us-east-1`
- DDBTableName: `contact-form-submissions`
- SesSender: `[your verified SES email - e.g., admin@example.com]`
- SesRecipients: `[recipient email - e.g., you@gmail.com]`
- FrontendOrigin: `https://omdeshpande09012005.github.io`
- Confirm: `y`
- IAM: `y`

---

## TASK 2: Verify SES Email

```powershell
# Check if SES is enabled
aws ses get-account-sending-enabled --region us-east-1

# If enabled, skip to Task 3
# If not, verify email:
aws ses verify-email-identity --email-address your-email@example.com --region us-east-1

# Then check your email for verification link and click it
```

---

## TASK 3: Create API Key

**Copy and paste the ENTIRE block below** (all at once):

```powershell
# Get API ID
$API_ID = aws apigateway get-rest-apis --region us-east-1 --query "items[?name=='FormApi'].id" --output text
echo "API ID: $API_ID"

# Create usage plan
$USAGE_PLAN_ID = aws apigateway create-usage-plan --name "formbridge-usage-plan" --api-stages "apiId=$API_ID,stage=Prod" --region us-east-1 --query 'id' --output text
echo "Usage Plan ID: $USAGE_PLAN_ID"

# Create API key
$API_KEY_ID = aws apigateway create-api-key --name "formbridge-analytics-key" --enabled --region us-east-1 --query 'id' --output text
echo "API Key ID: $API_KEY_ID"

# Get API key value (SAVE THIS SECURELY!)
$API_KEY_VALUE = aws apigateway get-api-key --api-key $API_KEY_ID --include-value --region us-east-1 --query 'value' --output text
echo "=== SAVE THIS API KEY VALUE ==="
echo "API Key Value: $API_KEY_VALUE"
echo "==== END OF API KEY ====="

# Associate key with usage plan
aws apigateway create-usage-plan-key --usage-plan-id $USAGE_PLAN_ID --key-id $API_KEY_ID --key-type API_KEY --region us-east-1

# Get analytics resource
$ANALYTICS_RESOURCE = aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 --query "items[?path=='/analytics'].id" --output text
echo "Analytics Resource: $ANALYTICS_RESOURCE"

# Enable API key requirement
aws apigateway update-method --rest-api-id $API_ID --resource-id $ANALYTICS_RESOURCE --http-method POST --patch-operations "op=replace,path=/apiKeyRequired,value=true" --region us-east-1

# Deploy
aws apigateway create-deployment --rest-api-id $API_ID --stage-name Prod --region us-east-1

echo "Done! API Key is now required for /analytics"
```

**Save the API_KEY_VALUE somewhere safe before continuing!**

---

## TASK 4: Test Endpoints

### Step 1: Get Your Endpoint URLs

```powershell
# Get all outputs
aws cloudformation describe-stacks --stack-name formbridge-stack --region us-east-1 --query 'Stacks[0].Outputs' --output table

# Copy the ApiUrl and AnalyticsUrl values
```

### Step 2: Set Variables

```powershell
# Replace the URLs with your actual values from above
$SUBMIT_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/submit"
$ANALYTICS_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/analytics"
$API_KEY = "YOUR_API_KEY_VALUE"
```

### Step 3: Test #1 - Submit Form

```powershell
# Copy and paste:
curl -X POST $SUBMIT_URL `
  -H "Content-Type: application/json" `
  -d '{
    "form_id": "portfolio-contact",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message from FormBridge"
  }'

# Expected: {"id": "...uuid..."}
# Check your email for notification!
```

### Step 4: Test #2 - Analytics Without Key (Should Fail)

```powershell
# Copy and paste:
curl -i -X POST $ANALYTICS_URL `
  -H "Content-Type: application/json" `
  -d '{"form_id": "portfolio-contact"}'

# Expected: 403 Forbidden (correct!)
```

### Step 5: Test #3 - Analytics With Key (Should Work)

```powershell
# Copy and paste:
curl -X POST $ANALYTICS_URL `
  -H "X-Api-Key: $API_KEY" `
  -H "Content-Type: application/json" `
  -d '{"form_id": "portfolio-contact"}'

# Expected: JSON with form statistics
```

---

## TASK 5: Update Your Portfolio

### Step 1: Open VS Code

```powershell
# Navigate to your portfolio
cd c:\Users\Admin\dev-projects\my-portfolio-vite

# Open in VS Code
code .
```

### Step 2: Find Your Contact Form

Look for: `src/components/Contact.jsx` (or similar Contact component)

### Step 3: Add This Code

At the top of your component:
```javascript
const SUBMIT_URL = "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod/submit";
```

In your form submit handler:
```javascript
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
      setSuccess(true);
      setFormData({ name: '', email: '', message: '' });
      setTimeout(() => setSuccess(false), 3000);
    } else {
      setError(data.error || 'Failed to send message');
    }
  } catch (error) {
    setError('Network error: ' + error.message);
  }
};
```

### Step 4: Test Locally

```powershell
# In portfolio directory
npm run dev

# Open http://localhost:5173
# Test the contact form
# You should receive an email!
```

---

## TASK 6: Monitor & Verify

### Check Lambda Logs

```powershell
# View live logs (press Ctrl+C to stop)
aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1
```

### Check DynamoDB

```powershell
# View stored submissions
aws dynamodb scan --table-name contact-form-submissions --max-items 10 --region us-east-1 --query 'Items' | jq '.'
```

### Check API Metrics

```powershell
# View API Gateway request count
aws cloudwatch get-metric-statistics `
  --namespace AWS/ApiGateway `
  --metric-name Count `
  --dimensions Name=ApiName,Value=FormApi `
  --start-time (Get-Date).AddHours(-1).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss') `
  --end-time (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss') `
  --period 300 `
  --statistics Sum `
  --region us-east-1 | jq '.Datapoints'
```

---

## Troubleshooting Commands

### If Deployment Fails

```powershell
# Check what went wrong
aws cloudformation describe-stack-events `
  --stack-name formbridge-stack `
  --region us-east-1 | jq '.StackEvents[] | {Time: .Timestamp, Status: .ResourceStatus, Reason: .ResourceStatusReason}'
```

### If Lambda Errors

```powershell
# View error logs
aws logs filter-log-events `
  --log-group-name /aws/lambda/contactFormProcessor `
  --filter-pattern "ERROR" `
  --region us-east-1 | jq '.events[] | {time: .timestamp, message: .message}'
```

### If Can't Find Endpoint

```powershell
# List all API resources
$API_ID = aws apigateway get-rest-apis --region us-east-1 --query "items[?name=='FormApi'].id" --output text
aws apigateway get-resources --rest-api-id $API_ID --region us-east-1 --query 'items[*].[path,id]' --output table
```

### Recreate Everything

```powershell
# Delete and redeploy
aws cloudformation delete-stack --stack-name formbridge-stack --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name formbridge-stack --region us-east-1

# Then run Task 1 again
cd w:\PROJECTS\formbridge\backend
sam build
sam deploy --guided
```

---

## One-Liner Summary

```powershell
# Everything in one command (if already deployed):
# 1. Deploy
cd w:\PROJECTS\formbridge\backend; sam build; sam deploy

# 2. Get endpoints
aws cloudformation describe-stacks --stack-name formbridge-stack --region us-east-1 --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' --output table

# 3. Monitor
aws logs tail /aws/lambda/contactFormProcessor --follow --region us-east-1
```

---

## Quick Copy Template

For your personal reference:

```
📋 MY FORMBRIDGE CONFIGURATION
═══════════════════════════════════════════════

🔗 API ID: _________________________________
🔑 API Key: _______________________________
📤 Submit URL: ____________________________
📊 Analytics URL: _________________________
⚡ Lambda ARN: ____________________________
🗄️  DynamoDB Table: ________________________

📧 SES Sender: ____________________________
✉️  Recipients: ____________________________

🌐 Frontend: https://omdeshpande09012005.github.io
🎯 Region: us-east-1
📦 Stack Name: formbridge-stack

═══════════════════════════════════════════════
```

---

## Common Copy-Paste Mistakes

❌ Don't forget to replace:
- `YOUR_API_ID` with your actual API ID
- `YOUR_API_KEY_VALUE` with your actual API key
- `your-email@example.com` with your real email

✅ Do copy entire blocks (don't split them)

---

**Ready? Start with TASK 1! Copy and paste the commands above. 🚀**

