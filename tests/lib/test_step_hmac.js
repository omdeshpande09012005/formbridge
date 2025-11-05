#!/usr/bin/env node

/**
 * Test step: HMAC Signature
 */

const { postJson } = require('./http_client.js');

const url = process.argv[2];
const payload = JSON.parse(process.argv[3]);
const hmacSecret = process.argv[4];

(async () => {
  try {
    const options = {
      hmacSecret: hmacSecret,
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
