export function handleSummary(data) {
  const metrics = data.metrics;
  const httpReqs = metrics.http_reqs;
  const httpReqDuration = metrics.http_req_duration;
  const httpReqFailed = metrics.http_req_failed;
  const timestamp = new Date().toISOString().split('T')[0];

  const testName = (data.summary && data.summary.scenario && data.summary.scenario.name) ? data.summary.scenario.name : 'loadtest';

  const totalRequests = (httpReqs && httpReqs.value) ? httpReqs.value : 0;
  const failedRequests = (httpReqFailed && httpReqFailed.value) ? httpReqFailed.value : 0;
  const successRate = totalRequests > 0 ? ((totalRequests - failedRequests) / totalRequests * 100).toFixed(2) : 0;
  const p95 = (httpReqDuration && httpReqDuration.stats && httpReqDuration.stats.p('0.95')) ? httpReqDuration.stats.p('0.95') : 0;
  const p99 = (httpReqDuration && httpReqDuration.stats && httpReqDuration.stats.p('0.99')) ? httpReqDuration.stats.p('0.99') : 0;
  const avgDuration = (httpReqDuration && httpReqDuration.stats && httpReqDuration.stats.avg) ? httpReqDuration.stats.avg : 0;
  const minDuration = (httpReqDuration && httpReqDuration.stats && httpReqDuration.stats.min) ? httpReqDuration.stats.min : 0;
  const maxDuration = (httpReqDuration && httpReqDuration.stats && httpReqDuration.stats.max) ? httpReqDuration.stats.max : 0;

  const responseCodeCounts = (data.metrics.http_resp_status && data.metrics.http_resp_status.values && data.metrics.http_resp_status.values.counts) ? data.metrics.http_resp_status.values.counts : {};

  try {
    mkdirSync('loadtest/reports', { recursive: true });
  } catch (e) {}

  const htmlContent = generateHTML({
    testName,
    totalRequests,
    failedRequests,
    successRate,
    p95,
    p99,
    avgDuration,
    minDuration,
    maxDuration,
    responseCodeCounts
  });

  const htmlFilename = 'loadtest/reports/results-' + testName + '-' + timestamp + '.html';
  try {
    writeFileSync(htmlFilename, htmlContent);
    console.log('HTML report: ' + htmlFilename);
  } catch (e) {
    console.error('HTML error: ' + e.message);
  }

  const csvContent = generateCSV({
    testName,
    totalRequests,
    failedRequests,
    successRate,
    p95,
    p99,
    avgDuration,
    minDuration,
    maxDuration
  });

  const csvFilename = 'loadtest/reports/results-' + testName + '-' + timestamp + '.csv';
  try {
    writeFileSync(csvFilename, csvContent);
    console.log('CSV report: ' + csvFilename);
  } catch (e) {
    console.error('CSV error: ' + e.message);
  }

  return { stdout: 'text' };
}

function generateHTML(stats) {
  const rows = Object.entries(stats.responseCodeCounts)
    .sort((a, b) => parseInt(a[0]) - parseInt(b[0]))
    .map(entry => {
      const code = entry[0];
      const count = entry[1];
      const percentage = ((count / stats.totalRequests) * 100).toFixed(2);
      let statusClass = 'status-success';
      if (code >= 400 && code < 500) statusClass = 'status-warning';
      if (code >= 500) statusClass = 'status-error';
      return '<tr><td><span class="status-badge ' + statusClass + '">' + code + '</span></td><td>' + count + '</td><td>' + percentage + '%</td></tr>';
    })
    .join('');

  const successClass = parseFloat(stats.successRate) >= 99 ? 'success' : 'warning';

  const html = '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>k6 Load Test Report</title><style>* { margin: 0; padding: 0; box-sizing: border-box; }body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 40px 20px; }.container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }.header h1 { font-size: 2.5em; margin-bottom: 10px; }.header p { font-size: 1.1em; opacity: 0.9; }.content { padding: 40px; }.metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 40px; }.metric-card { background: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; border-radius: 8px; }.metric-card.success { border-left-color: #22c55e; }.metric-card.warning { border-left-color: #eab308; }.metric-label { font-size: 0.85em; color: #666; text-transform: uppercase; margin-bottom: 8px; }.metric-value { font-size: 2em; font-weight: bold; color: #333; }.metric-unit { font-size: 0.6em; color: #999; margin-left: 5px; }.section { margin-bottom: 40px; }.section-title { font-size: 1.5em; font-weight: bold; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 2px solid #667eea; }table { width: 100%; border-collapse: collapse; }th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }th { background: #f3f4f6; font-weight: 600; color: #374151; }tr:hover { background: #f9fafb; }.status-badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 0.85em; font-weight: 600; }.status-success { background: #d1fae5; color: #065f46; }.status-warning { background: #fef3c7; color: #92400e; }.status-error { background: #fee2e2; color: #991b1b; }.test-info { background: #f0f9ff; border-left: 4px solid #0ea5e9; padding: 15px; border-radius: 4px; margin-bottom: 20px; font-size: 0.9em; }.footer { background: #f8f9fa; padding: 20px 40px; text-align: center; color: #666; font-size: 0.9em; border-top: 1px solid #e5e7eb; }</style></head><body><div class="container"><div class="header"><h1>📊 k6 Load Test Report</h1><p>' + stats.testName + '</p></div><div class="content"><div class="test-info"><strong>Test Name:</strong> ' + stats.testName + '<br><strong>Timestamp:</strong> ' + new Date().toISOString() + '<br><strong>Total Requests:</strong> ' + stats.totalRequests + '</div><div class="metrics-grid"><div class="metric-card ' + successClass + '"><div class="metric-label">Success Rate</div><div class="metric-value">' + stats.successRate + '<span class="metric-unit">%</span></div></div><div class="metric-card success"><div class="metric-label">P95 Latency</div><div class="metric-value">' + stats.p95.toFixed(0) + '<span class="metric-unit">ms</span></div></div><div class="metric-card"><div class="metric-label">P99 Latency</div><div class="metric-value">' + stats.p99.toFixed(0) + '<span class="metric-unit">ms</span></div></div><div class="metric-card"><div class="metric-label">Average Latency</div><div class="metric-value">' + stats.avgDuration.toFixed(0) + '<span class="metric-unit">ms</span></div></div></div><div class="section"><h2 class="section-title">Response Codes Histogram</h2><table><thead><tr><th>Status Code</th><th>Count</th><th>Percentage</th></tr></thead><tbody>' + rows + '</tbody></table></div><div class="section"><h2 class="section-title">Key Metrics</h2><table><tbody><tr><td>Total HTTP Requests</td><td>' + stats.totalRequests + '</td></tr><tr><td>Failed Requests</td><td>' + stats.failedRequests + '</td></tr><tr><td>Success Rate</td><td>' + stats.successRate + '%</td></tr><tr><td>P95 Latency</td><td>' + stats.p95.toFixed(2) + 'ms</td></tr><tr><td>P99 Latency</td><td>' + stats.p99.toFixed(2) + 'ms</td></tr><tr><td>Average Latency</td><td>' + stats.avgDuration.toFixed(2) + 'ms</td></tr><tr><td>Min Latency</td><td>' + stats.minDuration.toFixed(2) + 'ms</td></tr><tr><td>Max Latency</td><td>' + stats.maxDuration.toFixed(2) + 'ms</td></tr></tbody></table></div></div><div class="footer"><p>Generated by k6</p></div></div></body></html>';

  return html;
}

function generateCSV(stats) {
  return 'Metric,Value\nTest Name,' + stats.testName + '\nTimestamp,' + new Date().toISOString() + '\nTotal Requests,' + stats.totalRequests + '\nFailed Requests,' + stats.failedRequests + '\nSuccess Rate,' + stats.successRate + '%\nP95 Latency,' + stats.p95.toFixed(2) + 'ms\nP99 Latency,' + stats.p99.toFixed(2) + 'ms\nAverage Latency,' + stats.avgDuration.toFixed(2) + 'ms\nMin Latency,' + stats.minDuration.toFixed(2) + 'ms\nMax Latency,' + stats.maxDuration.toFixed(2) + 'ms';
}
