# FormBridge Secrets Management Migration

**Status:** ✅ IMPLEMENTATION COMPLETE  
**Date:** November 5, 2025  
**Version:** 1.0.0

---

## Overview

This guide covers the migration of FormBridge configuration and secrets from **environment variables** to **AWS Systems Manager Parameter Store (SSM)** and **AWS Secrets Manager** with **in-memory LRU caching** and **graceful fallback to environment variables**.

### Key Features

✅ **Secure Configuration**: Sensitive values (HMAC secrets) in Secrets Manager  
✅ **Cheap/Free Tier**: SSM Parameter Store has generous free tier (1000 parameters free)  
✅ **High Availability**: No cold-start overhead with 10-minute in-memory cache  
✅ **Zero Breaking Changes**: Environment variables remain as fallbacks  
✅ **Easy Rotation**: Update secrets without Lambda redeploy (cache invalidation via HMAC_VERSION)  
✅ **Non-Fatal Failures**: Fallback to env vars if SSM/Secrets unavailable  

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    contactFormProcessor Lambda              │
│                                                             │
│  load_config() → load_config_from_secrets_loader.py        │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  SecureConfig Instance (Singleton)                  │  │
│  │                                                      │  │
│  │  ┌─────────────────┐                                │  │
│  │  │ In-Memory Cache │ (TTL: 10 min)                  │  │
│  │  │ LRU + Timestamp │ Fast 1st call → cached after   │  │
│  │  └─────────────────┘                                │  │
│  │         ↓ (cache miss)                              │  │
│  │  ┌──────────────────────┐    ┌────────────────────┐ │  │
│  │  │ SSM Parameter Store  │    │ Secrets Manager    │ │  │
│  │  │ (fast network call)  │    │ (request secret)   │ │  │
│  │  │ GET /formbridge/.../ │    │ GET formbridge/... │ │  │
│  │  └──────────────────────┘    └────────────────────┘ │  │
│  │         ↓ (on failure)         ↓ (on failure)       │  │
│  │  ┌──────────────────────────────────────────────────┐│  │
│  │  │ Fallback to Environment Variables                 ││  │
│  │  │ (SES_RECIPIENTS, BRAND_NAME, etc.)               ││  │
│  │  └──────────────────────────────────────────────────┘│  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

Timeline of Requests:
1. Cold start (first invoke):  load SSM/Secrets (~100-200ms) + cache
2. Warm start (10 min window): use cache (~0ms)
3. Cache miss (> 10 min):      reload SSM/Secrets + update cache
4. SSM/Secrets unavailable:    use env vars (instant fallback)
```

---

## Why SSM Parameter Store & Secrets Manager?

| Feature | Parameter Store | Secrets Manager | Environment Vars |
|---------|-----------------|-----------------|------------------|
| **Cost** | 1000 free/month | $0.40/secret/month | Free (hardcoded) |
| **Security** | Std/SecureString | Encrypted at rest | Visible in console |
| **Audit Trail** | CloudTrail logs | CloudTrail + rotation audit | None |
| **Rotation** | Manual update | Auto-rotate with Lambda | Manual redeploy |
| **Use Case** | Config (non-sensitive) | Secrets (HMAC, API keys) | Dev fallback |

**FormBridge Recommendation:**
- **SSM Parameter Store**: Brand name, logo URL, color, dashboard URL, recipient list
- **Secrets Manager**: HMAC_SECRET (used for request signing)
- **Environment Variables**: Fallback for all above + always-present: STAGE, HMAC_VERSION, LOG_LEVEL

---

## Configuration Schema

### SSM Parameters

All parameters are under `/formbridge/{stage}/` with optional encryption:

```
/formbridge/prod/ses/recipients
  Type: String
  Value: "admin@example.com,support@example.com"
  Encrypted: No

/formbridge/prod/brand/name
  Type: String
  Value: "FormBridge"
  Encrypted: No

/formbridge/prod/brand/logo_url
  Type: String
  Value: "https://example.com/logo.svg"
  Encrypted: No

/formbridge/prod/brand/primary_hex
  Type: String
  Value: "#6D28D9"
  Encrypted: No

/formbridge/prod/dashboard/url
  Type: String
  Value: "https://dashboard.example.com"
  Encrypted: No
```

### Secrets Manager

```
formbridge/prod/HMAC_SECRET
  SecretString: "4f8d9e2c1a5b7f3e6a2b8d4c1f5a9e7b3c6d2e8f1a4b7c9d2e5f8a3b6c9e2f"
  Encrypted: Yes (KMS CMK or AWS managed)
  Rotation: Manual or Lambda-triggered
```

---

## How It Works

### Initial Implementation

1. **secrets_loader.py**: New module in `backend/secrets_loader.py`
   - `SecureConfig` class with LRU cache + 10-min TTL
   - `get_param(name, decrypt=False, fallback_env=None)` → SSM or env
   - `get_secret(name, fallback_env=None)` → Secrets Manager or env
   - Non-blocking: timeouts (1-2s), catches errors, falls back silently

2. **contact_form_lambda.py**: Updated to use `secrets_loader`
   - `load_config()` function: loads all branding/config from SSM/Secrets
   - Called once per request, cached for 10 minutes
   - On failure, uses environment variable as fallback
   - Zero impact on request flow (errors are non-fatal)

3. **template.yaml**: Updated IAM permissions
   - New Stage parameter (prod/dev/staging)
   - Added `ssm:GetParameter` on `/formbridge/{Stage}/*`
   - Added `secretsmanager:GetSecretValue` on `formbridge/{Stage}/*`
   - Added `kms:Decrypt` for SecureString parameters
   - Environment variables passed: STAGE, HMAC_VERSION, LOG_LEVEL

### Fallback Behavior

```python
# Example: Loading BRAND_NAME

config = load_config()

# Priority order:
# 1. Cache hit → return instantly
# 2. SSM /formbridge/prod/brand/name → fetch + cache
# 3. Env var BRAND_NAME → fetch + cache
# 4. Hardcoded default ("FormBridge") → return + cache

brand_name = config.get("brand_name")  # "FormBridge"
```

### Cache Invalidation

The cache can be invalidated via the `HMAC_VERSION` environment variable:

```python
# Lambda environment:
HMAC_VERSION = "1"

# cache_key = f"secret:formbridge/{stage}/HMAC_SECRET:v{hmac_version}"

# To rotate:
# 1. Update formbridge/prod/HMAC_SECRET in Secrets Manager
# 2. Change HMAC_VERSION=1 → HMAC_VERSION=2
# 3. Redeploy Lambda
# 4. Cache key changes → cache miss → new secret fetched

# Same day rotation possible without full redeploy:
# - Lambda Alias with canary → gradual rollout
# - Or force cache invalidation via config update
```

---

## Deployment Steps

### Step 1: Seed Parameters & Secrets

```bash
cd formbridge/scripts

# Generate HMAC secret (optional - script generates one)
HMAC_SECRET=$(openssl rand -hex 32)

# Run seeding script
./seed_parameters.sh --region ap-south-1 --stage prod
```

This creates:
- 5 SSM parameters (brand name, logo, color, recipients, dashboard URL)
- 1 Secrets Manager secret (HMAC_SECRET)

Verify in AWS Console:
- Systems Manager → Parameter Store → search `/formbridge/prod/`
- Secrets Manager → search `formbridge/prod/HMAC_SECRET`

### Step 2: Deploy Lambda

```bash
cd backend

# Update samconfig.toml if needed (Stage parameter)
sam build --use-container
sam deploy
```

Verify in Lambda console:
- Function: `contactFormProcessor`
- Environment variables:
  - STAGE=prod
  - HMAC_VERSION=1
  - LOG_LEVEL=INFO
  - (other existing env vars)

### Step 3: Test with SSM/Secrets

```bash
# Invoke Lambda via API Gateway
curl -X POST https://YOUR_API_ENDPOINT/submit \
  -H "Content-Type: application/json" \
  -d '{
    "form_id": "default",
    "name": "Test User",
    "email": "test@example.com",
    "message": "Test message"
  }'
```

Check CloudWatch logs for:
```
"Successfully loaded /formbridge/prod/brand/name from SSM"
"Cached /formbridge/prod/brand/name"
"Cache hit for param:/formbridge/prod/brand/name:v1"  # on next invocation
```

### Step 4: Test Fallback (Optional)

Temporarily disable SSM/Secrets access:
1. Modify Lambda IAM role to remove SSM/Secrets permissions
2. Invoke Lambda
3. Should see fallback: `"Using fallback env var BRAND_NAME for /formbridge/prod/brand/name"`
4. Request still succeeds (no outage)

---

## Testing Checklist

### Cold Start (First Invoke)

- [ ] CloudWatch logs show SSM/Secrets fetches
- [ ] Logs show "Successfully loaded ... from SSM"
- [ ] Email sent successfully with correct brand name/logo
- [ ] Response time: ~100-500ms (SSM + SES latency)

### Warm Start (Cached)

- [ ] Invoke same Lambda again within 10 minutes
- [ ] CloudWatch logs show "Cache hit for param:..."
- [ ] No SSM/Secrets API calls logged
- [ ] Response time: ~50-200ms (only SES latency)

### Cache Expiration

- [ ] Wait 10+ minutes
- [ ] Next invoke shows SSM/Secrets fetch again
- [ ] Logs show "Successfully loaded ..." (fresh fetch)

### Fallback Behavior

- [ ] Remove `ssm:GetParameter` from Lambda IAM role
- [ ] Invoke Lambda
- [ ] Logs show "SSM get_parameter failed... Using fallback"
- [ ] Request succeeds (email sent with env var values)
- [ ] Restore IAM permissions

### Rotation Dry-Run

- [ ] Update HMAC_SECRET in Secrets Manager (new value)
- [ ] Update HMAC_VERSION in Lambda env: 1 → 2
- [ ] Redeploy: `sam deploy`
- [ ] Invoke Lambda with old signature: should fail (401)
- [ ] Invoke with new signature: should succeed (200)

---

## Monitoring & Logs

### CloudWatch Log Patterns

**Successful SSM fetch:**
```
INFO: Successfully loaded /formbridge/prod/brand/name from SSM
INFO: Cached /formbridge/prod/brand/name
DEBUG: Cache hit for param:/formbridge/prod/brand/name:v1
```

**SSM timeout (fallback):**
```
WARNING: SSM get_parameter failed for /formbridge/prod/brand/name: RequestLimitExceeded. Using fallback.
INFO: Using fallback env var BRAND_NAME for /formbridge/prod/brand/name
```

**Secrets Manager fetch:**
```
INFO: Successfully loaded formbridge/prod/HMAC_SECRET from Secrets Manager (string)
```

**Cache invalidation:**
```
INFO: Cache invalidated. New version: 2
```

### CloudWatch Metrics to Monitor

```
SSM GetParameter API calls:
  - Namespace: AWS/SSM
  - Metric: CallCount (should be 1 per cold start, 0 per warm start)
  - Alarm: > 100 calls/hour (unusual churn)

Secrets Manager calls:
  - Namespace: AWS/SecretsManager
  - Metric: GetSecretValue (should be rare after cache stabilizes)

Lambda Duration:
  - Cold start: 100-500ms (SSM/Secrets + SES)
  - Warm start: 50-200ms (cache + SES)
  - Target: < 1s (P95)
```

---

## Rotation Playbook

### Scenario: Rotate HMAC Secret

**Requirement**: Update HMAC_SECRET without downtime.

**Option 1: Atomic Rotation with Version Bump (Recommended)**

1. Update secret in Secrets Manager:
   ```bash
   aws secretsmanager update-secret \
     --secret-id formbridge/prod/HMAC_SECRET \
     --secret-string "NEW_HMAC_VALUE" \
     --region ap-south-1
   ```

2. Increment HMAC_VERSION in template.yaml:
   ```yaml
   HMAC_VERSION: "2"  # was "1"
   ```

3. Redeploy Lambda:
   ```bash
   sam build --use-container && sam deploy
   ```

4. Verification:
   - Old HMAC signature (from HMAC_VERSION=1) → fails (401)
   - New HMAC signature (from HMAC_VERSION=2) → succeeds (200)
   - No request retry logic needed (client retries)

**Option 2: Gradual Rollout with Aliases (Advanced)**

1. Create new Lambda alias: `prod-v2`
2. Deploy with HMAC_VERSION=2 to prod-v2
3. Configure API Gateway to route 5% of traffic to prod-v2
4. Monitor errors
5. Gradually shift traffic: 10% → 25% → 50% → 100%
6. Delete prod-v1 alias

**Option 3: Dual-Key Validation (Complex)**

Allow validation with both old & new HMAC secrets for 24 hours:
- Accept signature with either v1 or v2 secret
- Log which version was used
- After 24h: require only v2

---

## Cost Analysis

### Free Tier (Per Month)

- **SSM Parameter Store**: 1,000 parameters free (FormBridge uses 5)
- **Secrets Manager**: Not included in free tier
- **Total SSM Cost**: $0 (well within free tier)

### Estimated Monthly Cost (Production)

| Service | Parameters | API Calls | Cost |
|---------|-----------|-----------|------|
| SSM Parameter Store | 5 | ~3M (1 per Lambda invoke) | $0 (free tier) |
| Secrets Manager | 1 | ~3M (1 per Lambda invoke) | $0.40 + $0.06 |
| **Total** | — | — | **~$0.46/month** |

### Comparison: Env Vars vs SSM

| Approach | Cost | Security | Audit | Notes |
|----------|------|----------|-------|-------|
| **Env Vars** | $0 | Low (visible) | None | Faster cold start (ms) |
| **SSM + Cache** | $0.46 | High | Full | First call: +100ms; cached calls: instant |
| **Cached Env** | $0 | Low | None | Hardcoded values (security risk) |

**Conclusion**: SSM + caching is essentially free and adds significant security/audit benefits.

---

## Migration Timeline

- **Phase 1**: secrets_loader.py created ✅ (Oct 27)
- **Phase 2**: contact_form_lambda.py updated to use secrets_loader ✅ (Oct 27)
- **Phase 3**: template.yaml IAM permissions added ✅ (Oct 27)
- **Phase 4**: seed_parameters.sh script created ✅ (Oct 27)
- **Phase 5**: Run seed script → create SSM/Secrets (USER ACTION)
- **Phase 6**: sam deploy → deploy updated Lambda (USER ACTION)
- **Phase 7**: Test with SSM/Secrets (USER ACTION)

---

## Troubleshooting

### Q: Lambda timing out on first invoke

**A**: Cold start is slow because SSM/Secrets fetch takes 100-200ms. This is normal. Subsequent invokes within 10 minutes will be instant. If consistently timing out:
- Check SSM Parameter Store health (AWS Console)
- Check Lambda timeout setting (should be ≥ 30s)
- Review CloudWatch logs for specific error

### Q: "Using fallback env var" messages in logs

**A**: Means SSM/Secrets unavailable (network error, permissions, or timeout). This is expected behavior—Lambda falls back to env vars gracefully. To debug:
```bash
# Check Lambda IAM role has ssm:GetParameter and secretsmanager:GetSecretValue
aws iam get-role-policy --role-name <role-name> --policy-name <policy-name>

# Check SSM parameter exists
aws ssm get-parameter --name /formbridge/prod/ses/recipients --region ap-south-1

# Check Secrets Manager secret exists
aws secretsmanager describe-secret --secret-id formbridge/prod/HMAC_SECRET --region ap-south-1
```

### Q: HMAC signature invalid after rotation

**A**: HMAC_VERSION environment variable wasn't updated. After updating secret:
1. Update template.yaml: HMAC_VERSION = "2"
2. Redeploy: sam deploy
3. Client must use new secret for signature

### Q: Cache not being used (always fetching from SSM)

**A**: Check HMAC_VERSION in logs. If incrementing every invoke, cache is being invalidated. Possible causes:
- Lambda container is being recycled (shouldn't happen for 10 min)
- HMAC_VERSION env var is dynamic (check template.yaml)
- secrets_loader.py cache_version logic is broken

---

## FAQ

**Q: Is SSM Parameter Store encrypted?**  
A: By default, String type parameters are not encrypted. SecureString type parameters are encrypted with AWS KMS. FormBridge uses String for non-sensitive config (brand name, URLs) and uses Secrets Manager (always encrypted) for HMAC_SECRET.

**Q: Can I use CloudFormation to create SSM parameters?**  
A: Yes, but the seed script is simpler for initial setup. For IaC, use `AWS::SSM::Parameter` resource in template.yaml.

**Q: What happens if SSM is down?**  
A: Lambda falls back to environment variables. No outage. Email/webhooks still work.

**Q: How do I change a parameter value?**  
A: Update via AWS Console → Systems Manager → Parameter Store, or use CLI:
```bash
aws ssm put-parameter --name /formbridge/prod/brand/name --value "NewName" --overwrite
```
Cache will refresh within 10 minutes (or use HMAC_VERSION bump for immediate refresh).

**Q: Can I cache longer than 10 minutes?**  
A: Yes, edit `CACHE_TTL_SECONDS = 600` in secrets_loader.py to a higher value (e.g., 3600 = 1 hour). Trade-off: faster rotation vs higher cache efficiency.

**Q: Does caching increase Lambda execution time?**  
A: No. Cold start: +100ms (SSM fetch). Warm start: 0ms (cache hit). Overall request time is dominated by SES, so impact is minimal.

**Q: How do I rotate secrets without any downtime?**  
A: Use the HMAC_VERSION bump method (Option 1 in Rotation Playbook). Update secret → increment version → deploy. Old clients briefly get 401, retry with new signature (automatic by most HTTP clients).

---

## Related Documentation

- **Webhook System**: See `docs/WEBHOOKS.md` for webhook relay configuration
- **Form Routing**: See `docs/FORM_ROUTING.md` for per-form configuration schema
- **IAM Policies**: See `backend/template.yaml` for complete IAM permission set
- **Secrets Loader Module**: See `backend/secrets_loader.py` for implementation details

---

## Summary

FormBridge now securely loads configuration from AWS SSM Parameter Store & Secrets Manager with:
- ✅ 10-minute LRU in-memory cache (no cold-start overhead)
- ✅ Graceful fallback to environment variables (zero downtime if SSM unavailable)
- ✅ HMAC secret rotation support (update value + bump version)
- ✅ Minimal cost (~$0.46/month for Secrets Manager)
- ✅ Full audit trail (CloudTrail logs all access)
- ✅ Zero breaking changes (all existing env vars still work)

**Next**: Run `./scripts/seed_parameters.sh` and deploy with `sam build && sam deploy`.

