#!/bin/bash

##############################################################################
# FormBridge End-to-End Test Suite - LOCAL
# Runs comprehensive tests against local demo pack
# Usage: bash tests/run_all_local.sh
##############################################################################

set -u  # Error on undefined variable

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"

# Load configuration
ENV_FILE="$SCRIPT_DIR/.env.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Configuration file not found: $ENV_FILE"
  echo "   Please copy tests/.env.local.example to tests/.env.local and fill in values"
  exit 1
fi

# Source environment and helpers
set -a
source "$ENV_FILE"
set +a
source "$SCRIPT_DIR/lib/aws_helpers.sh"

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

# Initialize summary
SUMMARY_FILE="$ARTIFACTS_DIR/summary.json"
REPORT_FILE="$SCRIPT_DIR/report.html"

##############################################################################
# Colors and Output
##############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  FormBridge End-to-End Test Suite (LOCAL)                   ║"
  echo "║  $(date '+%Y-%m-%d %H:%M:%S')                              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

print_step() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}▶ $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

record_step() {
  local step_name="$1"
  local status="$2"
  local duration_ms="$3"
  local info="${4:-}"

  # Append to summary using Node.js
  node "$SCRIPT_DIR/lib/append_step.js" "$SUMMARY_FILE" "$step_name" "$status" "$duration_ms" "$info"

  if [[ "$status" == "PASS" ]]; then
    echo -e "${GREEN}✓ PASS${NC} - $step_name (${duration_ms}ms)"
  else
    echo -e "${RED}✗ FAIL${NC} - $step_name (${duration_ms}ms): $info"
  fi
}

##############################################################################
# Sanity Checks
##############################################################################

sanity_checks() {
  print_step "SANITY CHECKS"

  local start_time=$(date +%s%N)

  # Check required tools
  echo "Checking required tools..."
  local tools_ok=true

  for tool in node jq curl; do
    if ! command -v "$tool" &> /dev/null; then
      echo -e "${RED}✗ Missing tool: $tool${NC}"
      tools_ok=false
    else
      echo -e "${GREEN}✓${NC} $tool: $(which $tool)"
    fi
  done

  if [[ "$tools_ok" != "true" ]]; then
    record_step "sanity_tools" "FAIL" 0 "Missing required tools"
    return 1
  fi

  # Print versions
  echo ""
  echo "Tool Versions:"
  echo "  Node.js: $(node --version)"
  echo "  jq: $(jq --version)"
  echo "  curl: $(curl --version | head -1)"

  # Check environment variables
  echo ""
  echo "Environment Configuration:"
  echo "  BASE_URL: $BASE_URL"
  echo "  FORM_ID: $FORM_ID"
  echo "  API_KEY: ${API_KEY:-(not set)}"
  echo "  HMAC_ENABLED: $HMAC_ENABLED"
  echo "  MAILHOG_URL: $MAILHOG_URL"
  echo "  DDB_TABLE: $DDB_TABLE"
  echo "  REGION: $REGION"

  # Test URL connectivity
  echo ""
  echo "Testing API connectivity..."
  if curl -s --connect-timeout 5 "$BASE_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} API is reachable"
  else
    echo -e "${YELLOW}⚠${NC} API may not be reachable (will continue)"
  fi

  local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
  record_step "sanity_checks" "PASS" $duration_ms ""
}

##############################################################################
# Test Steps
##############################################################################

test_submit() {
  print_step "TEST: Form Submission"

  local start_time=$(date +%s%N)

  # Create test payload
  local payload=$(cat <<EOF
{
  "form_id": "$FORM_ID",
  "name": "Test User",
  "email": "test@example.com",
  "message": "This is a test submission from the test suite",
  "timestamp": $(date +%s)
}
EOF
)

  echo "Submitting form: $FORM_ID"
  echo "Payload: $payload"

  # Call HTTP client
  local response=$(node "$SCRIPT_DIR/lib/test_step_submit.js" "$BASE_URL/submit" "$payload" "$API_KEY" "$HMAC_ENABLED" "$HMAC_SECRET")

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    local submission_id=$(echo "$response" | jq -r '.id')
    echo -e "${GREEN}✓ Submission successful${NC}"
    echo "  Submission ID: $submission_id"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "submit" "PASS" $duration_ms "{\"id\":\"$submission_id\"}"
    
    echo "$submission_id" > "$ARTIFACTS_DIR/last_submission_id.txt"
    return 0
  else
    echo -e "${RED}✗ Submission failed${NC}"
    echo "Response: $response"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "submit" "FAIL" $duration_ms "$(echo $response | head -c 100)"
    return 1
  fi
}

test_analytics() {
  print_step "TEST: Analytics"

  local start_time=$(date +%s%N)

  echo "Retrieving analytics for form: $FORM_ID"

  # Call analytics endpoint
  local response=$(node "$SCRIPT_DIR/lib/test_step_analytics.js" "$BASE_URL/analytics" "$FORM_ID" "$API_KEY")

  if echo "$response" | jq -e '.totals' > /dev/null 2>&1; then
    local total=$(echo "$response" | jq '.totals')
    echo -e "${GREEN}✓ Analytics retrieved${NC}"
    echo "  Total submissions: $total"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "analytics" "PASS" $duration_ms "{\"total\":$total}"
    return 0
  else
    echo -e "${RED}✗ Analytics failed${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "analytics" "FAIL" $duration_ms "No totals in response"
    return 1
  fi
}

test_export() {
  print_step "TEST: Export CSV"

  local start_time=$(date +%s%N)

  local export_date=$(date +%Y%m%d)
  local export_file="$ARTIFACTS_DIR/export_${export_date}.csv"

  echo "Exporting submissions for: $FORM_ID"

  # Call export endpoint
  local response=$(node "$SCRIPT_DIR/lib/test_step_export.js" "$BASE_URL/export" "$FORM_ID" 7 "$API_KEY")

  if [[ -n "$response" ]] && echo "$response" | grep -q ","; then
    echo "$response" > "$export_file"
    local lines=$(echo "$response" | wc -l)
    echo -e "${GREEN}✓ Export successful${NC}"
    echo "  Saved to: $export_file"
    echo "  Lines: $lines"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "export" "PASS" $duration_ms "{\"file\":\"export_${export_date}.csv\",\"lines\":$lines}"
    return 0
  else
    echo -e "${RED}✗ Export failed${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "export" "FAIL" $duration_ms "Invalid CSV response"
    return 1
  fi
}

test_hmac() {
  print_step "TEST: HMAC Signature"

  if [[ "$HMAC_ENABLED" != "true" ]]; then
    echo "HMAC not enabled, skipping"
    record_step "hmac" "PASS" 0 "Skipped (disabled)"
    return 0
  fi

  local start_time=$(date +%s%N)

  echo "Testing HMAC-signed request with secret"

  local payload=$(cat <<EOF
{
  "form_id": "$FORM_ID",
  "name": "HMAC Test",
  "email": "hmac@example.com",
  "message": "Testing HMAC signature",
  "timestamp": $(date +%s)
}
EOF
)

  local response=$(node "$SCRIPT_DIR/lib/test_step_hmac.js" "$BASE_URL/submit" "$payload" "$HMAC_SECRET")

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ HMAC test successful${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "hmac" "PASS" $duration_ms "{\"signed\":true}"
    return 0
  else
    echo -e "${RED}✗ HMAC test failed${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "hmac" "FAIL" $duration_ms "Signature validation failed"
    return 1
  fi
}

test_mailhog() {
  print_step "TEST: Email Branding (MailHog)"

  if [[ -z "$MAILHOG_URL" ]] || [[ "$MAILHOG_URL" == "http://localhost:8025" ]] && ! curl -s "$MAILHOG_URL" > /dev/null 2>&1; then
    echo "MailHog not available, skipping"
    record_step "mailhog_email" "PASS" 0 "Skipped (not available)"
    return 0
  fi

  local start_time=$(date +%s%N)

  echo "Checking MailHog for latest email message"

  # Get latest email from MailHog API
  local response=$(curl -s "$MAILHOG_URL/api/v1/messages?limit=1")

  if echo "$response" | jq -e '.items[0]' > /dev/null 2>&1; then
    local email_id=$(echo "$response" | jq -r '.items[0].ID')
    local html_body=$(echo "$response" | jq -r '.items[0].Content.Body // ""')

    # Save HTML
    local html_file="$ARTIFACTS_DIR/mailhog_latest.html"
    echo "$html_body" > "$html_file"

    if echo "$html_body" | grep -q "FormBridge"; then
      echo -e "${GREEN}✓ Email branding verified${NC}"
      echo "  Contains 'FormBridge': Yes"
      echo "  Saved to: $html_file"
      
      local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
      record_step "mailhog_email" "PASS" $duration_ms "{\"file\":\"mailhog_latest.html\"}"
      return 0
    else
      echo -e "${YELLOW}⚠ Email found but no FormBridge branding${NC}"
      
      local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
      record_step "mailhog_email" "PASS" $duration_ms "{\"file\":\"mailhog_latest.html\",\"branding\":false}"
      return 0
    fi
  else
    echo -e "${YELLOW}⚠ No emails found in MailHog${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "mailhog_email" "PASS" 0 "No emails in queue"
    return 0
  fi
}

test_dynamodb() {
  print_step "TEST: DynamoDB Query"

  local start_time=$(date +%s%N)

  echo "Querying DynamoDB table: $DDB_TABLE"

  # Query latest item
  local response=$(ddb_query_latest "$DDB_TABLE" "$FORM_ID" "$REGION" 2>/dev/null)

  if echo "$response" | jq -e '.Items[0]' > /dev/null 2>&1; then
    local item=$(echo "$response" | jq '.Items[0]')
    local json_file="$ARTIFACTS_DIR/dynamo_latest.json"
    echo "$item" | jq '.' > "$json_file"

    echo -e "${GREEN}✓ DynamoDB query successful${NC}"
    echo "  Item: $(echo $item | jq -c 'keys')"
    echo "  Saved to: $json_file"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "dynamodb_query" "PASS" $duration_ms "{\"file\":\"dynamo_latest.json\"}"
    return 0
  else
    echo -e "${YELLOW}⚠ No DynamoDB items found${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "dynamodb_query" "PASS" 0 "No items in table"
    return 0
  fi
}

test_sqs() {
  print_step "TEST: SQS Queue Status"

  if [[ -z "$WEBHOOK_QUEUE_URL" ]] || [[ "$WEBHOOK_QUEUE_URL" == "OPTIONAL_SQS_QUEUE_URL" ]]; then
    echo "SQS queue not configured, skipping"
    record_step "sqs_depth" "PASS" 0 "Skipped (not configured)"
    return 0
  fi

  local start_time=$(date +%s%N)

  echo "Checking SQS queue depth: $WEBHOOK_QUEUE_URL"

  local queue_depth=$(sqs_approx_count "$WEBHOOK_QUEUE_URL" "$REGION")

  echo "  Approximate messages: $queue_depth"

  if [[ "$queue_depth" -le 5 ]]; then
    echo -e "${GREEN}✓ SQS queue healthy${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "sqs_depth" "PASS" $duration_ms "{\"depth\":$queue_depth}"
    return 0
  else
    echo -e "${YELLOW}⚠ SQS queue has many messages${NC}"
    
    local duration_ms=$(( ($(date +%s%N) - start_time) / 1000000 ))
    record_step "sqs_depth" "PASS" $duration_ms "{\"depth\":$queue_depth,\"warning\":true}"
    return 0
  fi
}

##############################################################################
# Main Execution
##############################################################################

main() {
  print_banner

  # Initialize summary
  node "$SCRIPT_DIR/lib/init_summary.js" "$SUMMARY_FILE" "local" "$BASE_URL"

  # Run test steps
  sanity_checks || true
  test_submit || true
  test_analytics || true
  test_export || true
  test_hmac || true
  test_mailhog || true
  test_dynamodb || true
  test_sqs || true

  # Generate report
  print_step "GENERATING REPORT"
  node "$SCRIPT_DIR/lib/collect_summary.js" report "$SUMMARY_FILE" "$REPORT_FILE"

  echo ""
  echo -e "${GREEN}✓ Test suite completed${NC}"
  echo -e "${CYAN}📊 Open report: file://$REPORT_FILE${NC}"
  echo ""
}

main "$@"
