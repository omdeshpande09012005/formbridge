#!/bin/bash

################################################################################
# API Gateway 403 Diagnostic & Fix Script
# Idempotent bash script to diagnose and fix 403 Forbidden on API Gateway
# Supports audit-only mode (default) and --fix-permissive flag
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Configuration - Replace these with your values
################################################################################

REGION="${REGION:-ap-south-1}"
API_ID="${API_ID:-12mse3zde5}"
STAGE_NAME="${STAGE_NAME:-Prod}"
API_KEY_ID="${API_KEY_ID:-}"  # Optional, will auto-detect if empty
USAGE_PLAN_NAME="${USAGE_PLAN_NAME:-}"  # Optional, will auto-detect if empty
FIX_PERMISSIVE="${1:-}"  # Pass --fix-permissive to enable destructive changes

# Flags
AUDIT_ONLY=true
if [[ "$FIX_PERMISSIVE" == "--fix-permissive" ]]; then
    AUDIT_ONLY=false
    echo -e "${RED}⚠️  WARNING: Running in FIX mode (destructive changes)${NC}"
    echo -e "${RED}This will apply a permissive resource policy for testing only${NC}"
    sleep 3
fi

################################################################################
# Helper Functions
################################################################################

# Print section banner
print_banner() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

################################################################################
# Prechecks
################################################################################

print_banner "PRECHECKS"

# Check for required commands
for cmd in aws jq curl; do
    if command_exists "$cmd"; then
        print_success "$cmd installed"
    else
        print_error "$cmd not found. Please install it first."
        exit 1
    fi
done

# Validate AWS credentials
if ! aws sts get-caller-identity --region "$REGION" &>/dev/null; then
    print_error "AWS credentials not configured or invalid"
    exit 1
fi
print_success "AWS credentials valid"

# Check configuration
if [[ -z "$API_ID" ]] || [[ -z "$STAGE_NAME" ]]; then
    print_error "API_ID and STAGE_NAME must be set"
    exit 1
fi
print_success "Configuration valid: API_ID=$API_ID, STAGE_NAME=$STAGE_NAME, REGION=$REGION"

################################################################################
# Step 1: Get Stage Info
################################################################################

print_banner "STEP 1: STAGE INFORMATION"

STAGE_INFO=$(aws apigateway get-stage \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE_NAME" \
    --region "$REGION" 2>/dev/null || echo "{}")

if [[ "$STAGE_INFO" == "{}" ]]; then
    print_error "Stage $STAGE_NAME not found for API $API_ID"
    exit 1
fi

STAGE_ARN=$(echo "$STAGE_INFO" | jq -r '.arn // empty')
print_info "Stage ARN: $STAGE_ARN"

ENDPOINT=$(echo "$STAGE_INFO" | jq -r '.endpoint // empty')
print_info "Endpoint: $ENDPOINT"

EXECUTION_LOGS=$(echo "$STAGE_INFO" | jq -r '.methodSettings[0].loggingLevel // "OFF"' 2>/dev/null || echo "OFF")
if [[ "$EXECUTION_LOGS" == "OFF" ]]; then
    print_warning "Execution logging is OFF (will need to enable for CloudWatch diagnostics)"
else
    print_success "Execution logging is $EXECUTION_LOGS"
fi

################################################################################
# Step 2: Get Usage Plans & Verify Binding
################################################################################

print_banner "STEP 2: USAGE PLANS & API KEY BINDING"

USAGE_PLANS=$(aws apigateway get-usage-plans --region "$REGION" 2>/dev/null || echo "[]")
PLAN_COUNT=$(echo "$USAGE_PLANS" | jq '.items | length')
print_info "Found $PLAN_COUNT usage plan(s)"

# Find usage plan containing this API and stage
MATCHING_PLAN=""
MATCHING_PLAN_ID=""

for row in $(echo "${USAGE_PLANS}" | jq -r '.items[] | @base64'); do
    _jq() {
        echo "${row}" | base64 --decode | jq -r "${1}"
    }
    
    plan_id=$(_jq '.id')
    plan_name=$(_jq '.name')
    api_stages=$(_jq '.apiStages[] | .apiId' 2>/dev/null || echo "")
    
    if echo "$api_stages" | grep -q "$API_ID"; then
        MATCHING_PLAN="$plan_name"
        MATCHING_PLAN_ID="$plan_id"
        print_success "Found usage plan: $plan_name ($plan_id) containing API $API_ID"
        
        # Check if stage is in this plan
        stage_in_plan=$(aws apigateway get-usage-plan \
            --usage-plan-id "$plan_id" \
            --region "$REGION" | jq ".apiStages[] | select(.apiId == \"$API_ID\" and .stage == \"$STAGE_NAME\") | .apiId" 2>/dev/null || echo "")
        
        if [[ -n "$stage_in_plan" ]]; then
            print_success "Stage $STAGE_NAME is associated with this plan"
        else
            print_warning "Stage $STAGE_NAME is NOT associated with plan $plan_name"
        fi
    fi
done

if [[ -z "$MATCHING_PLAN_ID" ]]; then
    print_warning "No usage plan found for API $API_ID"
    MATCHING_PLAN_ID=""
else
    # Get API Keys from this plan
    print_info "Fetching API keys from plan $MATCHING_PLAN..."
    API_KEYS=$(aws apigateway get-usage-plan-keys \
        --usage-plan-id "$MATCHING_PLAN_ID" \
        --region "$REGION" 2>/dev/null || echo "[]")
    
    KEY_COUNT=$(echo "$API_KEYS" | jq '.items | length')
    print_info "Found $KEY_COUNT API key(s) in usage plan"
    
    if [[ $KEY_COUNT -gt 0 ]]; then
        while IFS= read -r key_id; do
            if [[ -n "$key_id" && "$key_id" != "null" ]]; then
                KEY_NAME=$(echo "$API_KEYS" | jq -r ".items[] | select(.id == \"$key_id\") | .name")
                print_info "  - Key: $KEY_NAME ($key_id)"
                
                # If no API_KEY_ID specified, use first one found
                if [[ -z "$API_KEY_ID" ]]; then
                    API_KEY_ID="$key_id"
                fi
            fi
        done < <(echo "$API_KEYS" | jq -r '.items[].id')
    fi
fi

################################################################################
# Step 3: Fetch Actual API Key Value
################################################################################

print_banner "STEP 3: API KEY VALUE"

if [[ -n "$API_KEY_ID" ]]; then
    print_info "Fetching API key value for: $API_KEY_ID"
    API_KEY_VALUE=$(aws apigateway get-api-key \
        --api-key "$API_KEY_ID" \
        --include-value \
        --region "$REGION" 2>/dev/null | jq -r '.value // empty')
    
    if [[ -n "$API_KEY_VALUE" ]]; then
        print_success "API Key retrieved"
        print_info "  Key value: ${API_KEY_VALUE:0:10}...${API_KEY_VALUE: -10}"
    else
        print_warning "Could not retrieve API key value"
        API_KEY_VALUE=""
    fi
else
    print_warning "No API_KEY_ID found"
    API_KEY_VALUE=""
fi

################################################################################
# Step 4: Check /submit POST Method Configuration
################################################################################

print_banner "STEP 4: /SUBMIT POST METHOD CONFIGURATION"

# Get resources
RESOURCES=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --region "$REGION" 2>/dev/null || echo "{}")

SUBMIT_RESOURCE_ID=$(echo "$RESOURCES" | jq -r '.items[] | select(.path == "/submit") | .id' 2>/dev/null || echo "")

if [[ -z "$SUBMIT_RESOURCE_ID" ]]; then
    print_error "/submit resource not found"
    print_info "Available resources:"
    echo "$RESOURCES" | jq -r '.items[] | .path' | head -20
    exit 1
fi

print_success "Found /submit resource: $SUBMIT_RESOURCE_ID"

# Check POST method
METHOD_CONFIG=$(aws apigateway get-method \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RESOURCE_ID" \
    --http-method POST \
    --region "$REGION" 2>/dev/null || echo "{}")

API_KEY_REQUIRED=$(echo "$METHOD_CONFIG" | jq -r '.apiKeyRequired // false')
AUTH_TYPE=$(echo "$METHOD_CONFIG" | jq -r '.authorizationType // "NONE"')

print_info "API Key Required: $API_KEY_REQUIRED"
print_info "Authorization Type: $AUTH_TYPE"

# If API key not required, enable it
if [[ "$API_KEY_REQUIRED" != "true" ]]; then
    if [[ "$AUDIT_ONLY" == "true" ]]; then
        print_warning "API key is NOT required for /submit POST (should be true)"
        print_info "To fix: run with --fix-permissive flag"
    else
        print_warning "Enabling API key requirement for /submit POST..."
        aws apigateway put-method \
            --rest-api-id "$API_ID" \
            --resource-id "$SUBMIT_RESOURCE_ID" \
            --http-method POST \
            --authorization-type NONE \
            --api-key-required \
            --region "$REGION" 2>/dev/null || true
        print_success "API key requirement enabled"
        NEEDS_REDEPLOY=true
    fi
else
    print_success "API key is required for /submit POST"
fi

################################################################################
# Step 5: Check Resource Policy
################################################################################

print_banner "STEP 5: RESOURCE POLICY ANALYSIS"

RESOURCE_POLICY=$(aws apigateway get-resource-policy \
    --rest-api-id "$API_ID" \
    --region "$REGION" 2>/dev/null | jq '.policy | fromjson // {}' 2>/dev/null || echo "{}")

if [[ "$(echo "$RESOURCE_POLICY" | jq 'length')" -eq 0 ]] || [[ "$(echo "$RESOURCE_POLICY" | jq -r '.Statement | length' 2>/dev/null || echo 0)" -eq 0 ]]; then
    print_success "No resource policy found (permissive by default)"
else
    print_info "Resource policy found. Checking for restrictions..."
    
    # Check for deny statements
    DENY_COUNT=$(echo "$RESOURCE_POLICY" | jq '[.Statement[] | select(.Effect == "Deny")] | length')
    if [[ $DENY_COUNT -gt 0 ]]; then
        print_warning "Found $DENY_COUNT DENY statement(s)"
        echo "$RESOURCE_POLICY" | jq '.Statement[] | select(.Effect == "Deny")'
    fi
    
    # Check for restrictive allows (by IP, VPC, Org)
    RESTRICTIVE=$(echo "$RESOURCE_POLICY" | jq '[.Statement[] | select(.Effect == "Allow" and (.Condition | length > 0))] | length')
    if [[ $RESTRICTIVE -gt 0 ]]; then
        print_warning "Found $RESTRICTIVE restrictive ALLOW statement(s) with conditions:"
        echo "$RESOURCE_POLICY" | jq '.Statement[] | select(.Effect == "Allow" and (.Condition | length > 0))'
    else
        print_success "No restrictive Allow conditions found"
    fi
fi

# If policy is restrictive and not audit-only, offer to fix
if [[ "$AUDIT_ONLY" == "false" ]] && [[ "$(echo "$RESOURCE_POLICY" | jq '.Statement | length' 2>/dev/null || echo 0)" -gt 0 ]]; then
    print_warning "Applying permissive policy for testing..."
    
    PERMISSIVE_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:'"$REGION"':*:'"$API_ID"'/*"
    }
  ]
}'
    
    aws apigateway put-resource-policy \
        --rest-api-id "$API_ID" \
        --policy "$PERMISSIVE_POLICY" \
        --region "$REGION" 2>/dev/null || true
    
    print_success "Permissive policy applied (for testing only)"
    NEEDS_REDEPLOY=true
fi

################################################################################
# Step 6: Test Invoke Method (bypasses network policies)
################################################################################

print_banner "STEP 6: TEST-INVOKE-METHOD (Local API Gateway Test)"

TEST_BODY='{"form_id":"k6-test","message":"test from diagnose script"}'

TEST_RESULT=$(aws apigateway test-invoke-method \
    --rest-api-id "$API_ID" \
    --resource-id "$SUBMIT_RESOURCE_ID" \
    --http-method POST \
    --body "$TEST_BODY" \
    --region "$REGION" 2>/dev/null || echo '{}')

TEST_STATUS=$(echo "$TEST_RESULT" | jq -r '.status // "unknown"')
TEST_BODY_RESPONSE=$(echo "$TEST_RESULT" | jq -r '.body // empty')

print_info "Test invoke status: $TEST_STATUS"

if [[ "$TEST_STATUS" == "200" ]]; then
    print_success "Test invoke returned 200 OK"
    print_info "Response: ${TEST_BODY_RESPONSE:0:100}"
elif [[ "$TEST_STATUS" == "403" ]]; then
    print_error "Test invoke returned 403 (may need API key in Lambda integration)"
    print_info "Response: ${TEST_BODY_RESPONSE:0:100}"
else
    print_warning "Test invoke returned $TEST_STATUS"
    print_info "Response: ${TEST_BODY_RESPONSE:0:200}"
fi

################################################################################
# Step 7: Redeploy if needed
################################################################################

if [[ "${NEEDS_REDEPLOY:-false}" == "true" ]]; then
    print_banner "REDEPLOYING API"
    
    aws apigateway create-deployment \
        --rest-api-id "$API_ID" \
        --stage-name "$STAGE_NAME" \
        --region "$REGION" 2>/dev/null || true
    
    print_success "API redeployed to stage $STAGE_NAME"
    sleep 2
fi

################################################################################
# Step 8: Sanity Check - cURL Commands
################################################################################

print_banner "STEP 8: SANITY CHECK - CURL COMMANDS"

ENDPOINT_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/submit"

print_info "Endpoint: $ENDPOINT_URL"
print_info ""
print_info "Test WITHOUT API Key (should be 403 if key required):"
echo ""
echo -e "${YELLOW}curl -i -X POST \"${ENDPOINT_URL}\" \\${NC}"
echo -e "${YELLOW}  -H 'Content-Type: application/json' \\${NC}"
echo -e "${YELLOW}  -d '{\"form_id\":\"test\",\"message\":\"hello\"}'${NC}"
echo ""

if [[ -n "$API_KEY_VALUE" ]]; then
    print_info "Test WITH API Key (should be 200 if all else OK):"
    echo ""
    echo -e "${GREEN}curl -i -X POST \"${ENDPOINT_URL}\" \\${NC}"
    echo -e "${GREEN}  -H 'Content-Type: application/json' \\${NC}"
    echo -e "${GREEN}  -H 'X-Api-Key: ${API_KEY_VALUE}' \\${NC}"
    echo -e "${GREEN}  -d '{\"form_id\":\"test\",\"message\":\"hello with key\"}'${NC}"
    echo ""
fi

################################################################################
# Step 9: Enable Execution Logs (if not already)
################################################################################

print_banner "STEP 9: ENABLE EXECUTION LOGGING"

if [[ "$EXECUTION_LOGS" == "OFF" ]]; then
    if [[ "$AUDIT_ONLY" == "true" ]]; then
        print_warning "Execution logging is OFF"
        print_info "To enable: run with --fix-permissive flag"
        print_info "Or manually in AWS Console → API Gateway → $STAGE_NAME → Logs/Tracing"
    else
        print_warning "Enabling execution logging..."
        
        aws apigateway update-stage \
            --rest-api-id "$API_ID" \
            --stage-name "$STAGE_NAME" \
            --patch-operations \
                op=replace,path=/*/*/logging/loglevel,value=INFO \
                op=replace,path=/*/*/logging/datatraceenabled,value=true \
            --region "$REGION" 2>/dev/null || true
        
        print_success "Execution logging enabled"
    fi
else
    print_success "Execution logging already enabled"
fi

################################################################################
# Step 10: CloudWatch Query Instructions
################################################################################

print_banner "STEP 10: CLOUDWATCH LOG GROUP NAME"

LOG_GROUP="/aws/apigateway/${API_ID}/${STAGE_NAME}"
print_info "CloudWatch Log Group: $LOG_GROUP"
print_info ""
print_info "To view logs, run:"
echo ""
echo -e "${YELLOW}aws logs tail \"${LOG_GROUP}\" --follow --region ${REGION}${NC}"
echo ""
print_info "Or use CloudWatch Logs Insights:"
echo ""
echo -e "${YELLOW}aws logs start-query \\${NC}"
echo -e "${YELLOW}  --log-group-name \"${LOG_GROUP}\" \\${NC}"
echo -e "${YELLOW}  --start-time \$((\$(date +%s) - 300)) \\${NC}"
echo -e "${YELLOW}  --end-time \$(date +%s) \\${NC}"
echo -e "${YELLOW}  --query-string 'fields @timestamp, @message | filter @message like /403|Forbidden|Access denied|Method request/ | sort @timestamp desc | limit 50' \\${NC}"
echo -e "${YELLOW}  --region ${REGION}${NC}"
echo ""

################################################################################
# Summary and Next Steps
################################################################################

print_banner "SUMMARY & NEXT STEPS"

echo ""
print_info "✓ Diagnostic complete."
echo ""

if [[ "$AUDIT_ONLY" == "true" ]]; then
    print_info "Running in AUDIT-ONLY mode."
    echo ""
    print_warning "To apply fixes (permissive policy, enable logging):"
    echo "  $0 --fix-permissive"
    echo ""
fi

print_info "If still getting 403:"
echo "  1. Verify API key is being sent in X-Api-Key header"
echo "  2. Check CloudWatch logs: $LOG_GROUP"
echo "  3. Confirm usage plan binding: API + Stage + Key"
echo "  4. Run test-invoke-method (step 6 output above)"
echo ""

if [[ -n "$API_KEY_VALUE" ]]; then
    print_success "Ready to test with k6:"
    echo ""
    echo "  export BASE_URL=\"https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}\""
    echo "  export API_KEY=\"${API_KEY_VALUE}\""
    echo "  k6 run loadtest/submit_smoke.js"
    echo ""
fi

print_banner "DIAGNOSTIC COMPLETE"
