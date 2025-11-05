import http from 'k6/http';
import { check, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import crypto from 'k6/crypto';
import encoding from 'k6/encoding';

// Custom metrics
const successRate = new Rate('success_rate');
const latency = new Trend('request_latency');

export const options = {
  scenarios: {
    smoke_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5s', target: 1 },    // Ramp up to 1 VU
        { duration: '30s', target: 1 },   // Hold at 1 VU
        { duration: '5s', target: 0 },    // Ramp down
      ],
      gracefulStop: '5s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<5000', 'p(99)<10000'],
    http_req_failed: ['rate<0.1'],
    success_rate: ['rate>0.90'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:3000';
const API_KEY = __ENV.API_KEY || '';
const FORM_ID = __ENV.FORM_ID || 'my-portfolio';
const HMAC_ENABLED = __ENV.HMAC_ENABLED === 'true';
const HMAC_SECRET = __ENV.HMAC_SECRET || '';

export default function (data) {
  group('Submit Form (Smoke Test)', () => {
    const payload = JSON.stringify({
      form_id: FORM_ID,
      name: 'Smoke Test User',
      email: 'smoke@test.example.com',
      message: 'This is a smoke test message',
      page: 'https://example.com/contact'
    });

    const headers = {
      'Content-Type': 'application/json',
    };

    // Add API key header
    if (API_KEY) {
      headers['X-Api-Key'] = API_KEY;
    }

    // Add HMAC signature if enabled
    if (HMAC_ENABLED && HMAC_SECRET) {
      const timestamp = Math.floor(Date.now() / 1000);
      const message = FORM_ID + timestamp;
      const signature = crypto.hmac('sha256', HMAC_SECRET, message, 'hex');
      headers['X-HMAC-Timestamp'] = timestamp.toString();
      headers['X-HMAC-Signature'] = signature;
    }

    const res = http.post(BASE_URL + '/submit', payload, { headers });

    latency.add(res.timings.duration, { type: 'submit' });

    // Check if request was successful (any 2xx or 3xx status)
    const isSuccess = res.status >= 200 && res.status < 400;
    
    const checks = check(res, {
      'status is 2xx or 3xx': (r) => r.status >= 200 && r.status < 400,
      'response time reasonable': (r) => r.timings.duration < 10000,
    });

    // Log failures for debugging
    if (!isSuccess) {
      console.log(`[FAIL] Response: ${res.status}, Body: ${res.body.substring(0, 200)}`);
    }

    // Track success rate based on HTTP status
    successRate.add(isSuccess);
  });
}
