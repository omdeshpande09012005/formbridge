#!/bin/bash

################################################################################
# FormBridge Local Demo Bootstrap Script
# Idempotent script to set up LocalStack, DynamoDB table, and test data
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
TABLE_NAME="contact-form-submissions"
LOCALSTACK_ENDPOINT="http://localhost:4566"
AWS_ACCESS_KEY_ID="test"
AWS_SECRET_ACCESS_KEY="test"

# Export for AWS CLI
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$REGION

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     FormBridge Local Demo - Bootstrap Script               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Verify Docker is running
echo -e "${YELLOW}Step 1: Verifying Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Step 2: Check if containers are running
echo ""
echo -e "${YELLOW}Step 2: Checking if LocalStack is running...${NC}"

if docker ps | grep -q "formbridge-localstack"; then
    echo -e "${GREEN}✓ LocalStack is running${NC}"
else
    echo -e "${RED}❌ LocalStack is not running${NC}"
    echo -e "${YELLOW}Run 'docker compose up -d' first${NC}"
    exit 1
fi

# Step 3: Wait for LocalStack to be ready
echo ""
echo -e "${YELLOW}Step 3: Waiting for LocalStack to be ready...${NC}"

for i in {1..30}; do
    if curl -s "$LOCALSTACK_ENDPOINT/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ LocalStack is ready${NC}"
        break
    fi
    echo -e "${YELLOW}Waiting... ($i/30)${NC}"
    sleep 1
done

# Step 4: Check if table exists
echo ""
echo -e "${YELLOW}Step 4: Creating DynamoDB table (if not exists)...${NC}"

TABLE_EXISTS=$(docker exec formbridge-localstack awslocal dynamodb list-tables \
    --endpoint-url "$LOCALSTACK_ENDPOINT" \
    --region "$REGION" 2>/dev/null | grep -c "$TABLE_NAME" || true)

if [ "$TABLE_EXISTS" -gt 0 ]; then
    echo -e "${GREEN}✓ Table '$TABLE_NAME' already exists${NC}"
else
    echo -e "${YELLOW}Creating table '$TABLE_NAME'...${NC}"
    
    docker exec formbridge-localstack awslocal dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions \
            AttributeName=pk,AttributeType=S \
            AttributeName=sk,AttributeType=S \
        --key-schema \
            AttributeName=pk,KeyType=HASH \
            AttributeName=sk,KeyType=RANGE \
        --billing-mode PAY_PER_REQUEST \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$REGION" > /dev/null 2>&1
    
    echo -e "${GREEN}✓ Table created successfully${NC}"
    
    # Enable TTL
    echo -e "${YELLOW}Enabling TTL...${NC}"
    docker exec formbridge-localstack awslocal dynamodb update-time-to-live \
        --table-name "$TABLE_NAME" \
        --time-to-live-specification "AttributeName=ttl,Enabled=true" \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$REGION" > /dev/null 2>&1
    
    echo -e "${GREEN}✓ TTL enabled${NC}"
fi

# Step 5: Seed test data
echo ""
echo -e "${YELLOW}Step 5: Seeding test data...${NC}"

# Generate timestamp and UUID for test item
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z" 2>/dev/null || echo "2025-11-05T12:00:00.000000Z")
TEST_UUID="12345678-1234-1234-1234-123456789012"
TTL=$(($(date +%s) + 7776000))  # 90 days from now

# Check if test item already exists
ITEM_EXISTS=$(docker exec formbridge-localstack awslocal dynamodb get-item \
    --table-name "$TABLE_NAME" \
    --key "{\"pk\": {\"S\": \"FORM#demo-test\"}, \"sk\": {\"S\": \"SUBMIT#${TIMESTAMP}#${TEST_UUID}\"}}" \
    --endpoint-url "$LOCALSTACK_ENDPOINT" \
    --region "$REGION" 2>/dev/null | grep -c "Item" || true)

if [ "$ITEM_EXISTS" -gt 0 ]; then
    echo -e "${GREEN}✓ Test data already exists${NC}"
else
    docker exec formbridge-localstack awslocal dynamodb put-item \
        --table-name "$TABLE_NAME" \
        --item "{
            \"pk\": {\"S\": \"FORM#demo-test\"},
            \"sk\": {\"S\": \"SUBMIT#${TIMESTAMP}#${TEST_UUID}\"},
            \"id\": {\"S\": \"${TEST_UUID}\"},
            \"form_id\": {\"S\": \"demo-test\"},
            \"name\": {\"S\": \"Demo User\"},
            \"email\": {\"S\": \"demo@example.com\"},
            \"message\": {\"S\": \"This is a test submission from the local demo.\"},
            \"page\": {\"S\": \"http://localhost:8080\"},
            \"ts\": {\"S\": \"${TIMESTAMP}\"},
            \"ttl\": {\"N\": \"${TTL}\"}
        }" \
        --endpoint-url "$LOCALSTACK_ENDPOINT" \
        --region "$REGION" > /dev/null 2>&1
    
    echo -e "${GREEN}✓ Test data seeded${NC}"
fi

# Step 6: Display endpoints and instructions
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Local Demo Environment Ready                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}📊 Service Endpoints:${NC}"
echo -e "   LocalStack Gateway:    ${BLUE}http://localhost:4566${NC}"
echo -e "   DynamoDB Admin:        ${BLUE}http://localhost:8001${NC}"
echo -e "   MailHog SMTP:          ${BLUE}localhost:1025${NC}"
echo -e "   MailHog Web UI:        ${BLUE}http://localhost:8025${NC}"
echo -e "   Frontend:              ${BLUE}http://localhost:8080${NC}"
echo ""

echo -e "${GREEN}📋 DynamoDB Table:${NC}"
echo -e "   Table Name:            ${BLUE}${TABLE_NAME}${NC}"
echo -e "   Partition Key (pk):    String"
echo -e "   Sort Key (sk):         String"
echo ""

echo -e "${GREEN}🧪 Test API Locally:${NC}"
echo ""
echo -e "   ${YELLOW}Start SAM API server:${NC}"
echo -e "   ${BLUE}sam local start-api --port 3000${NC}"
echo ""
echo -e "   ${YELLOW}Submit form (in another terminal):${NC}"
echo -e "   ${BLUE}curl -X POST http://localhost:3000/submit \\\\"
echo -e "     -H 'Content-Type: application/json' \\\\"
echo -e "     -d '{${NC}"
echo -e "       ${BLUE}\"form_id\": \"demo-test\",${NC}"
echo -e "       ${BLUE}\"name\": \"John Doe\",${NC}"
echo -e "       ${BLUE}\"email\": \"john@example.com\",${NC}"
echo -e "       ${BLUE}\"message\": \"Test message\"${NC}"
echo -e "     ${BLUE}}'${NC}"
echo ""

echo -e "${GREEN}📧 Environment Variables (for Lambda):${NC}"
echo -e "   ${BLUE}DDB_TABLE=${TABLE_NAME}${NC}"
echo -e "   ${BLUE}DDB_ENDPOINT=${LOCALSTACK_ENDPOINT}${NC}"
echo -e "   ${BLUE}SES_PROVIDER=mailhog${NC}"
echo -e "   ${BLUE}MAILHOG_HOST=localhost${NC}"
echo -e "   ${BLUE}MAILHOG_PORT=1025${NC}"
echo ""

echo -e "${GREEN}✅ Bootstrap complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "   1. Check DynamoDB: ${BLUE}http://localhost:8001${NC}"
echo -e "   2. Check emails:   ${BLUE}http://localhost:8025${NC}"
echo -e "   3. Visit frontend: ${BLUE}http://localhost:8080${NC}"
echo ""

