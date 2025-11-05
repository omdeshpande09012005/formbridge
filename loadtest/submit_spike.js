import http from 'k6/http';
import { check, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import crypto from 'k6/crypto';

const successRate = new Rate('success_rate');
const latency = new Trend('request_latency');
const throttled = new Counter('throttled_requests');

export const options = {
  scenarios: {
    spike_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 50 },   // Ramp up to 50 VUs
        { duration: '60s', target: 50 },   // Hold at 50 VUs
        { duration: '30s', target: 0 },    // Ramp down
      ],
      gracefulStop: '10s',
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
  group('Submit Form (Spike Test)', () => {
    const payload = JSON.stringify({
      form_id: FORM_ID,
      name: 'Spike Test User ' + Math.random(),
      email: 'spike' + Math.random() + '@test.example.com',
      message: 'This is a spike test message',
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

    if (res.status === 429) {
      throttled.add(1);
    }

    const success = check(res, {
      'status is 2xx, 3xx, or 429': (r) => (r.status >= 200 && r.status < 400) || r.status === 429,
      'no 5xx errors': (r) => r.status < 500,
    });

    successRate.add(success);
  });
}
