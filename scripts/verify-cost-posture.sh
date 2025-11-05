#!/bin/bash
##############################################################################
# verify-cost-posture.sh
# Read-only auditor for FormBridge cost posture
# Reports: tagged resources, estimated costs, PITR/TTL status, queue depths,
# SES sandbox status, and API Gateway usage metrics
#
# Usage:
#   REGION=ap-south-1 bash scripts/verify-cost-posture.sh
#
# Env vars:
#   REGION        - AWS region (default: ap-south-1)
##############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REGION="${REGION:-ap-south-1}"
PROFILE="${AWS_PROFILE:-default}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE")

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

section() {
  echo ""
  echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
}

##############################################################################
# Tagged Resources
##############################################################################

audit_tagged_resources() {
  section "ðŸ“Š TAGGED RESOURCES (Project=FormBridge)"
  
  log_info "Scanning for FormBridge-tagged resources..."
  echo ""
  
  # Lambda
  log_info "Lambda Functions:"
  LAMBDAS=$(aws lambda list-functions \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Functions[].FunctionArn" \
    --output text 2>/dev/null || echo "")
  
  TAGGED_LAMBDAS=0
  for ARN in $LAMBDAS; do
    TAGS=$(aws lambda list-tags \
      --resource "$ARN" \
      --profile "$PROFILE" \
      --query "Tags | select_value (. == null, {}, .)" \
      --output json 2>/dev/null || echo "{}")
    
    if echo "$TAGS" | jq -e '.Project == "FormBridge"' >/dev/null 2>&1; then
      FUNC_NAME=$(echo "$ARN" | awk -F: '{print $NF}')
      log_success "  âœ“ $FUNC_NAME (tagged)"
      ((TAGGED_LAMBDAS++))
    fi
  done
  echo "  Total tagged: $TAGGED_LAMBDAS"
  echo ""
  
  # DynamoDB
  log_info "DynamoDB Tables:"
  TABLES=$(aws dynamodb list-tables \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "TableNames" \
    --output text 2>/dev/null || echo "")
  
  TAGGED_TABLES=0
  for TABLE in $TABLES; do
    TABLE_ARN=$(aws dynamodb describe-table \
      --table-name "$TABLE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Table.TableArn" \
      --output text 2>/dev/null || echo "")
    
    TAGS=$(aws dynamodb list-tags-of-resource \
      --resource-arn "$TABLE_ARN" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Tags" \
      --output json 2>/dev/null || echo "[]")
    
    if echo "$TAGS" | jq -e '.[] | select(.Key == "Project" and .Value == "FormBridge")' >/dev/null 2>&1; then
      log_success "  âœ“ $TABLE (tagged)"
      ((TAGGED_TABLES++))
    fi
  done
  echo "  Total tagged: $TAGGED_TABLES"
  echo ""
  
  # API Gateway
  log_info "API Gateway:"
  APIS=$(aws apigateway get-rest-apis \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "items[].id" \
    --output text 2>/dev/null || echo "")
  
  for API_ID in $APIS; do
    TAGS=$(aws apigateway get-tags \
      --resource-arn "arn:aws:apigateway:$REGION::/restapis/$API_ID" \
      --profile "$PROFILE" \
      --output json 2>/dev/null || echo "{}")
    
    if echo "$TAGS" | jq -e '.tags.Project == "FormBridge"' >/dev/null 2>&1; then
      log_success "  âœ“ $API_ID (tagged)"
    fi
  done
  echo ""
  
  # SQS
  log_info "SQS Queues:"
  QUEUES=$(aws sqs list-queues \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "QueueUrls[]" \
    --output text 2>/dev/null || echo "")
  
  TAGGED_QUEUES=0
  for QUEUE_URL in $QUEUES; do
    TAGS=$(aws sqs list-queue-tags \
      --queue-url "$QUEUE_URL" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Tags" \
      --output json 2>/dev/null || echo "{}")
    
    if echo "$TAGS" | jq -e '.Project == "FormBridge"' >/dev/null 2>&1; then
      QUEUE_NAME=$(echo "$QUEUE_URL" | awk -F/ '{print $NF}')
      log_success "  âœ“ $QUEUE_NAME (tagged)"
      ((TAGGED_QUEUES++))
    fi
  done
  echo "  Total tagged: $TAGGED_QUEUES"
}

##############################################################################
# Cost Estimation
##############################################################################

audit_cost_estimation() {
  section "ðŸ’° ESTIMATED COSTS (Last 7 Days)"
  
  log_info "Retrieving cost data from Cost Explorer..."
  
  END_DATE=$(date +%Y-%m-%d)
  START_DATE=$(date -d '7 days ago' +%Y-%m-%d)
  
  COSTS=$(aws ce get-cost-and-usage \
    --time-period Start="$START_DATE",End="$END_DATE" \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --filter "Tags={Key={Key=Project,Values=[FormBridge]}}" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --output json 2>/dev/null || echo "{}")
  
  if echo "$COSTS" | jq -e '.ResultsByTime' >/dev/null 2>&1; then
    TOTAL_COST=$(echo "$COSTS" | jq -r '.ResultsByTime | map(.Total.UnblendedCost.Amount | tonumber) | add' 2>/dev/null || echo "0")
    
    if (( $(echo "$TOTAL_COST > 0" | bc -l) )); then
      log_success "Total cost (7 days): USD \$$(printf '%.2f' "$TOTAL_COST")"
      
      # Daily average
      AVG_DAILY=$(echo "scale=2; $TOTAL_COST / 7" | bc)
      MONTHLY_EST=$(echo "scale=2; $AVG_DAILY * 30" | bc)
      
      log_info "Daily average:      USD \$${AVG_DAILY}"
      log_info "Monthly estimate:   USD \$${MONTHLY_EST}"
      
      if (( $(echo "$MONTHLY_EST > 10" | bc -l) )); then
        log_warn "âš ï¸  Monthly estimate exceeds \$10 (consider optimization)"
      fi
    else
      log_info "No cost data available or cost is \$0"
    fi
  else
    log_warn "Could not retrieve cost data"
  fi
  
  echo ""
}

##############################################################################
# DynamoDB Configuration
##############################################################################

audit_dynamodb() {
  section "ðŸ“¦ DYNAMODB CONFIGURATION"
  
  TABLES=$(aws dynamodb list-tables \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "TableNames" \
    --output text 2>/dev/null || echo "")
  
  for TABLE in $TABLES; do
    if [[ ! "$TABLE" =~ formbridge ]]; then
      continue
    fi
    
    log_info "Table: $TABLE"
    
    TABLE_DESC=$(aws dynamodb describe-table \
      --table-name "$TABLE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --output json 2>/dev/null || echo "{}")
    
    # BillingMode
    BILLING_MODE=$(echo "$TABLE_DESC" | jq -r '.Table.BillingModeSummary.BillingMode // "PAY_PER_REQUEST"')
    if [[ "$BILLING_MODE" == "PAY_PER_REQUEST" ]]; then
      log_success "  âœ“ BillingMode: $BILLING_MODE"
    else
      log_warn "  âš  BillingMode: $BILLING_MODE (consider ON_DEMAND)"
    fi
    
    # TTL
    TTL_STATUS=$(echo "$TABLE_DESC" | jq -r '.Table.TimeToLiveDescription.TimeToLiveStatus // "DISABLED"')
    if [[ "$TTL_STATUS" == "ENABLED" ]]; then
      TTL_ATTR=$(echo "$TABLE_DESC" | jq -r '.Table.TimeToLiveDescription.AttributeName // "N/A"')
      log_success "  âœ“ TTL: ENABLED (attr: $TTL_ATTR)"
    else
      log_warn "  âš  TTL: DISABLED (enable for auto-cleanup)"
    fi
    
    # PITR
    PITR_STATUS=$(echo "$TABLE_DESC" | jq -r '.Table.ContinuousBackupsDescription.ContinuousBackupsStatus // "DISABLED"')
    if [[ "$PITR_STATUS" == "DISABLED" ]]; then
      log_success "  âœ“ PITR: DISABLED (lower cost)"
    else
      log_warn "  â„¹ PITR: $PITR_STATUS (adds cost for recovery, only use if needed)"
    fi
    
    # Item count
    ITEM_COUNT=$(echo "$TABLE_DESC" | jq -r '.Table.ItemCount // 0')
    log_info "  Items: $ITEM_COUNT"
    
    echo ""
  done
}

##############################################################################
# SQS Configuration
##############################################################################

audit_sqs() {
  section "ðŸš€ SQS QUEUE CONFIGURATION"
  
  log_info "Checking queue depths and retention..."
  echo ""
  
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
    
    log_info "Queue: $QUEUE"
    
    ATTRS=$(aws sqs get-queue-attributes \
      --queue-url "$QUEUE_URL" \
      --attribute-names All \
      --region "$REGION" \
      --profile "$PROFILE" \
      --output json 2>/dev/null || echo "{}")
    
    if [[ "$ATTRS" == "{}" ]]; then
      continue
    fi
    
    # Depth
    DEPTH=$(echo "$ATTRS" | jq -r '.Attributes.ApproximateNumberOfMessages // 0')
    if [[ "$DEPTH" == "0" ]]; then
      log_success "  âœ“ Queue depth: $DEPTH messages (empty)"
    elif [[ $(echo "$DEPTH > 1000" | bc) -eq 1 ]]; then
      log_warn "  âš  Queue depth: $DEPTH messages (consider investigation)"
    else
      log_info "  Queue depth: $DEPTH messages"
    fi
    
    # Retention
    RETENTION=$(echo "$ATTRS" | jq -r '.Attributes.MessageRetentionPeriod // 345600')
    RETENTION_DAYS=$((RETENTION / 86400))
    
    if [[ "$QUEUE" == "formbridge-webhook-dlq" ]]; then
      log_info "  Retention: ${RETENTION_DAYS} days (DLQ)"
    else
      if [[ "$RETENTION_DAYS" -le 4 ]]; then
        log_success "  âœ“ Retention: ${RETENTION_DAYS} days (good for cost)"
      else
        log_warn "  âš  Retention: ${RETENTION_DAYS} days (consider reducing)"
      fi
    fi
    
    # Visibility timeout
    VIS_TIMEOUT=$(echo "$ATTRS" | jq -r '.Attributes.VisibilityTimeout // 30')
    log_info "  Visibility timeout: ${VIS_TIMEOUT}s"
    
    # maxReceiveCount
    if [[ "$QUEUE" == "formbridge-webhook-queue" ]]; then
      REDRIVE=$(echo "$ATTRS" | jq -r '.Attributes.RedrivePolicy // "{}"')
      MAX_RECEIVES=$(echo "$REDRIVE" | jq -r 'fromjson | .maxReceiveCount // 0')
      if [[ "$MAX_RECEIVES" -eq 5 ]]; then
        log_success "  âœ“ DLQ maxReceiveCount: $MAX_RECEIVES (optimal)"
      else
        log_warn "  âš  DLQ maxReceiveCount: $MAX_RECEIVES (consider 5)"
      fi
    fi
    
    echo ""
  done
}

##############################################################################
# SES Configuration
##############################################################################

audit_ses() {
  section "ðŸ“§ SES CONFIGURATION"
  
  # Check if account is in sandbox
  QUOTA=$(aws ses get-account-sending-enabled \
    --region "$REGION" \
    --profile "$PROFILE" \
    --output json 2>/dev/null || echo "{}")
  
  SENDING_ENABLED=$(echo "$QUOTA" | jq -r '.Enabled // false')
  
  if [[ "$SENDING_ENABLED" == "true" ]]; then
    log_success "âœ“ SES: Production (sending enabled)"
  else
    log_warn "âš  SES: Sandbox mode (limited to verified recipients only)"
  fi
  
  # Verified identities
  IDENTITIES=$(aws ses list-identities \
    --region "$REGION" \
    --profile "$PROFILE" \
    --identity-type EmailAddress \
    --query "Identities" \
    --output text 2>/dev/null || echo "")
  
  IDENTITY_COUNT=$(echo "$IDENTITIES" | wc -w)
  log_info "Verified identities: $IDENTITY_COUNT"
  
  for IDENTITY in $IDENTITIES; do
    STATUS=$(aws ses get-identity-verification-attributes \
      --identities "$IDENTITY" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "VerificationAttributes[\"$IDENTITY\"].VerificationStatus" \
      --output text 2>/dev/null || echo "Unknown")
    
    if [[ "$STATUS" == "Success" ]]; then
      log_success "  âœ“ $IDENTITY"
    else
      log_warn "  âš  $IDENTITY ($STATUS)"
    fi
  done
  
  echo ""
}

##############################################################################
# API Gateway Metrics
##############################################################################

audit_api_gateway() {
  section "ðŸŒ API GATEWAY METRICS (Last 7 Days)"
  
  API_ID=$(aws apigateway get-rest-apis \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "items[0].id" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$API_ID" || "$API_ID" == "None" ]]; then
    log_warn "No API Gateway found"
    return
  fi
  
  log_info "API Gateway: $API_ID"
  echo ""
  
  END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
  START_TIME=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S)
  
  # Request count
  REQUEST_COUNT=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Count \
    --dimensions Name=ApiName,Value="$API_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 604800 \
    --statistics Sum \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Datapoints[0].Sum" \
    --output text 2>/dev/null || echo "N/A")
  
  log_info "Total requests (7d):   $REQUEST_COUNT"
  
  # 4XX errors
  ERROR_4XX=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name 4XXError \
    --dimensions Name=ApiName,Value="$API_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 604800 \
    --statistics Sum \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Datapoints[0].Sum" \
    --output text 2>/dev/null || echo "0")
  
  if [[ "$ERROR_4XX" != "N/A" && $(echo "$ERROR_4XX > 0" | bc -l) -eq 1 ]]; then
    log_warn "  4XX errors (7d):       $ERROR_4XX"
  else
    log_success "  âœ“ 4XX errors (7d):       0"
  fi
  
  # 5XX errors
  ERROR_5XX=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name 5XXError \
    --dimensions Name=ApiName,Value="$API_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 604800 \
    --statistics Sum \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Datapoints[0].Sum" \
    --output text 2>/dev/null || echo "0")
  
  if [[ "$ERROR_5XX" != "N/A" && $(echo "$ERROR_5XX > 0" | bc -l) -eq 1 ]]; then
    log_error "  âœ— 5XX errors (7d):       $ERROR_5XX"
  else
    log_success "  âœ“ 5XX errors (7d):       0"
  fi
  
  # Latency
  LATENCY=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApiGateway \
    --metric-name Latency \
    --dimensions Name=ApiName,Value="$API_ID" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 604800 \
    --statistics Average \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Datapoints[0].Average" \
    --output text 2>/dev/null || echo "N/A")
  
  if [[ "$LATENCY" != "N/A" ]]; then
    log_info "  Average latency:       ${LATENCY}ms"
  fi
  
  echo ""
}

##############################################################################
# Lambda Metrics
##############################################################################

audit_lambda_metrics() {
  section "âš¡ LAMBDA METRICS (Last 7 Days)"
  
  FUNCTIONS=$(aws lambda list-functions \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Functions[?contains(FunctionName, 'formbridge') || contains(FunctionName, 'FormBridge')].FunctionName" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$FUNCTIONS" ]]; then
    log_info "No FormBridge Lambda functions found"
    return
  fi
  
  END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
  START_TIME=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S)
  
  for FUNC in $FUNCTIONS; do
    log_info "Function: $FUNC"
    
    # Invocations
    INVOCATIONS=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda \
      --metric-name Invocations \
      --dimensions Name=FunctionName,Value="$FUNC" \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --period 604800 \
      --statistics Sum \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Datapoints[0].Sum" \
      --output text 2>/dev/null || echo "0")
    
    log_info "  Invocations (7d):      $INVOCATIONS"
    
    # Errors
    ERRORS=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda \
      --metric-name Errors \
      --dimensions Name=FunctionName,Value="$FUNC" \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --period 604800 \
      --statistics Sum \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Datapoints[0].Sum" \
      --output text 2>/dev/null || echo "0")
    
    if [[ $(echo "$ERRORS > 0" | bc -l) -eq 1 ]]; then
      log_warn "  Errors (7d):           $ERRORS"
    else
      log_success "  âœ“ Errors (7d):           0"
    fi
    
    # Duration
    DURATION=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda \
      --metric-name Duration \
      --dimensions Name=FunctionName,Value="$FUNC" \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --period 604800 \
      --statistics Average \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Datapoints[0].Average" \
      --output text 2>/dev/null || echo "N/A")
    
    if [[ "$DURATION" != "N/A" ]]; then
      log_info "  Average duration:     ${DURATION}ms"
    fi
    
    echo ""
  done
}

##############################################################################
# Summary & Recommendations
##############################################################################

print_recommendations() {
  section "ðŸ’¡ RECOMMENDATIONS"
  
  echo "1. ðŸ” Regular Audits"
  echo "   Run this script weekly to monitor cost trends"
  echo ""
  
  echo "2. ðŸ’° Budget Alerts"
  echo "   Verify FormBridge-Monthly-Budget is configured"
  echo "   Visit: https://console.aws.amazon.com/budgets/"
  echo ""
  
  echo "3. ðŸ·ï¸  Tagging"
  echo "   All FormBridge resources should have Project=FormBridge tag"
  echo "   Use for cost allocation and filtering"
  echo ""
  
  echo "4. ðŸ—‘ï¸  Cleanup"
  echo "   Enable DynamoDB TTL for automatic item expiration"
  echo "   Monitor SQS queue depths for stuck messages"
  echo ""
  
  echo "5. ðŸ“Š Cost Explorer"
  echo "   Filter by Project tag for detailed analysis"
  echo "   Visit: https://console.aws.amazon.com/cost-management/"
  echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
  log_info "FormBridge Cost Posture Audit"
  log_info "Region: $REGION | Account: $ACCOUNT_ID"
  echo ""
  
  audit_tagged_resources
  audit_cost_estimation
  audit_dynamodb
  audit_sqs
  audit_ses
  audit_api_gateway
  audit_lambda_metrics
  print_recommendations
  
  section "âœ… AUDIT COMPLETE"
  log_success "Cost posture review finished"
  echo ""
}

main "$@"
