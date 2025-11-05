#!/bin/bash

###############################################################################
# seed_parameters.sh
# Seed AWS SSM Parameter Store & Secrets Manager with FormBridge configuration
#
# This script is idempotent - running it multiple times is safe.
#
# Usage:
#   ./scripts/seed_parameters.sh [--region REGION] [--stage STAGE]
#
# Environment variables (can also be set as parameters):
#   AWS_REGION (default: ap-south-1)
#   STAGE (default: prod)
#
# Parameters created:
#   /formbridge/{stage}/ses/recipients       → comma-separated email list
#   /formbridge/{stage}/brand/name           → brand name (FormBridge)
#   /formbridge/{stage}/brand/logo_url       → URL to logo
#   /formbridge/{stage}/brand/primary_hex    → primary color hex
#   /formbridge/{stage}/dashboard/url        → dashboard URL
#
# Secrets created:
#   formbridge/{stage}/HMAC_SECRET          → shared HMAC-SHA256 secret
#
###############################################################################

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Defaults
REGION="${AWS_REGION:-ap-south-1}"
STAGE="${STAGE:-prod}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            REGION="$2"
            shift 2
            ;;
        --stage)
            STAGE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FormBridge SSM/Secrets Seeding${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"
echo -e "Stage:  ${YELLOW}${STAGE}${NC}"
echo ""

# Verify AWS credentials
echo -e "${BLUE}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
    echo -e "${RED}✗ Failed to authenticate with AWS${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials verified${NC}"
echo ""

###############################################################################
# SSM Parameter Functions
###############################################################################

put_parameter() {
    local name="$1"
    local value="$2"
    local description="$3"
    local param_type="${4:-String}"  # String or SecureString
    
    echo -n "  Creating parameter ${name}... "
    
    # Check if parameter already exists
    if aws ssm get-parameter --name "$name" --region "$REGION" > /dev/null 2>&1; then
        # Update existing parameter
        aws ssm put-parameter \
            --name "$name" \
            --value "$value" \
            --type "$param_type" \
            --overwrite \
            --description "$description" \
            --region "$REGION" > /dev/null
        echo -e "${YELLOW}(updated)${NC}"
    else
        # Create new parameter
        aws ssm put-parameter \
            --name "$name" \
            --value "$value" \
            --type "$param_type" \
            --description "$description" \
            --region "$REGION" > /dev/null
        echo -e "${GREEN}(created)${NC}"
    fi
}

###############################################################################
# Secrets Manager Functions
###############################################################################

put_secret() {
    local name="$1"
    local value="$2"
    local description="$3"
    
    echo -n "  Creating secret ${name}... "
    
    # Check if secret already exists
    if aws secretsmanager describe-secret --secret-id "$name" --region "$REGION" > /dev/null 2>&1; then
        # Update existing secret
        aws secretsmanager update-secret \
            --secret-id "$name" \
            --secret-string "$value" \
            --region "$REGION" > /dev/null
        echo -e "${YELLOW}(updated)${NC}"
    else
        # Create new secret
        aws secretsmanager create-secret \
            --name "$name" \
            --description "$description" \
            --secret-string "$value" \
            --region "$REGION" > /dev/null
        echo -e "${GREEN}(created)${NC}"
    fi
}

###############################################################################
# Seed SSM Parameters
###############################################################################

echo -e "${BLUE}Seeding SSM Parameters...${NC}"

# SES Recipients (comma-separated list)
put_parameter \
    "/formbridge/${STAGE}/ses/recipients" \
    "admin@formbridge.example.com,support@formbridge.example.com" \
    "FormBridge SES recipients list (comma-separated)" \
    "String"

# Brand Name
put_parameter \
    "/formbridge/${STAGE}/brand/name" \
    "FormBridge" \
    "FormBridge brand name" \
    "String"

# Brand Logo URL
put_parameter \
    "/formbridge/${STAGE}/brand/logo_url" \
    "https://omdeshpande09012005.github.io/website/assets/logo.svg" \
    "FormBridge logo URL" \
    "String"

# Brand Primary Hex Color
put_parameter \
    "/formbridge/${STAGE}/brand/primary_hex" \
    "#6D28D9" \
    "FormBridge primary color (hex)" \
    "String"

# Dashboard URL
put_parameter \
    "/formbridge/${STAGE}/dashboard/url" \
    "https://omdeshpande09012005.github.io/docs/" \
    "FormBridge dashboard URL" \
    "String"

echo ""

###############################################################################
# Seed Secrets Manager
###############################################################################

echo -e "${BLUE}Seeding Secrets Manager...${NC}"

# HMAC Secret
# Generate a random HMAC secret if you want: openssl rand -hex 32
HMAC_SECRET_VALUE="${HMAC_SECRET:-$(openssl rand -hex 32)}"

put_secret \
    "formbridge/${STAGE}/HMAC_SECRET" \
    "$HMAC_SECRET_VALUE" \
    "FormBridge HMAC-SHA256 signing secret for request authentication"

echo ""

###############################################################################
# Summary
###############################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Seeding completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Parameters created:${NC}"
echo "  /formbridge/${STAGE}/ses/recipients"
echo "  /formbridge/${STAGE}/brand/name"
echo "  /formbridge/${STAGE}/brand/logo_url"
echo "  /formbridge/${STAGE}/brand/primary_hex"
echo "  /formbridge/${STAGE}/dashboard/url"
echo ""
echo -e "${YELLOW}Secrets created:${NC}"
echo "  formbridge/${STAGE}/HMAC_SECRET"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Verify values in AWS Console:"
echo "     - Systems Manager → Parameter Store"
echo "     - Secrets Manager"
echo "  2. Deploy Lambda with: sam build && sam deploy"
echo "  3. Test by removing env vars and invoking /submit"
echo ""
echo -e "${YELLOW}To rotate HMAC_SECRET:${NC}"
echo "  1. Update the secret value"
echo "  2. Update HMAC_VERSION env var in Lambda"
echo "  3. Redeploy: sam deploy"
echo ""
