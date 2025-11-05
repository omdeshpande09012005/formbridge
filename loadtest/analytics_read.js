import http from 'k6/http';
import { check, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const successRate = new Rate('success_rate');
const latency = new Trend('request_latency');

export const options = {
  scenarios: {
    analytics_read: {
      executor: 'constant-vus',
      vus: 5,
      duration: '2m',
      gracefulStop: '5s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<300', 'p(99)<500'],
    'http_req_failed{staticAsset:no}': ['rate<0.01'],
    success_rate: ['rate>0.99'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:3000';
const API_KEY = __ENV.API_KEY || '';

export default function (data) {
  group('Read Analytics', () => {
    const headers = {
      'Content-Type': 'application/json',
    };

    if (API_KEY) {
      headers['Authorization'] = 'Bearer ' + API_KEY;
    }

    const res = http.get(BASE_URL + '/analytics', { headers });

    latency.add(res.timings.duration, { type: 'analytics' });

    const success = check(res, {
      'status is 2xx': (r) => r.status >= 200 && r.status < 300,
      'latency < 300ms': (r) => r.timings.duration < 300,
    });

    successRate.add(success);
  });
}
