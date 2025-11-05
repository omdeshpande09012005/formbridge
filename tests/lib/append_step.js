#!/usr/bin/env node

/**
 * Append a test step result to summary JSON
 */

const fs = require('fs');
const path = require('path');

const summaryPath = process.argv[2];
const stepName = process.argv[3];
const status = process.argv[4];
const durationMs = parseInt(process.argv[5]) || 0;
const info = process.argv[6] ? JSON.parse(process.argv[6]) : {};

try {
  // Read current summary
  let summary = {};
  if (fs.existsSync(summaryPath)) {
    summary = JSON.parse(fs.readFileSync(summaryPath, 'utf-8'));
  }

  // Add step
  summary.steps = summary.steps || [];
  summary.steps.push({
    name: stepName,
    status: status,
    ms: durationMs,
    info: info,
    timestamp: new Date().toISOString(),
  });

  // Write back
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  process.exit(0);
} catch (err) {
  console.error('Error:', err.message);
  process.exit(1);
}
