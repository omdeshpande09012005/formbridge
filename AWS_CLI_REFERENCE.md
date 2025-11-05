# FormBridge v2 - AWS CLI Quick Reference

A quick lookup guide for all AWS CLI commands used in the deployment.

---

## Configuration Reference

```bash
# Set these as variables for easy use
export REGION="ap-south-1"
export ACCOUNT_ID="864572276622"
export TABLE_NAME="contact-form-submissions"
export LAMBDA_NAME="contactFormProcessor"
export ROLE_NAME="formbridge-deploy"
export API_ID="YOUR_API_ID_HERE"
export STAGE_NAME="Prod"
export FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
export SES_SENDER="omdeshpande123456789@gmail.com"
export SES_RECIPIENTS="omdeshpande123456789@gmail.com,omdeshpande0901@gmail.com,sahil.bobhate@mitwpu.edu.in,yash.dharap@mitwpu.edu.in,om.deshpande@mitwpu.edu.in"
```

---

## DynamoDB Commands

### Check if Table Exists

```bash
aws dynamodb describe-table \
  --table-name ${TABLE_NAME} \
  --region ${REGION}
```

### Create Table (Composite Key)

```bash
aws dynamodb create-table \
  --table-name ${TABLE_NAME} \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region ${REGION}
```

### Wait for Table to be Active

```bash
aws dynamodb wait table-exists \
  --table-name ${TABLE_NAME} \
  --region ${REGION}
```

### Describe Table

```bash
aws dynamodb describe-table \
  --table-name ${TABLE_NAME} \
  --region ${REGION} \
  --query 'Table.[TableName,TableStatus,BillingModeSummary.BillingMode,ItemCount,TableSizeBytes]' \
  --output table
```

### Query Submissions by Form

```bash
aws dynamodb query \
  --table-name ${TABLE_NAME} \
  --region ${REGION} \
  --key-condition-expression "pk = :p AND begins_with(sk, :s)" \
  --expression-attribute-values \
    ':p={"S":"FORM#contact-us"}' \
    ':s={"S":"SUBMIT#"}' \
  --output json | jq '.Items[]'
```

### Scan All Items (for testing)

```bash
aws dynamodb scan \
  --table-name ${TABLE_NAME} \
  --region ${REGION} \
  --limit 10 \
  --output json | jq '.Items[]'
```

### Delete Item (use with caution)

```bash
aws dynamodb delete-item \
  --table-name ${TABLE_NAME} \
  --region ${REGION} \
  --key '{"pk":{"S":"FORM#test"},"sk":{"S":"SUBMIT#2025-11-05T00:00:00Z#uuid"}}'
```

### Delete Table

```bash
# WARNING: Deletes all data!
aws dynamodb delete-table \
  --table-name ${TABLE_NAME} \
  --region ${REGION}

# Wait for deletion
aws dynamodb wait table-not-exists \
  --table-name ${TABLE_NAME} \
  --region ${REGION}
```

---

## Lambda Commands

### Get Function Configuration

```bash
aws lambda get-function-configuration \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --output json
```

### Get Current Environment Variables

```bash
aws lambda get-function-configuration \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --query 'Environment.Variables' \
  --output json | jq '.'
```

### Update Environment Variables

```bash
aws lambda update-function-configuration \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --environment 'Variables={
    DDB_TABLE=contact-form-submissions,
    SES_SENDER=omdeshpande123456789@gmail.com,
    SES_RECIPIENTS=omdeshpande123456789@gmail.com,
    FRONTEND_ORIGIN=https://omdeshpande09012005.github.io
  }'
```

### Get Environment Variables (formatted)

```bash
aws lambda get-function-configuration \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --query 'Environment.Variables' \
  --output json | jq '.'
```

### Publish New Version

```bash
aws lambda publish-version \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --query '[Version,LastModified]' \
  --output json
```

### Invoke Function (testing)

```bash
aws lambda invoke \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --payload '{"body":"{\"message\":\"test\"}"}' \
  --output json response.json && cat response.json
```

### Get Function Role ARN

```bash
aws lambda get-function \
  --function-name ${LAMBDA_NAME} \
  --region ${REGION} \
  --query 'Configuration.Role' \
  --output text
```

### View Lambda Metrics

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=${LAMBDA_NAME} \
  --start-time 2025-11-05T00:00:00Z \
  --end-time 2025-11-06T00:00:00Z \
  --period 3600 \
  --statistics Sum \
  --region ${REGION}
```

---

## IAM Commands

### List Role Policies

```bash
aws iam list-role-policies \
  --role-name ${ROLE_NAME} \
  --region ${REGION} \
  --output table
```

### Get Specific Policy

```bash
aws iam get-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name formbridge-policy \
  --region ${REGION} \
  --output json | jq '.PolicyDocument'
```

### Attach Inline Policy

```bash
aws iam put-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name formbridge-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DynamoDBWrite",
        "Effect": "Allow",
        "Action": ["dynamodb:PutItem", "dynamodb:Query"],
        "Resource": "arn:aws:dynamodb:'${REGION}':'${ACCOUNT_ID}':table/'${TABLE_NAME}'"
      },
      {
        "Sid": "CloudWatchLogs",
        "Effect": "Allow",
        "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        "Resource": "arn:aws:logs:'${REGION}':'${ACCOUNT_ID}':log-group:/aws/lambda/'${LAMBDA_NAME}':*"
      },
      {
        "Sid": "SESEmail",
        "Effect": "Allow",
        "Action": ["ses:SendEmail", "ses:SendRawEmail"],
        "Resource": "*"
      }
    ]
  }' \
  --region ${REGION}
```

### Delete Inline Policy

```bash
aws iam delete-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name formbridge-policy \
  --region ${REGION}
```

### Get Role Details

```bash
aws iam get-role \
  --role-name ${ROLE_NAME} \
  --region ${REGION} \
  --output json
```

---

## API Gateway Commands

### Get All Resources

```bash
aws apigateway get-resources \
  --rest-api-id ${API_ID} \
  --region ${REGION} \
  --output json | jq '.items[]'
```

### Find /submit Resource ID

```bash
aws apigateway get-resources \
  --rest-api-id ${API_ID} \
  --region ${REGION} \
  --output json | jq -r '.items[] | select(.path=="/submit") | .id'
```

### Create /submit Resource

```bash
# First get root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id ${API_ID} \
  --region ${REGION} \
  --output json | jq -r '.items[] | select(.path=="/") | .id')

# Create /submit
aws apigateway create-resource \
  --rest-api-id ${API_ID} \
  --parent-id ${ROOT_ID} \
  --path-part submit \
  --region ${REGION}
```

### Create OPTIONS Method (CORS Preflight)

```bash
aws apigateway put-method \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region ${REGION}
```

### Create MOCK Integration

```bash
aws apigateway put-integration \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --type MOCK \
  --region ${REGION}
```

### Set OPTIONS Method Response Headers

```bash
aws apigateway put-method-response \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Headers=false \
    method.response.header.Access-Control-Allow-Methods=false \
    method.response.header.Access-Control-Allow-Origin=false \
  --region ${REGION}
```

### Set OPTIONS Integration Response Headers

```bash
aws apigateway put-integration-response \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Headers="'Content-Type,X-Api-Key'" \
    method.response.header.Access-Control-Allow-Methods="'OPTIONS,POST'" \
    method.response.header.Access-Control-Allow-Origin="'${FRONTEND_ORIGIN}'" \
  --region ${REGION}
```

### Set POST Method Response Headers

```bash
aws apigateway put-method-response \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method POST \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Origin=false \
  --region ${REGION}
```

### Set POST Integration Response Headers

```bash
aws apigateway put-integration-response \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method POST \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Origin="'${FRONTEND_ORIGIN}'" \
  --region ${REGION}
```

### Create Deployment

```bash
aws apigateway create-deployment \
  --rest-api-id ${API_ID} \
  --stage-name ${STAGE_NAME} \
  --region ${REGION}
```

### Get Stage Information

```bash
aws apigateway get-stage \
  --rest-api-id ${API_ID} \
  --stage-name ${STAGE_NAME} \
  --region ${REGION} \
  --output json | jq '.{StageName, LastUpdateTime, CacheClusterEnabled}'
```

### List Methods

```bash
aws apigateway get-method \
  --rest-api-id ${API_ID} \
  --resource-id ${SUBMIT_RESOURCE_ID} \
  --http-method OPTIONS \
  --region ${REGION}
```

---

## SES Commands

### List Verified Identities

```bash
aws ses list-identities \
  --identity-type EmailAddress \
  --region ${REGION} \
  --output table
```

### Verify Email Address

```bash
aws ses verify-email-identity \
  --email-address aayush.das@mitwpu.edu.in \
  --region ${REGION}
```

### Get Verification Attributes

```bash
aws ses get-identity-verification-attributes \
  --identities omdeshpande123456789@gmail.com \
  --region ${REGION} \
  --output json | jq '.'
```

### Check Sending Enabled

```bash
aws ses get-account-sending-enabled \
  --region ${REGION} \
  --output json
```

### Get Send Statistics

```bash
aws ses get-send-statistics \
  --region ${REGION} \
  --output json | jq '.SendDataPoints[]'
```

### Send Test Email

```bash
aws ses send-email \
  --from ${SES_SENDER} \
  --to test@example.com \
  --subject "Test Email" \
  --text "This is a test" \
  --region ${REGION}
```

---

## CloudWatch Logs Commands

### List Log Groups

```bash
aws logs describe-log-groups \
  --region ${REGION} \
  --output table
```

### Tail Lambda Logs (Real-time)

```bash
aws logs tail /aws/lambda/${LAMBDA_NAME} \
  --follow \
  --region ${REGION}
```

### Get Recent Log Events

```bash
aws logs tail /aws/lambda/${LAMBDA_NAME} \
  --max-items 20 \
  --region ${REGION}
```

### Filter Logs

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/${LAMBDA_NAME} \
  --filter-pattern "ERROR" \
  --region ${REGION} \
  --output json | jq '.events[]'
```

---

## CloudFormation Commands

### Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name formbridge-api \
  --region ${REGION} \
  --query 'Stacks[0].Outputs' \
  --output table
```

### Get Specific Output

```bash
aws cloudformation describe-stacks \
  --stack-name formbridge-api \
  --region ${REGION} \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

### List Stack Resources

```bash
aws cloudformation list-stack-resources \
  --stack-name formbridge-api \
  --region ${REGION} \
  --output table
```

---

## Testing & Verification

### Test API Endpoint

```bash
API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}"

curl -i -X POST "${API_URL}/submit" \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "contact-us",
    "name": "Test User",
    "email": "test@example.com",
    "message": "This is a test",
    "page": "https://omdeshpande09012005.github.io/contact"
  }'
```

### Test with API Key (if required)

```bash
curl -i -X POST "${API_URL}/submit" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{...}'
```

### Pretty Print JSON Response

```bash
curl -X POST "${API_URL}/submit" \
  -H "Content-Type: application/json" \
  -d '{"message":"test"}' 2>/dev/null | jq '.'
```

### Save Response to File

```bash
curl -X POST "${API_URL}/submit" \
  -H "Content-Type: application/json" \
  -d '{"message":"test"}' -o response.json 2>/dev/null && \
cat response.json | jq '.'
```

---

## Useful Aliases

Add these to your `.bashrc` or `.zshrc`:

```bash
# FormBridge AWS CLI shortcuts
alias fb-logs='aws logs tail /aws/lambda/contactFormProcessor --follow --region ap-south-1'
alias fb-table='aws dynamodb describe-table --table-name contact-form-submissions --region ap-south-1 --query "Table.[TableName,TableStatus,ItemCount]" --output table'
alias fb-query='aws dynamodb query --table-name contact-form-submissions --region ap-south-1 --key-condition-expression "pk = :p AND begins_with(sk, :s)" --expression-attribute-values ":p={\"S\":\"FORM#contact-us\"},\":s\"={\"S\":\"SUBMIT#\"}" --output json | jq ".Items[]"'
alias fb-identities='aws ses list-identities --identity-type EmailAddress --region ap-south-1 --output table'
alias fb-config='aws lambda get-function-configuration --function-name contactFormProcessor --region ap-south-1 --query "Environment.Variables" --output json | jq "."'
```

Usage:
```bash
fb-logs              # View Lambda logs
fb-table             # Check table status
fb-query             # Query submissions
fb-identities        # List SES identities
fb-config            # View Lambda env vars
```

---

## Common Patterns

### Extract Value from JSON Response

```bash
# Get table item count
aws dynamodb describe-table \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  --query 'Table.ItemCount' \
  --output text
```

### Conditional Logic

```bash
# Check if table exists
TABLE_EXISTS=$(aws dynamodb describe-table \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  2>/dev/null && echo "true" || echo "false")

if [ "$TABLE_EXISTS" = "true" ]; then
  echo "Table exists"
else
  echo "Table does not exist"
fi
```

### Loop Through Items

```bash
# Process all submissions
aws dynamodb query \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  --key-condition-expression "pk = :p" \
  --expression-attribute-values ':p={"S":"FORM#contact-us"}' \
  --output json | jq -r '.Items[] | .id.S' | while read id; do
  echo "Processing: $id"
done
```

---

## Debugging Tips

### Enable Verbose Output

```bash
aws dynamodb query \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  --key-condition-expression "pk = :p" \
  --expression-attribute-values ':p={"S":"FORM#contact-us"}' \
  --debug
```

### Show API Request/Response

```bash
# Add --debug flag to any command
aws ses list-identities --region ap-south-1 --debug
```

### Validate JSON Policy

```bash
# Check if policy JSON is valid
jq empty /tmp/policy.json && echo "Valid JSON" || echo "Invalid JSON"
```

### Count Items in Response

```bash
aws dynamodb scan \
  --table-name contact-form-submissions \
  --region ap-south-1 \
  --output json | jq '.Count'
```

---

This quick reference covers all the essential AWS CLI commands for FormBridge deployment and management.
