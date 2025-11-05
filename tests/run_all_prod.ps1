# FormBridge End-to-End Test Suite - PRODUCTION (PowerShell)
# Usage: pwsh tests/run_all_prod.ps1

param(
    [string]$EnvFile = "$PSScriptRoot/.env.prod"
)

$ErrorActionPreference = "Continue"

# Check if env file exists
if (!(Test-Path $EnvFile)) {
    Write-Host "❌ Configuration file not found: $EnvFile" -ForegroundColor Red
    Write-Host "   Please copy tests/.env.prod.example to tests/.env.prod and fill in values"
    exit 1
}

# Load environment variables from .env file
$env_vars = Get-Content $EnvFile | Where-Object { $_ -and !$_.StartsWith('#') } | ConvertFrom-StringData
$env_vars.GetEnumerator() | ForEach-Object {
    [Environment]::SetEnvironmentVariable($_.Key, $_.Value)
}

# Retrieve variables
$BASE_URL = [Environment]::GetEnvironmentVariable("BASE_URL")
$API_KEY = [Environment]::GetEnvironmentVariable("API_KEY")
$FORM_ID = [Environment]::GetEnvironmentVariable("FORM_ID")
$HMAC_ENABLED = [Environment]::GetEnvironmentVariable("HMAC_ENABLED")
$HMAC_SECRET = [Environment]::GetEnvironmentVariable("HMAC_SECRET")
$DDB_TABLE = [Environment]::GetEnvironmentVariable("DDB_TABLE")
$REGION = [Environment]::GetEnvironmentVariable("REGION")

$SCRIPT_DIR = $PSScriptRoot
$ARTIFACTS_DIR = Join-Path $SCRIPT_DIR "artifacts"
$SUMMARY_FILE = Join-Path $ARTIFACTS_DIR "summary.json"
$REPORT_FILE = Join-Path $SCRIPT_DIR "report.html"

# Create artifacts directory
if (!(Test-Path $ARTIFACTS_DIR)) {
    New-Item -ItemType Directory -Path $ARTIFACTS_DIR -Force | Out-Null
}

# Colors
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Fail { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Step { Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue; Write-Host "▶ $args" -ForegroundColor Cyan; Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Blue }

# Print banner
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  FormBridge End-to-End Test Suite (PRODUCTION)              ║" -ForegroundColor Cyan
Write-Host "║  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Validate configuration
if (!$API_KEY -or $API_KEY -eq "REPLACE_ME") {
    Write-Fail "API_KEY not configured or uses default value"
    exit 1
}

# Initialize summary
node "$SCRIPT_DIR/lib/init_summary.js" "$SUMMARY_FILE" "prod" "$BASE_URL" | Out-Null

# Sanity checks
Write-Step "SANITY CHECKS"

Write-Info "Checking required tools..."
$tools_ok = $true

foreach ($tool in @("node", "jq", "curl", "aws")) {
    $exists = Get-Command $tool -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Success "$tool is available"
    } else {
        Write-Fail "Missing tool: $tool"
        $tools_ok = $false
    }
}

if (!$tools_ok) {
    Write-Fail "Missing required tools"
    exit 1
}

Write-Info ""
Write-Info "Environment Configuration:"
Write-Info "  BASE_URL: $BASE_URL"
Write-Info "  FORM_ID: $FORM_ID"
Write-Info "  HMAC_ENABLED: $HMAC_ENABLED"
Write-Info "  REGION: $REGION"

# Test AWS credentials
Write-Info ""
Write-Info "Testing AWS credentials..."
try {
    $identity = aws sts get-caller-identity --region $REGION --output json 2>$null | ConvertFrom-Json
    Write-Success "AWS authenticated: $($identity.Arn)"
} catch {
    Write-Fail "AWS authentication failed"
    exit 1
}

# Test API connectivity
Write-Info ""
Write-Info "Testing API connectivity..."
try {
    $headers = @{ "X-Api-Key" = $API_KEY }
    $response = Invoke-WebRequest -Uri $BASE_URL -Headers $headers -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
    Write-Success "API is reachable"
} catch {
    Write-Warning "API may not be reachable (will continue)"
}

# Test submit
Write-Step "TEST: Form Submission"

$payload = @{
    form_id = $FORM_ID
    name = "Prod Test User"
    email = "test+prod@example.com"
    message = "Production test submission from PowerShell"
    timestamp = [int][double]::Parse((Get-Date -UFormat %s))
} | ConvertTo-Json

Write-Info "Submitting form: $FORM_ID"

try {
    $response = node "$SCRIPT_DIR/lib/test_step_submit.js" "$BASE_URL/submit" $payload $API_KEY $HMAC_ENABLED $HMAC_SECRET 2>$null | ConvertFrom-Json
    if ($response.id) {
        Write-Success "Submission successful"
        Write-Info "  Submission ID: $($response.id)"
        $response.id | Out-File "$ARTIFACTS_DIR/last_submission_id.txt" -Force
    } else {
        Write-Fail "Submission failed"
    }
} catch {
    Write-Fail "Submission failed: $_"
}

# Test analytics
Write-Step "TEST: Analytics"

Write-Info "Retrieving analytics for form: $FORM_ID"

try {
    $response = node "$SCRIPT_DIR/lib/test_step_analytics.js" "$BASE_URL/analytics" $FORM_ID $API_KEY 2>$null | ConvertFrom-Json
    if ($response.totals) {
        Write-Success "Analytics retrieved"
        Write-Info "  Total submissions: $($response.totals)"
    } else {
        Write-Fail "Analytics failed"
    }
} catch {
    Write-Fail "Analytics failed: $_"
}

# Test export
Write-Step "TEST: Export CSV"

$export_date = Get-Date -Format "yyyyMMdd"
$export_file = "$ARTIFACTS_DIR/export_${export_date}.csv"

Write-Info "Exporting submissions for: $FORM_ID"

try {
    $response = node "$SCRIPT_DIR/lib/test_step_export.js" "$BASE_URL/export" $FORM_ID 7 $API_KEY 2>$null
    if ($response -and $response -match ",") {
        $response | Out-File $export_file -Force
        $lines = ($response | Measure-Object -Line).Lines
        Write-Success "Export successful"
        Write-Info "  Saved to: $export_file"
        Write-Info "  Lines: $lines"
    } else {
        Write-Fail "Export failed: Invalid CSV response"
    }
} catch {
    Write-Fail "Export failed: $_"
}

# Test HMAC
if ($HMAC_ENABLED -eq "true") {
    Write-Step "TEST: HMAC Signature"
    
    if (!$HMAC_SECRET -or $HMAC_SECRET -eq "REPLACE_IF_ENABLED") {
        Write-Warning "HMAC enabled but secret not configured"
    } else {
        $payload = @{
            form_id = $FORM_ID
            name = "HMAC Prod Test"
            email = "hmac+prod@example.com"
            message = "Testing HMAC in production"
            timestamp = [int][double]::Parse((Get-Date -UFormat %s))
        } | ConvertTo-Json
        
        try {
            $response = node "$SCRIPT_DIR/lib/test_step_hmac.js" "$BASE_URL/submit" $payload $HMAC_SECRET 2>$null | ConvertFrom-Json
            if ($response.id) {
                Write-Success "HMAC test successful"
            } else {
                Write-Fail "HMAC test failed"
            }
        } catch {
            Write-Fail "HMAC test failed: $_"
        }
    }
}

# Generate report
Write-Step "GENERATING REPORT"

node "$SCRIPT_DIR/lib/collect_summary.js" report "$SUMMARY_FILE" "$REPORT_FILE" | Out-Null

Write-Host ""
Write-Success "Test suite completed"
Write-Info "📊 Open report: $REPORT_FILE"
Write-Host ""
