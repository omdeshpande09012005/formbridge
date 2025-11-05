#!/bin/bash

##############################################################################
# FormBridge AWS Helpers - Bash functions for DynamoDB, SQS, CloudWatch
##############################################################################

set -u  # Error on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

##############################################################################
# Utility Functions
##############################################################################

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

##############################################################################
# DynamoDB Query Functions
##############################################################################

# Query latest item from DynamoDB by form_id
# Usage: ddb_query_latest "contact-form-submissions-v2" "my-portfolio" "ap-south-1"
ddb_query_latest() {
  local table_name="$1"
  local form_id="$2"
  local region="${3:-ap-south-1}"

  log_info "Querying DynamoDB table: $table_name (form_id: $form_id)"

  local pk="FORM#$form_id"

  # Query with SortKey descending to get latest
  aws dynamodb query \
    --table-name "$table_name" \
    --key-condition-expression "pk = :pk" \
    --expression-attribute-values "{\":pk\": {\"S\": \"$pk\"}}" \
    --scan-index-forward false \
    --limit 1 \
    --region "$region" \
    --output json 2>/dev/null || true
}

# Count items in DynamoDB by form_id
# Usage: ddb_count_items "contact-form-submissions-v2" "my-portfolio" "ap-south-1"
ddb_count_items() {
  local table_name="$1"
  local form_id="$2"
  local region="${3:-ap-south-1}"

  log_info "Counting DynamoDB items for: $form_id"

  local pk="FORM#$form_id"

  aws dynamodb query \
    --table-name "$table_name" \
    --key-condition-expression "pk = :pk" \
    --expression-attribute-values "{\":pk\": {\"S\": \"$pk\"}}" \
    --select COUNT \
    --region "$region" \
    --output json 2>/dev/null | jq -r '.Count // 0'
}

# Scan DynamoDB table for all items (limited)
# Usage: ddb_scan_items "contact-form-submissions-v2" "ap-south-1" 10
ddb_scan_items() {
  local table_name="$1"
  local region="${2:-ap-south-1}"
  local limit="${3:-10}"

  log_info "Scanning DynamoDB table: $table_name (limit: $limit)"

  aws dynamodb scan \
    --table-name "$table_name" \
    --limit "$limit" \
    --region "$region" \
    --output json 2>/dev/null || true
}

##############################################################################
# SQS Queue Functions
##############################################################################

# Get SQS queue depth (approximate messages)
# Usage: sqs_queue_depth "https://sqs.ap-south-1.amazonaws.com/..." "ap-south-1"
sqs_queue_depth() {
  local queue_url="$1"
  local region="${2:-ap-south-1}"

  if [[ -z "$queue_url" ]] || [[ "$queue_url" == "OPTIONAL_SQS_QUEUE_URL" ]]; then
    log_warning "SQS Queue URL not configured, skipping"
    return 0
  fi

  log_info "Getting SQS queue depth: $queue_url"

  aws sqs get-queue-attributes \
    --queue-url "$queue_url" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --region "$region" \
    --output json 2>/dev/null | \
    jq -r '.Attributes | "\(.ApproximateNumberOfMessages) messages, \(.ApproximateNumberOfMessagesNotVisible) in-flight"'
}

# Get approximate message count
sqs_approx_count() {
  local queue_url="$1"
  local region="${2:-ap-south-1}"

  if [[ -z "$queue_url" ]] || [[ "$queue_url" == "OPTIONAL_SQS_QUEUE_URL" ]]; then
    echo "0"
    return 0
  fi

  aws sqs get-queue-attributes \
    --queue-url "$queue_url" \
    --attribute-names ApproximateNumberOfMessages \
    --region "$region" \
    --output json 2>/dev/null | \
    jq -r '.Attributes.ApproximateNumberOfMessages // 0'
}

##############################################################################
# SES Email Functions
##############################################################################

# Get SES send statistics
# Usage: ses_get_send_stats "ap-south-1"
ses_get_send_stats() {
  local region="${1:-ap-south-1}"

  log_info "Getting SES send statistics"

  aws ses get-send-statistics \
    --region "$region" \
    --output json 2>/dev/null || true
}

# Check if email is verified in SES
# Usage: ses_check_verified "noreply@formbridge.example.com" "ap-south-1"
ses_check_verified() {
  local email="$1"
  local region="${2:-ap-south-1}"

  log_info "Checking if email is SES verified: $email"

  aws ses list-verified-email-addresses \
    --region "$region" \
    --output json 2>/dev/null | \
    jq -r ".VerifiedEmailAddresses[] | select(. == \"$email\")" || true
}

##############################################################################
# CloudWatch Logs & Insights
##############################################################################

# Query CloudWatch Logs Insights
# Usage: cw_query_logs "/aws/lambda/contactFormProcessor" "fields @timestamp, @message | stats count()" "ap-south-1"
cw_query_logs() {
  local log_group="$1"
  local query="$2"
  local region="${3:-ap-south-1}"
  local start_time="${4:-3600}"  # Last 1 hour in seconds

  log_info "Querying CloudWatch Logs: $log_group"

  local start_epoch=$(($(date +%s) - start_time))
  local end_epoch=$(date +%s)

  # Get log streams first
  local streams=$(aws logs describe-log-streams \
    --log-group-name "$log_group" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --region "$region" \
    --output json 2>/dev/null | \
    jq -r '.logStreams[0].logStreamName // empty')

  if [[ -z "$streams" ]]; then
    log_warning "No log streams found for: $log_group"
    return 1
  fi

  # Query the log stream
  aws logs filter-log-events \
    --log-group-name "$log_group" \
    --log-stream-name "$streams" \
    --start-time $((start_epoch * 1000)) \
    --end-time $((end_epoch * 1000)) \
    --region "$region" \
    --output json 2>/dev/null || true
}

# Get CloudWatch alarms status
# Usage: cw_get_alarms "FormBridge" "ap-south-1"
cw_get_alarms() {
  local alarm_name_prefix="$1"
  local region="${2:-ap-south-1}"

  log_info "Getting CloudWatch alarms for: $alarm_name_prefix"

  aws cloudwatch describe-alarms \
    --alarm-name-prefix "$alarm_name_prefix" \
    --region "$region" \
    --output json 2>/dev/null || true
}

##############################################################################
# CloudFormation Functions
##############################################################################

# Get CloudFormation stack outputs
# Usage: cfn_get_outputs "formbridge-stack" "ap-south-1"
cfn_get_outputs() {
  local stack_name="$1"
  local region="${2:-ap-south-1}"

  log_info "Getting CloudFormation stack outputs: $stack_name"

  aws cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --region "$region" \
    --output json 2>/dev/null | \
    jq '.Stacks[0].Outputs // []'
}

# Get specific output value from stack
# Usage: cfn_get_output "formbridge-stack" "ApiEndpoint" "ap-south-1"
cfn_get_output() {
  local stack_name="$1"
  local output_key="$2"
  local region="${3:-ap-south-1}"

  aws cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --region "$region" \
    --output json 2>/dev/null | \
    jq -r ".Stacks[0].Outputs[] | select(.OutputKey == \"$output_key\") | .OutputValue // empty"
}

##############################################################################
# EC2 / General AWS Functions
##############################################################################

# Get current AWS account ID
get_account_id() {
  aws sts get-caller-identity --output json 2>/dev/null | jq -r '.Account'
}

# Get current AWS user/role
get_caller_identity() {
  aws sts get-caller-identity --output json 2>/dev/null | jq -r '.Arn'
}

##############################################################################
# Export functions
##############################################################################

export -f log_info log_success log_error log_warning
export -f ddb_query_latest ddb_count_items ddb_scan_items
export -f sqs_queue_depth sqs_approx_count
export -f ses_get_send_stats ses_check_verified
export -f cw_query_logs cw_get_alarms
export -f cfn_get_outputs cfn_get_output
export -f get_account_id get_caller_identity
