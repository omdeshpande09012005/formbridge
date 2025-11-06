#!/usr/bin/env bash
# FormBridge Email Sender - CURL Command
# Usage: ./send_email_curl.sh [recipient_email]

RECIPIENT="${1:-om.deshpande@mitwpu.edu.in}"
API_ENDPOINT="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit"

echo "🚀 FormBridge Email Sender"
echo "================================"
echo ""

# Create JSON payload
PAYLOAD=$(cat <<'EOF'
{
  "form_id": "email-template-test",
  "name": "Om Deshpande",
  "email": "om.deshpande@mitwpu.edu.in",
  "message": "Testing FormBridge email template (base.html) via API",
  "page": "https://omdeshpande09012005.github.io/formbridge/"
}
EOF
)

echo "📧 Sending via API..."
echo "Recipient: $RECIPIENT"
echo "Endpoint: $API_ENDPOINT"
echo ""

# Send the request
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --verbose

echo ""
echo "✅ Request sent!"
