🚀 QUICK START - RUN FORMBRIDGE TESTS NOW
═════════════════════════════════════════════════════════════════════════

WHAT'S READY:
✅ Test infrastructure complete (16 files)
✅ Environment configuration created (.env.local)
✅ All test scripts ready to run
✅ Report generation configured

═════════════════════════════════════════════════════════════════════════

STEP 1: START LOCAL API (if not already running)
─────────────────────────────────────────────────────────────────────────

Option A - Using Docker Compose:
  $ docker-compose up -d

Option B - Using SAM (AWS):
  $ sam local start-api

Option C - Using Node.js directly:
  $ npm run start
  (or appropriate start command for your API)

Wait for: "Ready on http://127.0.0.1:3000" message

═════════════════════════════════════════════════════════════════════════

STEP 2: RUN TESTS IN NEW TERMINAL
─────────────────────────────────────────────────────────────────────────

Choose ONE method:

METHOD A - PowerShell (Windows):
  $ cd w:\PROJECTS\formbridge
  $ powershell -ExecutionPolicy Bypass -File tests/run_all_local.ps1

METHOD B - Bash (macOS/Linux/WSL):
  $ cd w/PROJECTS/formbridge
  $ bash tests/run_all_local.sh

METHOD C - Direct Bash (if available):
  $ ./tests/run_all_local.sh

═════════════════════════════════════════════════════════════════════════

STEP 3: WAIT FOR RESULTS
─────────────────────────────────────────────────────────────────────────

You'll see output like:

  ╔══════════════════════════════════════════════════════════╗
  ║  FormBridge End-to-End Test Suite (LOCAL)                ║
  ║  2025-11-06 12:34:56                                     ║
  ╚══════════════════════════════════════════════════════════╝

  ▶ SANITY CHECKS
  ✓ curl found: /usr/bin/curl
  ✓ jq found: /usr/local/bin/jq
  ✓ node found: /usr/local/bin/node
  ✓ PASS - sanity_tools (45ms)

  ▶ TEST: Form Submission
  ✓ PASS - submit (234ms)

  ▶ TEST: Analytics
  ✓ PASS - analytics (156ms)

  ▶ TEST: Export CSV
  ✓ PASS - export (342ms)

  ... more tests ...

  ✓ Test suite completed
  📊 Open report: file:///w/PROJECTS/formbridge/tests/report.html

═════════════════════════════════════════════════════════════════════════

STEP 4: VIEW HTML REPORT
─────────────────────────────────────────────────────────────────────────

The tests automatically create: tests/report.html

Open it in your browser:
  • Click the file path shown in terminal
  • Or manually open: w:\PROJECTS\formbridge\tests\report.html
  • Or use: start tests/report.html (Windows) / open tests/report.html (Mac)

You'll see:
  ✓ Green card for each passed test
  ⚠ Yellow card for skipped tests
  ✗ Red card for failed tests
  • Execution time for each test
  • Links to any saved artifacts (CSV, JSON, HTML)

═════════════════════════════════════════════════════════════════════════

WHAT GETS TESTED:
─────────────────────────────────────────────────────────────────────────

1. SANITY CHECKS
   ✓ Tools installed (curl, jq, node, aws-cli)
   ✓ Configuration valid
   ✓ API reachable

2. FORM SUBMISSION
   ✓ POST /submit endpoint works
   ✓ Submission ID returned
   ✓ Response is valid JSON

3. ANALYTICS
   ✓ GET /analytics endpoint works
   ✓ Returns submission totals
   ✓ Data is consistent

4. CSV EXPORT
   ✓ Export endpoint works
   ✓ CSV format is valid
   ✓ File saved to artifacts/

5. HMAC SIGNATURE (if enabled)
   ✓ HMAC-SHA256 signing works
   ✓ Signature validation passes
   ✓ Request headers correct

6. EMAIL BRANDING (if MailHog available)
   ✓ Email sent successfully
   ✓ FormBridge branding present
   ✓ Email HTML valid

7. DYNAMODB QUERY (if AWS available)
   ✓ Latest submission retrieved
   ✓ DynamoDB table accessible
   ✓ Data format valid

8. SQS QUEUE STATUS (if configured)
   ✓ Queue depth measured
   ✓ Queue accessible
   ✓ Messages present

═════════════════════════════════════════════════════════════════════════

EXPECTED RESULTS:
─────────────────────────────────────────────────────────────────────────

If API is running:
  Expected: 8/8 tests PASS ✅
  Time: ~1-2 seconds
  Report: All green cards

If API is not running:
  Expected: 5/8 tests pass, 3 skipped ⚠
  (API connection errors expected)
  Report: Mix of green and red cards
  Solution: Start the API and re-run

═════════════════════════════════════════════════════════════════════════

ARTIFACTS SAVED:
─────────────────────────────────────────────────────────────────────────

After each test run, these files are created in tests/artifacts/:

  • summary.json                 → Full test results (JSON)
  • export_20251106.csv         → Exported submissions (if test passed)
  • mailhog_latest.html         → Email capture (if MailHog running)
  • dynamo_latest.json          → DynamoDB item (if AWS available)
  • last_submission_id.txt      → Last submission ID (if successful)

═════════════════════════════════════════════════════════════════════════

TROUBLESHOOTING:
─────────────────────────────────────────────────────────────────────────

❌ "node: command not found"
   → Node.js not installed
   → Use PowerShell version instead (tests/run_all_local.ps1)
   → Or install Node.js: https://nodejs.org/

❌ "curl: command not found"
   → curl not in PATH
   → Install: brew install curl (macOS) / apt install curl (Linux)

❌ "jq: command not found"
   → jq not installed (JSON parser)
   → Install: brew install jq (macOS) / apt install jq (Linux)
   → Note: Tests continue without jq with reduced parsing

❌ "API may not be reachable"
   → API server not running
   → Start it: docker-compose up -d
   → Or: sam local start-api

❌ "Cannot reach 127.0.0.1:3000"
   → Check BASE_URL in tests/.env.local
   → Default is: http://127.0.0.1:3000
   → Change if your API runs on different port

✅ "All tests passed"
   → Success! API is working correctly
   → Review report.html for details

═════════════════════════════════════════════════════════════════════════

ADVANCED OPTIONS:
─────────────────────────────────────────────────────────────────────────

Run Production Tests:
  $ bash tests/run_all_prod.sh          (Bash)
  $ powershell -ExecutionPolicy Bypass -File tests/run_all_prod.sh  (PowerShell)

Requires: PROD API URL, API_KEY, AWS credentials

Manual Configuration:
  $ vi tests/.env.local               (Edit config)
  $ export $(cat tests/.env.local)    (Load variables)
  $ bash tests/run_all_local.sh       (Run tests)

Enable Debugging:
  $ VERBOSE=true bash tests/run_all_local.sh
  $ LOG_LEVEL=DEBUG bash tests/run_all_local.sh

═════════════════════════════════════════════════════════════════════════

FILES CREATED:
─────────────────────────────────────────────────────────────────────────

Test Runners:
  ✅ tests/run_all_local.sh              (Main local test runner - Bash)
  ✅ tests/run_all_local.ps1             (Main local test runner - PowerShell)
  ✅ tests/run_all_prod.sh               (Production test runner - Bash)
  ✅ tests/run_all_prod.ps1              (Production test runner - PowerShell)

Libraries:
  ✅ tests/lib/http_client.js            (HTTP client with HMAC support)
  ✅ tests/lib/aws_helpers.sh            (AWS utility functions)
  ✅ tests/lib/collect_summary.js        (Report generation)
  ✅ tests/lib/test_step_*.js            (Individual test executors)

Configuration:
  ✅ tests/.env.local                    (Local configuration - READY)
  ✅ tests/.env.local.example            (Template)
  ✅ tests/.env.prod.example             (Template)

Documentation:
  ✅ tests/README.md                     (700+ line comprehensive guide)
  ✅ TEST_RESULTS_VERIFICATION.md        (Status & reference)
  ✅ This file: QUICK_START_TESTS.md     (Quick reference)

═════════════════════════════════════════════════════════════════════════

NEXT: Run tests now! 🚀

$ bash tests/run_all_local.sh
or
$ powershell -ExecutionPolicy Bypass -File tests/run_all_local.ps1

═════════════════════════════════════════════════════════════════════════
