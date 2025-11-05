# Observability Script - Placeholder Reference

## ALL-CAPS Placeholders in setup-observability.sh

Replace these with your actual values before running:

### AWS Configuration

```bash
REGION="us-east-1"                              # AWS region
ACCOUNT_ID="123456789012"                       # Your AWS account ID
LAMBDA_NAME="contactFormProcessor"              # Lambda function name
API_ID="12mse3zde5"                             # API Gateway REST API ID
STAGE_NAME="Prod"                               # API Gateway stage name
DDB_TABLE="contact-form-submissions"            # DynamoDB table name
SES_IDENTITY="noreply@example.com"              # Verified SES sender email
```

### Alert Configuration

```bash
ALERT_EMAIL="admin@example.com"                 # Email to receive alerts
PROJECT_TAG="FormBridge"                        # Project name (for resource naming)
ALARM_NAMESPACE="FormBridge/Prod"               # Custom metric namespace
```

---

## Alarm Thresholds (Easy to Tweak)

```bash
LAMBDA_ERROR_THRESHOLD=1                        # Errors to trigger alarm
LAMBDA_ERROR_PERIOD=300                         # Period in seconds (5 min)

APIGW_5XX_THRESHOLD=1                           # 5XX errors to trigger
APIGW_5XX_PERIOD=300                            # Period in seconds

DDB_THROTTLE_THRESHOLD=1                        # Throttle events to trigger
DDB_THROTTLE_PERIOD=300                         # Period in seconds
```

---

## How to Find These Values

### REGION
```bash
# Your AWS region (e.g., us-east-1, ap-south-1)
aws configure get region
```

### ACCOUNT_ID
```bash
aws sts get-caller-identity --query Account --output text
```

### LAMBDA_NAME
```bash
# List all Lambda functions
aws lambda list-functions --query 'Functions[].FunctionName' --output table
```

### API_ID
```bash
# List all REST APIs
aws apigateway get-rest-apis --query 'items[].{Name:name,Id:id}' --output table
```

### STAGE_NAME
```bash
# List stages for a specific API
aws apigateway get-stages --rest-api-id 12mse3zde5 --query 'item[].stageName' --output table
```

### DDB_TABLE
```bash
# List all DynamoDB tables
aws dynamodb list-tables --query 'TableNames' --output table
```

### SES_IDENTITY
```bash
# List verified SES identities
aws ses list-verified-email-addresses --query 'VerifiedEmailAddresses' --output table
```

---

## Environment Variables Method

Instead of editing the script, pass variables when running:

```bash
export REGION="us-east-1"
export ACCOUNT_ID="123456789012"
export LAMBDA_NAME="contactFormProcessor"
export API_ID="12mse3zde5"
export STAGE_NAME="Prod"
export DDB_TABLE="contact-form-submissions"
export SES_IDENTITY="noreply@example.com"
export ALERT_EMAIL="admin@example.com"
export PROJECT_TAG="FormBridge"
export ALARM_NAMESPACE="FormBridge/Prod"

bash local/scripts/setup-observability.sh
```

---

## Quick Copy-Paste Setup

### Step 1: Get Your Values

```bash
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_NAME="contactFormProcessor"  # Update with your Lambda name
API_ID="12mse3zde5"                 # Update with your API ID
STAGE_NAME="Prod"                   # Update with your stage
DDB_TABLE="contact-form-submissions" # Update with your table
SES_IDENTITY="noreply@example.com"  # Update with your verified email
ALERT_EMAIL="admin@example.com"     # Your alert email
PROJECT_TAG="FormBridge"            # Your project name
ALARM_NAMESPACE="FormBridge/Prod"   # Your alarm namespace
```

### Step 2: Export and Run

```bash
export REGION ACCOUNT_ID LAMBDA_NAME API_ID STAGE_NAME DDB_TABLE SES_IDENTITY ALERT_EMAIL PROJECT_TAG ALARM_NAMESPACE
bash local/scripts/setup-observability.sh
```

---

## Verification: Check Created Resources

### SNS Topics
```bash
aws sns list-topics --query 'Topics[?TopicArn | contains("FormBridge")].TopicArn' --output table
```

### CloudWatch Alarms
```bash
aws cloudwatch describe-alarms --query 'Alarms[?Tags[?Key==`Project` && Value==`FormBridge`]].AlarmName' --output table
```

### Log Metric Filters
```bash
aws logs describe-metric-filters --log-group-name /aws/lambda/contactFormProcessor --query 'MetricFilters[].filterName' --output table
```

---

## Testing: Fire Alarms

### Test Lambda Error Alarm
```bash
aws lambda invoke \
  --function-name $LAMBDA_NAME \
  --region $REGION \
  --payload '{"error": true}' \
  /tmp/response.json

# Check result
cat /tmp/response.json
```

### Test API Gateway 5XX
```bash
# Send malformed JSON to trigger 5XX
curl -X POST https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/submit \
  -H 'Content-Type: application/json' \
  -d '{"incomplete": json'
```

### Watch Alarm State
```bash
aws cloudwatch describe-alarms \
  --alarm-names "${PROJECT_TAG}-${LAMBDA_NAME}-Errors" \
  --region $REGION \
  --query 'Alarms[0].{Name:AlarmName,State:StateValue}' \
  --output table
```

---

## Troubleshooting: Invalid Values

### Wrong Lambda Name
```bash
# Error: Lambda function not found
# Fix: Get correct name
aws lambda list-functions --query 'Functions[].FunctionName'
```

### Wrong API ID
```bash
# Error: API Gateway not found
# Fix: Get correct ID
aws apigateway get-rest-apis --query 'items[].[name,id]' --output table
```

### Wrong Region
```bash
# Error: Invalid region
# Fix: Use valid region
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

### SES Identity Not Verified
```bash
# Error: Email identity not verified
# Fix: Verify first
aws ses verify-email-identity --email-address noreply@example.com --region $REGION
```

---

## For FormBridge (Default Values)

Most common setup (adjust as needed):

```bash
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_NAME="contactFormProcessor"
API_ID="12mse3zde5"
STAGE_NAME="Prod"
DDB_TABLE="contact-form-submissions"
SES_IDENTITY="noreply@formbridge.example.com"
ALERT_EMAIL="admin@omdeshpande.com"
PROJECT_TAG="FormBridge"
ALARM_NAMESPACE="FormBridge/Prod"
```

---

**Note:** All placeholders are in ALL-CAPS for easy find-and-replace in the script.

