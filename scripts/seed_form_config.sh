#!/bin/bash
# FormBridge Config Seeding Script
# Idempotent AWS CLI script to seed per-form routing configurations
# 
# Usage:
#   ./scripts/seed_form_config.sh [--region REGION] [--table TABLE_NAME]
# 
# Environment Variables:
#   AWS_REGION - AWS region (default: ap-south-1)
#   TABLE_NAME - DynamoDB table name (default: formbridge-config)

set -e

# Configuration
REGION="${AWS_REGION:-ap-south-1}"
TABLE_NAME="${TABLE_NAME:-formbridge-config}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      REGION="$2"
      shift 2
      ;;
    --table)
      TABLE_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}=== FormBridge Form Config Seeding ===${NC}"
echo "Region: $REGION"
echo "Table: $TABLE_NAME"
echo ""

# Function to put form config item
put_form_config() {
  local form_id="$1"
  local recipients_str="$2"
  local subject_prefix="$3"
  local brand_color="$4"
  local dashboard_url="$5"
  
  # Convert recipients string to JSON array
  IFS=',' read -ra RECIPIENTS_ARRAY <<< "$recipients_str"
  local recipients_json="["
  for i in "${!RECIPIENTS_ARRAY[@]}"; do
    RECIPIENT=$(echo "${RECIPIENTS_ARRAY[$i]}" | xargs)  # trim whitespace
    if [ $i -gt 0 ]; then recipients_json+=","; fi
    recipients_json+="{\"S\": \"$RECIPIENT\"}"
  done
  recipients_json+="]"
  
  # Build item JSON with optional prefix
  local item_json="{
    \"pk\": {\"S\": \"FORM#$form_id\"},
    \"sk\": {\"S\": \"CONFIG#v1\"},
    \"recipients\": {\"L\": $recipients_json},
    \"brand_primary_hex\": {\"S\": \"$brand_color\"},
    \"dashboard_url\": {\"S\": \"$dashboard_url\"}"
  
  if [ -n "$subject_prefix" ]; then
    item_json+=",\"subject_prefix\": {\"S\": \"$subject_prefix\"}"
  fi
  
  item_json+="}"
  
  # Put item into DynamoDB
  if aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item "$item_json" \
    --region "$REGION" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Seeded form: ${BLUE}$form_id${NC}"
    echo "   Recipients: $recipients_str"
    echo "   Prefix: ${subject_prefix:-[none]}"
    echo "   Color: $brand_color"
    echo "   Dashboard: $dashboard_url"
  else
    echo -e "${RED}✗${NC} Failed to seed form: ${BLUE}$form_id${NC}"
    return 1
  fi
}

# Seed form configurations
echo -e "${BLUE}Seeding form configurations...${NC}"
echo ""

# Contact Form
put_form_config \
  "contact-us" \
  "admin@example.com,support@example.com" \
  "[Contact]" \
  "#6D28D9" \
  "https://example.com/dashboard?form=contact-us"
echo ""

# Careers Form
put_form_config \
  "careers" \
  "hr@example.com,hiring@example.com" \
  "[Careers]" \
  "#0EA5E9" \
  "https://example.com/dashboard?form=careers"
echo ""

# Support Form
put_form_config \
  "support" \
  "support@example.com" \
  "[Support]" \
  "#10B981" \
  "https://example.com/dashboard?form=support"
echo ""

echo -e "${GREEN}=== Seeding Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Update your form_id values in the forms (contact-us, careers, support)"
echo "2. Submit test forms and verify routing"
echo "3. Check emails in your configured recipients"
echo ""
echo "To customize further, edit this script or use AWS CLI directly:"
echo "  aws dynamodb put-item --table-name $TABLE_NAME --item '{...}' --region $REGION"
