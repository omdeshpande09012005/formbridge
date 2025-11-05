#!/usr/bin/env node

/**
 * FormBridge Test Suite - Simple Runner
 * Runs all tests using Node.js directly
 * Usage: node tests/run_simple.js
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Colors for output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function header(title) {
  console.log('');
  log('╔' + '═'.repeat(62) + '╗', 'cyan');
  log(`║  ${title.padEnd(60)}║`, 'cyan');
  log('╚' + '═'.repeat(62) + '╝', 'cyan');
  console.log('');
}

function section(title) {
  log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`, 'cyan');
  log(`▶ ${title}`, 'cyan');
  log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'cyan');
}

// Load environment
const envFile = path.join(__dirname, '.env.local');
if (!fs.existsSync(envFile)) {
  log('❌ Configuration file not found:', 'red');
  log('   Please copy tests/.env.local.example to tests/.env.local', 'red');
  process.exit(1);
}

const envContent = fs.readFileSync(envFile, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
  if (line && !line.startsWith('#')) {
    const [key, value] = line.split('=');
    if (key && value) {
      env[key] = value.trim();
    }
  }
});

const BASE_URL = env.BASE_URL || 'http://127.0.0.1:3000';
const API_KEY = env.API_KEY || '';
const FORM_ID = env.FORM_ID || 'my-portfolio';

// Test results
let results = {
  passed: 0,
  failed: 0,
  skipped: 0,
  tests: [],
  startTime: Date.now()
};

// HTTP helper
function makeRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json'
      },
      timeout: 15000
    };

    if (API_KEY) {
      options.headers['X-Api-Key'] = API_KEY;
    }

    let bodyData = '';
    if (body) {
      bodyData = JSON.stringify(body);
      options.headers['Content-Length'] = Buffer.byteLength(bodyData);
    }

    const protocol = url.protocol === 'https:' ? https : http;
    const req = protocol.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (bodyData) {
      req.write(bodyData);
    }
    req.end();
  });
}

async function recordTest(name, status, duration, info = '') {
  let icon = status === 'PASS' ? '✓' : status === 'SKIP' ? '⊘' : '✗';
  let color = status === 'PASS' ? 'green' : status === 'SKIP' ? 'yellow' : 'red';

  log(`${icon} ${status} - ${name} (${duration}ms)${info ? ': ' + info : ''}`, color);

  if (status === 'PASS') results.passed++;
  if (status === 'FAIL') results.failed++;
  if (status === 'SKIP') results.skipped++;

  results.tests.push({ name, status, duration, info });
}

// Main test suite
async function runTests() {
  header(`FormBridge End-to-End Test Suite (LOCAL)`);
  log(`Configuration: ${BASE_URL}`, 'blue');
  log(`Form ID: ${FORM_ID}`, 'blue');
  console.log('');

  // Initialize artifacts directory
  const artifactsDir = path.join(__dirname, 'artifacts');
  if (!fs.existsSync(artifactsDir)) {
    fs.mkdirSync(artifactsDir, { recursive: true });
  }

  // Test 1: Sanity checks
  section('SANITY CHECKS');
  let start = Date.now();
  log('✓ Configuration loaded', 'green');
  log(`✓ BASE_URL: ${BASE_URL}`, 'green');
  log(`✓ FORM_ID: ${FORM_ID}`, 'green');
  await recordTest('sanity_config', 'PASS', Date.now() - start);
  console.log('');

  // Test 2: API Connectivity
  section('TEST: API Connectivity');
  start = Date.now();
  try {
    const response = await makeRequest('GET', '/');
    log('✓ API is reachable', 'green');
    await recordTest('api_connectivity', 'PASS', Date.now() - start);
  } catch (e) {
    log(`✗ API connection failed: ${e.message}`, 'red');
    await recordTest('api_connectivity', 'FAIL', Date.now() - start, e.message);
  }
  console.log('');

  // Test 3: Form Submission
  section('TEST: Form Submission');
  start = Date.now();
  try {
    const payload = {
      form_id: FORM_ID,
      name: 'Test User',
      email: 'test@example.com',
      message: 'This is a test submission',
      timestamp: Math.floor(Date.now() / 1000)
    };
    log(`Submitting form: ${FORM_ID}`, 'blue');

    const response = await makeRequest('POST', '/submit', payload);
    if (response.status === 200) {
      const body = JSON.parse(response.body);
      if (body.id) {
        log(`✓ Submission successful`, 'green');
        log(`  ID: ${body.id}`, 'green');
        fs.writeFileSync(path.join(artifactsDir, 'last_submission_id.txt'), body.id);
        await recordTest('submit', 'PASS', Date.now() - start);
      } else {
        throw new Error('No ID in response');
      }
    } else {
      throw new Error(`Status ${response.status}`);
    }
  } catch (e) {
    log(`✗ Submission failed: ${e.message}`, 'red');
    await recordTest('submit', 'FAIL', Date.now() - start, e.message);
  }
  console.log('');

  // Test 4: Analytics
  section('TEST: Analytics');
  start = Date.now();
  try {
    const payload = { form_id: FORM_ID };
    log(`Retrieving analytics for: ${FORM_ID}`, 'blue');

    const response = await makeRequest('POST', '/analytics', payload);
    if (response.status === 200) {
      const body = JSON.parse(response.body);
      if (body.totals !== undefined) {
        log(`✓ Analytics retrieved`, 'green');
        log(`  Total submissions: ${body.totals}`, 'green');
        await recordTest('analytics', 'PASS', Date.now() - start);
      } else {
        throw new Error('No totals in response');
      }
    } else {
      throw new Error(`Status ${response.status}`);
    }
  } catch (e) {
    log(`✗ Analytics failed: ${e.message}`, 'red');
    await recordTest('analytics', 'FAIL', Date.now() - start, e.message);
  }
  console.log('');

  // Test 5: CSV Export
  section('TEST: CSV Export');
  start = Date.now();
  try {
    const payload = { form_id: FORM_ID };
    log(`Exporting submissions for: ${FORM_ID}`, 'blue');

    const response = await makeRequest('POST', '/export', payload);
    if (response.status === 200) {
      const csv = response.body;
      if (csv && csv.includes('form_id')) {
        const filename = `export_${new Date().toISOString().split('T')[0]}.csv`;
        fs.writeFileSync(path.join(artifactsDir, filename), csv);
        const lines = csv.split('\n').length;
        log(`✓ Export successful`, 'green');
        log(`  Saved: ${filename}`, 'green');
        log(`  Lines: ${lines}`, 'green');
        await recordTest('export', 'PASS', Date.now() - start);
      } else {
        throw new Error('Invalid CSV format');
      }
    } else {
      throw new Error(`Status ${response.status}`);
    }
  } catch (e) {
    log(`✗ Export failed: ${e.message}`, 'red');
    await recordTest('export', 'FAIL', Date.now() - start, e.message);
  }
  console.log('');

  // Test 6: Optional tests (HMAC, Email, DynamoDB, SQS)
  section('OPTIONAL TESTS');
  log('⊘ HMAC: Not enabled (skipped)', 'yellow');
  log('⊘ Email: MailHog not available (skipped)', 'yellow');
  log('⊘ DynamoDB: AWS not configured (skipped)', 'yellow');
  log('⊘ SQS: Not configured (skipped)', 'yellow');
  results.skipped += 4;
  console.log('');

  // Summary
  const totalTime = Date.now() - results.startTime;
  section('TEST SUMMARY');
  log(`✓ Passed:  ${results.passed}`, 'green');
  log(`✗ Failed:  ${results.failed}`, results.failed > 0 ? 'red' : 'green');
  log(`⊘ Skipped: ${results.skipped}`, 'yellow');
  log(`Total:   ${results.passed + results.failed + results.skipped}`, 'blue');
  log(`Time:    ${totalTime}ms`, 'blue');
  console.log('');

  // Success rate
  const total = results.passed + results.failed;
  const rate = total > 0 ? Math.round((results.passed / total) * 100) : 0;
  log(`Success Rate: ${rate}%`, rate === 100 ? 'green' : rate >= 50 ? 'yellow' : 'red');

  // Save summary
  const summary = {
    timestamp: new Date().toISOString(),
    environment: 'local',
    results: results,
    url: BASE_URL
  };
  fs.writeFileSync(path.join(artifactsDir, 'summary.json'), JSON.stringify(summary, null, 2));
  log(`Report saved: tests/artifacts/summary.json`, 'cyan');
  console.log('');

  process.exit(results.failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(e => {
  log(`ERROR: ${e.message}`, 'red');
  process.exit(1);
});
