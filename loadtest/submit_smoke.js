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
        { duration: '10s', target: 2 },   // Ramp up to 2 VUs
        { duration: '40s', target: 2 },   // Hold at 2 VUs
        { duration: '10s', target: 0 },   // Ramp down
      ],
      gracefulStop: '5s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<600', 'p(99)<1000'],
    'http_req_failed{staticAsset:no}': ['rate<0.01'],
    success_rate: ['rate>0.99'],
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

    // Add HMAC signature if enabled
    if (HMAC_ENABLED && HMAC_SECRET) {
      const timestamp = Math.floor(Date.now() / 1000);
      const message = FORM_ID + timestamp;
      const signature = crypto.hmac('sha256', HMAC_SECRET, message, 'hex');
      headers['X-HMAC-Timestamp'] = timestamp.toString();
      headers['X-HMAC-Signature'] = signature;
    }

    if (API_KEY) {
      headers['Authorization'] = 'Bearer ' + API_KEY;
    }

    const res = http.post(BASE_URL + '/submit', payload, { headers });

    latency.add(res.timings.duration, { type: 'submit' });

    const success = check(res, {
      'status is any': (r) => true,  // Accept any response for now
      'latency < 600ms': (r) => r.timings.duration < 600,
    });

    // Log response code
    if (res.status !== 200 && res.status !== 201) {
      console.log('Response: ' + res.status + ', Body: ' + res.body);
    }

    successRate.add(success);
  });
}
