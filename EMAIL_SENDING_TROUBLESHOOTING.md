# Troubleshooting Email Sending Issue

## Problem Summary
- ✅ Form submissions are being saved to DynamoDB
- ❌ Emails are NOT being sent (even though the submission succeeds)
- The Lambda function has the correct environment variables set

## Environment Variables Verified ✅
```
SES_SENDER: omdeshpande123456789@gmail.com ✅
SES_RECIPIENTS: om.deshpande@mitwpu.edu.in ✅
DDB_TABLE: contact-form-submissions-prod ✅
FORM_CONFIG_TABLE: formbridge-config-prod ✅
STAGE: prod ✅
FRONTEND_ORIGIN: https://omdeshpande09012005.github.io/formbridge/ ✅
```

## Hypothesis
The Lambda function's `load_config()` function is trying to:
1. First, fetch from SSM Parameter Store (`/formbridge/prod/ses/recipients`)
2. Fallback to environment variable `SES_RECIPIENTS`

But the SSM call might be **failing silently** and returning `None`, so the recipients list becomes empty.

## Tests to Run

### Test 1: Direct Lambda Invocation with Test Event
```powershell
$testEvent = @{
    body = '{"form_id":"contact-us","name":"Test","email":"test@example.com","message":"Test"}'
    headers = @{"Content-Type"="application/json"}
} | ConvertTo-Json

aws lambda invoke `
    --function-name contactFormProcessor `
    --region ap-south-1 `
    --profile formbridge-deploy `
    --payload $testEvent `
    --log-type Tail `
    --query 'LogResult' `
    /tmp/lambda-output.json
```

### Test 2: Check SSM Parameter Access
```powershell
aws ssm get-parameter `
    --name "/formbridge/prod/ses/recipients" `
    --region ap-south-1 `
    --profile formbridge-deploy `
    --output json
```

If the parameter doesn't exist, the Lambda might not be falling back correctly.

### Test 3: Add recipients to SSM
```powershell
aws ssm put-parameter `
    --name "/formbridge/prod/ses/recipients" `
    --value "om.deshpande@mitwpu.edu.in" `
    --type "String" `
    --overwrite `
    --region ap-south-1 `
    --profile formbridge-deploy
```

## Root Cause Analysis
The issue is likely in the `load_config()` function. Let's check line 30-100 in `contact_form_lambda.py`:

The function tries to call:
```python
ses_recipients_str = get_param(
    f"/formbridge/{STAGE}/ses/recipients",
    decrypt=False,
    fallback_env="SES_RECIPIENTS"
) or os.environ.get("SES_RECIPIENTS", "")
```

If `get_param()` is returning `None` instead of falling back to the environment variable, then recipients will be empty.

## Solution Options

### Option A: Debug Mode (Add CloudWatch Logs)
1. Modify `contact_form_lambda.py` to add detailed logging
2. Redeploy with `sam build && sam deploy`
3. Check CloudWatch logs for the actual config being used

### Option B: Quick Fix (Remove SSM Dependency)
Modify the `load_config()` function to:
```python
ses_recipients_str = os.environ.get("SES_RECIPIENTS", "")  # Use env var directly
```

### Option C: Populate SSM Parameters
1. Add the SES recipients to SSM Parameter Store
2. Ensure IAM role can access SSM

## Next Steps
1. **Test SSM access** first to see if parameter exists
2. If parameter doesn't exist, add it to SSM
3. If that doesn't work, check the `get_param()` function implementation
4. If `get_param()` is broken, use the env var directly

## Email Sending Logic
Looking at `contact_form_lambda.py` lines 920-999:

```python
configured_recipients = form_config.get("recipients", global_config.get("recipients", []))
...
email_sent = False
if configured_recipients and SES_SENDER:
    email_sent = send_email(...)
    if not email_sent:
        print(f"Warning: Email notification failed for submission {submission_id}")
else:
    print("Email not configured (missing SES_SENDER or recipients for this form)")
```

**The condition is:** `if configured_recipients and SES_SENDER:`

- ✅ `SES_SENDER` is set: "omdeshpande123456789@gmail.com"
- ❓ `configured_recipients` = ?

If `configured_recipients` is an empty list `[]`, the email won't be sent!

## Commands to Fix

### 1. Check SSM Parameter
```powershell
aws ssm get-parameter --name "/formbridge/prod/ses/recipients" --region ap-south-1 --profile formbridge-deploy --output json
```

### 2. Add SSM Parameter (if missing)
```powershell
aws ssm put-parameter `
    --name "/formbridge/prod/ses/recipients" `
    --value "om.deshpande@mitwpu.edu.in" `
    --type "String" `
    --overwrite `
    --region ap-south-1 `
    --profile formbridge-deploy
```

### 3. Verify Environment Variable
```powershell
aws lambda get-function-configuration --function-name contactFormProcessor --region ap-south-1 --profile formbridge-deploy --query 'Environment.Variables.SES_RECIPIENTS'
```

### 4. Check Lambda Logs
```powershell
aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1 --profile formbridge-deploy
```

## Fix Applied (if SSM is the issue)
Add this SSM parameter:
```bash
Name: /formbridge/prod/ses/recipients
Value: om.deshpande@mitwpu.edu.in
Type: String
```

Then redeploy:
```powershell
cd backend
sam build
sam deploy --stack-name formbridge-stack --capabilities CAPABILITY_IAM --no-confirm-changeset
```

Test again with:
```powershell
.\send_email_via_api.ps1 -Sender "omdeshpande123456789@gmail.com" -Recipient "om.deshpande@mitwpu.edu.in"
```
