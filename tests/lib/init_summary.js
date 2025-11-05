#!/usr/bin/env node

/**
 * Initialize test summary JSON file
 */

const fs = require('fs');
const path = require('path');

const summaryPath = process.argv[2] || './artifacts/summary.json';
const env = process.argv[3] || 'local';
const baseUrl = process.argv[4] || 'http://localhost:3000';

const summary = {
  run_at: new Date().toISOString(),
  env: env,
  base_url: baseUrl,
  steps: [],
  metrics: {
    k6: {
      p95_ms: null,
      p99_ms: null,
      success_rate: null,
      total_requests: 0,
    },
  },
  links: {
    export_csv: null,
    mailhog_html: null,
    k6_html: null,
    dynamo_json: null,
  },
};

const dir = path.dirname(summaryPath);
if (!fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}

fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
console.log(`✓ Summary initialized: ${summaryPath}`);
