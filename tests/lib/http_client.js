#!/usr/bin/env node

/**
 * FormBridge HTTP Client Library
 * Supports JSON POST, X-Api-Key, HMAC signatures
 * Uses Node 18+ fetch (or undici fallback)
 */

const crypto = require('crypto');

/**
 * Compute HMAC-SHA256 signature
 * Format: HMAC_SHA256(secret, timestamp\nrawBody)
 */
function computeHmacSignature(secret, timestamp, rawBody) {
  const message = `${timestamp}\n${rawBody}`;
  return crypto
    .createHmac('sha256', secret)
    .update(message)
    .digest('hex');
}

/**
 * HTTP POST with optional HMAC signing
 * Returns { status, body, headers, ms }
 */
async function postJson(url, body, options = {}) {
  const {
    apiKey = null,
    hmacSecret = null,
    verbose = false,
    timeout = 10000,
  } = options;

  const startTime = Date.now();
  const rawBody = JSON.stringify(body);

  const headers = {
    'Content-Type': 'application/json',
  };

  if (apiKey) {
    headers['X-Api-Key'] = apiKey;
  }

  if (hmacSecret) {
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const signature = computeHmacSignature(hmacSecret, timestamp, rawBody);
    headers['X-Timestamp'] = timestamp;
    headers['X-Signature'] = signature;
  }

  if (verbose) {
    console.log(`[HTTP] POST ${url}`);
    console.log(`[HTTP] Headers: ${JSON.stringify(headers, null, 2)}`);
    console.log(`[HTTP] Body: ${rawBody}`);
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: rawBody,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    let responseBody;
    const contentType = response.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      responseBody = await response.json();
    } else {
      responseBody = await response.text();
    }

    const ms = Date.now() - startTime;

    if (verbose) {
      console.log(`[HTTP] Status: ${response.status}`);
      console.log(`[HTTP] Response Body: ${JSON.stringify(responseBody)}`);
      console.log(`[HTTP] Duration: ${ms}ms`);
    }

    return {
      status: response.status,
      body: responseBody,
      headers: Object.fromEntries(response.headers.entries()),
      ms,
    };
  } catch (err) {
    const ms = Date.now() - startTime;
    if (verbose) {
      console.error(`[HTTP] Error after ${ms}ms: ${err.message}`);
    }
    throw {
      status: 0,
      error: err.message,
      ms,
    };
  }
}

/**
 * HTTP GET with optional headers
 * Returns { status, body, headers, ms }
 */
async function getJson(url, options = {}) {
  const {
    apiKey = null,
    verbose = false,
    timeout = 10000,
  } = options;

  const startTime = Date.now();

  const headers = {
    'Accept': 'application/json',
  };

  if (apiKey) {
    headers['X-Api-Key'] = apiKey;
  }

  if (verbose) {
    console.log(`[HTTP] GET ${url}`);
    console.log(`[HTTP] Headers: ${JSON.stringify(headers, null, 2)}`);
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const response = await fetch(url, {
      method: 'GET',
      headers,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    let responseBody;
    const contentType = response.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      responseBody = await response.json();
    } else {
      responseBody = await response.text();
    }

    const ms = Date.now() - startTime;

    if (verbose) {
      console.log(`[HTTP] Status: ${response.status}`);
      console.log(`[HTTP] Response Body: ${JSON.stringify(responseBody)}`);
      console.log(`[HTTP] Duration: ${ms}ms`);
    }

    return {
      status: response.status,
      body: responseBody,
      headers: Object.fromEntries(response.headers.entries()),
      ms,
    };
  } catch (err) {
    const ms = Date.now() - startTime;
    if (verbose) {
      console.error(`[HTTP] Error after ${ms}ms: ${err.message}`);
    }
    throw {
      status: 0,
      error: err.message,
      ms,
    };
  }
}

/**
 * Download CSV data
 */
async function getCsv(url, options = {}) {
  const {
    apiKey = null,
    verbose = false,
    timeout = 10000,
  } = options;

  const startTime = Date.now();

  const headers = {
    'Accept': 'text/csv',
  };

  if (apiKey) {
    headers['X-Api-Key'] = apiKey;
  }

  if (verbose) {
    console.log(`[HTTP] GET ${url} (CSV)`);
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const response = await fetch(url, {
      method: 'GET',
      headers,
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    const csvData = await response.text();
    const ms = Date.now() - startTime;

    if (verbose) {
      console.log(`[HTTP] Status: ${response.status}`);
      console.log(`[HTTP] CSV length: ${csvData.length}`);
    }

    return {
      status: response.status,
      body: csvData,
      headers: Object.fromEntries(response.headers.entries()),
      ms,
    };
  } catch (err) {
    const ms = Date.now() - startTime;
    if (verbose) {
      console.error(`[HTTP] Error after ${ms}ms: ${err.message}`);
    }
    throw {
      status: 0,
      error: err.message,
      ms,
    };
  }
}

module.exports = {
  computeHmacSignature,
  postJson,
  getJson,
  getCsv,
};
