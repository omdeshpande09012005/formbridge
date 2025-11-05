#!/bin/bash
set -e

# FormBridge Webhook Configuration Seeding Script
# Idempotent AWS CLI script to seed webhook configurations into DynamoDB
# Usage:
#   ./scripts/seed_webhook_config.sh --region us-east-1 --table formbridge-config
#   ./scripts/seed_webhook_config.sh --region ap-south-1
#   ./scripts/seed_webhook_config.sh

# Defaults
REGION="${AWS_REGION:-ap-south-1}"
TABLE_NAME="formbridge-config"

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
      echo "Usage: $0 [--region REGION] [--table TABLE_NAME]"
      exit 1
      ;;
  esac
done

echo "═══════════════════════════════════════════════════════════════════"
echo "FormBridge Webhook Configuration Seeding"
echo "═══════════════════════════════════════════════════════════════════"
echo "Region: $REGION"
echo "Table: $TABLE_NAME"
echo ""

# Function to put form config with webhooks
put_form_config() {
  local form_id=$1
  local recipients=$2
  local subject_prefix=$3
  local brand_hex=$4
  local dashboard_url=$5
  local slack_url=$6
  local generic_url=$7
  local hmac_secret=$8

  echo "📝 Seeding $form_id..."

  # Build JSON item
  local webhooks_list="[]"
  
  if [ ! -z "$slack_url" ]; then
    webhooks_list=$(cat <<EOF
[
  {
    "M": {
      "type": {"S": "slack"},
      "url": {"S": "$slack_url"}
    }
  }
]
EOF
)
  fi

  if [ ! -z "$generic_url" ]; then
    local generic_item="{\"M\": {\"type\": {\"S\": \"generic\"}, \"url\": {\"S\": \"$generic_url\"}"
    
    if [ ! -z "$hmac_secret" ]; then
      generic_item="$generic_item, \"hmac_secret\": {\"S\": \"$hmac_secret\"}, \"hmac_header\": {\"S\": \"X-Webhook-Signature\"}"
    fi
    
    generic_item="$generic_item}}"

    if [ "$webhooks_list" = "[]" ]; then
      webhooks_list="[$generic_item]"
    else
      # Append to existing webhooks
      webhooks_list=$(echo "$webhooks_list" | sed '$ d')
      webhooks_list="$webhooks_list,$generic_item]"
    fi
  fi

  # Build recipients list
  local recipients_list=$(echo "$recipients" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | jq -R -s -c 'split("\n") | map(select(length > 0)) | map({"S": .})')

  # Put item
  aws dynamodb put-item \
    --region "$REGION" \
    --table-name "$TABLE_NAME" \
    --item "{
      \"pk\": {\"S\": \"FORM#$form_id\"},
      \"sk\": {\"S\": \"CONFIG#v1\"},
      \"recipients\": {\"L\": $recipients_list},
      \"subject_prefix\": {\"S\": \"$subject_prefix\"},
      \"brand_primary_hex\": {\"S\": \"$brand_hex\"},
      \"dashboard_url\": {\"S\": \"$dashboard_url\"},
      \"webhooks\": {\"L\": $webhooks_list}
    }" \
    2>/dev/null || {
      echo "  ❌ Error seeding $form_id"
      return 1
    }

  echo "  ✅ $form_id seeded"
}

# Example configurations
# TODO: Update these with your actual Slack URLs, Discord URLs, and webhook.site endpoints

echo "🔄 Seeding webhook configurations..."
echo ""

# Form 1: Support (Slack + Generic/webhook.site)
put_form_config \
  "support" \
  "support@example.com" \
  "[Support]" \
  "#10B981" \
  "https://example.com/dashboard/?form_id=support" \
  "https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK_URL_HERE" \
  "https://webhook.site/your-unique-id-for-support" \
  "support-webhook-secret"

# Form 2: Contact Us (Discord)
put_form_config \
  "contact-us" \
  "admin@example.com,sales@example.com" \
  "[Contact]" \
  "#6D28D9" \
  "https://example.com/dashboard/?form_id=contact-us" \
  "" \
  "https://webhook.site/your-unique-id-for-contact" \
  ""

# Form 3: Careers (Slack + Discord + Generic)
put_form_config \
  "careers" \
  "hr@example.com,recruiting@example.com" \
  "[Careers]" \
  "#0EA5E9" \
  "https://example.com/dashboard/?form_id=careers" \
  "https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK_FOR_CAREERS" \
  "https://webhook.site/your-unique-id-for-careers" \
  "careers-webhook-secret"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ Webhook configuration seeding complete!"
echo ""
echo "📌 IMPORTANT: Replace placeholder URLs:"
echo "   • Slack webhooks: https://api.slack.com/messaging/webhooks"
echo "   • Discord webhooks: Server Settings → Integrations → Webhooks"
echo "   • Generic webhooks: Use webhook.site or your custom endpoint"
echo ""
echo "To verify seeding:"
echo "  aws dynamodb get-item \\"
echo "    --table-name $TABLE_NAME \\"
echo "    --key '{\"pk\": {\"S\": \"FORM#support\"}, \"sk\": {\"S\": \"CONFIG#v1\"}}' \\"
echo "    --region $REGION"
echo "═══════════════════════════════════════════════════════════════════"
