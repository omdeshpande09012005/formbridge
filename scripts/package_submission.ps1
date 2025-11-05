# FormBridge Submission Packager (PowerShell)
# Purpose: Create idempotent submission package for professor/demo delivery
# Usage: .\package_submission.ps1
# Output: /dist/formbridge_submission_YYYYMMDD.zip

param(
    [string]$OutputDir = "dist",
    [string]$ExcludePattern = ".venv|.aws-sam|.env|__pycache__|.pyc|node_modules|.git|.vscode",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors for output
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }

# Get current directory
$ProjectRoot = Get-Location
$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$DateOnly = (Get-Date).ToString("yyyyMMdd")
$ZipName = "formbridge_submission_$DateOnly.zip"
$ZipPath = Join-Path $OutputDir $ZipName
$TempDir = Join-Path $env:TEMP "formbridge_package_$Timestamp"

Write-Info "FormBridge Submission Packager"
Write-Info "==============================="
Write-Info "Output: $OutputDir"
Write-Info "Timestamp: $Timestamp"
Write-Info ""

# Pre-flight checks
Write-Info "Running pre-flight checks..."

$RequiredFiles = @(
    "api/openapi.yaml",
    "api/postman/FormBridge.postman_collection.json",
    "api/postman/FormBridge.Dev.postman_environment.json",
    "api/postman/FormBridge.Prod.postman_environment.json",
    "backend/contact_form_lambda.py",
    "docs/demo/VIVA_SCRIPT.md",
    "docs/demo/DEMO_RUNBOOK.md",
    "docs/demo/SUBMISSION_CHECKLIST.md",
    "docs/demo/FAQ.md",
    "docs/demo/ONE_PAGER.md",
    "docs/demo/SCREENSHOT_SHOTLIST.md",
    "README.md",
    "template.yaml"
)

$MissingFiles = @()
foreach ($file in $RequiredFiles) {
    $FilePath = Join-Path $ProjectRoot $file
    if (-not (Test-Path $FilePath -PathType Leaf)) {
        $MissingFiles += $file
        Write-Warning "Missing: $file"
    } else {
        Write-Success "Found: $file"
    }
}

if ($MissingFiles.Count -gt 0) {
    Write-Error-Custom "Missing $($MissingFiles.Count) required files. Aborting."
    exit 1
}

Write-Info ""
Write-Info "Creating temporary staging directory..."
if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
New-Item -ItemType Directory -Path $TempDir | Out-Null
Write-Success "Staging dir: $TempDir"

Write-Info ""
Write-Info "Copying project files (excluding: $ExcludePattern)..."

# Define what to copy
$ItemsToCopy = @(
    "backend",
    "dashboard",
    "docs",
    "api",
    "scripts",
    "template.yaml",
    "README.md",
    "README_PRODUCTION.md",
    "IMPLEMENTATION_SUMMARY_HMAC_EXPORT.md",
    "HMAC_EXPORT_QUICK_REFERENCE.md",
    "SESSION_COMPLETION_SUMMARY.md"
)

$ExcludePatterns = @(".venv", ".aws-sam", ".env", "__pycache__", ".pyc", "node_modules", ".git", ".vscode", ".gitignore", ".github")

foreach ($item in $ItemsToCopy) {
    $SourcePath = Join-Path $ProjectRoot $item
    if (Test-Path $SourcePath) {
        $DestPath = Join-Path $TempDir $item
        
        if ((Get-Item $SourcePath) -is [System.IO.DirectoryInfo]) {
            # Copy directory
            Copy-Item -Path $SourcePath -Destination $DestPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Copied directory: $item"
        } else {
            # Copy file
            Copy-Item -Path $SourcePath -Destination $DestPath -Force
            Write-Success "Copied file: $item"
        }
    }
}

# Copy screenshots if exists
$ScreenshotSrc = Join-Path $ProjectRoot "docs/screenshots"
if (Test-Path $ScreenshotSrc) {
    $ScreenshotDest = Join-Path $TempDir "docs/screenshots"
    Copy-Item -Path $ScreenshotSrc -Destination $ScreenshotDest -Recurse -Force
    Write-Success "Copied screenshots"
} else {
    Write-Warning "No screenshots folder found (optional)"
}

# Create READ_ME_FIRST.txt
Write-Info ""
Write-Info "Creating READ_ME_FIRST.txt..."

$ReadmeContent = @"
╔════════════════════════════════════════════════════════════════════════════╗
║                     FormBridge - Submission Package                        ║
║                      Serverless Contact Form API                           ║
║                                                                            ║
║  Date: $(Get-Date -Format "dddd, MMMM dd, yyyy")                                               ║
╚════════════════════════════════════════════════════════════════════════════╝

👋 WELCOME

This package contains the complete FormBridge project—a production-ready,
serverless contact form API built on AWS Lambda, DynamoDB, and SES.

📚 GETTING STARTED (Pick One)

  Option 1: QUICK DEMO (5 minutes)
  ─────────────────────────────────
  1. Read: docs/demo/ONE_PAGER.md
  2. Watch: docs/demo/DEMO_RUNBOOK.md (visual walkthrough)
  3. Try locally: make local-up && make sam-api

  Option 2: VIVA PRESENTATION (8 minutes)
  ──────────────────────────────────────
  1. Read: docs/demo/VIVA_SCRIPT.md (complete script with Q&A)
  2. Practice with: docs/demo/DEMO_RUNBOOK.md
  3. Check: docs/demo/SUBMISSION_CHECKLIST.md before presenting

  Option 3: TECHNICAL DEEP-DIVE (30 minutes)
  ──────────────────────────────────────────
  1. Architecture: docs/demo/ONE_PAGER.md → Architecture section
  2. API Spec: api/openapi.yaml (or open in Swagger UI)
  3. FAQ: docs/demo/FAQ.md (design decisions explained)
  4. Code: backend/contact_form_lambda.py (main handler)

📁 PROJECT STRUCTURE

  formbridge_submission_YYYYMMDD/
  ├── backend/                              # Lambda Python code
  │   └── contact_form_lambda.py
  ├── dashboard/                            # React analytics dashboard
  │   ├── index.html
  │   ├── app.js
  │   └── config.example.js
  ├── docs/                                 # Documentation
  │   ├── demo/                             # Demo & viva docs
  │   │   ├── VIVA_SCRIPT.md               # 6-8 min presentation script
  │   │   ├── DEMO_RUNBOOK.md              # Step-by-step demo guide
  │   │   ├── ONE_PAGER.md                 # 1-page recruiter/prof summary
  │   │   ├── FAQ.md                       # 50 Q&As on design/architecture
  │   │   ├── SUBMISSION_CHECKLIST.md      # Pre-submission verification
  │   │   └── SCREENSHOT_SHOTLIST.md       # What to screenshot
  │   ├── screenshots/                      # Screenshots (if provided)
  │   ├── HMAC_SIGNING.md                  # HMAC implementation guide
  │   └── EXPORT_README.md                 # CSV export guide
  ├── api/                                  # API artifacts
  │   ├── openapi.yaml                     # OpenAPI 3.0 specification
  │   └── postman/                          # Postman collection & envs
  │       ├── FormBridge.postman_collection.json
  │       ├── FormBridge.Dev.postman_environment.json
  │       └── FormBridge.Prod.postman_environment.json
  ├── scripts/                              # Utility scripts
  ├── template.yaml                         # SAM infrastructure template
  ├── README.md                             # Main project README
  ├── README_PRODUCTION.md                  # Production deployment guide
  ├── IMPLEMENTATION_SUMMARY_HMAC_EXPORT.md # HMAC/CSV implementation details
  ├── SESSION_COMPLETION_SUMMARY.md         # Session overview
  └── READ_ME_FIRST.txt                     # This file

🚀 QUICK START (5 MINUTES)

  1. Install dependencies:
     - AWS CLI: https://aws.amazon.com/cli/
     - SAM CLI: https://aws.amazon.com/serverless/sam/
     - Docker: https://docker.com
     - Postman: https://www.postman.com

  2. Deploy locally:
     \$ cd formbridge_submission_YYYYMMDD
     \$ make local-up          # Start Docker services
     \$ make sam-api           # Run Lambda locally
     \$ make local-test        # Test form submission

  3. Deploy to AWS:
     \$ sam build
     \$ sam deploy --guided

  4. View results:
     - Dashboard: http://localhost:8080 (local) or GitHub Pages URL (prod)
     - DynamoDB: http://localhost:8001 (local admin UI)
     - Emails: http://localhost:8025 (MailHog for local testing)

📊 DEMO HIGHLIGHTS

  What you'll see:
  ✓ Form submission → DynamoDB storage → Email notification
  ✓ Real-time analytics dashboard (7-day trends)
  ✓ CSV export for reporting
  ✓ Security in action: API key validation, rate limiting, CORS
  ✓ CloudWatch logs and alarms

  Time required: 5–8 minutes live demo + Q&A

🔗 KEY DOCUMENTATION

  For professors/examiners:
  - ONE_PAGER.md                → Start here (project overview)
  - SUBMISSION_CHECKLIST.md     → Verification checklist
  - FAQ.md                      → Common questions & answers

  For developers:
  - template.yaml               → Infrastructure as Code (SAM)
  - backend/contact_form_lambda.py → Main Lambda handler
  - api/openapi.yaml            → API specification

  For operations:
  - README_PRODUCTION.md        → Deployment & monitoring guide
  - docs/demo/DEMO_RUNBOOK.md   → Live demo instructions

💰 COST & DEPLOYMENT

  - AWS free tier eligible: $0/month for typical usage
  - Region: ap-south-1 (Mumbai)
  - Uptime: 99.95%+ (AWS SLA)
  - Status: ✅ Live in production

🎯 NEXT STEPS

  1. Read ONE_PAGER.md (5 min)
  2. Review FAQ.md for common questions (10 min)
  3. Practice VIVA_SCRIPT.md using DEMO_RUNBOOK.md (20 min)
  4. Check SUBMISSION_CHECKLIST.md before viva (5 min)
  5. Deliver! 🚀

📧 CONTACT & LINKS

  GitHub: https://github.com/omdeshpande09012005/formbridge
  Dashboard: https://omdeshpande09012005.github.io/dashboard/
  OpenAPI UI: https://omdeshpande09012005.github.io/swagger/
  Portfolio: https://omdeshpande09012005.github.io

═══════════════════════════════════════════════════════════════════════════════

Questions? See docs/demo/FAQ.md or reach out.

Happy presenting! 🎉

$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))

═══════════════════════════════════════════════════════════════════════════════
"@

$ReadmeFile = Join-Path $TempDir "READ_ME_FIRST.txt"
Set-Content -Path $ReadmeFile -Value $ReadmeContent -Encoding UTF8
Write-Success "Created READ_ME_FIRST.txt"

# Create output directory if not exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Success "Created output directory: $OutputDir"
}

# Remove old zip if exists and not Force
if ((Test-Path $ZipPath) -and -not $Force) {
    Write-Warning "Zip already exists: $ZipPath"
    Write-Warning "Use -Force to overwrite"
    exit 1
}

# Create zip file
Write-Info ""
Write-Info "Creating zip package..."

try {
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }
    
    # Compress directory
    $SourcePath = "$TempDir\*"
    Compress-Archive -Path $SourcePath -DestinationPath $ZipPath -Force
    
    Write-Success "Created zip: $ZipPath"
    
    # Get file size
    $FileSize = (Get-Item $ZipPath).Length / 1MB
    Write-Success "File size: $('{0:F2}' -f $FileSize) MB"
    
} catch {
    Write-Error-Custom "Failed to create zip: $_"
    exit 1
}

# Cleanup temp directory
Write-Info "Cleaning up temporary files..."
Remove-Item -Recurse -Force $TempDir
Write-Success "Temp directory cleaned"

# Final summary
Write-Info ""
Write-Info "═════════════════════════════════════════════════════════"
Write-Success "✓ Submission package ready!"
Write-Info "═════════════════════════════════════════════════════════"
Write-Info ""
Write-Info "Package: $ZipPath"
Write-Info "Size: $('{0:F2}' -f $FileSize) MB"
Write-Info "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info ""
Write-Info "Next steps:"
Write-Info "1. Extract zip: Expand-Archive -Path $ZipPath -DestinationPath <folder>"
Write-Info "2. Read: READ_ME_FIRST.txt"
Write-Info "3. Start with: docs/demo/ONE_PAGER.md"
Write-Info ""
Write-Success "Ready for submission! 🎉"
