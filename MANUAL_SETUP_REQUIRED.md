🔍 FORMBRIDGE TEST SETUP - WHAT YOU NEED TO DO MANUALLY
═════════════════════════════════════════════════════════════════════════════════════

Current Status: November 6, 2025
✅ Test infrastructure: READY
⚠️  API: NOT RUNNING (required for full tests)

═════════════════════════════════════════════════════════════════════════════════════

📋 CHECKLIST - WHAT'S AUTOMATIC vs MANUAL
─────────────────────────────────────────────────────────────────────────────────────

✅ AUTOMATIC (Already Done):
  ✅ Test files created (16 files)
  ✅ Test configuration file created (tests/.env.local)
  ✅ Test runners ready (Bash + PowerShell)
  ✅ Report generation system configured
  ✅ All libraries and utilities in place
  ✅ GitHub Actions workflow configured

❌ MANUAL STEPS (You Need to Do):

  STEP 1: START THE FORMBRIDGE API
  ───────────────────────────────────
  
  You have 3 options (pick ONE):
  
  Option A - Using Docker Compose (RECOMMENDED if available):
    $ docker-compose up -d
    Wait for: "Ready on http://127.0.0.1:3000"
    
  Option B - Using AWS SAM Local:
    $ cd backend
    $ sam local start-api
    Wait for: "Serving on http://127.0.0.1:3000"
    
  Option C - Using Node.js directly:
    $ npm run start
    (or whatever your API start command is)
  
  ⏱️  This will take 30-60 seconds to start
  
  
  STEP 2: VERIFY API IS RUNNING (Optional but recommended)
  ────────────────────────────────────────────────────────
  
  Open a new terminal and run:
    $ curl http://127.0.0.1:3000
    
  You should get a response (not "connection refused")
  

  STEP 3: RUN THE TESTS (in another terminal)
  ─────────────────────────────────────────────
  
  Then run ONE of these commands (depending on your OS):
  
  Windows (PowerShell):
    $ cd w:\PROJECTS\formbridge
    $ powershell -ExecutionPolicy Bypass -File tests/run_all_local.ps1
    
  Linux/macOS/WSL (Bash):
    $ cd w/PROJECTS/formbridge
    $ bash tests/run_all_local.sh

═════════════════════════════════════════════════════════════════════════════════════

🎯 CURRENT STATUS
─────────────────────────────────────────────────────────────────────────────────────

API Status:              ⚠️  NOT RUNNING - You need to start it manually
                         See "STEP 1: START THE FORMBRIDGE API" above

Test Files:              ✅ 16 files ready
  • 4 test runners (2 Bash, 2 PowerShell)
  • 9 libraries & utilities
  • 2 configuration templates
  • 1 configuration file created

Configuration:           ✅ tests/.env.local ready
  • BASE_URL: http://127.0.0.1:3000
  • FORM_ID: my-portfolio
  • API_KEY: test-api-key-local
  • HMAC_ENABLED: false
  • All other settings: sensible defaults

Ready to Test:           ⏳ YES - after you start the API

═════════════════════════════════════════════════════════════════════════════════════

📊 WHAT HAPPENS WHEN YOU RUN TESTS
─────────────────────────────────────────────────────────────────────────────────────

1. Tests connect to http://127.0.0.1:3000
2. Run 8 test scenarios:
   • Sanity checks (verify tools & config)
   • Form submission test
   • Analytics retrieval test
   • CSV export test
   • HMAC signature test (if enabled)
   • Email branding test (if MailHog available)
   • DynamoDB query test (if AWS available)
   • SQS queue test (if configured)

3. Create report: tests/report.html
4. Save artifacts: tests/artifacts/

⏱️  Expected time: 1-5 seconds (depending on what's available)

═════════════════════════════════════════════════════════════════════════════════════

⚠️  EXPECTED TEST RESULTS (if API not running)
─────────────────────────────────────────────────────────────────────────────────────

Since API is currently NOT RUNNING:

✅ PASS:
  • Sanity tools (curl available)
  • HMAC test (skipped, disabled)
  • MailHog test (skipped, not required)
  • DynamoDB test (skipped, not required)
  • SQS test (skipped, not configured)

❌ FAIL:
  • Form submission (can't reach API)
  • Analytics (can't reach API)
  • CSV export (can't reach API)

Result: 5/8 tests pass or skip, 3 fail
This is EXPECTED and NORMAL when API isn't running.

Once you start the API, run tests again → 8/8 should pass ✅

═════════════════════════════════════════════════════════════════════════════════════

🚀 QUICK START (TL;DR)
─────────────────────────────────────────────────────────────────────────────────────

Terminal 1 - Start API:
  $ docker-compose up -d
  (or: cd backend && sam local start-api)
  Wait 30-60 seconds

Terminal 2 - Run Tests:
  $ cd w:\PROJECTS\formbridge
  $ powershell -ExecutionPolicy Bypass -File tests/run_all_local.ps1

Terminal 2 - View Results:
  Results show in terminal + open tests/report.html in browser

═════════════════════════════════════════════════════════════════════════════════════

❓ FAQ - MANUAL SETUP QUESTIONS
─────────────────────────────────────────────────────────────────────────────────────

Q: What if I don't have Docker?
A: Use Option B (SAM local) or Option C (npm start)

Q: What if I don't have SAM installed?
A: Use Option C (npm start) if available

Q: Where is docker-compose.yml?
A: Check your backend/ directory or root directory
   If missing, you'll need to use a different startup method

Q: Do I need Node.js installed?
A: For the test runners: PowerShell version doesn't need Node.js
   For the API: depends on your setup

Q: How long does startup take?
A: Usually 30-60 seconds for API to be ready
   Tests run in 1-5 seconds

Q: Can I run tests without the API?
A: Yes! Tests will still run and show partial results
   (5/8 pass, 3 skip/fail due to no API)

Q: Where are the test results saved?
A: 
  • Report: tests/report.html (open in browser)
  • JSON: tests/artifacts/summary.json
  • CSV: tests/artifacts/export_*.csv (if API available)
  • Other: tests/artifacts/ directory

═════════════════════════════════════════════════════════════════════════════════════

📁 FILES CREATED & READY
─────────────────────────────────────────────────────────────────────────────────────

Test Runners (Pick one based on your OS):
  ✅ tests/run_all_local.sh          (Bash - Linux/macOS/WSL)
  ✅ tests/run_all_local.ps1         (PowerShell - Windows) ← Use this on Windows
  ✅ tests/run_all_prod.sh           (Production - Bash)
  ✅ tests/run_all_prod.ps1          (Production - PowerShell)

Libraries (Auto-used by test runners):
  ✅ tests/lib/http_client.js        (HTTP requests with HMAC)
  ✅ tests/lib/aws_helpers.sh        (AWS operations)
  ✅ tests/lib/collect_summary.js    (Report generation)
  ✅ tests/lib/init_summary.js       (Initialize results)
  ✅ tests/lib/append_step.js        (Add test results)
  ✅ tests/lib/test_step_submit.js   (Submit form test)
  ✅ tests/lib/test_step_analytics.js (Analytics test)
  ✅ tests/lib/test_step_export.js   (Export CSV test)
  ✅ tests/lib/test_step_hmac.js     (HMAC test)

Configuration:
  ✅ tests/.env.local                (AUTO-CREATED with defaults) ← Ready to use
  ✅ tests/.env.local.example        (Template reference)
  ✅ tests/.env.prod.example         (Production template)

Documentation:
  ✅ QUICK_START_TESTS.md            (Quick reference)
  ✅ TEST_RESULTS_VERIFICATION.md    (Status guide)
  ✅ FULL_TEST_PACK_CHECKLIST.md     (Complete checklist)
  ✅ tests/README.md                 (700+ line guide)

CI/CD:
  ✅ .github/workflows/full_test.yml (GitHub Actions)

═════════════════════════════════════════════════════════════════════════════════════

🔧 MANUAL CONFIGURATION (if needed)
─────────────────────────────────────────────────────────────────────────────────────

If you need to customize test settings, edit:
  
  File: w:\PROJECTS\formbridge\tests\.env.local
  
  Common settings:
    BASE_URL=http://127.0.0.1:3000        (API URL)
    API_KEY=test-api-key-local            (If required)
    FORM_ID=my-portfolio                  (Form to test)
    HMAC_ENABLED=false                    (Enable HMAC signing)
    DDB_TABLE=contact-form-submissions-v2 (DynamoDB table name)
    REGION=ap-south-1                     (AWS region)

That's it! No other manual changes needed.

═════════════════════════════════════════════════════════════════════════════════════

✅ SUMMARY
─────────────────────────────────────────────────────────────────────────────────────

What's automatic:     ✅ All test infrastructure
What you must do:     ❌ Start the API manually
After that:           ✅ Run tests (fully automatic)

Status:               Ready to run once API is started

Next action:          STEP 1: Start API (see above)
                      STEP 2: Run tests
                      STEP 3: View results

═════════════════════════════════════════════════════════════════════════════════════

Questions? Check:
  • QUICK_START_TESTS.md - Quick reference
  • tests/README.md - Comprehensive guide
  • TEST_RESULTS_VERIFICATION.md - Troubleshooting

═════════════════════════════════════════════════════════════════════════════════════
