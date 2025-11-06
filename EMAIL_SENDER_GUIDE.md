# FormBridge Email Sender - Usage Guide

## Quick Start - Send Email via FormBridge API

Your FormBridge service is fully configured with AWS SES and can send emails using your `base.html` template. However, **you must first verify your sender email in AWS SES**.

### Prerequisites
- AWS SES sender email verified in ap-south-1 region
- FormBridge backend deployed and running

### Option 1: PowerShell Command

```powershell
# Set your variables
$ApiUrl = "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit"
$Payload = @{
    form_id = "email-template-test"
    name = "Om Deshpande"
    email = "om.deshpande@mitwpu.edu.in"
    message = "Testing FormBridge email template"
} | ConvertTo-Json

# Send the email
Invoke-WebRequest -Uri $ApiUrl `
    -Method POST `
    -Headers @{"Content-Type" = "application/json"} `
    -Body $Payload
```

### Option 2: Run PowerShell Script

```powershell
.\send_email_via_api.ps1
```

### Option 3: Run Batch Script (Windows)

```cmd
send_email.bat
```

### Option 4: CURL Command (if curl is installed)

```bash
curl -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "email-template-test",
    "name": "Om Deshpande",
    "email": "om.deshpande@mitwpu.edu.in",
    "message": "Testing FormBridge email template"
  }'
```

---

## How It Works

1. **Send Request**: Submit a form via FormBridge API with required fields
2. **Backend Processing**: Lambda function receives submission
3. **Email Trigger**: SES sends email with base.html template to configured recipients
4. **Database**: Submission stored in DynamoDB for analytics

### API Endpoint
- **URL**: `https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit`
- **Method**: POST
- **Content-Type**: application/json

### Required Payload Fields
```json
{
  "form_id": "your-form-name",
  "name": "Sender Name",
  "email": "sender@example.com",
  "message": "Message content"
}
```

### Optional Fields
```json
{
  "page": "https://referrer-page.com"
}
```

---

## Email Template

Your system automatically uses `email_templates/base.html` which includes:
- ✅ Professional gradient header with branding
- ✅ Form submission details formatted
- ✅ Responsive design for all devices
- ✅ Brand colors and customization options
- ✅ Call-to-action buttons
- ✅ Footer with links

---

## Troubleshooting

### 500 Error - "Not authorized to perform 'ses:SendEmail'"
**Solution**: Verify the SES sender email in AWS Console:
1. Go to AWS SES → Email Addresses
2. Verify the sender email address
3. Ensure it's in production mode (not sandbox)

### 400 Error - "Invalid JSON payload"
**Check**:
- ✅ form_id is provided
- ✅ name is provided
- ✅ email is provided and valid
- ✅ message is provided and not empty

### Email Not Received
**Check**:
1. Lambda logs in CloudWatch
2. SES verified recipients list
3. Email spam folder
4. SES bounce rate (if high, emails may be throttled)

---

## Configuration

### Current Settings
- **API Endpoint**: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod
- **Region**: ap-south-1
- **SES Sender**: omdeshpande123456789@gmail.com (⚠️ MUST be verified)
- **Database**: DynamoDB (contact-form-submissions-prod)
- **Template**: email_templates/base.html

### To Change Settings
Edit `backend/template.yaml` and redeploy:
```bash
cd backend
sam deploy
```

---

## Example - Using from Your Website

The FormBridge contact form on your website automatically sends emails:

```javascript
// From your contact.html form
const response = await fetch(
  'https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      form_id: 'website-contact',
      name: form.name.value,
      email: form.email.value,
      message: form.message.value
    })
  }
);
```

---

## Production Checklist

- [ ] SES sender email is verified
- [ ] SES exit sandbox mode (if needed)
- [ ] Recipients list configured in SSM Parameter Store
- [ ] HMAC signature enabled (optional security)
- [ ] Email template customized
- [ ] API endpoint configured in website
- [ ] Load test running successfully
- [ ] CloudWatch logs monitoring active

---

## Support

For more information:
- AWS SES Documentation: https://docs.aws.amazon.com/ses/
- FormBridge Backend: See `backend/DEPLOY.md`
- API Integration: See `docs/API_INTEGRATION.md`

