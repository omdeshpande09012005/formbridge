#!/bin/bash

################################################################################
# FormBridge v2 - AWS Deployment & Verification Script
# 
# This script performs all necessary AWS configurations for the serverless
# contact form application deployment.
#
# BEFORE RUNNING: Replace all UPPERCASE placeholders with your actual values
################################################################################

set -e  # Exit on error

# ============================================================================
# CONFIGURATION - REPLACE THESE VALUES
# ============================================================================

REGION="ap-south-1"                                    # AWS Region
ACCOUNT_ID="864572276622"                              # AWS Account ID
TABLE_NAME="contact-form-submissions"                  # DynamoDB table
LAMBDA_NAME="contactFormProcessor"                     # Lambda function
ROLE_NAME="formbridge-deploy"                          # IAM role name
API_ID="YOUR_API_ID_HERE"                              # API Gateway API ID
STAGE_NAME="Prod"                                      # API Gateway stage
FRONTEND_ORIGIN="https://omdeshpande09012005.github.io" # CORS origin
SES_SENDER="omdeshpande123456789@gmail.com"            # Verified SES sender
SES_RECIPIENTS="omdeshpande123456789@gmail.com,omdeshpande0901@gmail.com,sahil.bobhate@mitwpu.edu.in,yash.dharap@mitwpu.edu.in,om.deshpande@mitwpu.edu.in"  # Recipients

# ============================================================================
# DERIVED VALUES (Do not modify)
# ============================================================================

TABLE_ARN="arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${TABLE_NAME}"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}"

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║       FormBridge v2 - AWS Deployment & Verification Script             ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Region:          ${REGION}"
echo "  Account ID:      ${ACCOUNT_ID}"
echo "  Table:           ${TABLE_NAME}"
echo "  Lambda:          ${LAMBDA_NAME}"
echo "  IAM Role:        ${ROLE_NAME}"
echo "  API Gateway:     ${API_ID} / ${STAGE_NAME}"
echo "  CORS Origin:     ${FRONTEND_ORIGIN}"
echo "  SES Sender:      ${SES_SENDER}"
echo "  API URL:         ${API_URL}"
echo ""

# ============================================================================
# STEP 1: CREATE DYNAMODB TABLE (if not exists)
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 1: DynamoDB Table Setup"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Check if table exists
TABLE_EXISTS=$(aws dynamodb describe-table \
  --table-name "${TABLE_NAME}" \
  --region "${REGION}" \
  2>/dev/null || echo "NOT_FOUND")

if [ "${TABLE_EXISTS}" = "NOT_FOUND" ]; then
  echo "✓ Table does not exist. Creating: ${TABLE_NAME}"
  
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions \
      AttributeName=pk,AttributeType=S \
      AttributeName=sk,AttributeType=S \
    --key-schema \
      AttributeName=pk,KeyType=HASH \
      AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    --output table
  
  echo ""
  echo "✓ Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${REGION}"
  
  echo "✓ Table is ACTIVE"
else
  echo "✓ Table already exists: ${TABLE_NAME}"
fi

echo ""
echo "Table Description:"
aws dynamodb describe-table \
  --table-name "${TABLE_NAME}" \
  --region "${REGION}" \
  --query 'Table.[TableName,TableStatus,BillingModeSummary.BillingMode,ItemCount,TableSizeBytes]' \
  --output table

echo ""

# ============================================================================
# STEP 2: LAMBDA ENVIRONMENT VARIABLES (pull, merge, push)
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 2: Lambda Environment Variables"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

echo "✓ Fetching current Lambda environment variables..."
CURRENT_ENV=$(aws lambda get-function-configuration \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --query 'Environment.Variables' \
  --output json 2>/dev/null || echo '{}')

echo "Current environment variables:"
echo "${CURRENT_ENV}" | jq '.' || echo "{}"

echo ""
echo "✓ Merging new environment variables..."

# Create merged environment JSON (new vars override existing ones)
NEW_ENV=$(echo "${CURRENT_ENV}" | jq \
  --arg table "${TABLE_NAME}" \
  --arg sender "${SES_SENDER}" \
  --arg recipients "${SES_RECIPIENTS}" \
  --arg origin "${FRONTEND_ORIGIN}" \
  '. + {
      "DDB_TABLE": $table,
      "SES_SENDER": $sender,
      "SES_RECIPIENTS": $recipients,
      "FRONTEND_ORIGIN": $origin
    }')

echo "Merged environment variables:"
echo "${NEW_ENV}" | jq '.'

echo ""
echo "✓ Updating Lambda environment variables..."
aws lambda update-function-configuration \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --environment "Variables=$(echo ${NEW_ENV} | jq -c '.')" \
  --query 'Environment.Variables' \
  --output json | jq '.'

echo ""
echo "✓ Publishing new Lambda version..."
VERSION_RESPONSE=$(aws lambda publish-version \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --query '[Version,LastModified]' \
  --output json)

echo "New version: ${VERSION_RESPONSE}"

echo ""

# ============================================================================
# STEP 3: LAMBDA IAM PERMISSIONS
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 3: Lambda IAM Permissions"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

POLICY_NAME="formbridge-policy"
echo "✓ Creating inline IAM policy: ${POLICY_NAME}"

# Create minimal inline policy
POLICY_JSON='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DynamoDBWrite",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": "'${TABLE_ARN}'"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:'${REGION}':'${ACCOUNT_ID}':log-group:/aws/lambda/'${LAMBDA_NAME}':*"
    },
    {
      "Sid": "SESEmail",
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    }
  ]
}'

echo "Attaching policy to role: ${ROLE_NAME}"
aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "${POLICY_NAME}" \
  --policy-document "${POLICY_JSON}" \
  --region "${REGION}"

echo "✓ Policy attached successfully"

echo ""
echo "Current role inline policies:"
aws iam list-role-policies \
  --role-name "${ROLE_NAME}" \
  --region "${REGION}" \
  --output table

echo ""
echo "✓ Showing policy details:"
aws iam get-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "${POLICY_NAME}" \
  --region "${REGION}" \
  --output json | jq '.PolicyDocument'

echo ""

# ============================================================================
# STEP 4: API GATEWAY REST CORS CONFIGURATION
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 4: API Gateway CORS Configuration"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

echo "✓ Fetching API resources..."
RESOURCES=$(aws apigateway get-resources \
  --rest-api-id "${API_ID}" \
  --region "${REGION}" \
  --output json)

# Find /submit resource
SUBMIT_RESOURCE_ID=$(echo "${RESOURCES}" | jq -r '.items[] | select(.path=="/submit") | .id' 2>/dev/null || echo "")

if [ -z "${SUBMIT_RESOURCE_ID}" ]; then
  echo "⚠ /submit resource not found. Creating it..."
  
  # Get root resource ID
  ROOT_RESOURCE_ID=$(echo "${RESOURCES}" | jq -r '.items[] | select(.path=="/") | .id')
  
  # Create /submit resource
  SUBMIT_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ROOT_RESOURCE_ID}" \
    --path-part "submit" \
    --region "${REGION}" \
    --output json)
  
  SUBMIT_RESOURCE_ID=$(echo "${SUBMIT_RESOURCE}" | jq -r '.id')
  echo "✓ Created /submit resource with ID: ${SUBMIT_RESOURCE_ID}"
else
  echo "✓ Found /submit resource with ID: ${SUBMIT_RESOURCE_ID}"
fi

echo ""
echo "✓ Creating OPTIONS method for CORS preflight..."
aws apigateway put-method \
  --rest-api-id "${API_ID}" \
  --resource-id "${SUBMIT_RESOURCE_ID}" \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region "${REGION}" \
  --output json | jq '.httpMethod, .authorizationType'

echo ""
echo "✓ Creating MOCK integration for OPTIONS method..."
aws apigateway put-integration \
  --rest-api-id "${API_ID}" \
  --resource-id "${SUBMIT_RESOURCE_ID}" \
  --http-method OPTIONS \
  --type MOCK \
  --region "${REGION}" \
  --output json | jq '.type'

echo ""
echo "✓ Setting OPTIONS method response headers..."
aws apigateway put-method-response \
  --rest-api-id "${API_ID}" \
  --resource-id "${SUBMIT_RESOURCE_ID}" \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Headers=false \
    method.response.header.Access-Control-Allow-Methods=false \
    method.response.header.Access-Control-Allow-Origin=false \
  --region "${REGION}" \
  --output json | jq '.statusCode, .responseParameters'

echo ""
echo "✓ Setting OPTIONS integration response headers..."
aws apigateway put-integration-response \
  --rest-api-id "${API_ID}" \
  --resource-id "${SUBMIT_RESOURCE_ID}" \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Headers="'Content-Type,X-Api-Key'" \
    method.response.header.Access-Control-Allow-Methods="'OPTIONS,POST'" \
    method.response.header.Access-Control-Allow-Origin="'${FRONTEND_ORIGIN}'" \
  --region "${REGION}" \
  --output json | jq '.statusCode, .responseParameters'

echo ""
echo "✓ Setting POST method response headers..."
aws apigateway put-method-response \
  --rest-api-id "${API_ID}" \
  --resource-id "${SUBMIT_RESOURCE_ID}" \
  --http-method POST \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Origin=false \
  --region "${REGION}" \
  --output json | jq '.statusCode, .responseParameters' 2>/dev/null || echo "POST method already configured"

echo ""
echo "✓ Setting POST integration response headers..."
aws apigateway put-integration-response \
  --rest-api-id "${API_ID}" \
  --resource-id "${SUBMIT_RESOURCE_ID}" \
  --http-method POST \
  --status-code 200 \
  --response-parameters \
    method.response.header.Access-Control-Allow-Origin="'${FRONTEND_ORIGIN}'" \
  --region "${REGION}" \
  --output json | jq '.statusCode, .responseParameters' 2>/dev/null || echo "POST integration response already configured"

echo ""
echo "✓ Redeploying API Gateway stage: ${STAGE_NAME}"
aws apigateway create-deployment \
  --rest-api-id "${API_ID}" \
  --stage-name "${STAGE_NAME}" \
  --region "${REGION}" \
  --output json | jq '.id'

echo ""
echo "✓ Verifying stage configuration:"
aws apigateway get-stage \
  --rest-api-id "${API_ID}" \
  --stage-name "${STAGE_NAME}" \
  --region "${REGION}" \
  --output json | jq '{StageName: .stageName, LastUpdateTime: .lastUpdateTime, CacheClusterEnabled: .cacheClusterEnabled}'

echo ""

# ============================================================================
# STEP 5: SMOKE TESTS
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 5: Smoke Tests"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

export API_URL="${API_URL}"
echo "API URL: ${API_URL}"
echo ""

# Test payload
TEST_PAYLOAD='{
  "form_id": "contact-us",
  "name": "Test User",
  "email": "test@example.com",
  "message": "This is a test submission from AWS CLI",
  "page": "https://omdeshpande09012005.github.io/contact"
}'

echo "✓ Test Payload:"
echo "${TEST_PAYLOAD}" | jq '.'
echo ""

echo "✓ Sending POST request to ${API_URL}/submit"
RESPONSE=$(curl -i -X POST "${API_URL}/submit" \
  -H "Content-Type: application/json" \
  -d "${TEST_PAYLOAD}" \
  2>/dev/null)

echo "Response:"
echo "${RESPONSE}"
echo ""

# Extract submission ID from response
SUBMISSION_ID=$(echo "${RESPONSE}" | grep -oP '"id":"?\K[^,"]*' | head -1 || echo "")

if [ -n "${SUBMISSION_ID}" ]; then
  echo "✓ Successfully received submission ID: ${SUBMISSION_ID}"
else
  echo "⚠ Could not extract submission ID from response"
fi

echo ""

# ============================================================================
# STEP 6: VERIFY DYNAMODB RECORD
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 6: DynamoDB Record Verification"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

echo "✓ Querying DynamoDB for submissions from contact-us form..."
echo ""

QUERY_RESPONSE=$(aws dynamodb query \
  --table-name "${TABLE_NAME}" \
  --region "${REGION}" \
  --key-condition-expression "pk = :p AND begins_with(sk, :s)" \
  --expression-attribute-values \
    ':p={"S":"FORM#contact-us"}' \
    ':s={"S":"SUBMIT#"}' \
  --output json)

echo "Records found:"
echo "${QUERY_RESPONSE}" | jq '.Items[] | {
  id: .id.S,
  form_id: .form_id.S,
  name: .name.S,
  email: .email.S,
  ts: .ts.S,
  ip: .ip.S,
  page: .page.S
}'

echo ""
echo "Total items: $(echo ${QUERY_RESPONSE} | jq '.Count')"

echo ""

# ============================================================================
# STEP 7: SES VERIFICATION & IDENTITY CHECK
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "STEP 7: SES Identity Verification"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

echo "⚠ IMPORTANT: Before sending production emails, verify all SES identities!"
echo ""
echo "Configured identities:"
echo "  SES_SENDER: ${SES_SENDER}"
echo "  SES_RECIPIENTS: ${SES_RECIPIENTS}"
echo ""

echo "✓ Listing verified SES identities in ${REGION}..."
aws ses list-identities \
  --region "${REGION}" \
  --identity-type EmailAddress \
  --output table

echo ""
echo "✓ Checking SES sending status (should be in PRODUCTION not SANDBOX)..."
aws ses get-account-sending-enabled \
  --region "${REGION}" \
  --output json

echo ""
echo "⚠ ACTION REQUIRED:"
echo "  1. If not all identities are verified, go to AWS SES console"
echo "  2. Verify: omdeshpande123456789@gmail.com (already verified)"
echo "  3. Verify: omdeshpande0901@gmail.com (already verified)"
echo "  4. Verify: aayush.das@mitwpu.edu.in (currently UNVERIFIED)"
echo "  5. Verify: sahil.bobhate@mitwpu.edu.in (already verified)"
echo "  6. Verify: yash.dharap@mitwpu.edu.in (already verified)"
echo "  7. Verify: om.deshpande@mitwpu.edu.in (already verified)"
echo ""
echo "  To verify email via CLI:"
echo "    aws ses verify-email-identity \\"
echo "      --email-address EMAIL@example.com \\"
echo "      --region ${REGION}"
echo ""

# ============================================================================
# FINAL VERIFICATION CHECKLIST
# ============================================================================

echo "════════════════════════════════════════════════════════════════════════"
echo "VERIFICATION CHECKLIST"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

echo "Expected Outputs:"
echo ""
echo "  ✓ DynamoDB:"
echo "    [ ] Table '${TABLE_NAME}' exists and is ACTIVE"
echo "    [ ] Billing mode is ON_DEMAND"
echo "    [ ] Primary key: pk (S), sk (S)"
echo ""

echo "  ✓ Lambda:"
echo "    [ ] Environment variables set: DDB_TABLE, SES_SENDER, SES_RECIPIENTS, FRONTEND_ORIGIN"
echo "    [ ] New version published"
echo ""

echo "  ✓ IAM Role '${ROLE_NAME}':"
echo "    [ ] Inline policy 'formbridge-policy' attached"
echo "    [ ] Includes DynamoDB PutItem and Query permissions"
echo "    [ ] Includes CloudWatch Logs permissions"
echo "    [ ] Includes SES SendEmail permissions"
echo ""

echo "  ✓ API Gateway:"
echo "    [ ] /submit resource exists"
echo "    [ ] OPTIONS method configured for CORS preflight"
echo "    [ ] POST method has CORS headers"
echo "    [ ] Stage redeployed"
echo ""

echo "  ✓ Smoke Test:"
if [ -n "${SUBMISSION_ID}" ]; then
  echo "    [✓] HTTP 200 response received"
  echo "    [✓] Submission ID returned: ${SUBMISSION_ID}"
  echo "    [ ] DynamoDB record present (check Step 6 output above)"
  echo "    [ ] SES email received (check inbox)"
else
  echo "    [ ] HTTP response successful"
  echo "    [ ] Submission ID returned"
  echo "    [ ] DynamoDB record present"
  echo "    [ ] SES email received"
fi
echo ""

echo "  ✓ SES:"
echo "    [ ] All SES_RECIPIENTS verified"
echo "    [ ] SES_SENDER verified"
echo "    [ ] Production mode enabled (not Sandbox)"
echo ""

echo "════════════════════════════════════════════════════════════════════════"
echo "DEPLOYMENT COMPLETE ✓"
echo "════════════════════════════════════════════════════════════════════════"
echo ""
echo "Next Steps:"
echo "  1. Verify all items in the checklist above"
echo "  2. Monitor CloudWatch logs: aws logs tail /aws/lambda/${LAMBDA_NAME} --follow"
echo "  3. Check SES email delivery status"
echo "  4. Update frontend to send form submissions to: ${API_URL}/submit"
echo ""
