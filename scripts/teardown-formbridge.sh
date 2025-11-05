#!/bin/bash
##############################################################################
# teardown-formbridge.sh
# Interactive safe cleanup script for FormBridge infrastructure
# Deletes stacks/resources in correct dependency order
# Requires --really-destroy flag for destructive operations
#
# Usage (dry-run, safe):
#   bash scripts/teardown-formbridge.sh --dry-run
#
# Usage (real):
#   bash scripts/teardown-formbridge.sh --really-destroy
#
# Options:
#   --dry-run              Show what would be deleted (no changes)
#   --really-destroy       Actually delete resources
#   --purge-secrets        Also delete SSM Parameters and Secrets Manager
#   --keep-data            Keep DynamoDB tables (don't delete)
#   --keep-sns             Keep SNS topics (don't delete)
#   --keep-budget          Keep AWS Budget (don't delete)
##############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
REGION="${REGION:-ap-south-1}"
PROFILE="${AWS_PROFILE:-default}"
DRY_RUN=true
REALLY_DESTROY=false
PURGE_SECRETS=false
KEEP_DATA=false
KEEP_SNS=false
KEEP_BUDGET=false

# Tracking
DELETED=()
SKIPPED=()
KEPT=()

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

log_prompt() {
  echo -e "${MAGENTA}[?]${NC} $*"
}

log_delete() {
  echo -e "${RED}[DEL]${NC} $*"
}

##############################################################################
# Parse Arguments
##############################################################################

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        REALLY_DESTROY=false
        ;;
      --really-destroy)
        DRY_RUN=false
        REALLY_DESTROY=true
        ;;
      --purge-secrets)
        PURGE_SECRETS=true
        ;;
      --keep-data)
        KEEP_DATA=true
        ;;
      --keep-sns)
        KEEP_SNS=true
        ;;
      --keep-budget)
        KEEP_BUDGET=true
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done
  
  if [[ "$DRY_RUN" == false && "$REALLY_DESTROY" == false ]]; then
    echo "Usage: bash teardown-formbridge.sh [--dry-run | --really-destroy] [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run              Show what would be deleted (safe)"
    echo "  --really-destroy       Actually delete resources (DESTRUCTIVE)"
    echo "  --purge-secrets        Also delete SSM/Secrets Manager"
    echo "  --keep-data            Don't delete DynamoDB tables"
    echo "  --keep-sns             Don't delete SNS topics"
    echo "  --keep-budget          Don't delete budget"
    echo ""
    exit 1
  fi
}

##############################################################################
# Confirmation
##############################################################################

confirm_destruction() {
  if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY RUN MODE: No resources will be deleted"
    return 0
  fi
  
  log_warn "========== DESTRUCTIVE OPERATION =========="
  log_warn "This will DELETE FormBridge infrastructure!"
  echo ""
  log_prompt "Type 'yes, really destroy FormBridge' to confirm:"
  read -r response
  
  if [[ "$response" != "yes, really destroy FormBridge" ]]; then
    log_error "Destruction cancelled by user"
    exit 1
  fi
  
  log_info "Confirmed. Proceeding with teardown..."
}

##############################################################################
# CloudFormation Stack Deletion
##############################################################################

delete_cloudformation_stacks() {
  log_info "Checking for CloudFormation stacks..."
  
  STACKS=$(aws cloudformation list-stacks \
    --region "$REGION" \
    --profile "$PROFILE" \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[?contains(StackName, 'formbridge') || contains(StackName, 'FormBridge')].StackName" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$STACKS" ]]; then
    log_info "No active CloudFormation stacks found"
    return
  fi
  
  for STACK in $STACKS; do
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete CloudFormation stack: $STACK"
      DELETED+=("Stack: $STACK")
    else
      log_delete "Deleting CloudFormation stack: $STACK"
      aws cloudformation delete-stack \
        --stack-name "$STACK" \
        --region "$REGION" \
        --profile "$PROFILE"
      
      log_info "Waiting for stack deletion..."
      aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK" \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || log_warn "Stack deletion timed out or already deleted"
      
      log_success "Stack deleted: $STACK"
      DELETED+=("Stack: $STACK")
    fi
  done
}

##############################################################################
# Event Source Mappings
##############################################################################

delete_event_source_mappings() {
  log_info "Checking for SQS event source mappings..."
  
  # Find Lambda functions
  FUNCTIONS=$(aws lambda list-functions \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Functions[?contains(FunctionName, 'formbridge') || contains(FunctionName, 'FormBridge')].FunctionName" \
    --output text 2>/dev/null || echo "")
  
  for FUNC in $FUNCTIONS; do
    MAPPINGS=$(aws lambda list-event-source-mappings \
      --function-name "$FUNC" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "EventSourceMappings[].UUID" \
      --output text 2>/dev/null || echo "")
    
    for MAPPING in $MAPPINGS; do
      if [[ "$DRY_RUN" == true ]]; then
        log_delete "[DRY] Would delete event source mapping: $MAPPING"
        DELETED+=("ESM: $MAPPING")
      else
        log_delete "Deleting event source mapping: $MAPPING"
        aws lambda delete-event-source-mapping \
          --uuid "$MAPPING" \
          --region "$REGION" \
          --profile "$PROFILE" 2>/dev/null || true
        
        log_success "Event source mapping deleted"
        DELETED+=("ESM: $MAPPING")
      fi
    done
  done
}

##############################################################################
# Consumer Lambda
##############################################################################

delete_consumer_lambda() {
  log_info "Checking for consumer Lambda functions..."
  
  CONSUMER_FUNCS=$(aws lambda list-functions \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Functions[?FunctionName=='formbridgeWebhookDispatcher'].FunctionName" \
    --output text 2>/dev/null || echo "")
  
  for FUNC in $CONSUMER_FUNCS; do
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete Lambda: $FUNC"
      DELETED+=("Lambda: $FUNC")
    else
      log_delete "Deleting Lambda: $FUNC"
      aws lambda delete-function \
        --function-name "$FUNC" \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || log_warn "Lambda not found: $FUNC"
      
      log_success "Lambda deleted"
      DELETED+=("Lambda: $FUNC")
    fi
  done
}

##############################################################################
# SQS Queues (Main + DLQ)
##############################################################################

delete_sqs_queues() {
  log_info "Checking for SQS queues..."
  
  for QUEUE in formbridge-webhook-queue formbridge-webhook-dlq; do
    QUEUE_URL=$(aws sqs get-queue-url \
      --queue-name "$QUEUE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query QueueUrl \
      --output text 2>/dev/null || echo "")
    
    if [[ -z "$QUEUE_URL" ]]; then
      log_info "Queue not found (skipping): $QUEUE"
      SKIPPED+=("Queue: $QUEUE")
      continue
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete SQS queue: $QUEUE"
      DELETED+=("Queue: $QUEUE")
    else
      log_delete "Deleting SQS queue: $QUEUE"
      aws sqs delete-queue \
        --queue-url "$QUEUE_URL" \
        --region "$REGION" \
        --profile "$PROFILE"
      
      log_success "Queue deleted: $QUEUE"
      DELETED+=("Queue: $QUEUE")
    fi
  done
}

##############################################################################
# API Gateway (Stage + Deployment + API)
##############################################################################

delete_api_gateway() {
  log_info "Checking for API Gateway resources..."
  
  API_ID=$(aws apigateway get-rest-apis \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "items[0].id" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$API_ID" || "$API_ID" == "None" ]]; then
    log_info "No API Gateway found"
    return
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    log_delete "[DRY] Would delete API Gateway: $API_ID"
    DELETED+=("API Gateway: $API_ID")
  else
    log_delete "Deleting API Gateway: $API_ID"
    aws apigateway delete-rest-api \
      --rest-api-id "$API_ID" \
      --region "$REGION" \
      --profile "$PROFILE" 2>/dev/null || log_warn "Could not delete API Gateway"
    
    log_success "API Gateway deleted"
    DELETED+=("API Gateway: $API_ID")
  fi
}

##############################################################################
# Main Lambda (contactFormProcessor)
##############################################################################

delete_main_lambda() {
  log_info "Checking for main contact form Lambda..."
  
  MAIN_FUNC=$(aws lambda list-functions \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Functions[?FunctionName=='contactFormProcessor'].FunctionName" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$MAIN_FUNC" ]]; then
    log_info "Main Lambda not found"
    return
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    log_delete "[DRY] Would delete Lambda: $MAIN_FUNC"
    DELETED+=("Lambda: $MAIN_FUNC")
  else
    log_delete "Deleting Lambda: $MAIN_FUNC"
    aws lambda delete-function \
      --function-name "$MAIN_FUNC" \
      --region "$REGION" \
      --profile "$PROFILE" 2>/dev/null || log_warn "Lambda not found: $MAIN_FUNC"
    
    log_success "Lambda deleted"
    DELETED+=("Lambda: $MAIN_FUNC")
  fi
}

##############################################################################
# DynamoDB Tables
##############################################################################

delete_dynamodb_tables() {
  if [[ "$KEEP_DATA" == true ]]; then
    log_info "Keeping DynamoDB tables (--keep-data flag set)"
    KEPT+=("DynamoDB: contact-form-submissions (user kept)")
    KEPT+=("DynamoDB: formbridge-config (user kept)")
    return
  fi
  
  log_info "Checking for DynamoDB tables..."
  
  for TABLE in contact-form-submissions formbridge-config; do
    TABLE_EXISTS=$(aws dynamodb describe-table \
      --table-name "$TABLE" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Table.TableStatus" \
      --output text 2>/dev/null || echo "")
    
    if [[ -z "$TABLE_EXISTS" ]]; then
      log_info "Table not found (skipping): $TABLE"
      SKIPPED+=("DynamoDB: $TABLE")
      continue
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete DynamoDB table: $TABLE"
      DELETED+=("DynamoDB: $TABLE")
    else
      log_delete "Deleting DynamoDB table: $TABLE"
      aws dynamodb delete-table \
        --table-name "$TABLE" \
        --region "$REGION" \
        --profile "$PROFILE"
      
      log_success "Table deleted: $TABLE"
      DELETED+=("DynamoDB: $TABLE")
    fi
  done
}

##############################################################################
# SNS Topics
##############################################################################

delete_sns_topics() {
  if [[ "$KEEP_SNS" == true ]]; then
    log_info "Keeping SNS topics (--keep-sns flag set)"
    KEPT+=("SNS: FormBridge-Budget-Alerts (user kept)")
    return
  fi
  
  log_info "Checking for SNS topics..."
  
  for TOPIC in FormBridge-Budget-Alerts; do
    TOPIC_ARN=$(aws sns list-topics \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query "Topics[?contains(TopicArn, '$TOPIC')].TopicArn" \
      --output text 2>/dev/null || echo "")
    
    if [[ -z "$TOPIC_ARN" ]]; then
      log_info "Topic not found (skipping): $TOPIC"
      SKIPPED+=("SNS: $TOPIC")
      continue
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete SNS topic: $TOPIC"
      DELETED+=("SNS: $TOPIC")
    else
      log_delete "Deleting SNS topic: $TOPIC_ARN"
      aws sns delete-topic \
        --topic-arn "$TOPIC_ARN" \
        --region "$REGION" \
        --profile "$PROFILE"
      
      log_success "Topic deleted: $TOPIC"
      DELETED+=("SNS: $TOPIC")
    fi
  done
}

##############################################################################
# AWS Budget
##############################################################################

delete_budget() {
  if [[ "$KEEP_BUDGET" == true ]]; then
    log_info "Keeping AWS Budget (--keep-budget flag set)"
    KEPT+=("Budget: FormBridge-Monthly-Budget (user kept)")
    return
  fi
  
  log_info "Checking for AWS Budget..."
  
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE" 2>/dev/null || echo "")
  
  BUDGET_EXISTS=$(aws budgets describe-budgets \
    --account-id "$ACCOUNT_ID" \
    --query "Budgets[?BudgetName=='FormBridge-Monthly-Budget'].BudgetName" \
    --output text 2>/dev/null || echo "")
  
  if [[ -z "$BUDGET_EXISTS" ]]; then
    log_info "Budget not found"
    SKIPPED+=("Budget: FormBridge-Monthly-Budget")
    return
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    log_delete "[DRY] Would delete budget: FormBridge-Monthly-Budget"
    DELETED+=("Budget: FormBridge-Monthly-Budget")
  else
    log_delete "Deleting budget: FormBridge-Monthly-Budget"
    aws budgets delete-budget \
      --account-id "$ACCOUNT_ID" \
      --budget-name "FormBridge-Monthly-Budget" \
      --profile "$PROFILE"
    
    log_success "Budget deleted"
    DELETED+=("Budget: FormBridge-Monthly-Budget")
  fi
}

##############################################################################
# SSM Parameters & Secrets
##############################################################################

delete_secrets() {
  if [[ "$PURGE_SECRETS" == false ]]; then
    log_info "Keeping SSM Parameters and Secrets Manager (use --purge-secrets to remove)"
    return
  fi
  
  log_info "Purging SSM Parameters and Secrets..."
  
  # SSM Parameters
  PARAMS=$(aws ssm describe-parameters \
    --filters "Key=Name,Values=/formbridge/" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Parameters[].Name" \
    --output text 2>/dev/null || echo "")
  
  for PARAM in $PARAMS; do
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete SSM parameter: $PARAM"
    else
      log_delete "Deleting SSM parameter: $PARAM"
      aws ssm delete-parameter \
        --name "$PARAM" \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || true
    fi
  done
  
  # Secrets Manager
  SECRETS=$(aws secretsmanager list-secrets \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "SecretList[?contains(Name, 'formbridge')].Name" \
    --output text 2>/dev/null || echo "")
  
  for SECRET in $SECRETS; do
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY] Would delete secret: $SECRET"
    else
      log_delete "Deleting secret: $SECRET"
      aws secretsmanager delete-secret \
        --secret-id "$SECRET" \
        --force-delete-without-recovery \
        --region "$REGION" \
        --profile "$PROFILE" 2>/dev/null || true
    fi
  done
}

##############################################################################
# Summary Report
##############################################################################

print_summary() {
  echo ""
  log_info "=========================================="
  if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY RUN SUMMARY"
  else
    log_info "TEARDOWN COMPLETE"
  fi
  log_info "=========================================="
  echo ""
  
  if [[ ${#DELETED[@]} -gt 0 ]]; then
    echo "ðŸ—‘ï¸  Deleted/Would Delete (${#DELETED[@]}):"
    for item in "${DELETED[@]}"; do
      echo "  âœ“ $item"
    done
    echo ""
  fi
  
  if [[ ${#KEPT[@]} -gt 0 ]]; then
    echo "ðŸ“Œ Kept (${#KEPT[@]}):"
    for item in "${KEPT[@]}"; do
      echo "  â†’ $item"
    done
    echo ""
  fi
  
  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo "â­ï¸  Skipped/Not Found (${#SKIPPED[@]}):"
    for item in "${SKIPPED[@]}"; do
      echo "  âˆ’ $item"
    done
    echo ""
  fi
  
  echo "ðŸ“ What Remains:"
  echo "  â€¢ Git repositories (.git/ folders)"
  echo "  â€¢ CloudWatch Logs (if not in stack)"
  echo "  â€¢ IAM Roles (if custom)"
  if [[ "$PURGE_SECRETS" == false ]]; then
    echo "  â€¢ SSM Parameters (use --purge-secrets)"
    echo "  â€¢ Secrets Manager secrets (use --purge-secrets)"
  fi
  if [[ "$KEEP_DATA" == true ]]; then
    echo "  â€¢ DynamoDB data (kept by request)"
  fi
  if [[ "$KEEP_SNS" == true ]]; then
    echo "  â€¢ SNS topics (kept by request)"
  fi
  if [[ "$KEEP_BUDGET" == true ]]; then
    echo "  â€¢ AWS Budget (kept by request)"
  fi
  echo ""
  
  if [[ "$DRY_RUN" == true ]]; then
    echo "ðŸ”„ To actually delete, run:"
    echo "   bash scripts/teardown-formbridge.sh --really-destroy"
    echo ""
  else
    log_success "Teardown complete!"
  fi
}

##############################################################################
# Main Execution
##############################################################################

main() {
  parse_args "$@"
  
  log_info "FormBridge Infrastructure Teardown"
  echo ""
  
  confirm_destruction
  echo ""
  
  delete_cloudformation_stacks
  delete_event_source_mappings
  delete_consumer_lambda
  delete_sqs_queues
  delete_api_gateway
  delete_main_lambda
  delete_dynamodb_tables
  delete_sns_topics
  delete_budget
  delete_secrets
  
  echo ""
  print_summary
}

main "$@"
