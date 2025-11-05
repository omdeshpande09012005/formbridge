# FormBridge Lambda Testing Guide

## Overview
This guide covers testing the FormBridge contact form Lambda function with both `/submit` and `/analytics` endpoints.

---

## Prerequisites

### Local Testing Tools
- **AWS SAM CLI** (or AWS Lambda Runtime for emulation)
- **curl** or **Postman** (for HTTP requests)
- **AWS Credentials** configured (`~/.aws/credentials`)

### Environment Setup
```bash
cd backend
pip install -r requirements.txt
```

### Required Environment Variables
Set these before running tests:
```bash
export DDB_TABLE="contact-submissions-dev"
export SES_SENDER="noreply@formbridge.example.com"
export SES_RECIPIENTS="admin@example.com,team@example.com"
export FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
```

---

## Testing with SAM Local

### Start Local Lambda Emulation
```bash
cd backend
sam local start-api --port 3001
```

This starts a local API Gateway + Lambda emulator on `http://localhost:3001`.

### Test Routes
- **Submit endpoint:** `POST http://localhost:3001/submit`
- **Analytics endpoint:** `POST http://localhost:3001/analytics`

---

## Test Cases

### 1. Submit Endpoint - Valid Submission

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "This is a test message",
    "page": "https://example.com/contact"
  }'
```

**Expected Response (200):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

### 2. Submit Endpoint - Missing Required Field (name)

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "email": "john@example.com",
    "message": "Test message"
  }'
```

**Expected Response (400):**
```json
{
  "error": "name required"
}
```

---

### 3. Submit Endpoint - Invalid Email Format

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "name": "John Doe",
    "email": "invalid-email",
    "message": "Test message"
  }'
```

**Expected Response (400):**
```json
{
  "error": "invalid email format"
}
```

---

### 4. Submit Endpoint - Missing Message

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "name": "John Doe",
    "email": "john@example.com"
  }'
```

**Expected Response (400):**
```json
{
  "error": "message required"
}
```

---

### 5. Analytics Endpoint - Get Form Stats

**Request:**
```bash
curl -X POST http://localhost:3001/analytics \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form"
  }'
```

**Expected Response (200):**
```json
{
  "form_id": "contact-form",
  "total_submissions": 42,
  "last_7_days": [
    {"date": "2025-10-29", "count": 5},
    {"date": "2025-10-30", "count": 3},
    {"date": "2025-10-31", "count": 8},
    {"date": "2025-11-01", "count": 2},
    {"date": "2025-11-02", "count": 1},
    {"date": "2025-11-03", "count": 4},
    {"date": "2025-11-04", "count": 7}
  ],
  "latest_id": "550e8400-e29b-41d4-a716-446655440001",
  "last_submission_ts": "2025-11-04T18:32:15.123456Z"
}
```

---

### 6. Analytics Endpoint - Missing form_id

**Request:**
```bash
curl -X POST http://localhost:3001/analytics \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Response (400):**
```json
{
  "error": "form_id required"
}
```

---

### 7. Analytics Endpoint - Non-existent Form

**Request:**
```bash
curl -X POST http://localhost:3001/analytics \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "non-existent-form"
  }'
```

**Expected Response (200):**
```json
{
  "form_id": "non-existent-form",
  "total_submissions": 0,
  "last_7_days": [
    {"date": "2025-10-29", "count": 0},
    {"date": "2025-10-30", "count": 0},
    {"date": "2025-10-31", "count": 0},
    {"date": "2025-11-01", "count": 0},
    {"date": "2025-11-02", "count": 0},
    {"date": "2025-11-03", "count": 0},
    {"date": "2025-11-04", "count": 0}
  ],
  "latest_id": null,
  "last_submission_ts": null
}
```

---

### 8. Invalid JSON Payload

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d 'not-json'
```

**Expected Response (400):**
```json
{
  "error": "Invalid JSON payload"
}
```

---

### 9. CORS Headers Verification

**Request:**
```bash
curl -v -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","name":"John","email":"john@example.com","message":"Test"}'
```

**Expected Response Headers:**
```
Access-Control-Allow-Origin: https://omdeshpande09012005.github.io
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

---

### 10. Email Case-Insensitivity

**Request 1:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-form",
    "name": "John Doe",
    "email": "John.Doe@EXAMPLE.COM",
    "message": "Test message"
  }'
```

**Expected:** Email stored as `john.doe@example.com` (lowercase)

---

### 11. Default form_id

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test without form_id"
  }'
```

**Expected:** Submission stored with `form_id: "default"`

---

### 12. Whitespace Trimming

**Request:**
```bash
curl -X POST http://localhost:3001/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "  contact-form  ",
    "name": "  John Doe  ",
    "email": "  john@example.com  ",
    "message": "  Test message  ",
    "page": "  https://example.com  "
  }'
```

**Expected:** All fields trimmed, whitespace removed

---

## DynamoDB Item Inspection

### Query All Submissions for a Form
```bash
aws dynamodb query \
  --table-name contact-submissions-dev \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk":{"S":"FORM#contact-form"}}' \
  --region us-east-1
```

### Get Latest Submission
```bash
aws dynamodb query \
  --table-name contact-submissions-dev \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk":{"S":"FORM#contact-form"}}' \
  --scan-index-forward false \
  --limit 1 \
  --region us-east-1
```

### Check TTL Field
```bash
aws dynamodb get-item \
  --table-name contact-submissions-dev \
  --key '{"pk":{"S":"FORM#contact-form"},"sk":{"S":"SUBMIT#2025-11-04T18:32:15.123456Z#550e8400-e29b-41d4-a716-446655440001"}}' \
  --region us-east-1
```

---

## Load Testing

### Bulk Submit Requests (100 submissions)
```bash
#!/bin/bash
for i in {1..100}; do
  curl -X POST http://localhost:3001/submit \
    -H "Content-Type: application/json" \
    -d "{
      \"form_id\": \"load-test\",
      \"name\": \"Test User $i\",
      \"email\": \"user$i@example.com\",
      \"message\": \"Load test message $i\"
    }" &
done
wait
echo "100 requests sent"
```

Then query analytics:
```bash
curl -X POST http://localhost:3001/analytics \
  -H "Content-Type: application/json" \
  -d '{"form_id":"load-test"}'
```

---

## Production Testing (AWS Lambda)

### Deploy with SAM
```bash
sam deploy --guided
```

### Test Deployed Function
```bash
# Get API Gateway URL from CloudFormation stack
API_URL=$(aws cloudformation describe-stacks \
  --stack-name formbridge-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

# Test submit
curl -X POST $API_URL/submit \
  -H "Content-Type: application/json" \
  -d '{"form_id":"prod","name":"Test","email":"test@example.com","message":"Production test"}'

# Test analytics
curl -X POST $API_URL/analytics \
  -H "Content-Type: application/json" \
  -d '{"form_id":"prod"}'
```

---

## Troubleshooting

### Issue: "DynamoDB put_item failed"
**Cause:** DynamoDB table doesn't exist or credentials are wrong
**Fix:** 
```bash
# Verify table exists
aws dynamodb describe-table --table-name contact-submissions-dev

# Check credentials
aws sts get-caller-identity
```

### Issue: "SES send_email failed: MessageRejected"
**Cause:** Sender email not verified in SES
**Fix:**
```bash
# Verify sender in SES
aws ses verify-email-identity --email-address noreply@formbridge.example.com
```

### Issue: CORS Error in Browser
**Cause:** `FRONTEND_ORIGIN` doesn't match request origin
**Fix:** Update `FRONTEND_ORIGIN` env var or add domain to SES verified identities

### Issue: "Invalid JSON payload" on valid JSON
**Cause:** Content-Type header missing or incorrect
**Fix:** Add `-H "Content-Type: application/json"` to curl request

---

## Monitoring

### View Lambda Logs
```bash
sam logs -n ContactFormFunction --stack-name formbridge-stack --tail
```

### CloudWatch Insights Query
```
fields @timestamp, @message, form_id, id
| filter @message like /Stored submission/
| stats count() by form_id
```

### DynamoDB Metrics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedWriteCapacityUnits \
  --dimensions Name=TableName,Value=contact-submissions-dev \
  --start-time 2025-11-01T00:00:00Z \
  --end-time 2025-11-05T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

---

## Checklist

- [ ] All 12 test cases pass locally
- [ ] CORS headers present in responses
- [ ] DynamoDB items stored with TTL
- [ ] Email normalization working (lowercase)
- [ ] Analytics calculations correct
- [ ] Error messages clear and actionable
- [ ] Load test (100+ requests) handles pagination correctly
- [ ] No sensitive data in logs
- [ ] Deployed to AWS and tested
- [ ] SES emails delivered successfully

