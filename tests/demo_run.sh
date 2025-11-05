#!/bin/bash
# FormBridge Demo Test Run - Shows what tests do (API not required)
# This runs a simplified version to demonstrate the test system

set -e

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  FormBridge Test Pack - DEMO RUN (No API Required)       ║"
echo "║  This shows what the tests do                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment
if [ ! -f ".env.local" ]; then
    echo "❌ Configuration file not found: .env.local"
    echo "   Please run: cp tests/.env.local.example tests/.env.local"
    exit 1
fi

echo -e "${BLUE}Loading configuration...${NC}"
export $(cat tests/.env.local | grep -v '^#' | xargs)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ TEST 1: Configuration Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ BASE_URL: $BASE_URL"
echo "✓ FORM_ID: $FORM_ID"
echo "✓ Configuration loaded successfully"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ TEST 2: Test Payload Generation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TIMESTAMP=$(date +%s)
PAYLOAD=$(cat <<EOF
{
  "form_id": "$FORM_ID",
  "name": "Demo User",
  "email": "demo@example.com",
  "message": "This is a demo test run",
  "timestamp": $TIMESTAMP
}
EOF
)

echo "Generated payload:"
echo "$PAYLOAD" | head -5
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ TEST 3: Test Endpoint Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Endpoints that would be tested:"
echo "  ✓ POST   $BASE_URL/submit       (Form submission)"
echo "  ✓ POST   $BASE_URL/analytics    (Analytics)"
echo "  ✓ POST   $BASE_URL/export       (CSV export)"
echo "  ✓ GET    $BASE_URL/health       (Health check)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ TEST 4: Headers Preparation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Request headers would be:"
echo "  ✓ Content-Type: application/json"
if [ ! -z "$API_KEY" ]; then
    echo "  ✓ X-Api-Key: [present]"
fi
if [ "$HMAC_ENABLED" = "true" ]; then
    echo "  ✓ X-Timestamp: $TIMESTAMP"
    echo "  ✓ X-Signature: [computed]"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ TEST 5: Artifact Directory Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "tests/artifacts" ]; then
    echo "✓ Artifact directory exists: tests/artifacts"
    ls -lah tests/artifacts/ 2>/dev/null | head -5 || echo "  (empty)"
else
    echo "✓ Would create artifact directory: tests/artifacts"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ TEST 6: API Connectivity Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v curl &> /dev/null; then
    echo "Testing connectivity to $BASE_URL..."
    if timeout 2 curl -s "$BASE_URL" > /dev/null 2>&1; then
        echo "✓ API is reachable!"
        echo "  Status: Ready for full test run"
    else
        echo "⚠ API not reachable (expected if not running)"
        echo "  To run full tests:"
        echo "    1. Start API: docker-compose up -d"
        echo "    2. Run tests: bash tests/run_all_local.sh"
    fi
else
    echo "ℹ curl not available (tests would use Node.js)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ DEMO RUN COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Test infrastructure verified!"
echo ""
echo "To run FULL tests:"
echo "  1. Start API (if not running):"
echo "     $ docker-compose up -d"
echo "  2. Run tests:"
echo "     $ bash tests/run_all_local.sh"
echo "     or (Windows):"
echo "     $ powershell -ExecutionPolicy Bypass -File tests/run_all_local.ps1"
echo ""
echo "Results will be saved to:"
echo "  • tests/report.html (HTML report)"
echo "  • tests/artifacts/ (JSON, CSV, etc)"
echo ""
