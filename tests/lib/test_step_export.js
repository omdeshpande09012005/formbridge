#!/usr/bin/env node

/**
 * Test step: Export CSV
 */

const { postJson } = require('./http_client.js');

const url = process.argv[2];
const formId = process.argv[3];
const days = parseInt(process.argv[4]) || 7;
const apiKey = process.argv[5];

(async () => {
  try {
    const payload = {
      form_id: formId,
      days: days,
    };

    const options = {
      apiKey: apiKey || null,
      verbose: process.env.VERBOSE === 'true',
    };

    const result = await postJson(url, payload, options);

    if (result.status === 200 || result.status === 201) {
      // Export endpoint returns CSV, not JSON
      if (typeof result.body === 'string') {
        console.log(result.body);
      } else {
        console.log(JSON.stringify(result.body));
      }
    } else {
      console.error(JSON.stringify({
        error: `HTTP ${result.status}`,
        message: result.body,
      }));
      process.exit(1);
    }
  } catch (err) {
    console.error(JSON.stringify({
      error: 'Network error',
      message: err.message || err.error,
    }));
    process.exit(1);
  }
})();
