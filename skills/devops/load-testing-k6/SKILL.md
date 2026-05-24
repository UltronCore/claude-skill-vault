---
name: load-testing-k6
description: Write and run load tests with k6 to measure API performance, find bottlenecks, and validate SLOs under realistic traffic patterns. Covers ramp-up scenarios, thresholds, metrics, and CI integration.
version: 1.0.0
tags: [k6, load-testing, performance, slo, stress-testing, api-testing]
---

# Load Testing with k6

## Overview

This skill covers designing and executing load tests using k6 — the modern JavaScript-based load testing tool. It addresses realistic traffic modeling with stages, custom metrics, threshold-based pass/fail for CI, browser-based load tests, and interpreting results. k6 runs tests defined in JavaScript/TypeScript, makes them version-controllable, and integrates with Grafana for live dashboards.

## When to Use

- Pre-launch performance validation for a new API or feature
- Finding the breaking point of a service under increasing load
- Validating SLOs (latency p99 < 200ms) at expected production traffic
- Catching performance regressions in CI before merging
- Comparing before/after performance of an optimization

## Step-by-Step Workflow

### 1. Installation and Basic Test
```bash
brew install k6  # macOS
# Or: docker run -i grafana/k6 run - <script.js

# First test
k6 run script.js
k6 run --vus 10 --duration 30s script.js  # 10 virtual users for 30s
```

### 2. Complete Test Script Structure
```javascript
// load-tests/api-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const orderCreationTime = new Trend('order_creation_duration', true);
const checkoutErrors = new Counter('checkout_errors');
const orderSuccessRate = new Rate('order_success_rate');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Warm up: ramp to 10 VUs
    { duration: '5m', target: 100 },  // Load: ramp to 100 VUs
    { duration: '2m', target: 100 },  // Sustain: hold 100 VUs
    { duration: '5m', target: 200 },  // Stress: ramp to 200 VUs
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    // Test fails if these are violated
    'http_req_duration': ['p(99)<500', 'p(95)<200'],  // 99% < 500ms
    'http_req_failed': ['rate<0.01'],                  // < 1% errors
    'order_success_rate': ['rate>0.99'],               // > 99% success
    'order_creation_duration': ['p(95)<300'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://api.staging.example.com';

// Shared setup data (runs once, not per VU)
export function setup() {
  const res = http.post(`${BASE_URL}/auth/token`, JSON.stringify({
    username: 'load-test-user', password: 'test-password'
  }), { headers: { 'Content-Type': 'application/json' } });
  
  return { token: res.json('access_token') };
}

// Main test function — runs for each VU continuously
export default function(data) {
  const headers = {
    'Authorization': `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };
  
  // Scenario 1: Browse products
  const products = http.get(`${BASE_URL}/products?page=1`, { headers });
  check(products, {
    'products status 200': r => r.status === 200,
    'products has data': r => r.json('items.length') > 0,
  });
  
  sleep(Math.random() * 2 + 1); // Think time: 1-3s
  
  // Scenario 2: Create order
  const start = new Date();
  const orderRes = http.post(
    `${BASE_URL}/orders`,
    JSON.stringify({
      items: [{ product_id: 'prod-1', quantity: 1 }],
      payment_method: 'card',
    }),
    { headers }
  );
  orderCreationTime.add(new Date() - start);
  
  const orderSuccess = check(orderRes, {
    'order created': r => r.status === 201,
    'order has id': r => r.json('order_id') !== undefined,
  });
  
  orderSuccessRate.add(orderSuccess);
  if (!orderSuccess) {
    checkoutErrors.add(1);
    console.log(`Order failed: ${orderRes.status} - ${orderRes.body}`);
  }
  
  sleep(Math.random() * 3 + 2); // Think time: 2-5s
}

// Teardown (runs once after test)
export function teardown(data) {
  console.log('Test complete');
}
```

### 3. Run with Different Profiles
```bash
# Smoke test (verify script works)
k6 run --vus 1 --duration 1m load-tests/api-test.js

# Load test
BASE_URL=https://api.staging.example.com k6 run load-tests/api-test.js

# Stress test (override stages)
k6 run --stage 0s:1,2m:500,5m:500,2m:0 load-tests/api-test.js

# Spike test
k6 run --stage 0s:10,30s:1000,30s:1000,30s:0 load-tests/api-test.js

# Output to InfluxDB + Grafana
k6 run --out influxdb=http://localhost:8086/k6 load-tests/api-test.js
```

### 4. Live Grafana Dashboard
```bash
# Start InfluxDB + Grafana
docker-compose up -d influxdb grafana

# docker-compose.yml
services:
  influxdb:
    image: influxdb:1.8
    ports: [8086:8086]
    environment:
      INFLUXDB_DB: k6
  grafana:
    image: grafana/grafana
    ports: [3000:3000]
    depends_on: [influxdb]

# Run test with live output
k6 run --out influxdb=http://localhost:8086/k6 script.js
# Import k6 dashboard in Grafana: https://grafana.com/grafana/dashboards/2587
```

### 5. Scenarios (Multiple Traffic Patterns)
```javascript
export const options = {
  scenarios: {
    // Constant arrival rate (more realistic than VUs)
    api_requests: {
      executor: 'constant-arrival-rate',
      rate: 1000,           // 1000 requests/second
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 200,
      maxVUs: 500,
    },
    // Separate scenario for heavy operations
    checkout_flow: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 50 },
        { duration: '5m', target: 50 },
      ],
      exec: 'checkoutUser',  // Different function
    },
  },
};

export function checkoutUser() {
  // Dedicated checkout flow test
}
```

## Key Commands Reference

```bash
# Run and generate HTML report
k6 run --out json=results.json script.js
k6 report results.json  # Experimental

# Summary output
k6 run --summary-trend-stats="avg,min,med,max,p(90),p(95),p(99)" script.js

# Cloud execution (k6 Cloud)
k6 cloud script.js

# Debug a single iteration
k6 run --vus 1 --iterations 1 --http-debug="full" script.js

# Check thresholds only (no live output)
k6 run --no-summary script.js; echo "Exit code: $?"
```

## Common Patterns

### Pattern 1: Realistic User Journey
```javascript
import { group } from 'k6';

export default function() {
  group('user authentication', () => {
    const loginRes = http.post(`${BASE_URL}/login`, credentials);
    check(loginRes, { 'login ok': r => r.status === 200 });
    token = loginRes.json('token');
    sleep(1);
  });
  
  group('product browsing', () => {
    for (let i = 0; i < randomIntBetween(2, 5); i++) {
      http.get(`${BASE_URL}/products/${randomItem(productIds)}`, { headers });
      sleep(randomIntBetween(1, 3));
    }
  });
  
  group('checkout', () => {
    const cart = http.post(`${BASE_URL}/cart`, cartData, { headers });
    sleep(2);
    const order = http.post(`${BASE_URL}/checkout`, { headers });
    check(order, { 'checkout success': r => r.status === 201 });
  });
}
```

### Pattern 2: CI Integration with GitHub Actions
```yaml
jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install k6
        run: |
          sudo gpg -k
          sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
            --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
            | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update && sudo apt-get install k6
      - name: Run load test
        run: k6 run --env BASE_URL=${{ secrets.STAGING_URL }} load-tests/smoke.js
        env:
          K6_CLOUD_TOKEN: ${{ secrets.K6_CLOUD_TOKEN }}
```

### Pattern 3: Parameterized Data with CSV
```javascript
import { SharedArray } from 'k6/data';
import papaparse from 'https://jslib.k6.io/papaparse/5.1.1/index.js';

const users = new SharedArray('users', () => {
  return papaparse.parse(open('./test-users.csv'), { header: true }).data;
});

export default function() {
  const user = users[__VU % users.length];  // Round-robin
  const res = http.post(`${BASE_URL}/login`, JSON.stringify({
    email: user.email,
    password: user.password,
  }));
  check(res, { 'login ok': r => r.status === 200 });
}
```

## Pitfalls to Avoid

1. **Testing from a single machine without enough headroom**: k6 is efficient but a single machine can only generate ~2000-5000 VUs before becoming the bottleneck. For high-load tests, use k6 Cloud or distribute across multiple machines with k6's distributed mode. Check CPU/network of the load generator machine during tests.

2. **Ignoring think time**: Real users don't hammer endpoints without pause. Always add `sleep(randomBetween(1,3))` between requests. Tests without think time create artificial saturation patterns that don't match production behavior. The constant-arrival-rate executor is better than VUs for modeling realistic traffic.

3. **Not baselining before optimizing**: Run a load test before optimization, record the metrics, then run after. Without a baseline, you can't prove improvement. Save results with `--out json=before.json` and compare key percentiles.

## Related Skills

- `chaos-engineering` — Combining chaos with load for realistic failure scenarios
- `circuit-breaker-patterns` — Verifying circuit breakers trigger correctly under load
- `opentelemetry-instrumentation` — Correlating load test spikes with traces
- `postgres-advanced` — Identifying DB bottlenecks exposed by load testing

## GitNexus Index

```json
{
  "skill": "load-testing-k6",
  "category": "devops",
  "triggers": ["k6", "load testing", "stress test", "performance test", "slo validation", "latency testing"],
  "outputs": ["load test script", "performance report", "threshold config", "CI load test"],
  "complexity": "medium",
  "tools": ["k6", "grafana", "influxdb", "k6-cloud"]
}
```
