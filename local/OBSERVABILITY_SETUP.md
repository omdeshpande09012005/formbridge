# FormBridge Observability & Alerts Setup

Comprehensive CloudWatch alarms and SNS notifications for the FormBridge stack. Creates alerts for Lambda errors, API Gateway 5XX responses, DynamoDB throttling, and SES bounce/complaint events.

## Overview

The `setup-observability.sh` script creates:

- **3 SNS Topics**: Alerts, SES Bounce, SES Complaint
- **5 CloudWatch Alarms**: Lambda errors (2 types), API Gateway 5XX, DynamoDB read/write throttling
- **1 Log Metric Filter**: Lambda error log messages
- **Email Subscriptions**: Alert email subscribed to all topics
- **SES Integration**: Bounce and complaint topics attached to verified sender

## Quick Start

### 1. Set Configuration Variables

Edit the script or pass environment variables:

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
```

### 2. Run the Setup Script

```bash
bash local/scripts/setup-observability.sh
```

### 3. Confirm Email Subscriptions

Check your email for subscription confirmation links from SNS and click to confirm.

## What Gets Created

### SNS Topics

| Topic | Purpose | Subscribers |
|-------|---------|-------------|
| `${PROJECT_TAG}-alerts` | General alerts | ALERT_EMAIL |
| `${PROJECT_TAG}-ses-bounce` | Email bounce events | ALERT_EMAIL |
| `${PROJECT_TAG}-ses-complaint` | Email complaint events | ALERT_EMAIL |

### CloudWatch Alarms

#### Lambda Errors

- **`${PROJECT_TAG}-${LAMBDA_NAME}-Errors`**
  - Metric: `Errors` (AWS/Lambda namespace)
  - Threshold: >= 1 error in 5 minutes
  - Action: Publish to alerts SNS topic

- **`${PROJECT_TAG}-${LAMBDA_NAME}-LogErrors`**
  - Metric: `${ALARM_NAMESPACE}/LambdaErrorLogCount` (custom metric from log filter)
  - Pattern: `?ERROR ?Error ?Exception` (catches ERROR, Error, Exception keywords)
  - Threshold: >= 1 match in 5 minutes
  - Action: Publish to alerts SNS topic

#### API Gateway 5XX

- **`${PROJECT_TAG}-${API_ID}-${STAGE_NAME}-5XX`**
  - Metric: `5XXError` (AWS/ApiGateway namespace)
  - Dimensions: `ApiName=${API_ID}`, `Stage=${STAGE_NAME}`
  - Threshold: >= 1 error in 5 minutes
  - Action: Publish to alerts SNS topic

#### DynamoDB Throttling

- **`${PROJECT_TAG}-${DDB_TABLE}-ReadThrottle`**
  - Metric: `ReadThrottleEvents` (AWS/DynamoDB namespace)
  - Threshold: >= 1 event in 5 minutes
  - Action: Publish to alerts SNS topic

- **`${PROJECT_TAG}-${DDB_TABLE}-WriteThrottle`**
  - Metric: `WriteThrottleEvents` (AWS/DynamoDB namespace)
  - Threshold: >= 1 event in 5 minutes
  - Action: Publish to alerts SNS topic

### Log Metric Filters

- **`${PROJECT_TAG}-${LAMBDA_NAME}-ErrorFilter`**
  - Log Group: `/aws/lambda/${LAMBDA_NAME}`
  - Pattern: `?ERROR ?Error ?Exception`
  - Metric: `${ALARM_NAMESPACE}/LambdaErrorLogCount`

## Idempotency

The script is fully idempotent and safe to run multiple times:

- Checks if SNS topic exists before creating
- Checks if email subscription exists before adding
- Checks if alarm exists before creating
- Checks if log metric filter exists before creating
- Reuses existing resources if found

## Threshold Configuration

Modify these variables in the script to adjust alarm sensitivity:

```bash
# Lambda errors
LAMBDA_ERROR_THRESHOLD=1              # errors to trigger alarm
LAMBDA_ERROR_PERIOD=300               # seconds (5 minutes)

# API Gateway 5XX
APIGW_5XX_THRESHOLD=1                 # errors to trigger alarm
APIGW_5XX_PERIOD=300                  # seconds

# DynamoDB throttling
DDB_THROTTLE_THRESHOLD=1              # events to trigger alarm
DDB_THROTTLE_PERIOD=300               # seconds
```

## Testing Alarms

### Test Lambda Error Alarm

Invoke the Lambda with invalid input to trigger an error:

```bash
aws lambda invoke \
  --function-name contactFormProcessor \
  --region us-east-1 \
  --payload '{"invalid": true}' \
  /tmp/response.json

# Check error in response
cat /tmp/response.json
```

### Test API Gateway 5XX

Send malformed request to trigger a 500 error:

```bash
# Missing closing brace - will cause JSON parse error
curl -X POST https://12mse3zde5.execute-api.us-east-1.amazonaws.com/Prod/submit \
  -H 'Content-Type: application/json' \
  -d '{"form_id": "test", "invalid": json'
```

### Monitor Alarm State

CloudWatch takes 1-5 minutes to aggregate metrics. Check alarm state:

```bash
aws cloudwatch describe-alarms \
  --alarm-names "FormBridge-contactFormProcessor-Errors" \
  --region us-east-1 \
  --query 'Alarms[0].{Name:AlarmName,State:StateValue}' \
  --output table
```

### View Lambda Logs

Check CloudWatch logs for errors in real-time:

```bash
aws logs tail /aws/lambda/contactFormProcessor \
  --region us-east-1 \
  --follow
```

## Verification Commands

### List All Alarms

```bash
aws cloudwatch describe-alarms \
  --region us-east-1 \
  --query 'Alarms[?Tags[?Key==`Project` && Value==`FormBridge`]].{Name:AlarmName,State:StateValue,Threshold:Threshold,MetricName:MetricName}' \
  --output table
```

### Check SNS Topic Subscriptions

```bash
# Get topic ARN first
TOPIC_ARN=$(aws sns list-topics --region us-east-1 --query "Topics[?TopicArn | contains('FormBridge-alerts')].TopicArn" --output text)

# List subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn "$TOPIC_ARN" \
  --region us-east-1 \
  --query 'Subscriptions[].{Endpoint:Endpoint,Status:SubscriptionArn}' \
  --output table
```

### View Log Metric Filters

```bash
aws logs describe-metric-filters \
  --log-group-name /aws/lambda/contactFormProcessor \
  --region us-east-1 \
  --query 'MetricFilters[].{Name:filterName,Pattern:filterPattern,Metric:metricTransformations[0].metricName}' \
  --output table
```

### Check Metric Data

```bash
# Check Lambda error metrics
aws cloudwatch get-metric-statistics \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --dimensions Name=FunctionName,Value=contactFormProcessor \
  --start-time 2025-11-01T00:00:00Z \
  --end-time 2025-11-05T23:59:59Z \
  --period 300 \
  --statistics Sum \
  --region us-east-1 \
  --query 'Datapoints | sort_by(@, &Timestamp) | reverse(@)' \
  --output table
```

## Troubleshooting

### Alarms Not Firing

1. **Email not confirmed**: Check your inbox for SNS subscription confirmation links
2. **No metrics yet**: Wait 5 minutes for CloudWatch to aggregate data
3. **Threshold too high**: Lower the threshold or trigger more errors
4. **Wrong dimensions**: Verify Lambda name, API ID, stage, and table name match

### Email Not Received

1. **Check SES sending limit**: Make sure account isn't in SES sandbox
2. **Verify email identity**: Ensure sender email is verified in SES
3. **Check spam folder**: SNS emails might go to spam
4. **Unsubscribe status**: Verify subscription isn't in "PendingConfirmation"

### Log Metric Filter Not Working

1. **Log group doesn't exist**: Create at least one Lambda invocation to create the log group
2. **Pattern too specific**: Verify error pattern `?ERROR ?Error ?Exception` matches your log format
3. **No matching logs**: Ensure Lambda is actually logging those keywords

## Updating Thresholds

To change alarm thresholds after creation:

```bash
# Edit the script variables and run again
# The script will update existing alarms
aws cloudwatch put-metric-alarm \
  --alarm-name FormBridge-contactFormProcessor-Errors \
  --threshold 5 \
  --region us-east-1 \
  # ... other parameters
```

## Cost Implications

### No Additional Charges For:
- SNS topics (topics themselves are free, subscription is free)
- Email subscriptions
- CloudWatch alarms (up to 10 free per month)
- Custom metrics from logs (logs are already stored)

### Potential Charges:
- SNS email notifications (if high volume)
- CloudWatch Logs storage (already paid for by Lambda)
- CloudWatch custom metrics beyond free tier

## Tags Applied

All created resources are tagged with:
- `Project: ${PROJECT_TAG}` (e.g., FormBridge)
- `Env: Prod`

Use these tags to organize and track resources in AWS billing.

## Next Steps

1. **Run the script**: `bash local/scripts/setup-observability.sh`
2. **Confirm emails**: Check inbox and click subscription links
3. **Test alarms**: Invoke Lambda with bad input
4. **Monitor dashboard**: Use AWS CloudWatch console to watch alarms
5. **Adjust thresholds**: If alarms are too noisy, increase thresholds

---

**Script Location**: `local/scripts/setup-observability.sh`  
**Lines**: 404  
**Idempotent**: Yes  
**Requires**: AWS CLI configured with credentials

