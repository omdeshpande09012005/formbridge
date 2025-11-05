# FormBridge End-to-End Test Suite - LOCAL (PowerShell)
# Usage: pwsh tests/run_all_local.ps1

param(
    [string]$EnvFile = "$PSScriptRoot/.env.local"
)

$ErrorActionPreference = "Continue"

# Check if env file exists
if (!(Test-Path $EnvFile)) {
    Write-Host "❌ Configuration file not found: $EnvFile" -ForegroundColor Red
    Write-Host "   Please copy tests/.env.local.example to tests/.env.local and fill in values"
    exit 1
}

# Load environment variables from .env file
$env_vars = Get-Content $EnvFile | Where-Object { $_ -and !$_.StartsWith('#') } | ConvertFrom-StringData
$env_vars.GetEnumerator() | ForEach-Object {
    if ($_.Value) {  # Only set non-empty values
        [Environment]::SetEnvironmentVariable($_.Key, $_.Value)
    }
}

# Retrieve variables
$BASE_URL = [Environment]::GetEnvironmentVariable("BASE_URL")
$API_KEY = [Environment]::GetEnvironmentVariable("API_KEY")
$FORM_ID = [Environment]::GetEnvironmentVariable("FORM_ID")
$HMAC_ENABLED = [Environment]::GetEnvironmentVariable("HMAC_ENABLED")
$HMAC_SECRET = [Environment]::GetEnvironmentVariable("HMAC_SECRET")
$MAILHOG_URL = [Environment]::GetEnvironmentVariable("MAILHOG_URL")
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
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Step { Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue; Write-Host "▶ $args" -ForegroundColor Cyan; Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Blue }

# Print banner
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  FormBridge End-to-End Test Suite (LOCAL)                   ║" -ForegroundColor Cyan
Write-Host "║  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Initialize summary
node "$SCRIPT_DIR/lib/init_summary.js" "$SUMMARY_FILE" "local" "$BASE_URL" | Out-Null

# Sanity checks
Write-Step "SANITY CHECKS"

Write-Info "Checking required tools..."
$tools_ok = $true

foreach ($tool in @("node", "jq", "curl")) {
    $exists = Get-Command $tool -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Success "$tool is available"
    } else {
        Write-Error "Missing tool: $tool"
        $tools_ok = $false
    }
}

if (!$tools_ok) {
    Write-Error "Missing required tools"
    exit 1
}

Write-Info ""
Write-Info "Environment Configuration:"
Write-Info "  BASE_URL: $BASE_URL"
Write-Info "  FORM_ID: $FORM_ID"
Write-Info "  HMAC_ENABLED: $HMAC_ENABLED"

# Test connectivity
Write-Info ""
Write-Info "Testing API connectivity..."
try {
    $response = Invoke-WebRequest -Uri $BASE_URL -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
    Write-Success "API is reachable"
} catch {
    Write-Warning "API may not be reachable - continuing tests"
}

# Test submit
Write-Step "TEST: Form Submission"

$payload = @{
    form_id = $FORM_ID
    name = "Test User"
    email = "test@example.com"
    message = "PowerShell test submission"
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
        Write-Error "Submission failed: $response"
    }
} catch {
    Write-Error "Submission failed: $_"
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
        Write-Error "Analytics failed: $response"
    }
} catch {
    Write-Error "Analytics failed: $_"
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
        Write-Error "Export failed: Invalid CSV response"
    }
} catch {
    Write-Error "Export failed: $_"
}

# Generate report
Write-Step "GENERATING REPORT"

node "$SCRIPT_DIR/lib/collect_summary.js" report "$SUMMARY_FILE" "$REPORT_FILE" | Out-Null

Write-Host ""
Write-Success "Test suite completed"
Write-Info "📊 Open report: $REPORT_FILE"
Write-Host ""
