# API Gateway 403 Diagnostic Scripts - Integration Guide

Complete guide to integrate the diagnostic scripts into your FormBridge workflow and troubleshooting process.

## Overview

This package provides **idempotent, production-safe** diagnostics for API Gateway 403 errors:

- **Bash Script**: `diagnose-api-403.sh` - Full-featured, runs on Linux/macOS/WSL
- **PowerShell Script**: `diagnose-api-403.ps1` - Windows-native alternative
- **Documentation**: Comprehensive guides and quick reference

## Files Included

```
scripts/
├── diagnose-api-403.sh          # Main diagnostic script (bash)
├── diagnose-api-403.ps1         # Windows alternative (PowerShell)
├── DIAGNOSE_README.md           # Detailed documentation
├── QUICK_REFERENCE.md           # Quick AWS CLI commands
└── THIS_FILE.md                 # Integration guide
```

## Quick Start (5 minutes)

### For Linux/macOS/WSL Users

```bash
cd w:/PROJECTS/formbridge

# Run audit (no changes)
bash scripts/diagnose-api-403.sh

# Review output and findings

# If needed, apply fixes
bash scripts/diagnose-api-403.sh --fix-permissive

# Test with curl commands from output
```

### For Windows Users

```powershell
cd w:\PROJECTS\formbridge

# Run diagnostic
powershell -ExecutionPolicy Bypass -File scripts\diagnose-api-403.ps1

# Review output

# Optionally apply manual fixes from QUICK_REFERENCE.md
```

## Pre-Flight Checklist

Before running diagnostics, verify:

```bash
# 1. AWS CLI installed
aws --version

# 2. jq installed (JSON processor)
jq --version

# 3. curl installed
curl --version

# 4. AWS credentials configured
aws sts get-caller-identity

# 5. Correct API ID and stage
aws apigateway get-stage \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --region ap-south-1
```

## What the Scripts Diagnose

| Check | Purpose | Impact |
|-------|---------|--------|
| Stage exists | Verify deployment target | Fatal if missing |
| Usage plans | Check API key binding | Critical for auth |
| API key value | Retrieve actual key for testing | Required for requests |
| Method config | Verify apiKeyRequired setting | May need fix |
| Resource policy | Check for blocking policies | Usually the culprit |
| Test invoke | Bypass network to test Lambda | Isolates issues |
| CloudWatch logs | Show error details | Debugging tool |

## Workflow: From 403 to Working Tests

### Phase 1: Diagnosis (5 min)

```bash
# Run diagnostic audit
bash scripts/diagnose-api-403.sh

# Document findings:
# - ✓ Stage OK
# - ✓ Usage plan OK
# - ✓ API key OK
# - ⚠ Resource policy: RESTRICTIVE
# - ✗ Test invoke: 403
```

### Phase 2: Quick Fixes (2 min)

```bash
# Apply fixes (permissive policy + logging)
bash scripts/diagnose-api-403.sh --fix-permissive

# Output: API redeployed automatically
```

### Phase 3: Verification (3 min)

```bash
# Run curl commands from script output
# Test WITHOUT key (should be 403):
curl -i -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" \
  -H "Content-Type: application/json" \
  -d '{"form_id":"test","message":"hello"}'

# Test WITH key (should be 200):
curl -i -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_KEY_HERE" \
  -d '{"form_id":"test","message":"hello"}'
```

### Phase 4: Load Testing (See loadtest/README.md)

```bash
# Set up k6 environment
export BASE_URL="https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod"
export API_KEY="<FROM_DIAGNOSTIC_OUTPUT>"
export FORM_ID="my-portfolio"

# Run smoke test
k6 run loadtest/submit_smoke.js
```

## Integration with CI/CD

### GitHub Actions

Add to `.github/workflows/deploy.yml`:

```yaml
- name: Diagnose API Gateway
  run: |
    bash scripts/diagnose-api-403.sh
  env:
    AWS_REGION: ap-south-1
    API_ID: ${{ secrets.API_ID }}
    STAGE_NAME: Prod
```

### Local Pre-Push Hook

Create `.git/hooks/pre-push`:

```bash
#!/bin/bash
echo "Checking API Gateway health..."
bash scripts/diagnose-api-403.sh
if [ $? -ne 0 ]; then
    echo "API Gateway issues detected. Fix before pushing."
    exit 1
fi
```

## Troubleshooting the Diagnostic Script

### "aws not found"
```bash
# Install AWS CLI
brew install awscli  # macOS
apt install awscliv2  # Ubuntu
# or download from: https://aws.amazon.com/cli/
```

### "jq not found"
```bash
# Install jq
brew install jq      # macOS
apt install jq       # Ubuntu
choco install jq     # Windows (with Chocolatey)
```

### "AWS credentials not valid"
```bash
# Configure AWS
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=ap-south-1
```

### Script hangs or times out
```bash
# Add timeout
timeout 30 bash scripts/diagnose-api-403.sh

# Or run with verbose output
bash -x scripts/diagnose-api-403.sh
```

## Common Issues & Solutions

### Issue: "403 even with API key"

1. **Run diagnostic**:
   ```bash
   bash scripts/diagnose-api-403.sh
   ```

2. **Check findings**:
   - Is API key in usage plan? (Step 2)
   - Is stage bound to plan? (Step 2)
   - Is apiKeyRequired true? (Step 4)
   - Is resource policy permissive? (Step 5)

3. **Apply fixes**:
   ```bash
   bash scripts/diagnose-api-403.sh --fix-permissive
   ```

4. **Test again**:
   ```bash
   curl -i -X POST "https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit" \
     -H "X-Api-Key: YOUR_KEY"
   ```

5. **Check CloudWatch** if still failing:
   ```bash
   aws logs tail /aws/apigateway/12mse3zde5/Prod --follow
   ```

### Issue: "Stage not found"

```bash
# List available stages
aws apigateway get-stages --rest-api-id 12mse3zde5 --region ap-south-1

# Update script with correct stage name
export STAGE_NAME=YourStageName
bash scripts/diagnose-api-403.sh
```

### Issue: "No API key found"

```bash
# List API keys
aws apigateway get-api-keys --region ap-south-1

# Get key value
aws apigateway get-api-key --api-key <KEY_ID> --include-value --region ap-south-1
```

## Advanced: Manual Fixes

If automatic fixes don't work, apply manually:

### 1. Enable API Key Requirement

```bash
RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id 12mse3zde5 \
  --region ap-south-1 | jq -r '.items[] | select(.path == "/submit") | .id')

aws apigateway put-method \
  --rest-api-id 12mse3zde5 \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --api-key-required \
  --region ap-south-1
```

### 2. Apply Permissive Policy (Testing Only)

```bash
aws apigateway put-resource-policy \
  --rest-api-id 12mse3zde5 \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:ap-south-1:*:12mse3zde5/*"
    }]
  }' \
  --region ap-south-1
```

### 3. Enable Execution Logging

```bash
aws apigateway update-stage \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --patch-operations \
    op=replace,path=/*/*/logging/loglevel,value=INFO \
    op=replace,path=/*/*/logging/datatraceenabled,value=true \
  --region ap-south-1
```

### 4. Deploy API

```bash
aws apigateway create-deployment \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --region ap-south-1
```

## Monitoring & Logging

### View Execution Logs

```bash
# Real-time tail
aws logs tail /aws/apigateway/12mse3zde5/Prod --follow --region ap-south-1

# Search for errors
aws logs start-query \
  --log-group-name /aws/apigateway/12mse3zde5/Prod \
  --start-time $(($(date +%s) - 3600)) \
  --query-string 'fields @timestamp, @message | filter @message like /403|Forbidden/ | limit 50' \
  --region ap-south-1
```

### CloudWatch Logs Insights Queries

**Find 403 errors**:
```
fields @timestamp, @message, httpMethod, resourcePath, status
| filter status = 403
| stats count() by resourcePath
```

**Find slow requests**:
```
fields @timestamp, @duration
| filter @duration > 500
| sort @duration desc
```

**Find authorization failures**:
```
fields @timestamp, @message, authorizer, principalId
| filter @message like /Authorization|Forbidden|Access denied/
```

## Performance & Optimization

### Run Time
- **Diagnostic**: ~10-15 seconds
- **With fixes**: +5 seconds (deployment)
- **cURL test**: <1 second

### Costs
- No charges for diagnostics
- API calls are negligible (well within free tier)
- Deployment is free
- CloudWatch logs: ~$0.50/GB ingested

## Security Considerations

### Production Notes

⚠️ **IMPORTANT**: The `--fix-permissive` flag applies a **public-facing policy** for testing:

```json
{
  "Principal": "*",
  "Action": "execute-api:Invoke",
  "Resource": "arn:aws:execute-api:region:*:api/*"
}
```

**Do NOT use in production without proper restrictions.**

### Restrictive Policy Example (Production)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "execute-api:Invoke",
    "Resource": "arn:aws:execute-api:ap-south-1:*:12mse3zde5/Prod/POST/submit",
    "Condition": {
      "IpAddress": {
        "aws:SourceIp": [
          "203.0.113.0/24",
          "198.51.100.0/24"
        ]
      }
    }
  }]
}
```

## Maintenance

### Update Frequency
- Check for AWS API changes quarterly
- Review CloudFormation/SAM template updates
- Test with new k6 versions

### Backup Configuration
```bash
# Export current stage config
aws apigateway get-stage \
  --rest-api-id 12mse3zde5 \
  --stage-name Prod \
  --region ap-south-1 > stage-backup.json

# Export resource policy
aws apigateway get-resource-policy \
  --rest-api-id 12mse3zde5 \
  --region ap-south-1 > policy-backup.json
```

## Support & References

- **AWS API Gateway Docs**: https://docs.aws.amazon.com/apigateway/
- **AWS CLI Reference**: https://docs.aws.amazon.com/cli/latest/reference/apigateway/
- **k6 Documentation**: https://k6.io/docs/
- **FormBridge README**: See `README_PRODUCTION.md`

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-05 | 1.0.0 | Initial release - Bash + PowerShell scripts |

---

**Questions or Issues?** Check:
1. `DIAGNOSE_README.md` - Detailed documentation
2. `QUICK_REFERENCE.md` - Command reference
3. CloudWatch logs - AWS error details
4. AWS Support - For account-level issues
