#!/usr/bin/env node

/**
 * FormBridge Test Summary Collector
 * Aggregates step outputs into a single JSON summary with artifacts
 */

const fs = require('fs');
const path = require('path');

/**
 * Create a new summary object
 */
function createSummary(env, baseUrl) {
  return {
    run_at: new Date().toISOString(),
    env: env, // 'local' or 'prod'
    base_url: baseUrl,
    steps: [], // Array of { name, status, ms, info }
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
      k6_json: null,
      dynamo_json: null,
    },
  };
}

/**
 * Add a test step result
 */
function addStep(summary, name, status, ms, info = {}) {
  summary.steps.push({
    name: name,
    status: status, // 'PASS' or 'FAIL'
    ms: ms,
    info: info,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Add k6 metrics from parsed results
 */
function addK6Metrics(summary, k6Results) {
  if (!k6Results) return;

  if (k6Results.p95) summary.metrics.k6.p95_ms = k6Results.p95;
  if (k6Results.p99) summary.metrics.k6.p99_ms = k6Results.p99;
  if (k6Results.success_rate) summary.metrics.k6.success_rate = k6Results.success_rate;
  if (k6Results.total_requests) summary.metrics.k6.total_requests = k6Results.total_requests;
}

/**
 * Add artifact link
 */
function addLink(summary, linkType, filePath) {
  if (summary.links.hasOwnProperty(linkType)) {
    summary.links[linkType] = filePath;
  }
}

/**
 * Get summary overview
 */
function getSummaryOverview(summary) {
  const total = summary.steps.length;
  const passed = summary.steps.filter(s => s.status === 'PASS').length;
  const failed = summary.steps.filter(s => s.status === 'FAIL').length;
  const totalMs = summary.steps.reduce((sum, s) => sum + (s.ms || 0), 0);

  return {
    env: summary.env,
    run_at: summary.run_at,
    total_steps: total,
    passed: passed,
    failed: failed,
    success_rate: total > 0 ? ((passed / total) * 100).toFixed(2) + '%' : 'N/A',
    total_duration_ms: totalMs,
  };
}

/**
 * Save summary to file
 */
function saveSummary(summary, outputPath) {
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(outputPath, JSON.stringify(summary, null, 2));
  console.log(`✓ Summary saved to: ${outputPath}`);
}

/**
 * Load summary from file
 */
function loadSummary(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
}

/**
 * Parse k6 JSON output to extract metrics
 */
function parseK6Results(k6JsonPath) {
  if (!fs.existsSync(k6JsonPath)) {
    return null;
  }

  try {
    const content = fs.readFileSync(k6JsonPath, 'utf-8');
    const lines = content.split('\n');

    let metrics = {
      p95: null,
      p99: null,
      success_rate: null,
      total_requests: 0,
    };

    for (const line of lines) {
      if (!line.trim()) continue;

      try {
        const data = JSON.parse(line);

        // Count successful requests
        if (data.type === 'Point' && data.metric === 'http_reqs') {
          metrics.total_requests = (metrics.total_requests || 0) + 1;
        }

        // Extract latency percentiles
        if (data.type === 'Summary' && data.metric === 'http_req_duration') {
          if (data.data && data.data.summary) {
            metrics.p95 = data.data.summary['p(95)'];
            metrics.p99 = data.data.summary['p(99)'];
          }
        }
      } catch (e) {
        // Skip invalid JSON lines
      }
    }

    return metrics;
  } catch (err) {
    console.error(`Failed to parse k6 results: ${err.message}`);
    return null;
  }
}

/**
 * Generate HTML report from summary
 */
function generateHtmlReport(summary, outputPath) {
  const overview = getSummaryOverview(summary);

  const rows = summary.steps
    .map(
      (step) => `
    <tr class="step-row ${step.status === 'PASS' ? 'pass' : 'fail'}">
      <td class="step-name">${escapeHtml(step.name)}</td>
      <td class="step-status ${step.status.toLowerCase()}">${step.status}</td>
      <td class="step-ms">${step.ms}ms</td>
      <td class="step-info">${escapeHtml(JSON.stringify(step.info))}</td>
    </tr>
  `
    )
    .join('\n');

  const artifactLinks = Object.entries(summary.links)
    .filter(([, link]) => link)
    .map(([name, link]) => `<a href="${link}" target="_blank">${name}</a>`)
    .join(' | ');

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>FormBridge Test Report</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; padding: 20px; }
    .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); padding: 30px; }
    h1 { font-size: 2em; margin-bottom: 10px; color: #333; }
    .header-meta { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
    .meta-card { background: #f9f9f9; padding: 15px; border-radius: 6px; border-left: 4px solid #6D28D9; }
    .meta-card strong { display: block; color: #666; font-size: 0.85em; margin-bottom: 5px; }
    .meta-card em { display: block; font-size: 1.3em; font-style: normal; color: #333; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 30px; }
    .summary-card { background: #f9f9f9; padding: 20px; border-radius: 6px; text-align: center; border-top: 3px solid #ccc; }
    .summary-card.passed { border-top-color: #10b981; }
    .summary-card.failed { border-top-color: #ef4444; }
    .summary-card strong { display: block; color: #666; font-size: 0.9em; margin-bottom: 10px; }
    .summary-card em { display: block; font-size: 2em; font-style: normal; font-weight: bold; color: #333; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
    th { background: #f9f9f9; border-bottom: 2px solid #ddd; padding: 12px; text-align: left; font-weight: 600; }
    td { padding: 12px; border-bottom: 1px solid #eee; }
    tr.step-row.pass { background: #f0fdf4; }
    tr.step-row.pass td:first-child::before { content: '✓ '; color: #10b981; font-weight: bold; }
    tr.step-row.fail { background: #fef2f2; }
    tr.step-row.fail td:first-child::before { content: '✗ '; color: #ef4444; font-weight: bold; }
    .step-status { font-weight: bold; }
    .step-status.pass { color: #10b981; }
    .step-status.fail { color: #ef4444; }
    .step-ms { font-variant-numeric: tabular-nums; }
    .step-info { font-size: 0.85em; color: #666; word-break: break-all; }
    .artifacts { background: #f9f9f9; padding: 20px; border-radius: 6px; margin-bottom: 30px; }
    .artifacts h3 { margin-bottom: 15px; color: #333; }
    .artifacts a { color: #6D28D9; text-decoration: none; margin-right: 15px; }
    .artifacts a:hover { text-decoration: underline; }
    .footer { text-align: center; color: #999; font-size: 0.85em; border-top: 1px solid #eee; padding-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>FormBridge Test Report</h1>

    <div class="header-meta">
      <div class="meta-card">
        <strong>Environment</strong>
        <em>${escapeHtml(overview.env.toUpperCase())}</em>
      </div>
      <div class="meta-card">
        <strong>Run Time</strong>
        <em>${new Date(overview.run_at).toLocaleString()}</em>
      </div>
      <div class="meta-card">
        <strong>Total Duration</strong>
        <em>${overview.total_duration_ms}ms</em>
      </div>
    </div>

    <div class="summary">
      <div class="summary-card passed">
        <strong>Passed</strong>
        <em>${overview.passed}/${overview.total_steps}</em>
      </div>
      <div class="summary-card failed">
        <strong>Failed</strong>
        <em>${overview.failed}/${overview.total_steps}</em>
      </div>
      <div class="summary-card">
        <strong>Success Rate</strong>
        <em>${overview.success_rate}</em>
      </div>
    </div>

    <h2 style="margin-top: 30px; margin-bottom: 20px; font-size: 1.3em;">Test Steps</h2>
    <table>
      <thead>
        <tr>
          <th>Step Name</th>
          <th style="width: 100px;">Status</th>
          <th style="width: 100px;">Duration</th>
          <th>Details</th>
        </tr>
      </thead>
      <tbody>
        ${rows}
      </tbody>
    </table>

    ${artifactLinks ? `<div class="artifacts"><h3>📎 Artifacts</h3>${artifactLinks}</div>` : ''}

    <div class="footer">
      <p>FormBridge End-to-End Test Report | Generated on ${new Date().toLocaleString()}</p>
    </div>
  </div>
</body>
</html>
  `;

  fs.writeFileSync(outputPath, html);
  console.log(`✓ HTML report saved to: ${outputPath}`);
}

/**
 * Escape HTML special characters
 */
function escapeHtml(text) {
  if (typeof text !== 'string') return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Export functions
module.exports = {
  createSummary,
  addStep,
  addK6Metrics,
  addLink,
  getSummaryOverview,
  saveSummary,
  loadSummary,
  parseK6Results,
  generateHtmlReport,
};

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];

  if (command === 'create') {
    const env = args[1] || 'local';
    const baseUrl = args[2] || 'http://localhost:3000';
    const summary = createSummary(env, baseUrl);
    console.log(JSON.stringify(summary, null, 2));
  } else if (command === 'report') {
    const summaryPath = args[1] || './artifacts/summary.json';
    const reportPath = args[2] || './report.html';
    const summary = loadSummary(summaryPath);
    if (summary) {
      generateHtmlReport(summary, reportPath);
    } else {
      console.error('No summary found at ' + summaryPath);
    }
  } else {
    console.log('Usage:');
    console.log('  collect_summary.js create <env> <baseUrl>');
    console.log('  collect_summary.js report <summaryPath> <reportPath>');
  }
}
