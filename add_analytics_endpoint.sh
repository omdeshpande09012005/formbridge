#!/bin/bash

################################################################################
# FormBridge API Gateway - Add /analytics Endpoint Script
# 
# Purpose: Add a new /analytics endpoint to existing REST API with:
#   - POST method with Lambda integration
#   - API Key requirement
#   - CORS support
#   - Deploy to production stage
#
# Prerequisites:
#   - AWS CLI configured with credentials
#   - jq installed for JSON parsing
#   - Existing REST API with /submit endpoint
#
# Usage:
#   1. Replace ALL CAPS placeholders:
#      - API_ID: Your API Gateway REST API ID
#      - REGION: AWS region (e.g., us-east-1)
#      - LAMBDA_NAME: Lambda function name
#      - STAGE_NAME: API stage name (e.g., prod)
#      - USAGE_PLAN_NAME: Usage plan name for API keys
#      - API_KEY_NAME: Name for your API key
#      - FRONTEND_ORIGIN: CORS origin (e.g., https://example.com)
#
#   2. Run the script:
#      ./add_analytics_endpoint.sh
#
################################################################################

set -euo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===== CONFIGURATION - REPLACE THESE PLACEHOLDERS =====
API_ID="API_ID"
REGION="REGION"
LAMBDA_NAME="LAMBDA_NAME"
STAGE_NAME="STAGE_NAME"
USAGE_PLAN_NAME="USAGE_PLAN_NAME"
API_KEY_NAME="API_KEY_NAME"
FRONTEND_ORIGIN="FRONTEND_ORIGIN"

# Derived variables
API_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
LAMBDA_ARN="arn:aws:lambda:${REGION}:$(aws sts get-caller-identity --query Account --output text):function:${LAMBDA_NAME}"

# ===== UTILITY FUNCTIONS =====

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ===== VALIDATION =====

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}FormBridge API Gateway - Analytics Endpoint Setup${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

log_info "Validating configuration..."

if [[ "$API_ID" == "API_ID" ]] || [[ -z "$API_ID" ]]; then
    log_error "API_ID placeholder not replaced! Update the script."
    exit 1
fi

if [[ "$REGION" == "REGION" ]] || [[ -z "$REGION" ]]; then
    log_error "REGION placeholder not replaced! Update the script."
    exit 1
fi

if [[ "$LAMBDA_NAME" == "LAMBDA_NAME" ]] || [[ -z "$LAMBDA_NAME" ]]; then
    log_error "LAMBDA_NAME placeholder not replaced! Update the script."
    exit 1
fi

if [[ "$STAGE_NAME" == "STAGE_NAME" ]] || [[ -z "$STAGE_NAME" ]]; then
    log_error "STAGE_NAME placeholder not replaced! Update the script."
    exit 1
fi

if [[ "$FRONTEND_ORIGIN" == "FRONTEND_ORIGIN" ]] || [[ -z "$FRONTEND_ORIGIN" ]]; then
    log_error "FRONTEND_ORIGIN placeholder not replaced! Update the script."
    exit 1
fi

log_success "Configuration validated"
echo ""

# Verify AWS CLI is available
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install it first."
    exit 1
fi

# Verify jq is available
if ! command -v jq &> /dev/null; then
    log_warning "jq not found. Some operations may fail. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
fi

log_info "API Configuration:"
echo "  API ID:          $API_ID"
echo "  Region:          $REGION"
echo "  Lambda:          $LAMBDA_NAME"
echo "  Stage:           $STAGE_NAME"
echo "  CORS Origin:     $FRONTEND_ORIGIN"
echo "  Lambda ARN:      $LAMBDA_ARN"
echo ""

# ===== STEP 1: GET EXISTING /submit RESOURCE =====

log_info "Step 1: Finding /submit resource..."

SUBMIT_RESOURCE=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --region "$REGION" \
    --output json | jq -r '.items[] | select(.path=="/submit") | .id' | head -1)

if [[ -z "$SUBMIT_RESOURCE" ]]; then
    log_error "Could not find /submit resource. Is the API properly set up?"
    exit 1
fi

log_success "Found /submit resource: $SUBMIT_RESOURCE"

# Get parent resource ID
PARENT_RESOURCE=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --region "$REGION" \
    --output json | jq -r '.items[] | select(.path=="/") | .id')

if [[ -z "$PARENT_RESOURCE" ]]; then
    log_error "Could not find root resource."
    exit 1
fi

log_success "Found parent (root) resource: $PARENT_RESOURCE"
echo ""

# ===== STEP 2: CREATE OR GET /analytics RESOURCE =====

log_info "Step 2: Creating /analytics resource..."

# Check if /analytics already exists
ANALYTICS_RESOURCE=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --region "$REGION" \
    --output json | jq -r '.items[] | select(.path=="/analytics") | .id' | head -1)

if [[ -n "$ANALYTICS_RESOURCE" ]]; then
    log_warning "/analytics resource already exists: $ANALYTICS_RESOURCE"
else
    log_info "Creating new /analytics resource..."
    
    ANALYTICS_RESPONSE=$(aws apigateway create-resource \
        --rest-api-id "$API_ID" \
        --parent-id "$PARENT_RESOURCE" \
        --path-part "analytics" \
        --region "$REGION" \
        --output json)
    
    ANALYTICS_RESOURCE=$(echo "$ANALYTICS_RESPONSE" | jq -r '.id')
    
    if [[ -z "$ANALYTICS_RESOURCE" ]]; then
        log_error "Failed to create /analytics resource"
        exit 1
    fi
    
    log_success "Created /analytics resource: $ANALYTICS_RESOURCE"
fi

echo ""

# ===== STEP 3: CREATE POST METHOD FOR /analytics =====

log_info "Step 3: Creating POST method for /analytics..."

# Check if POST method already exists
POST_METHOD=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "POST" \
    --region "$REGION" \
    --output json 2>/dev/null || echo "{}")

if echo "$POST_METHOD" | jq -e '.httpMethod' &>/dev/null; then
    log_warning "POST method already exists for /analytics"
else
    log_info "Creating new POST method..."
    
    aws apigateway put-method \
        --rest-api-id "$API_ID" \
        --resource-id "$ANALYTICS_RESOURCE" \
        --http-method "POST" \
        --authorization-type "NONE" \
        --api-key-required false \
        --region "$REGION" \
        --output json > /dev/null
    
    log_success "Created POST method"
fi

echo ""

# ===== STEP 4: CREATE LAMBDA INTEGRATION =====

log_info "Step 4: Setting up Lambda integration for POST /analytics..."

# Create the integration
INTEGRATION_RESPONSE=$(aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "POST" \
    --type "AWS_PROXY" \
    --integration-http-method "POST" \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region "$REGION" \
    --output json)

log_success "Lambda integration created (AWS_PROXY)"

# Set integration response
aws apigateway put-integration-response \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "POST" \
    --status-code "200" \
    --region "$REGION" \
    --output json > /dev/null

log_success "Integration response configured"

echo ""

# ===== STEP 5: ENABLE API KEY REQUIREMENT =====

log_info "Step 5: Enabling API Key requirement for POST /analytics..."

aws apigateway update-method \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "POST" \
    --patch-operations op=replace,path=/apiKeyRequired,value=true \
    --region "$REGION" \
    --output json > /dev/null

log_success "API Key requirement enabled"

echo ""

# ===== STEP 6: CREATE OPTIONS METHOD FOR CORS =====

log_info "Step 6: Creating OPTIONS method for CORS support..."

# Check if OPTIONS method already exists
OPTIONS_METHOD=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "OPTIONS" \
    --region "$REGION" \
    --output json 2>/dev/null || echo "{}")

if echo "$OPTIONS_METHOD" | jq -e '.httpMethod' &>/dev/null; then
    log_warning "OPTIONS method already exists for /analytics"
else
    log_info "Creating new OPTIONS method..."
    
    aws apigateway put-method \
        --rest-api-id "$API_ID" \
        --resource-id "$ANALYTICS_RESOURCE" \
        --http-method "OPTIONS" \
        --authorization-type "NONE" \
        --region "$REGION" \
        --output json > /dev/null
    
    log_success "Created OPTIONS method"
fi

# Create MOCK integration for OPTIONS
aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "OPTIONS" \
    --type "MOCK" \
    --region "$REGION" \
    --output json > /dev/null

log_success "MOCK integration created for OPTIONS"

echo ""

# ===== STEP 7: CONFIGURE CORS HEADERS =====

log_info "Step 7: Configuring CORS headers..."

# Create integration response for OPTIONS with CORS headers
CORS_RESPONSE_PARAMS="{
    \"method.response.header.Access-Control-Allow-Headers\": \"'Content-Type,X-Api-Key'\",
    \"method.response.header.Access-Control-Allow-Methods\": \"'OPTIONS,POST'\",
    \"method.response.header.Access-Control-Allow-Origin\": \"'${FRONTEND_ORIGIN}'\",
    \"method.response.header.Access-Control-Max-Age\": \"'3600'\"
}"

# First, add response models for OPTIONS method
aws apigateway put-method-response \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "OPTIONS" \
    --status-code "200" \
    --response-models "application/json=Empty" \
    --response-parameters "$CORS_RESPONSE_PARAMS" \
    --region "$REGION" \
    --output json > /dev/null 2>&1 || true

# Create integration response with headers
aws apigateway put-integration-response \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "OPTIONS" \
    --status-code "200" \
    --response-parameters "$CORS_RESPONSE_PARAMS" \
    --region "$REGION" \
    --output json > /dev/null

log_success "CORS headers configured for OPTIONS"

# Also add CORS headers to POST method response
log_info "Adding CORS headers to POST method response..."

POST_RESPONSE_PARAMS="{
    \"method.response.header.Access-Control-Allow-Origin\": \"'${FRONTEND_ORIGIN}'\"
}"

aws apigateway put-method-response \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "POST" \
    --status-code "200" \
    --response-models "application/json=Empty" \
    --response-parameters "$POST_RESPONSE_PARAMS" \
    --region "$REGION" \
    --output json > /dev/null 2>&1 || true

aws apigateway put-integration-response \
    --rest-api-id "$API_ID" \
    --resource-id "$ANALYTICS_RESOURCE" \
    --http-method "POST" \
    --status-code "200" \
    --response-parameters "$POST_RESPONSE_PARAMS" \
    --response-templates '{"application/json":"$input.path(\"$\")"}' \
    --region "$REGION" \
    --output json > /dev/null

log_success "CORS headers configured for POST"

echo ""

# ===== STEP 8: GRANT LAMBDA PERMISSIONS =====

log_info "Step 8: Granting Lambda invocation permissions to API Gateway..."

# Check if permission already exists
PERMISSION_EXISTS=$(aws lambda get-policy \
    --function-name "$LAMBDA_NAME" \
    --region "$REGION" \
    --output json 2>/dev/null | jq -e '.Policy' || echo "")

if echo "$PERMISSION_EXISTS" | grep -q "apigateway.amazonaws.com" 2>/dev/null; then
    log_warning "Lambda permission for API Gateway already exists"
else
    aws lambda add-permission \
        --function-name "$LAMBDA_NAME" \
        --statement-id "AllowAPIGatewayInvoke-${ANALYTICS_RESOURCE}" \
        --action "lambda:InvokeFunction" \
        --principal "apigateway.amazonaws.com" \
        --source-arn "arn:aws:execute-api:${REGION}:$(aws sts get-caller-identity --query Account --output text):${API_ID}/*/*" \
        --region "$REGION" \
        --output json > /dev/null 2>&1 || true
    
    log_success "Lambda permission granted"
fi

echo ""

# ===== STEP 9: DEPLOY API =====

log_info "Step 9: Deploying API to stage '$STAGE_NAME'..."

DEPLOYMENT=$(aws apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION" \
    --output json)

DEPLOYMENT_ID=$(echo "$DEPLOYMENT" | jq -r '.id')

if [[ -z "$DEPLOYMENT_ID" ]] || [[ "$DEPLOYMENT_ID" == "null" ]]; then
    log_error "Deployment failed"
    exit 1
fi

log_success "API deployed with ID: $DEPLOYMENT_ID"

echo ""

# ===== STEP 10: VERIFY API KEY (IF NEEDED) =====

log_info "Step 10: Verifying API Key setup..."

# Check if usage plan exists
USAGE_PLAN=$(aws apigateway get-usage-plans \
    --region "$REGION" \
    --output json | jq -r ".items[] | select(.name==\"${USAGE_PLAN_NAME}\") | .id" | head -1)

if [[ -z "$USAGE_PLAN" ]]; then
    log_warning "Usage plan '$USAGE_PLAN_NAME' not found. API Key requirement may not work."
    log_info "To enable API Key validation, create a usage plan and associate with this API."
else
    log_success "Found usage plan: $USAGE_PLAN"
fi

# Check if API key exists
API_KEY=$(aws apigateway get-api-keys \
    --region "$REGION" \
    --output json | jq -r ".items[] | select(.name==\"${API_KEY_NAME}\") | .id" | head -1)

if [[ -z "$API_KEY" ]]; then
    log_warning "API Key '$API_KEY_NAME' not found."
    log_info "To create an API Key, run:"
    echo "  aws apigateway create-api-key --name \"${API_KEY_NAME}\" --enabled --region \"${REGION}\""
else
    log_success "Found API Key: $API_KEY"
    
    # Get the actual key value
    API_KEY_VALUE=$(aws apigateway get-api-key \
        --api-key "$API_KEY" \
        --include-value \
        --region "$REGION" \
        --output json | jq -r '.value')
fi

echo ""

# ===== SUMMARY =====

echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""

echo -e "${BLUE}API Endpoint Summary:${NC}"
echo "  Base URL:        ${API_ENDPOINT}/${STAGE_NAME}"
echo "  Analytics URL:   ${API_ENDPOINT}/${STAGE_NAME}/analytics"
echo "  Requires API Key: YES"
echo "  CORS Origin:     ${FRONTEND_ORIGIN}"
echo ""

if [[ -n "$API_KEY_VALUE" ]]; then
    echo -e "${BLUE}API Key Details:${NC}"
    echo "  Key Name:        ${API_KEY_NAME}"
    echo "  Key ID:          ${API_KEY}"
    echo "  Key Value:       ${API_KEY_VALUE:0:10}... (hidden for security)"
    echo ""
fi

# ===== TEST COMMANDS =====

echo -e "${BLUE}Test Commands:${NC}"
echo ""

echo "1. Test WITHOUT API Key (should return 403 Forbidden):"
echo -e "   ${YELLOW}curl -i -X POST \"${API_ENDPOINT}/${STAGE_NAME}/analytics\" \\${NC}"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"form_id\":\"my-portfolio'}'"
echo ""

if [[ -n "$API_KEY_VALUE" ]]; then
    echo "2. Test WITH API Key (should return 200 OK):"
    echo -e "   ${YELLOW}curl -i -X POST \"${API_ENDPOINT}/${STAGE_NAME}/analytics\" \\${NC}"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -H \"X-Api-Key: ${API_KEY_VALUE}\" \\"
    echo "     -d '{\"form_id\":\"my-portfolio'}'"
    echo ""
    
    echo "3. Test OPTIONS for CORS:"
    echo -e "   ${YELLOW}curl -i -X OPTIONS \"${API_ENDPOINT}/${STAGE_NAME}/analytics\" \\${NC}"
    echo "     -H \"Origin: ${FRONTEND_ORIGIN}\" \\"
    echo "     -H \"Access-Control-Request-Method: POST\""
    echo ""
else
    echo "2. Test WITH API Key (replace <YOUR_API_KEY>):"
    echo -e "   ${YELLOW}curl -i -X POST \"${API_ENDPOINT}/${STAGE_NAME}/analytics\" \\${NC}"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -H \"X-Api-Key: <YOUR_API_KEY>\" \\"
    echo "     -d '{\"form_id\":\"my-portfolio'}'"
    echo ""
fi

echo -e "${BLUE}Useful AWS CLI Commands:${NC}"
echo ""

echo "1. View all resources in API:"
echo -e "   ${YELLOW}aws apigateway get-resources --rest-api-id ${API_ID} --region ${REGION}${NC}"
echo ""

echo "2. View method configuration:"
echo -e "   ${YELLOW}aws apigateway get-method --rest-api-id ${API_ID} \\${NC}"
echo "     --resource-id ${ANALYTICS_RESOURCE} --http-method POST --region ${REGION}"
echo ""

echo "3. View integration configuration:"
echo -e "   ${YELLOW}aws apigateway get-integration --rest-api-id ${API_ID} \\${NC}"
echo "     --resource-id ${ANALYTICS_RESOURCE} --http-method POST --region ${REGION}"
echo ""

echo "4. Delete /analytics endpoint (if needed):"
echo -e "   ${YELLOW}aws apigateway delete-resource --rest-api-id ${API_ID} \\${NC}"
echo "     --resource-id ${ANALYTICS_RESOURCE} --region ${REGION}"
echo ""

echo "5. View Lambda invocation logs:"
echo -e "   ${YELLOW}aws logs tail /aws/lambda/${LAMBDA_NAME} --follow${NC}"
echo ""

echo -e "${GREEN}Setup complete! Your /analytics endpoint is ready for testing.${NC}"
echo ""
