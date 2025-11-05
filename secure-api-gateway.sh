#!/bin/bash
set -euo pipefail

################################################################################
# FormBridge API Gateway Security Script
# Idempotent bash script to secure API Gateway with API Keys + Usage Plan + CORS
# All placeholders are in ALL_CAPS - replace before running
################################################################################

# Configuration placeholders (REPLACE THESE)
REGION="ap-south-1"
ACCOUNT_ID="864572276622"
API_ID="12mse3zde5"
STAGE_NAME="Prod"
SUBMIT_PATH="/submit"
USAGE_PLAN_NAME="FormBridgeBasic"
API_KEY_NAME="FormBridgeDemoKey"
FRONTEND_ORIGIN="https://omdeshpande09012005.github.io"
RATE_LIMIT="2"
BURST_LIMIT="5"
MONTHLY_QUOTA="10000"

################################################################################
# Utility Functions
################################################################################

log_section() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║ $1"
    echo "╚════════════════════════════════════════════════════════════════╝"
}

log_step() {
    echo "▶ $1"
}

log_success() {
    echo "✓ $1"
}

log_error() {
    echo "✗ $1" >&2
}

exit_error() {
    log_error "$1"
    exit 1
}

################################################################################
# Prechecks
################################################################################

log_section "STEP 1: Verify Prerequisites"

log_step "Checking if AWS CLI is installed..."
if ! command -v aws &> /dev/null; then
    exit_error "AWS CLI not found. Please install it first."
fi
log_success "AWS CLI found: $(aws --version)"

log_step "Checking if jq is installed..."
if ! command -v jq &> /dev/null; then
    exit_error "jq not found. Please install it first (apt-get install jq or brew install jq)"
fi
log_success "jq found: $(jq --version)"

log_step "Checking AWS credentials..."
if ! aws sts get-caller-identity --region "$REGION" &> /dev/null; then
    exit_error "AWS credentials not configured. Run 'aws configure' first."
fi
CALLER_ID=$(aws sts get-caller-identity --region "$REGION" | jq -r '.Account')
log_success "AWS credentials valid. Account: $CALLER_ID"

log_step "Checking API Gateway API exists..."
if ! aws apigateway get-rest-api --rest-api-id "$API_ID" --region "$REGION" &> /dev/null; then
    exit_error "API Gateway REST API not found: $API_ID"
fi
log_success "API Gateway API found: $API_ID"

################################################################################
# Find or Create /submit Resource
################################################################################

log_section "STEP 2: Find Resource for $SUBMIT_PATH"

log_step "Fetching all resources for API $API_ID..."
RESOURCES=$(aws apigateway get-resources --rest-api-id "$API_ID" --region "$REGION")

log_step "Searching for resource with path $SUBMIT_PATH..."
SUBMIT_RES_ID=$(echo "$RESOURCES" | jq -r ".items[] | select(.path==\"$SUBMIT_PATH\") | .id" | head -1)

if [ -z "$SUBMIT_RES_ID" ]; then
    exit_error "Resource $SUBMIT_PATH not found. Create the integration first via console or terraform."
fi
log_success "Found resource ID for $SUBMIT_PATH: $SUBMIT_RES_ID"

################################################################################
# Mark POST Method as API Key Required
################################################################################

log_section "STEP 3: Enable API Key Requirement on POST $SUBMIT_PATH"

log_step "Checking if POST method exists on $SUBMIT_PATH..."
POST_METHOD=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method POST \
    --region "$REGION" 2>/dev/null || echo "{}")

if [ "$POST_METHOD" == "{}" ] || [ -z "$POST_METHOD" ]; then
    exit_error "POST method not found on $SUBMIT_PATH. Create the Lambda integration first."
fi

log_step "Checking current apiKeyRequired status..."
CURRENT_KEY_REQUIRED=$(echo "$POST_METHOD" | jq -r '.apiKeyRequired // false')
log_success "Current apiKeyRequired: $CURRENT_KEY_REQUIRED"

if [ "$CURRENT_KEY_REQUIRED" != "true" ]; then
    log_step "Setting apiKeyRequired to true..."
    aws apigateway update-method \
        --rest-api-id "$API_ID" \
        --resource-id "$SUBMIT_RES_ID" \
        --http-method POST \
        --patch-operations op=replace,path=/apiKeyRequired,value=true \
        --region "$REGION" > /dev/null
    log_success "apiKeyRequired set to true"
else
    log_success "apiKeyRequired already true (idempotent)"
fi

log_step "Verifying apiKeyRequired is true..."
VERIFY_METHOD=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method POST \
    --region "$REGION")
VERIFIED_KEY_REQUIRED=$(echo "$VERIFY_METHOD" | jq -r '.apiKeyRequired')
[ "$VERIFIED_KEY_REQUIRED" == "true" ] && log_success "Verified: apiKeyRequired = true" || exit_error "Failed to set apiKeyRequired"

################################################################################
# CORS for /submit (OPTIONS method + mock integration)
################################################################################

log_section "STEP 4: Configure CORS for $SUBMIT_PATH"

log_step "Checking if OPTIONS method exists..."
OPTIONS_METHOD=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method OPTIONS \
    --region "$REGION" 2>/dev/null || echo "{}")

if [ "$OPTIONS_METHOD" == "{}" ] || [ -z "$OPTIONS_METHOD" ]; then
    log_step "Creating OPTIONS method (CORS preflight)..."
    aws apigateway put-method \
        --rest-api-id "$API_ID" \
        --resource-id "$SUBMIT_RES_ID" \
        --http-method OPTIONS \
        --authorization-type NONE \
        --region "$REGION" > /dev/null
    log_success "OPTIONS method created"
else
    log_success "OPTIONS method already exists (idempotent)"
fi

log_step "Checking if MOCK integration exists on OPTIONS..."
OPTIONS_INTEGRATION=$(aws apigateway get-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method OPTIONS \
    --region "$REGION" 2>/dev/null || echo "{}")

INTEGRATION_TYPE=$(echo "$OPTIONS_INTEGRATION" | jq -r '.type // ""')

if [ "$INTEGRATION_TYPE" != "MOCK" ]; then
    log_step "Creating MOCK integration for OPTIONS..."
    aws apigateway put-integration \
        --rest-api-id "$API_ID" \
        --resource-id "$SUBMIT_RES_ID" \
        --http-method OPTIONS \
        --type MOCK \
        --region "$REGION" > /dev/null
    log_success "MOCK integration created for OPTIONS"
else
    log_success "MOCK integration already exists (idempotent)"
fi

log_step "Configuring method response for OPTIONS (status 200)..."
aws apigateway put-method-response \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-models application/json=Empty \
    --response-parameters \
        method.response.header.Access-Control-Allow-Headers=true \
        method.response.header.Access-Control-Allow-Methods=true \
        method.response.header.Access-Control-Allow-Origin=true \
    --region "$REGION" > /dev/null
log_success "Method response configured"

log_step "Configuring integration response for OPTIONS (status 200)..."
aws apigateway put-integration-response \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters \
        method.integration.response.header.Access-Control-Allow-Headers="'Content-Type,X-Api-Key'" \
        method.integration.response.header.Access-Control-Allow-Methods="'OPTIONS,POST'" \
        method.integration.response.header.Access-Control-Allow-Origin="'$FRONTEND_ORIGIN'" \
    --region "$REGION" > /dev/null
log_success "Integration response configured with CORS headers"

log_step "Verifying CORS configuration..."
OPTIONS_INT_RESPONSE=$(aws apigateway get-integration-response \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RES_ID" \
    --http-method OPTIONS \
    --status-code 200 \
    --region "$REGION")
echo "$OPTIONS_INT_RESPONSE" | jq '.responseParameters' 2>/dev/null && log_success "CORS headers verified"

################################################################################
# Usage Plan (Rate Limit + Quota) - Create or Get
################################################################################

log_section "STEP 5: Create or Get Usage Plan"

log_step "Checking if usage plan named '$USAGE_PLAN_NAME' exists..."
USAGE_PLANS=$(aws apigateway get-usage-plans --region "$REGION")
USAGE_PLAN_ID=$(echo "$USAGE_PLANS" | jq -r ".items[] | select(.name==\"$USAGE_PLAN_NAME\") | .id" | head -1)

if [ -z "$USAGE_PLAN_ID" ]; then
    log_step "Creating usage plan: $USAGE_PLAN_NAME..."
    USAGE_PLAN=$(aws apigateway create-usage-plan \
        --name "$USAGE_PLAN_NAME" \
        --description "Rate limiting for $USAGE_PLAN_NAME API" \
        --throttle rateLimit="$RATE_LIMIT",burstLimit="$BURST_LIMIT" \
        --quota limit="$MONTHLY_QUOTA",period=MONTH \
        --region "$REGION")
    USAGE_PLAN_ID=$(echo "$USAGE_PLAN" | jq -r '.id')
    log_success "Usage plan created: $USAGE_PLAN_ID"
else
    log_success "Usage plan already exists: $USAGE_PLAN_ID (idempotent)"
fi

log_step "Checking if API stage is attached to usage plan..."
USAGE_PLAN_DETAIL=$(aws apigateway get-usage-plan --usage-plan-id "$USAGE_PLAN_ID" --region "$REGION")
STAGE_ATTACHED=$(echo "$USAGE_PLAN_DETAIL" | jq ".apiStages[] | select(.apiId==\"$API_ID\" and .stage==\"$STAGE_NAME\")" || echo "")

if [ -z "$STAGE_ATTACHED" ] || [ "$STAGE_ATTACHED" == "" ]; then
    log_step "Attaching API stage $STAGE_NAME to usage plan..."
    aws apigateway update-usage-plan \
        --usage-plan-id "$USAGE_PLAN_ID" \
        --patch-operations op=add,path=/apiStages,value="$API_ID:$STAGE_NAME" \
        --region "$REGION" > /dev/null
    log_success "API stage attached to usage plan"
else
    log_success "API stage already attached (idempotent)"
fi

################################################################################
# API Key - Create or Get + Association
################################################################################

log_section "STEP 6: Create or Get API Key and Associate with Usage Plan"

log_step "Checking if API Key named '$API_KEY_NAME' exists..."
API_KEYS=$(aws apigateway get-api-keys --region "$REGION")
API_KEY_ID=$(echo "$API_KEYS" | jq -r ".items[] | select(.name==\"$API_KEY_NAME\") | .id" | head -1)

if [ -z "$API_KEY_ID" ]; then
    log_step "Creating API Key: $API_KEY_NAME..."
    API_KEY=$(aws apigateway create-api-key \
        --name "$API_KEY_NAME" \
        --description "API Key for $API_KEY_NAME" \
        --enabled \
        --region "$REGION")
    API_KEY_ID=$(echo "$API_KEY" | jq -r '.id')
    API_KEY_VALUE=$(echo "$API_KEY" | jq -r '.value')
    log_success "API Key created: $API_KEY_ID"
else
    log_success "API Key already exists: $API_KEY_ID (idempotent)"
    log_step "Fetching API Key value..."
    API_KEY_DATA=$(aws apigateway get-api-key --api-key "$API_KEY_ID" --include-value --region "$REGION")
    API_KEY_VALUE=$(echo "$API_KEY_DATA" | jq -r '.value')
fi

log_step "Checking if API Key is associated with usage plan..."
PLAN_KEYS=$(aws apigateway get-usage-plan-keys --usage-plan-id "$USAGE_PLAN_ID" --region "$REGION")
KEY_ASSOCIATED=$(echo "$PLAN_KEYS" | jq ".items[] | select(.id==\"$API_KEY_ID\")" || echo "")

if [ -z "$KEY_ASSOCIATED" ] || [ "$KEY_ASSOCIATED" == "" ]; then
    log_step "Associating API Key with usage plan..."
    aws apigateway create-usage-plan-key \
        --usage-plan-id "$USAGE_PLAN_ID" \
        --key-id "$API_KEY_ID" \
        --key-type API_KEY \
        --region "$REGION" > /dev/null
    log_success "API Key associated with usage plan"
else
    log_success "API Key already associated (idempotent)"
fi

################################################################################
# Deploy API Gateway
################################################################################

log_section "STEP 7: Deploy API Gateway Changes"

log_step "Creating deployment for stage $STAGE_NAME..."
DEPLOYMENT=$(aws apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE_NAME" \
    --description "Enable API Key + CORS for $SUBMIT_PATH" \
    --region "$REGION")
DEPLOYMENT_ID=$(echo "$DEPLOYMENT" | jq -r '.id')
log_success "Deployment created: $DEPLOYMENT_ID"

log_step "Verifying deployment..."
STAGE_INFO=$(aws apigateway get-stage \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION")
STAGE_DEPLOYMENT=$(echo "$STAGE_INFO" | jq -r '.deploymentId')
[ "$STAGE_DEPLOYMENT" == "$DEPLOYMENT_ID" ] && log_success "Deployment verified on stage $STAGE_NAME" || log_error "Deployment verification failed"

################################################################################
# Validation with curl
################################################################################

log_section "STEP 8: Validate with curl"

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}"
SUBMIT_URL="$API_URL$SUBMIT_PATH"

log_step "API Endpoint: $SUBMIT_URL"
log_step "API Key ID: $API_KEY_ID"
log_step "API Key Value: $(echo "$API_KEY_VALUE" | head -c 20)...***"

# Test 1: Request WITHOUT API Key (expect 403)
log_step "Test 1: POST without API Key (expect 403 Forbidden)..."
TEST1_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$SUBMIT_URL" \
    -H "Content-Type: application/json" \
    -d '{"form_id":"test","message":"curl test without key"}' 2>/dev/null || echo "")
TEST1_HTTP_CODE=$(echo "$TEST1_RESPONSE" | tail -1)
TEST1_BODY=$(echo "$TEST1_RESPONSE" | head -n -1)

if [ "$TEST1_HTTP_CODE" == "403" ]; then
    log_success "Test 1 PASSED: Got 403 Forbidden"
    echo "Response: $TEST1_BODY"
else
    log_error "Test 1 FAILED: Expected 403, got $TEST1_HTTP_CODE"
    echo "Response: $TEST1_BODY"
fi

# Test 2: Request WITH API Key (expect 200)
log_step "Test 2: POST with valid API Key (expect 200 OK)..."
TEST2_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$SUBMIT_URL" \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $API_KEY_VALUE" \
    -d '{"form_id":"test","message":"curl test with key"}' 2>/dev/null || echo "")
TEST2_HTTP_CODE=$(echo "$TEST2_RESPONSE" | tail -1)
TEST2_BODY=$(echo "$TEST2_RESPONSE" | head -n -1)

if [ "$TEST2_HTTP_CODE" == "200" ]; then
    log_success "Test 2 PASSED: Got 200 OK"
    echo "Response: $TEST2_BODY"
    SUBMISSION_ID=$(echo "$TEST2_BODY" | jq -r '.id // "N/A"')
    log_success "Submission ID: $SUBMISSION_ID"
else
    log_error "Test 2 FAILED: Expected 200, got $TEST2_HTTP_CODE"
    echo "Response: $TEST2_BODY"
fi

# Test 3: OPTIONS CORS preflight (expect 200)
log_step "Test 3: OPTIONS preflight request (expect 200 OK)..."
TEST3_RESPONSE=$(curl -s -w "\n%{http_code}" -X OPTIONS "$SUBMIT_URL" \
    -H "Origin: $FRONTEND_ORIGIN" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: Content-Type,X-Api-Key" 2>/dev/null || echo "")
TEST3_HTTP_CODE=$(echo "$TEST3_RESPONSE" | tail -1)

if [ "$TEST3_HTTP_CODE" == "200" ]; then
    log_success "Test 3 PASSED: CORS preflight successful"
    CORS_ORIGIN=$(curl -s -I -X OPTIONS "$SUBMIT_URL" \
        -H "Origin: $FRONTEND_ORIGIN" 2>/dev/null | grep -i "Access-Control-Allow-Origin" || echo "Not found")
    echo "CORS Header: $CORS_ORIGIN"
else
    log_error "Test 3 FAILED: Expected 200, got $TEST3_HTTP_CODE"
fi

################################################################################
# Final Summary
################################################################################

log_section "DEPLOYMENT SUMMARY"

cat <<EOF

╔════════════════════════════════════════════════════════════════╗
║                 CONFIGURATION SUMMARY                          ║
╚════════════════════════════════════════════════════════════════╝

📍 AWS Configuration:
   • Region: $REGION
   • Account ID: $ACCOUNT_ID

🔌 API Gateway:
   • API ID: $API_ID
   • Stage: $STAGE_NAME
   • Resource ID (/submit): $SUBMIT_RES_ID
   • Endpoint: $SUBMIT_URL

🔐 API Key:
   • API Key ID: $API_KEY_ID
   • API Key Name: $API_KEY_NAME
   • Value: ${API_KEY_VALUE}
   
   ⚠️  Keep this secure! Store in .env or GitHub Secrets.

📊 Rate Limiting (Usage Plan):
   • Usage Plan ID: $USAGE_PLAN_ID
   • Usage Plan Name: $USAGE_PLAN_NAME
   • Rate Limit: $RATE_LIMIT req/sec
   • Burst Limit: $BURST_LIMIT requests
   • Monthly Quota: $MONTHLY_QUOTA requests

🌐 CORS Configuration:
   • Allowed Origin: $FRONTEND_ORIGIN
   • Allowed Methods: OPTIONS,POST
   • Allowed Headers: Content-Type,X-Api-Key

🧪 Test Commands:

   # Without API Key (expect 403):
   curl -X POST $SUBMIT_URL \\
     -H "Content-Type: application/json" \\
     -d '{"form_id":"test","message":"hello"}'

   # With API Key (expect 200):
   curl -X POST $SUBMIT_URL \\
     -H "Content-Type: application/json" \\
     -H "X-Api-Key: $API_KEY_VALUE" \\
     -d '{"form_id":"test","message":"hello"}'

   # CORS Preflight (expect 200):
   curl -X OPTIONS $SUBMIT_URL \\
     -H "Origin: $FRONTEND_ORIGIN" \\
     -H "Access-Control-Request-Method: POST"

╔════════════════════════════════════════════════════════════════╗
║                 EXPECTED OUTCOMES CHECKLIST                    ║
╚════════════════════════════════════════════════════════════════╝

✓ POST without X-Api-Key header:
  → Status: 403 Forbidden
  → Response: {"message":"Forbidden"}

✓ POST with valid X-Api-Key header:
  → Status: 200 OK
  → Response: {"id":"uuid-v4"}

✓ OPTIONS preflight request:
  → Status: 200 OK
  → Headers: Access-Control-Allow-Origin, Methods, Headers

✓ Rate limiting (burst 5 requests):
  → Requests 1-5: 200 OK
  → Request 6 (within 1 sec): 429 Too Many Requests

✓ Monthly quota:
  → After 10,000 requests in a month: 429 Too Many Requests

╔════════════════════════════════════════════════════════════════╗
║                    NEXT STEPS                                  ║
╚════════════════════════════════════════════════════════════════╝

1. ✅ Script execution complete - idempotent & rerunnable
2. 📝 Store API Key in .env file (not in git)
3. 🚀 Deploy frontend with X-Api-Key header
4. 🔄 Monitor CloudWatch logs: /aws/lambda/contact-form-handler
5. 📊 Check rate limit usage: aws apigateway get-usage --usage-plan-id $USAGE_PLAN_ID
6. 🔑 Rotate API Key every 90 days

⚠️  WARNING: API keys in static frontend code are not secret!
    Use environment variables or backend proxy for production.

EOF

log_success "API Gateway security configuration complete!"

