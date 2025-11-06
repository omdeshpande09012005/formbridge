#!/bin/bash
# FormBridge Email Sender via API
# This script sends an email by submitting a form through the FormBridge API

# Configuration
API_ENDPOINT="https://YOUR_API_ID.execute-api.ap-south-1.amazonaws.com/Prod/submit"
FORM_ID="email-template-test"
SENDER_NAME="Om Deshpande"
SENDER_EMAIL="om.deshpande@mitwpu.edu.in"
RECIPIENT_EMAIL="om.deshpande@mitwpu.edu.in"
SUBJECT="FormBridge Email Template Test"
MESSAGE="This is a test email sent using FormBridge with the base.html template"

echo "🚀 FormBridge Email Sender via API"
echo "=================================================="
echo ""

# Read the HTML template
TEMPLATE_PATH="./email_templates/base.html"

if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "❌ Error: Template not found at $TEMPLATE_PATH"
    exit 1
fi

HTML_CONTENT=$(<"$TEMPLATE_PATH")
echo "📄 Template loaded ($(wc -c < "$TEMPLATE_PATH") bytes)"
echo ""

# Create JSON payload
PAYLOAD=$(cat <<EOF
{
  "form_id": "$FORM_ID",
  "submissions": {
    "name": "$SENDER_NAME",
    "email": "$SENDER_EMAIL",
    "subject": "$SUBJECT",
    "message": "$MESSAGE"
  },
  "metadata": {
    "template": "base.html",
    "template_size": $(wc -c < "$TEMPLATE_PATH"),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
)

echo "📧 Sending via API..."
echo "   Endpoint: $API_ENDPOINT"
echo "   Form ID: $FORM_ID"
echo "   From: $SENDER_NAME <$SENDER_EMAIL>"
echo ""

# Send request
RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "✅ API Response:"
echo "$RESPONSE" | python -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Parse response
if echo "$RESPONSE" | grep -q "submission_id"; then
    echo "🎉 Email submitted successfully!"
    echo "   Check $RECIPIENT_EMAIL for the email"
else
    echo "⚠️  Response indicates possible issue"
    echo "   Please verify API endpoint is correct"
fi
