#!/bin/bash
##############################################################################
# setup-cost-guardrails.sh
# Idempotent AWS CLI tool to establish cost controls for FormBridge
# Creates budgets, SNS alerts, applies mandatory tagging, verifies DynamoDB/SQS
#
# Usage:
#   REGION=ap-south-1 ALERT_EMAIL=ops@example.com BUDGET_LIMIT=3.00 \
#     bash scripts/setup-cost-guardrails.sh
#
# Placeholders (set as env vars):
#   REGION        - AWS region (default: ap-south-1)
#   ALERT_EMAIL   - Email for budget alerts (required)
#   BUDGET_LIMIT  - Monthly budget in USD (default: 3.00)
##############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults
REGION="${REGION:-ap-south-1}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
BUDGET_LIMIT="${BUDGET_LIMIT:-3.00}"
PROFILE="${AWS_PROFILE:-default}"

# Derived variables
BUDGET_NAME="FormBridge-Monthly-Budget"
SNS_TOPIC_NAME="FormBridge-Budget-Alerts"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE" 2>/dev/null || echo "UNKNOWN")

##############################################################################
# Utility Functions
##############################################################################

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[âœ“]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

exit_error() {
  log_error "$1"
  exit 1
}

validate_inputs() {
  if [[ -z "$ALERT_EMAIL" ]]; then
    exit_error "ALERT_EMAIL environment variable is required. Set it and retry."
  fi
  
  if ! [[ "$BUDGET_LIMIT" =~ ^[0-9]+\.[0-9]{2}$ ]]; then
    exit_error "BUDGET_LIMIT must be in format: X.XX (e.g., 3.00)"
  fi
  
  log_info "Configuration:"
  echo "  Region:       $REGION"
  echo "  Alert Email:  $ALERT_EMAIL"
  echo "  Budget Limit: USD $BUDGET_LIMIT"
  echo "  Account ID:   $ACCOUNT_ID"
}

##############################################################################
# SNS Topic Setup
##############################################################################

setup_sns_topic() {
  log_info "Setting up SNS topic for budget alerts..."
  
  SNS_TOPIC_ARN=$(aws sns list-topics \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Topics[?contains(TopicArn, '$SNS_TOPIC_NAME')].TopicArn" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$SNS_TOPIC_ARN" ]]; then
    log_info "Creating SNS topic: $SNS_TOPIC_NAME"
    SNS_TOPIC_ARN=$(aws sns create-topic \
      --name "$SNS_TOPIC_NAME" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query TopicArn \
      --output text)
    
    # Apply cost tags to SNS topic
    aws sns tag-resource \
      --topic-arn "$SNS_TOPIC_ARN" \
      --tags Key=Project,Value=FormBridge Key=Env,Value=Prod Key=Owner,Value=OmDeshpande \
      --region "$REGION" \
      --profile "$PROFILE"
    
    log_success "SNS topic created: $SNS_TOPIC_ARN"
  else
    log_success "SNS topic exists: $SNS_TOPIC_ARN"
  fi
  
  # Check if email is already subscribed
  SUBSCRIPTION_EXISTS=$(aws sns list-subscriptions-by-topic \
    --topic-arn "$SNS_TOPIC_ARN" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Subscriptions[?Endpoint=='$ALERT_EMAIL'].SubscriptionArn" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$SUBSCRIPTION_EXISTS" ]]; then
    log_info "Subscribing email to SNS topic: $ALERT_EMAIL"
    aws sns subscribe \
      --topic-arn "$SNS_TOPIC_ARN" \
      --protocol email \
      --notification-endpoint "$ALERT_EMAIL" \
      --region "$REGION" \
      --profile "$PROFILE" > /dev/null
    
    log_warn "Email subscription pending. Please check your inbox and confirm the SNS subscription."
  else
    log_success "Email already subscribed to SNS topic"
  fi
}

##############################################################################
# AWS Budget Setup
##############################################################################

setup_budget() {
  log_info "Setting up AWS Budget: $BUDGET_NAME..."
  
  # Check if budget already exists
  BUDGET_EXISTS=$(aws budgets describe-budgets \
    --account-id "$ACCOUNT_ID" \
    --query "Budgets[?BudgetName=='$BUDGET_NAME'].BudgetName" \
    --output text 2>/dev/null || echo "")
  
  if [[ -n "$BUDGET_EXISTS" ]]; then
    log_info "Budget already exists. Updating notifications..."
  else
    log_info "Creating new budget: $BUDGET_NAME"
    
    # Create budget
    aws budgets create-budget \
      --account-id "$ACCOUNT_ID" \
      --budget "{
        \"BudgetName\": \"$BUDGET_NAME\",
        \"BudgetLimit\": {
          \"Amount\": \"$BUDGET_LIMIT\",
          \"Unit\": \"USD\"
        },
        \"TimeUnit\": \"MONTHLY\",
        \"BudgetType\": \"COST\",
        \"CostFilters\": {
          \"TagKeyValue\": [\"Project\$FormBridge\"]
        }
      }" \
      --profile "$PROFILE" 2>/dev/null || true
  fi
  
  # Set up notifications for 50%, 80%, 100%
  for THRESHOLD in 50 80 100; do
    NOTIFICATION_EXISTS=$(aws budgets describe-notifications-for-budget \
      --account-id "$ACCOUNT_ID" \
      --budget-name "$BUDGET_NAME" \
      --query "Notifications[?NotificationThreshold==$THRESHOLD && NotificationType=='ACTUAL'].NotificationArn" \
      --output text 2>/dev/null || echo "")
    
    if [[ -z "$NOTIFICATION_EXISTS" ]]; then
      log_info "Creating notification for $THRESHOLD% threshold..."
      
      aws budgets create-notification \
        --account-id "$ACCOUNT_ID" \
        --budget-name "$BUDGET_NAME" \
        --notification "{
          \"NotificationType\": \"ACTUAL\",
          \"ComparisonOperator\": \"GREATER_THAN\",
          \"NotificationThreshold\": $THRESHOLD,
          \"ThresholdType\": \"PERCENTAGE\"
        }" \
        --subscriber "{
          \"SubscriptionType\": \"SNS\",
          \"Address\": \"$SNS_TOPIC_ARN\"
        }" \
        --profile "$PROFILE" 2>/dev/null || true
    fi
  done
  
  log_success "Budget '$BUDGET_NAME' configured with alerts at 50%, 80%, and 100%"
}

##############################################################################
# Apply Cost Tags to Core Resources
##############################################################################

tag_core_resources() {
  log_info "Applying cost tags to FormBridge resources..."
  
  TAGS="Project=FormBridge Env=Prod Owner=OmDeshpande"
  TAG_ARRAY="Key=Project,Value=FormBridge Key=Env,Value=Prod Key=Owner,Value=OmDeshpande"
  
  # Lambda functions
  log_info "Tagging Lambda functions..."
  for FUNC in contactFormProcessor formbridgeWebhookDispatcher; do
    FUNC_ARN=$(aws lambda list-functions \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Functions[?FunctionName=='$FUNC'].FunctionArn" \
      --output text 2>/dev/null || echo "")
    
    if [[ -n "$FUNC_ARN" ]]; then
      aws lambda tag-resource \
        --resource "$FUNC_ARN" \
        --tags $TAGS \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || log_warn "Could not tag Lambda $FUNC"
      log_success "Tagged Lambda: $FUNC"
    fi
  done
  
  # API Gateway
  log_info "Tagging API Gateway..."
  API_ID=$(aws apigateway get-rest-apis \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "items[0].id" \
    --output text 2>/dev/null || echo "")
  
  if [[ -n "$API_ID" && "$API_ID" != "None" ]]; then
    aws apigateway tag-resource \
      --resource-arn "arn:aws:apigateway:$REGION::/restapis/$API_ID" \
      --tags $TAGS \
      --region "$REGION" \
      --profile "$PROFILE" 2>/dev/null || log_warn "Could not tag API Gateway"
    log_success "Tagged API Gateway: $API_ID"
  fi
  
  # DynamoDB tables
  log_info "Tagging DynamoDB tables..."
  for TABLE in contact-form-submissions formbridge-config; do
    TABLE_ARN=$(aws dynamodb describe-table \
      --table-name "$TABLE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Table.TableArn" \
      --output text 2>/dev/null || echo "")
    
    if [[ -n "$TABLE_ARN" && "$TABLE_ARN" != "None" ]]; then
      aws dynamodb tag-resource \
        --resource-arn "$TABLE_ARN" \
        --tags $TAG_ARRAY \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || log_warn "Could not tag DynamoDB $TABLE"
      log_success "Tagged DynamoDB: $TABLE"
    fi
  done
  
  # SQS queues
  log_info "Tagging SQS queues..."
  for QUEUE in formbridge-webhook-queue formbridge-webhook-dlq; do
    QUEUE_URL=$(aws sqs get-queue-url \
      --queue-name "$QUEUE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query QueueUrl \
      --output text 2>/dev/null || echo "")
    
    if [[ -n "$QUEUE_URL" ]]; then
      QUEUE_ARN=$(aws sqs get-queue-attributes \
        --queue-url "$QUEUE_URL" \
        --attribute-names QueueArn \
        --region "$REGION" \
        --profile "$PROFILE" \
        --query "Attributes.QueueArn" \
        --output text)
      
      aws sqs tag-queue-url \
        --queue-url "$QUEUE_URL" \
        --tags $TAGS \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || log_warn "Could not tag SQS $QUEUE"
      log_success "Tagged SQS: $QUEUE"
    fi
  done
}

##############################################################################
# Verify DynamoDB Configuration
##############################################################################

verify_dynamodb() {
  log_info "Verifying DynamoDB settings..."
  
  for TABLE in contact-form-submissions formbridge-config; do
    TABLE_DESC=$(aws dynamodb describe-table \
      --table-name "$TABLE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --output json 2>/dev/null || echo "{}")
    
    if [[ "$TABLE_DESC" == "{}" ]]; then
      log_warn "Table not found: $TABLE"
      continue
    fi
    
    # Check BillingMode
    BILLING_MODE=$(echo "$TABLE_DESC" | jq -r '.Table.BillingModeSummary.BillingMode // "PAY_PER_REQUEST"')
    if [[ "$BILLING_MODE" == "PAY_PER_REQUEST" ]]; then
      log_success "âœ“ $TABLE: BillingMode = $BILLING_MODE (good for variable load)"
    else
      log_warn "âœ— $TABLE: BillingMode = $BILLING_MODE (consider ON_DEMAND for variable load)"
    fi
    
    # Check TTL
    TTL_STATUS=$(echo "$TABLE_DESC" | jq -r '.Table.TimeToLiveDescription.TimeToLiveStatus // "DISABLED"')
    if [[ "$TTL_STATUS" == "ENABLED" ]]; then
      log_success "âœ“ $TABLE: TTL = ENABLED (auto-cleanup enabled)"
    else
      log_warn "âœ— $TABLE: TTL = $TTL_STATUS (consider enabling for cost optimization)"
    fi
    
    # Check PITR
    PITR_STATUS=$(echo "$TABLE_DESC" | jq -r '.Table.ContinuousBackupsDescription.ContinuousBackupsStatus // "DISABLED"')
    if [[ "$PITR_STATUS" == "DISABLED" ]]; then
      log_success "âœ“ $TABLE: PITR = DISABLED (lower cost)"
    else
      log_warn "  $TABLE: PITR = $PITR_STATUS (adds cost for point-in-time recovery)"
    fi
  done
}

##############################################################################
# Verify SQS Configuration
##############################################################################

verify_sqs() {
  log_info "Verifying SQS queue settings..."
  
  for QUEUE in formbridge-webhook-queue formbridge-webhook-dlq; do
    QUEUE_URL=$(aws sqs get-queue-url \
      --queue-name "$QUEUE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query QueueUrl \
      --output text 2>/dev/null || echo "")
    
    if [[ -z "$QUEUE_URL" ]]; then
      log_warn "Queue not found: $QUEUE"
      continue
    fi
    
    QUEUE_ATTRS=$(aws sqs get-queue-attributes \
      --queue-url "$QUEUE_URL" \
      --attribute-names All \
      --region "$REGION" \
      --profile "$PROFILE" \
      --output json 2>/dev/null || echo "{}")
    
    if [[ "$QUEUE_ATTRS" == "{}" ]]; then
      continue
    fi
    
    # Check message retention
    RETENTION=$(echo "$QUEUE_ATTRS" | jq -r '.Attributes.MessageRetentionPeriod // "345600"')
    RETENTION_DAYS=$((RETENTION / 86400))
    
    if [[ "$QUEUE" == "formbridge-webhook-dlq" ]]; then
      log_info "  $QUEUE: Retention = ${RETENTION_DAYS} days (DLQ: recommended)"
    else
      log_info "  $QUEUE: Retention = ${RETENTION_DAYS} days"
    fi
    
    # Check maxReceiveCount for main queue
    if [[ "$QUEUE" == "formbridge-webhook-queue" ]]; then
      MAX_RECEIVES=$(echo "$QUEUE_ATTRS" | jq -r '.Attributes.RedrivePolicy // "{}" | fromjson | .maxReceiveCount // 0')
      if [[ "$MAX_RECEIVES" -eq 5 ]]; then
        log_success "âœ“ $QUEUE: maxReceiveCount = $MAX_RECEIVES (good DLQ setup)"
      else
        log_warn "âœ— $QUEUE: maxReceiveCount = $MAX_RECEIVES (consider 5 for optimal DLQ)"
      fi
    fi
    
    # Check approximate queue depth
    QUEUE_DEPTH=$(echo "$QUEUE_ATTRS" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"')
    log_info "  $QUEUE: Approximate depth = $QUEUE_DEPTH messages"
  done
}

##############################################################################
# CloudWatch Alarms
##############################################################################

verify_cloudwatch_alarms() {
  log_info "Verifying CloudWatch alarms..."
  
  # List all FormBridge-related alarms
  ALARMS=$(aws cloudwatch describe-alarms \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "MetricAlarms[?contains(AlarmName, 'FormBridge') || contains(AlarmName, 'formbridge')]" \
    --output json 2>/dev/null || echo "[]")
  
  ALARM_COUNT=$(echo "$ALARMS" | jq 'length')
  
  if [[ "$ALARM_COUNT" -gt 0 ]]; then
    log_success "Found $ALARM_COUNT FormBridge CloudWatch alarms"
    
    # Tag each alarm
    echo "$ALARMS" | jq -r '.[] | .AlarmArn' | while read -r ALARM_ARN; do
      aws cloudwatch tag-resource \
        --resource-arn "$ALARM_ARN" \
        --tags Key=Project,Value=FormBridge Key=Env,Value=Prod Key=Owner,Value=OmDeshpande \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || true
    done
  else
    log_warn "No FormBridge CloudWatch alarms found"
  fi
}

##############################################################################
# Summary Report
##############################################################################

print_summary() {
  log_info "========================================"
  log_info "Cost Guardrails Setup Complete"
  log_info "========================================"
  
  echo ""
  echo "ðŸ“Š Budget & Alerts:"
  echo "  â€¢ Budget Name:        $BUDGET_NAME"
  echo "  â€¢ Monthly Limit:      USD $BUDGET_LIMIT"
  echo "  â€¢ Alert Thresholds:   50%, 80%, 100%"
  echo "  â€¢ SNS Topic:          $SNS_TOPIC_ARN"
  echo "  â€¢ Alert Email:        $ALERT_EMAIL"
  echo ""
  
  echo "ðŸ·ï¸  Tagging:"
  echo "  â€¢ Project:            FormBridge"
  echo "  â€¢ Environment:        Prod"
  echo "  â€¢ Owner:              OmDeshpande"
  echo ""
  
  echo "ðŸ”— Useful Links:"
  echo "  â€¢ AWS Budgets Console:"
  echo "    https://console.aws.amazon.com/budgets/home#/budgets"
  echo ""
  echo "  â€¢ Cost Explorer:"
  echo "    https://console.aws.amazon.com/cost-management/home#/custom"
  echo ""
  echo "  â€¢ CloudWatch Alarms:"
  echo "    https://console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"
  echo ""
  
  echo "âœ… Next Steps:"
  echo "  1. Confirm SNS email subscription (check your inbox)"
  echo "  2. Run verify-cost-posture.sh to audit current settings"
  echo "  3. Set up alerts on CloudWatch dashboard"
  echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
  log_info "FormBridge Cost Guardrails Setup"
  echo ""
  
  validate_inputs
  echo ""
  
  setup_sns_topic
  echo ""
  
  setup_budget
  echo ""
  
  tag_core_resources
  echo ""
  
  verify_dynamodb
  echo ""
  
  verify_sqs
  echo ""
  
  verify_cloudwatch_alarms
  echo ""
  
  print_summary
}

main "$@"
