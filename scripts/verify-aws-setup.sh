#!/bin/bash

#################################################################################
# FormBridge AWS Resource Verification Script
# Checks all infrastructure is correctly deployed
#################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Configuration
REGION="${AWS_REGION:-ap-south-1}"
PROFILE="${AWS_PROFILE:-default}"
STACK_NAME="formbridge-stack"

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Helper functions
info() {
  echo -e "${BLUE}ℹ${RESET} $*"
}

success() {
  echo -e "${GREEN}✓${RESET} $*"
  ((CHECKS_PASSED++))
}

error() {
  echo -e "${RED}✕${RESET} $*"
  ((CHECKS_FAILED++))
}

warn() {
  echo -e "${YELLOW}⚠${RESET} $*"
  ((CHECKS_WARNING++))
}

separator() {
  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo "$*"
  echo "────────────────────────────────────────────────────────────"
  echo ""
}

#################################################################################
# 1. CloudFormation Stack
#################################################################################

separator "1. CloudFormation Stack"

STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
  success "CloudFormation Stack: $STACK_STATUS"
else
  error "CloudFormation Stack: $STACK_STATUS (expected CREATE_COMPLETE or UPDATE_COMPLETE)"
fi

#################################################################################
# 2. Lambda Functions
#################################################################################

separator "2. Lambda Functions"

# Main Lambda
MAIN_LAMBDA=$(aws lambda get-function \
  --function-name contactFormProcessor \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Configuration.FunctionName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$MAIN_LAMBDA" != "NOT_FOUND" ]; then
  success "Main Lambda: contactFormProcessor"
else
  error "Main Lambda: contactFormProcessor not found"
fi

# Check for webhook consumer Lambda
WEBHOOK_LAMBDA=$(aws lambda list-functions \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Functions[?contains(FunctionName, `webhook`)].FunctionName' \
  --output text 2>/dev/null || echo "")

if [ -z "$WEBHOOK_LAMBDA" ]; then
  warn "Webhook Consumer Lambda: Not found (optional if using SQS integration)"
else
  success "Webhook Consumer Lambda: $WEBHOOK_LAMBDA"
fi

#################################################################################
# 3. API Gateway
#################################################################################

separator "3. API Gateway"

API_ID=$(aws apigateway get-rest-apis \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'items[0].id' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$API_ID" != "NOT_FOUND" ] && [ ! -z "$API_ID" ]; then
  ENDPOINT="https://$API_ID.execute-api.$REGION.amazonaws.com/Prod"
  success "API Gateway: $API_ID"
  info "Endpoint: $ENDPOINT"
  
  # Try to ping the API
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$ENDPOINT/analytics" \
    -H "X-Api-Key: test-key" \
    -H "Content-Type: application/json" \
    -d '{"action":"test"}' \
    --max-time 5 2>/dev/null || echo "000")
  
  if [ "$HTTP_CODE" = "403" ]; then
    success "API Gateway Accessibility: Reachable (403 = auth required, expected)"
  elif [ "$HTTP_CODE" = "401" ]; then
    success "API Gateway Accessibility: Reachable (401 = auth required, expected)"
  elif [ "$HTTP_CODE" = "200" ]; then
    success "API Gateway Accessibility: Reachable and accepting requests (200)"
  else
    warn "API Gateway Accessibility: HTTP $HTTP_CODE (may be unreachable or rate limited)"
  fi
else
  error "API Gateway: Not found"
fi

#################################################################################
# 4. DynamoDB Tables
#################################################################################

separator "4. DynamoDB Tables"

# Table 1: Submissions
SUBMISSIONS_TABLE=$(aws dynamodb describe-table \
  --table-name contact-form-submissions \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Table.TableName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SUBMISSIONS_TABLE" != "NOT_FOUND" ]; then
  BILLING_MODE=$(aws dynamodb describe-table \
    --table-name contact-form-submissions \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Table.BillingModeSummary.BillingMode' \
    --output text 2>/dev/null)
  success "Submissions Table: contact-form-submissions (BillingMode: $BILLING_MODE)"
else
  error "Submissions Table: contact-form-submissions not found"
fi

# Table 2: Config
CONFIG_TABLE=$(aws dynamodb describe-table \
  --table-name formbridge-config \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Table.TableName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CONFIG_TABLE" != "NOT_FOUND" ]; then
  success "Config Table: formbridge-config"
else
  warn "Config Table: formbridge-config not found (optional)"
fi

#################################################################################
# 5. SQS Queues
#################################################################################

separator "5. SQS Queues"

QUEUE_URLS=$(aws sqs list-queues \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'QueueUrls' \
  --output text 2>/dev/null || echo "")

if [ -z "$QUEUE_URLS" ]; then
  warn "SQS Queues: None found (optional if not using webhook queue)"
else
  WEBHOOK_QUEUE=$(echo "$QUEUE_URLS" | tr ' ' '\n' | grep -i webhook || true)
  if [ ! -z "$WEBHOOK_QUEUE" ]; then
    success "Webhook Queue: $(basename $WEBHOOK_QUEUE)"
  else
    success "SQS Queues: Found $(echo $QUEUE_URLS | wc -w) queue(s)"
  fi
fi

#################################################################################
# 6. SNS Topics (for Cost Guardrails)
#################################################################################

separator "6. SNS Topics"

SNS_TOPICS=$(aws sns list-topics \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Topics[*].TopicArn' \
  --output text 2>/dev/null || echo "")

if [ -z "$SNS_TOPICS" ]; then
  warn "SNS Topics: None found (will be created by cost guardrails setup)"
else
  BUDGET_TOPIC=$(echo "$SNS_TOPICS" | tr ' ' '\n' | grep -i budget || true)
  if [ ! -z "$BUDGET_TOPIC" ]; then
    success "Budget Topic: Found (cost guardrails already configured)"
  fi
fi

#################################################################################
# 7. CloudWatch Alarms
#################################################################################

separator "7. CloudWatch Alarms"

ALARMS=$(aws cloudwatch describe-alarms \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'MetricAlarms[*].AlarmName' \
  --output text 2>/dev/null || echo "")

if [ -z "$ALARMS" ]; then
  info "CloudWatch Alarms: None found"
else
  ALARM_COUNT=$(echo "$ALARMS" | wc -w)
  success "CloudWatch Alarms: Found $ALARM_COUNT alarm(s)"
  for ALARM in $ALARMS; do
    info "  - $ALARM"
  done
fi

#################################################################################
# 8. IAM Roles & Policies
#################################################################################

separator "8. IAM Roles & Policies"

LAMBDA_ROLE=$(aws iam list-roles \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query "Roles[?contains(RoleName, '$STACK_NAME')].RoleName" \
  --output text 2>/dev/null || echo "")

if [ ! -z "$LAMBDA_ROLE" ]; then
  success "IAM Roles: Found $(echo $LAMBDA_ROLE | wc -w) role(s)"
  for ROLE in $LAMBDA_ROLE; do
    info "  - $ROLE"
  done
else
  warn "IAM Roles: No FormBridge-specific roles found"
fi

#################################################################################
# 9. CloudWatch Logs
#################################################################################

separator "9. CloudWatch Logs"

LOG_GROUPS=$(aws logs describe-log-groups \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query "logGroups[?contains(logGroupName, 'formbridge')].logGroupName" \
  --output text 2>/dev/null || echo "")

if [ ! -z "$LOG_GROUPS" ]; then
  success "CloudWatch Log Groups: Found $(echo $LOG_GROUPS | wc -w)"
  for GROUP in $LOG_GROUPS; do
    info "  - $GROUP"
  done
else
  info "CloudWatch Logs: No FormBridge-specific log groups found yet"
fi

#################################################################################
# 10. Cost Tags
#################################################################################

separator "10. Resource Tags"

# Check if resources have FormBridge tags
TAGGED_LAMBDAS=$(aws lambda list-functions \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Functions[*].FunctionArn' \
  --output text 2>/dev/null || echo "")

if [ ! -z "$TAGGED_LAMBDAS" ]; then
  for ARN in $TAGGED_LAMBDAS; do
    TAGS=$(aws lambda list-tags-by-resource \
      --resource "$ARN" \
      --region "$REGION" \
      --profile "$PROFILE" \
      --query 'Tags.Project' \
      --output text 2>/dev/null || echo "")
    
    if [ "$TAGS" = "FormBridge" ]; then
      success "Cost Tags: Found on $(basename $ARN)"
      break
    fi
  done
else
  info "Cost Tags: Not yet applied (will be added by cost guardrails setup)"
fi

#################################################################################
# Summary
#################################################################################

separator "✓ VERIFICATION SUMMARY"

TOTAL=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

echo -e "${GREEN}Passed:${RESET}  $CHECKS_PASSED"
echo -e "${RED}Failed:${RESET}  $CHECKS_FAILED"
echo -e "${YELLOW}Warnings:${RESET} $CHECKS_WARNING"
echo -e "${BLUE}Total:${RESET}   $TOTAL"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All critical resources verified!${RESET}"
  echo ""
  echo "Next steps:"
  echo "  1. Run: bash scripts/setup-cost-guardrails.sh"
  echo "  2. Configure: GitHub Secrets → STATUS_API_KEY"
  echo "  3. Trigger: GitHub Actions → Status Check workflow"
  exit 0
else
  echo -e "${RED}✕ Some resources need attention${RESET}"
  echo ""
  echo "Recommended fixes:"
  echo "  - Deploy infrastructure: sam deploy (from backend/)"
  echo "  - Check AWS credentials: aws sts get-caller-identity"
  echo "  - Verify region: export AWS_REGION=ap-south-1"
  exit 1
fi
