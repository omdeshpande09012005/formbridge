#!/bin/bash

################################################################################
# FormBridge Observability & Alerts Setup Script
# 
# Creates SNS topics, email subscriptions, CloudWatch alarms, and log metric
# filters for Lambda, API Gateway, DynamoDB, and SES.
#
# Usage: bash setup-observability.sh
#
# Idempotent: Safe to run multiple times. Creates resources only if missing.
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURATION - UPDATE THESE WITH YOUR VALUES
# ============================================================================

# AWS Configuration
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-123456789012}"
LAMBDA_NAME="${LAMBDA_NAME:-contactFormProcessor}"
API_ID="${API_ID:-12mse3zde5}"
STAGE_NAME="${STAGE_NAME:-Prod}"
DDB_TABLE="${DDB_TABLE:-contact-form-submissions}"
SES_IDENTITY="${SES_IDENTITY:-noreply@example.com}"

# Alert Configuration
ALERT_EMAIL="${ALERT_EMAIL:-admin@example.com}"
PROJECT_TAG="${PROJECT_TAG:-FormBridge}"
ALARM_NAMESPACE="${ALARM_NAMESPACE:-FormBridge/Prod}"

# Alarm Thresholds (easily tweakable)
LAMBDA_ERROR_THRESHOLD=1
LAMBDA_ERROR_PERIOD=300       # 5 minutes
LAMBDA_ERROR_DATAPOINTS=1

APIGW_5XX_THRESHOLD=1
APIGW_5XX_PERIOD=300          # 5 minutes
APIGW_5XX_DATAPOINTS=1

DDB_THROTTLE_THRESHOLD=1
DDB_THROTTLE_PERIOD=300       # 5 minutes
DDB_THROTTLE_DATAPOINTS=1

# ============================================================================
# Helper Functions
# ============================================================================

echo_banner() {
  echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

echo_success() {
  echo -e "${GREEN}✓${NC} $1"
}

echo_info() {
  echo -e "${YELLOW}ℹ${NC} $1"
}

echo_error() {
  echo -e "${RED}✗${NC} $1"
}

# Check if SNS topic exists
sns_topic_exists() {
  local topic_name=$1
  aws sns list-topics --region "$REGION" --query "Topics[?TopicArn | contains('$topic_name')].TopicArn" --output text 2>/dev/null | grep -q "$topic_name" && return 0 || return 1
}

# Get SNS topic ARN by name
get_sns_topic_arn() {
  local topic_name=$1
  aws sns list-topics --region "$REGION" --query "Topics[?TopicArn | contains('$topic_name')].TopicArn" --output text | awk '{print $1}'
}

# Check if subscription exists
subscription_exists() {
  local topic_arn=$1
  local endpoint=$2
  aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" --region "$REGION" --query "Subscriptions[?Endpoint=='$endpoint'].SubscriptionArn" --output text 2>/dev/null | grep -q "arn:" && return 0 || return 1
}

# Check if alarm exists
alarm_exists() {
  local alarm_name=$1
  aws cloudwatch describe-alarms --alarm-names "$alarm_name" --region "$REGION" --query 'Alarms[0].AlarmName' --output text 2>/dev/null | grep -q "$alarm_name" && return 0 || return 1
}

# Check if log metric filter exists
log_metric_filter_exists() {
  local log_group=$1
  local filter_name=$2
  aws logs describe-metric-filters --log-group-name "$log_group" --region "$REGION" --query "MetricFilters[?filterName=='$filter_name'].filterName" --output text 2>/dev/null | grep -q "$filter_name" && return 0 || return 1
}

# ============================================================================
# Main Setup
# ============================================================================

echo_banner "FormBridge Observability & Alerts Setup"

echo ""
echo_info "Configuration:"
echo "  Region:           $REGION"
echo "  Account ID:       $ACCOUNT_ID"
echo "  Lambda:           $LAMBDA_NAME"
echo "  API Gateway:      $API_ID / $STAGE_NAME"
echo "  DynamoDB Table:   $DDB_TABLE"
echo "  Alert Email:      $ALERT_EMAIL"
echo "  Project Tag:      $PROJECT_TAG"
echo "  Alarm Namespace:  $ALARM_NAMESPACE"
echo ""

# ============================================================================
# 1. SNS Topics for Alerts
# ============================================================================

echo_banner "Step 1: Creating SNS Topics"

ALERTS_TOPIC_NAME="${PROJECT_TAG}-alerts"
if sns_topic_exists "$ALERTS_TOPIC_NAME"; then
  ALERTS_TOPIC_ARN=$(get_sns_topic_arn "$ALERTS_TOPIC_NAME")
  echo_success "SNS topic '$ALERTS_TOPIC_NAME' already exists"
  echo "  ARN: $ALERTS_TOPIC_ARN"
else
  ALERTS_TOPIC_ARN=$(aws sns create-topic \
    --name "$ALERTS_TOPIC_NAME" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod \
    --query 'TopicArn' \
    --output text)
  echo_success "Created SNS topic '$ALERTS_TOPIC_NAME'"
  echo "  ARN: $ALERTS_TOPIC_ARN"
fi

# Email subscription to alerts topic
if ! subscription_exists "$ALERTS_TOPIC_ARN" "$ALERT_EMAIL"; then
  aws sns subscribe \
    --topic-arn "$ALERTS_TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$ALERT_EMAIL" \
    --region "$REGION" \
    > /dev/null
  echo_success "Created email subscription to '$ALERT_EMAIL' on alerts topic"
  echo_info "User must confirm subscription via email link!"
else
  echo_success "Email subscription for '$ALERT_EMAIL' already exists on alerts topic"
fi

# ============================================================================
# 2. SES Bounce & Complaint Topics
# ============================================================================

echo_banner "Step 2: Creating SES Bounce & Complaint Topics"

BOUNCE_TOPIC_NAME="${PROJECT_TAG}-ses-bounce"
if sns_topic_exists "$BOUNCE_TOPIC_NAME"; then
  BOUNCE_TOPIC_ARN=$(get_sns_topic_arn "$BOUNCE_TOPIC_NAME")
  echo_success "SNS topic '$BOUNCE_TOPIC_NAME' already exists"
  echo "  ARN: $BOUNCE_TOPIC_ARN"
else
  BOUNCE_TOPIC_ARN=$(aws sns create-topic \
    --name "$BOUNCE_TOPIC_NAME" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod \
    --query 'TopicArn' \
    --output text)
  echo_success "Created SNS topic '$BOUNCE_TOPIC_NAME'"
  echo "  ARN: $BOUNCE_TOPIC_ARN"
fi

if ! subscription_exists "$BOUNCE_TOPIC_ARN" "$ALERT_EMAIL"; then
  aws sns subscribe \
    --topic-arn "$BOUNCE_TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$ALERT_EMAIL" \
    --region "$REGION" \
    > /dev/null
  echo_success "Created email subscription to '$ALERT_EMAIL' on bounce topic"
else
  echo_success "Email subscription for '$ALERT_EMAIL' already exists on bounce topic"
fi

COMPLAINT_TOPIC_NAME="${PROJECT_TAG}-ses-complaint"
if sns_topic_exists "$COMPLAINT_TOPIC_NAME"; then
  COMPLAINT_TOPIC_ARN=$(get_sns_topic_arn "$COMPLAINT_TOPIC_NAME")
  echo_success "SNS topic '$COMPLAINT_TOPIC_NAME' already exists"
  echo "  ARN: $COMPLAINT_TOPIC_ARN"
else
  COMPLAINT_TOPIC_ARN=$(aws sns create-topic \
    --name "$COMPLAINT_TOPIC_NAME" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod \
    --query 'TopicArn' \
    --output text)
  echo_success "Created SNS topic '$COMPLAINT_TOPIC_NAME'"
  echo "  ARN: $COMPLAINT_TOPIC_ARN"
fi

if ! subscription_exists "$COMPLAINT_TOPIC_ARN" "$ALERT_EMAIL"; then
  aws sns subscribe \
    --topic-arn "$COMPLAINT_TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$ALERT_EMAIL" \
    --region "$REGION" \
    > /dev/null
  echo_success "Created email subscription to '$ALERT_EMAIL' on complaint topic"
else
  echo_success "Email subscription for '$ALERT_EMAIL' already exists on complaint topic"
fi

# ============================================================================
# 3. Attach SES Notification Topics
# ============================================================================

echo_banner "Step 3: Attaching SES Notification Topics"

echo_info "Setting SES bounce notifications for $SES_IDENTITY..."
aws ses set-identity-notification-topic \
  --identity "$SES_IDENTITY" \
  --notification-type Bounce \
  --sns-topic "$BOUNCE_TOPIC_ARN" \
  --region "$REGION" \
  2>/dev/null || echo_info "SES notification topic already set or identity not verified"

echo_info "Setting SES complaint notifications for $SES_IDENTITY..."
aws ses set-identity-notification-topic \
  --identity "$SES_IDENTITY" \
  --notification-type Complaint \
  --sns-topic "$COMPLAINT_TOPIC_ARN" \
  --region "$REGION" \
  2>/dev/null || echo_info "SES notification topic already set or identity not verified"

echo_success "SES notification topics attached (or already configured)"

# ============================================================================
# 4. Lambda Error Alarms
# ============================================================================

echo_banner "Step 4: Creating Lambda Error Alarms"

# AWS/Lambda built-in metric alarm
LAMBDA_ERRORS_ALARM="${PROJECT_TAG}-${LAMBDA_NAME}-Errors"
if alarm_exists "$LAMBDA_ERRORS_ALARM"; then
  echo_success "Alarm '$LAMBDA_ERRORS_ALARM' already exists"
else
  aws cloudwatch put-metric-alarm \
    --alarm-name "$LAMBDA_ERRORS_ALARM" \
    --alarm-description "Alert on Lambda function errors" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period $LAMBDA_ERROR_PERIOD \
    --threshold $LAMBDA_ERROR_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions "$ALERTS_TOPIC_ARN" \
    --dimensions Name=FunctionName,Value="$LAMBDA_NAME" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod
  echo_success "Created alarm '$LAMBDA_ERRORS_ALARM'"
  echo "  Threshold: >= $LAMBDA_ERROR_THRESHOLD errors in $LAMBDA_ERROR_PERIOD seconds"
fi

# Custom metric from log filter
LAMBDA_LOG_GROUP="/aws/lambda/${LAMBDA_NAME}"
LAMBDA_LOG_FILTER="${PROJECT_TAG}-${LAMBDA_NAME}-ErrorFilter"
LAMBDA_LOG_METRIC="${ALARM_NAMESPACE}/LambdaErrorLogCount"

echo_info "Creating log metric filter on $LAMBDA_LOG_GROUP..."
if log_metric_filter_exists "$LAMBDA_LOG_GROUP" "$LAMBDA_LOG_FILTER"; then
  echo_success "Log metric filter '$LAMBDA_LOG_FILTER' already exists"
else
  aws logs put-metric-filter \
    --log-group-name "$LAMBDA_LOG_GROUP" \
    --filter-name "$LAMBDA_LOG_FILTER" \
    --filter-pattern "?ERROR ?Error ?Exception" \
    --metric-transformations metricName="$LAMBDA_LOG_METRIC",metricNamespace="$ALARM_NAMESPACE",metricValue=1 \
    --region "$REGION" \
    2>/dev/null || echo_info "Log group may not exist yet or filter already created"
  echo_success "Created log metric filter"
fi

# Alarm on custom log metric
LAMBDA_LOG_ERRORS_ALARM="${PROJECT_TAG}-${LAMBDA_NAME}-LogErrors"
if alarm_exists "$LAMBDA_LOG_ERRORS_ALARM"; then
  echo_success "Alarm '$LAMBDA_LOG_ERRORS_ALARM' already exists"
else
  aws cloudwatch put-metric-alarm \
    --alarm-name "$LAMBDA_LOG_ERRORS_ALARM" \
    --alarm-description "Alert on Lambda error log messages" \
    --metric-name "LambdaErrorLogCount" \
    --namespace "$ALARM_NAMESPACE" \
    --statistic Sum \
    --period $LAMBDA_ERROR_PERIOD \
    --threshold $LAMBDA_ERROR_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions "$ALERTS_TOPIC_ARN" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod
  echo_success "Created alarm '$LAMBDA_LOG_ERRORS_ALARM'"
fi

# ============================================================================
# 5. API Gateway 5XX Alarms
# ============================================================================

echo_banner "Step 5: Creating API Gateway 5XX Alarms"

APIGW_5XX_ALARM="${PROJECT_TAG}-${API_ID}-${STAGE_NAME}-5XX"
if alarm_exists "$APIGW_5XX_ALARM"; then
  echo_success "Alarm '$APIGW_5XX_ALARM' already exists"
else
  aws cloudwatch put-metric-alarm \
    --alarm-name "$APIGW_5XX_ALARM" \
    --alarm-description "Alert on API Gateway 5XX errors" \
    --metric-name 5XXError \
    --namespace AWS/ApiGateway \
    --statistic Sum \
    --period $APIGW_5XX_PERIOD \
    --threshold $APIGW_5XX_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions "$ALERTS_TOPIC_ARN" \
    --dimensions Name=ApiName,Value="$API_ID" Name=Stage,Value="$STAGE_NAME" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod
  echo_success "Created alarm '$APIGW_5XX_ALARM'"
  echo "  Threshold: >= $APIGW_5XX_THRESHOLD 5XX errors in $APIGW_5XX_PERIOD seconds"
fi

# ============================================================================
# 6. DynamoDB Throttling Alarms
# ============================================================================

echo_banner "Step 6: Creating DynamoDB Throttling Alarms"

DDB_READ_THROTTLE_ALARM="${PROJECT_TAG}-${DDB_TABLE}-ReadThrottle"
if alarm_exists "$DDB_READ_THROTTLE_ALARM"; then
  echo_success "Alarm '$DDB_READ_THROTTLE_ALARM' already exists"
else
  aws cloudwatch put-metric-alarm \
    --alarm-name "$DDB_READ_THROTTLE_ALARM" \
    --alarm-description "Alert on DynamoDB read throttling" \
    --metric-name ReadThrottleEvents \
    --namespace AWS/DynamoDB \
    --statistic Sum \
    --period $DDB_THROTTLE_PERIOD \
    --threshold $DDB_THROTTLE_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions "$ALERTS_TOPIC_ARN" \
    --dimensions Name=TableName,Value="$DDB_TABLE" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod
  echo_success "Created alarm '$DDB_READ_THROTTLE_ALARM'"
fi

DDB_WRITE_THROTTLE_ALARM="${PROJECT_TAG}-${DDB_TABLE}-WriteThrottle"
if alarm_exists "$DDB_WRITE_THROTTLE_ALARM"; then
  echo_success "Alarm '$DDB_WRITE_THROTTLE_ALARM' already exists"
else
  aws cloudwatch put-metric-alarm \
    --alarm-name "$DDB_WRITE_THROTTLE_ALARM" \
    --alarm-description "Alert on DynamoDB write throttling" \
    --metric-name WriteThrottleEvents \
    --namespace AWS/DynamoDB \
    --statistic Sum \
    --period $DDB_THROTTLE_PERIOD \
    --threshold $DDB_THROTTLE_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions "$ALERTS_TOPIC_ARN" \
    --dimensions Name=TableName,Value="$DDB_TABLE" \
    --region "$REGION" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value=Prod
  echo_success "Created alarm '$DDB_WRITE_THROTTLE_ALARM'"
fi

# ============================================================================
# 7. Summary & Verification
# ============================================================================

echo_banner "Setup Complete - Summary"

echo ""
echo_info "SNS Topics Created:"
echo "  Alerts:           $ALERTS_TOPIC_ARN"
echo "  SES Bounce:       $BOUNCE_TOPIC_ARN"
echo "  SES Complaint:    $COMPLAINT_TOPIC_ARN"

echo ""
echo_info "Alarms Created:"
echo "  - $LAMBDA_ERRORS_ALARM"
echo "  - $LAMBDA_LOG_ERRORS_ALARM"
echo "  - $APIGW_5XX_ALARM"
echo "  - $DDB_READ_THROTTLE_ALARM"
echo "  - $DDB_WRITE_THROTTLE_ALARM"

echo ""
echo_info "Log Metric Filter Created:"
echo "  - $LAMBDA_LOG_FILTER (logs: $LAMBDA_LOG_GROUP, metric: $LAMBDA_LOG_METRIC)"

# ============================================================================
# 8. Verification Commands
# ============================================================================

echo_banner "Verification Commands"

echo ""
echo "View all alarms:"
echo "  aws cloudwatch describe-alarms --region $REGION --query 'Alarms[?Tags[?Key==\`Project\` && Value==\`$PROJECT_TAG\`]].{Name:AlarmName,State:StateValue}' --output table"

echo ""
echo "View SNS subscriptions (alerts):"
echo "  aws sns list-subscriptions-by-topic --topic-arn $ALERTS_TOPIC_ARN --region $REGION --query 'Subscriptions[].{Endpoint:Endpoint,Status:SubscriptionArn}' --output table"

echo ""
echo "View Lambda alarm state:"
echo "  aws cloudwatch describe-alarms --alarm-names '$LAMBDA_ERRORS_ALARM' --region $REGION --query 'Alarms[0].{Name:AlarmName,State:StateValue,LastUpdate:StateUpdatedTimestamp}' --output table"

# ============================================================================
# 9. Testing & Troubleshooting Tips
# ============================================================================

echo_banner "Testing & Troubleshooting"

echo ""
echo_info "ACTION ITEMS:"
echo "  1. Confirm email subscription(s) by clicking links in your inbox"
echo "     - Check: $ALERT_EMAIL (alerts, bounce, complaint topics)"
echo ""
echo "  2. Test Lambda alarm:"
echo "     - Invoke with bad input to trigger an error:"
echo "       aws lambda invoke --function-name $LAMBDA_NAME --region $REGION --payload '{\"invalid\": true}' /tmp/response.json"
echo ""
echo "  3. Test API Gateway 5XX alarm:"
echo "     - Make request with malformed JSON:"
echo "       curl -X POST https://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}/submit -H 'Content-Type: application/json' -d '{invalid json'"
echo ""
echo "  4. Check alarm state (wait ~5 minutes for CloudWatch to aggregate metrics):"
echo "     aws cloudwatch describe-alarms --alarm-names '$LAMBDA_ERRORS_ALARM' --region $REGION"
echo ""
echo "  5. View CloudWatch logs:"
echo "     aws logs tail $LAMBDA_LOG_GROUP --region $REGION --follow"
echo ""
echo "  6. Confirm SES setup (if identity not verified yet):"
echo "     aws ses verify-email-identity --email-address $SES_IDENTITY --region $REGION"

echo ""
echo_banner "Observability Setup Complete!"
echo ""
echo_success "All SNS topics, alarms, and log filters have been created (idempotently)"
echo_info "Email confirmations required - please check your inbox!"
echo ""
