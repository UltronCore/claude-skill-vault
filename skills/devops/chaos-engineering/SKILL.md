---
name: chaos-engineering
description: Design and run chaos engineering experiments to build confidence in system resilience. Covers hypothesis-driven failure injection, steady-state monitoring, Chaos Monkey, Litmus, and game days.
version: 1.0.0
tags: [chaos-engineering, resilience, fault-injection, reliability, SRE, disaster-recovery]
---

# Chaos Engineering

## Overview

This skill provides a structured methodology for chaos engineering: formulating hypotheses about system behavior, defining steady-state metrics, injecting failures safely, observing results, and documenting findings. It covers tooling (Litmus, Chaos Mesh, toxiproxy, tc-netem), blast-radius control, progressive rollout of experiments, and game day organization. The goal is discovering weaknesses before production incidents do.

## When to Use

- Before a major product launch to validate resilience assumptions
- After implementing circuit breakers or retry logic — verify they actually work
- Building confidence in Kubernetes pod disruption handling
- Testing database failover, cache invalidation, or degraded-mode behavior
- Quarterly reliability game days for SRE teams

## Step-by-Step Workflow

### 1. Define the Experiment (Scientific Method)

**Template:**
```markdown
## Chaos Experiment: [Name]
**Date:** YYYY-MM-DD  **Environment:** staging

### Hypothesis
We believe that when [failure condition], the system will [expected behavior]
because [reason]. We expect [metric] to stay within [threshold].

### Steady State
- Success rate >= 99.5% (measured over 5min window)
- P99 latency < 500ms
- No error alerts firing in Grafana

### Failure Injection
- What: Kill 1 of 3 order-service pods
- Scope: staging/order-service deployment
- Duration: 2 minutes

### Rollback Trigger
- Success rate drops below 95%
- Any data loss detected
- Manual escalation

### Expected Outcome
Traffic reroutes within 10s, success rate temporarily dips to ~97%, 
recovers to 99.5%+ within 30s.
```

### 2. Network Failure with toxiproxy
```bash
# Install toxiproxy
brew install toxiproxy

# Start proxy
toxiproxy-server &

# Create proxy for your database
toxiproxy-cli create -l localhost:15432 -u postgres-host:5432 my-db

# Add latency (simulates slow database)
toxiproxy-cli toxic add -t latency -a latency=500 -a jitter=100 my-db

# Add packet loss (simulates flaky network)
toxiproxy-cli toxic add -t bandwidth -a rate=100 my-db

# Simulate complete outage
toxiproxy-cli toxic add -t timeout -a timeout=0 my-db

# Remove toxic (restore normal)
toxiproxy-cli toxic remove -n timeout_1 my-db

# Python client for programmatic control
from toxiproxy import Toxiproxy

client = Toxiproxy()
proxy = client.create("order-db", listen="0.0.0.0:15432", upstream="postgres:5432")

with proxy.add_toxic("latency", {"latency": 500, "jitter": 100}):
    # Run experiment — toxic removed after context
    run_load_test()
```

### 3. Kubernetes Pod/Node Failure with Chaos Mesh
```yaml
# chaos/pod-kill-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: order-service-pod-kill
  namespace: staging
spec:
  action: pod-kill
  mode: one          # Kill one random pod
  selector:
    namespaces: [staging]
    labelSelectors:
      app: order-service
  duration: 2m
  scheduler:
    cron: "@every 30m"  # Repeat every 30m for continuous validation
---
# Network chaos: partition between services
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: payment-network-delay
  namespace: staging
spec:
  action: delay
  mode: all
  selector:
    labelSelectors:
      app: payment-service
  delay:
    latency: "300ms"
    correlation: "25"
    jitter: "50ms"
  duration: 5m
```

```bash
# Apply and monitor
kubectl apply -f chaos/pod-kill-experiment.yaml
kubectl get podchaos -n staging
kubectl describe podchaos order-service-pod-kill -n staging

# Check Chaos Mesh dashboard
kubectl port-forward -n chaos-testing svc/chaos-dashboard 2333:2333
```

### 4. Linux Network Impairment with tc-netem
```bash
# Add 200ms latency to eth0
sudo tc qdisc add dev eth0 root netem delay 200ms

# Add 200ms ± 50ms with 25% correlation (more realistic)
sudo tc qdisc add dev eth0 root netem delay 200ms 50ms 25%

# Packet loss: 1% random packet loss
sudo tc qdisc add dev eth0 root netem loss 1%

# Packet corruption
sudo tc qdisc add dev eth0 root netem corrupt 0.1%

# Remove all rules
sudo tc qdisc del dev eth0 root

# Target specific destination (requires tc filter)
sudo tc qdisc add dev eth0 root handle 1: prio priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
sudo tc filter add dev eth0 parent 1: protocol ip u32 match ip dst 10.0.0.100/32 flowid 1:1
sudo tc qdisc add dev eth0 parent 1:1 handle 10: netem delay 300ms
```

### 5. Monitor During Experiment
```python
import prometheus_api_client
import time

prom = prometheus_api_client.PrometheusConnect(url="http://prometheus:9090")

def monitor_steady_state(duration_seconds: int, check_interval: int = 10):
    start = time.time()
    violations = []
    
    while time.time() - start < duration_seconds:
        # Success rate
        result = prom.custom_query(
            'sum(rate(http_requests_total{status!~"5.."}[1m])) / sum(rate(http_requests_total[1m]))'
        )
        success_rate = float(result[0]["value"][1]) if result else 0
        
        # P99 latency
        p99 = prom.custom_query(
            'histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m]))'
        )
        p99_ms = float(p99[0]["value"][1]) * 1000 if p99 else 999
        
        print(f"Success rate: {success_rate:.3%} | P99: {p99_ms:.0f}ms")
        
        if success_rate < 0.995 or p99_ms > 500:
            violations.append({
                "time": time.time(),
                "success_rate": success_rate,
                "p99_ms": p99_ms
            })
            if len(violations) > 3:
                print("ROLLBACK TRIGGERED: Steady state violated")
                return False
        
        time.sleep(check_interval)
    
    return len(violations) == 0
```

## Key Commands Reference

```bash
# Litmus Chaos (Kubernetes-native)
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.x.x.yaml
kubectl get chaosexperiments -n litmus

# Chaos Mesh installation
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing --create-namespace

# Gremlin (SaaS, agent-based)
gremlin attack-container --target container/my-service -- cpu --cores 2 --length 60

# Stress CPU (standalone)
stress-ng --cpu 4 --timeout 60s
stress-ng --vm 2 --vm-bytes 1G --timeout 60s

# Kill random process
kill -9 $(pgrep -n python)

# Fill disk
dd if=/dev/zero of=/tmp/fill bs=1M count=10000
```

## Common Patterns

### Pattern 1: Progressive Blast Radius
```markdown
Level 1 (LOCAL): Developer machine only, no network involved
Level 2 (UNIT): Single process/service in isolation with mocks
Level 3 (INTEGRATION): Two real services in staging, no users
Level 4 (STAGING): Full staging environment, internal traffic only
Level 5 (CANARY): 1% production traffic, monitored closely
Level 6 (PRODUCTION): 10%, 25%, 50%, 100% of production
```

### Pattern 2: Game Day Runbook Template
```markdown
# Game Day: [Scenario Name] — [Date]

## Scenario
We simulate: [major outage scenario]

## Team Roles
- **Chaos Lead**: Injects failures, monitors experiment
- **Observer**: Documents response, notes anomalies  
- **Incident Commander**: Makes rollback decisions
- **On-Call**: Responds as if real incident

## Timeline
09:00 - Brief, review runbook, verify monitoring
09:15 - Begin experiment (start injection)
09:45 - Stop injection, observe recovery
10:00 - Debrief: what worked, what didn't
10:30 - Action items logged

## Success Criteria
[ ] System recovered within SLO
[ ] Alerts fired as expected  
[ ] Runbook was sufficient for response
[ ] No data loss
```

### Pattern 3: Automated Chaos in CI/CD
```yaml
# .github/workflows/chaos-test.yml
jobs:
  chaos-test:
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to staging
        run: helm upgrade --install my-app ./chart --namespace staging
      
      - name: Wait for deployment
        run: kubectl rollout status deployment/my-app -n staging --timeout=120s
      
      - name: Run chaos experiment
        run: |
          kubectl apply -f chaos/pod-kill-experiment.yaml
          sleep 120  # Let experiment run
          kubectl delete -f chaos/pod-kill-experiment.yaml
      
      - name: Validate steady state
        run: python scripts/validate_steady_state.py --duration 60
```

## Pitfalls to Avoid

1. **Starting in production without staging validation**: Always prove the experiment works safely in staging first. Even "small" chaos experiments can cascade unexpectedly. Build confidence incrementally — never skip staging.

2. **No automated kill switch**: Every experiment needs a time limit and an automated rollback trigger. Never rely on humans to notice when to stop. Implement automated monitoring that aborts the experiment and pages on-call if thresholds are breached.

3. **Chaos without observability**: Injecting failures with no metrics to observe is just causing outages. You need dashboards showing the steady-state metrics BEFORE the experiment starts. If you can't measure the hypothesis, don't run the experiment yet.

## Related Skills

- `circuit-breaker-patterns` — Validating that circuit breakers trip correctly
- `load-testing-k6` — Combining chaos with load tests for real-world validation
- `opentelemetry-instrumentation` — Observability needed during experiments
- `kubernetes-architect` — Kubernetes-level resilience patterns

## GitNexus Index

```json
{
  "skill": "chaos-engineering",
  "category": "devops",
  "triggers": ["chaos engineering", "fault injection", "chaos monkey", "resilience testing", "game day", "failure injection", "toxiproxy"],
  "outputs": ["chaos experiment", "game day runbook", "resilience report", "chaos config"],
  "complexity": "high",
  "tools": ["chaos-mesh", "litmus", "toxiproxy", "tc-netem", "gremlin", "stress-ng"]
}
```
