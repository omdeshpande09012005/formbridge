#!/bin/bash

# FormBridge SAM Deployment Script (Simplified)
# Automatically builds and deploys the backend to AWS

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     FormBridge SAM Deployment (Automated)                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/backend" && pwd)"
REGION="${AWS_REGION:-us-east-1}"
STACK_NAME="formbridge-stack"

# Validate prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null || { echo -e "${RED}❌ AWS CLI required${NC}"; exit 1; }
command -v sam >/dev/null || { echo -e "${RED}❌ SAM CLI required${NC}"; exit 1; }
echo -e "${GREEN}✓ Prerequisites OK${NC}"

# Navigate to backend
cd "$BACKEND_DIR"

# Build
echo ""
echo -e "${YELLOW}Building application...${NC}"
sam build && echo -e "${GREEN}✓ Build complete${NC}"

# Deploy
echo ""
echo -e "${YELLOW}Deploying to AWS...${NC}"
sam deploy \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"

# Get outputs
echo ""
echo -e "${YELLOW}Retrieving endpoints...${NC}"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs' \
    --output table

