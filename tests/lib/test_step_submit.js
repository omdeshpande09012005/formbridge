#!/usr/bin/env node

/**
 * Test step: Submit form
 */

const { postJson } = require('./http_client.js');

const url = process.argv[2];
const payload = JSON.parse(process.argv[3]);
const apiKey = process.argv[4];
const hmacEnabled = process.argv[5] === 'true';
const hmacSecret = process.argv[6];

(async () => {
  try {
    const options = {
      apiKey: apiKey || null,
      hmacSecret: hmacEnabled && hmacSecret ? hmacSecret : null,
      verbose: process.env.VERBOSE === 'true',
    };

    const result = await postJson(url, payload, options);

    if (result.status === 200 || result.status === 201) {
      console.log(JSON.stringify(result.body));
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
