---
name: blue-green-deployments
description: Implement zero-downtime blue-green deployments using Kubernetes, AWS, and GitHub Actions. Covers traffic switching, smoke tests, automated rollback, canary graduation, and database migration strategies compatible with blue-green.
version: 1.0.0
tags: [blue-green, deployments, zero-downtime, kubernetes, aws, canary, rollback, devops, ci-cd]
---

# Blue-Green Deployments

## Overview

Blue-green deployment runs two identical production environments (blue = current, green = new) and switches traffic between them atomically — eliminating downtime and providing instant rollback. The strategy works by keeping the old environment live while deploying to the new one, running smoke tests against the new environment, then switching the load balancer. If anything fails post-switch, traffic reverts to the old environment in seconds.

## When to Use

- Production services where any downtime directly impacts revenue or SLA
- Deploying changes where rolling updates would create version mismatch across pods
- Releases with complex database migrations that must be backward-compatible
- When you need sub-second rollback capability (not just pod restart speed)
- Compliance environments that require full environment validation before live traffic
- Regulated industries where change management requires a verified pre-production state

## Step-by-Step Workflow

### 1. Kubernetes Blue-Green with Service Selector Switching

```yaml
# blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-blue
  namespace: production
  labels:
    app: api
    slot: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
      slot: blue
  template:
    metadata:
      labels:
        app: api
        slot: blue
        version: "1.4.2"
    spec:
      containers:
        - name: api
          image: myapp:1.4.2
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          resources:
            requests: {cpu: 100m, memory: 128Mi}
            limits: {cpu: 500m, memory: 256Mi}
---
# Service: traffic selector determines which slot is live
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: production
spec:
  selector:
    app: api
    slot: blue    # <-- this is the ONLY thing we change to switch traffic
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

```bash
#!/bin/bash
# deploy-blue-green.sh — complete blue-green deployment script

set -e

IMAGE="$1"          # e.g. myapp:1.5.0
NAMESPACE="production"
APP="api"

# Determine current and new slots
CURRENT_SLOT=$(kubectl get svc $APP -n $NAMESPACE \
  -o jsonpath='{.spec.selector.slot}')
NEW_SLOT=$([ "$CURRENT_SLOT" = "blue" ] && echo "green" || echo "blue")
CURRENT_IMAGE=$(kubectl get deploy $APP-$CURRENT_SLOT -n $NAMESPACE \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "Current slot: $CURRENT_SLOT ($CURRENT_IMAGE)"
echo "Deploying to: $NEW_SLOT with image $IMAGE"

# 1. Deploy new version to inactive slot
kubectl set image deployment/$APP-$NEW_SLOT \
  $APP=$IMAGE -n $NAMESPACE

# 2. Wait for new slot to be ready
kubectl rollout status deployment/$APP-$NEW_SLOT \
  -n $NAMESPACE --timeout=5m

# 3. Run smoke tests against new slot (via internal service or port-forward)
echo "Running smoke tests against $NEW_SLOT..."
kubectl run smoke-test --image=curlimages/curl --rm -it --restart=Never \
  --command -- curl -sf http://$APP-$NEW_SLOT.$NAMESPACE.svc.cluster.local/healthz

# 4. Switch traffic to new slot
echo "Switching traffic to $NEW_SLOT..."
kubectl patch svc $APP -n $NAMESPACE \
  -p "{\"spec\":{\"selector\":{\"slot\":\"$NEW_SLOT\"}}}"

# 5. Verify traffic is flowing
sleep 10
HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" https://api.acme.com/healthz)
if [ "$HTTP_STATUS" != "200" ]; then
  echo "SMOKE TEST FAILED! Rolling back to $CURRENT_SLOT..."
  kubectl patch svc $APP -n $NAMESPACE \
    -p "{\"spec\":{\"selector\":{\"slot\":\"$CURRENT_SLOT\"}}}"
  exit 1
fi

echo "Deployment successful! $NEW_SLOT is now live."
echo "Old slot ($CURRENT_SLOT) still running — ready for rollback if needed."
```

### 2. AWS ALB Blue-Green with Weighted Target Groups

```python
# aws_blue_green.py — manage AWS ALB target group weights
import boto3
from dataclasses import dataclass

@dataclass
class BlueGreenConfig:
    load_balancer_arn: str
    listener_arn: str
    blue_target_group_arn: str
    green_target_group_arn: str

def get_current_weights(config: BlueGreenConfig) -> dict:
    """Get current traffic weights for blue and green target groups."""
    client = boto3.client("elbv2")
    rules = client.describe_rules(ListenerArn=config.listener_arn)["Rules"]

    for rule in rules:
        for action in rule.get("Actions", []):
            if action["Type"] == "forward":
                groups = action.get("ForwardConfig", {}).get("TargetGroups", [])
                return {g["TargetGroupArn"]: g["Weight"] for g in groups}
    return {}

def set_traffic_split(config: BlueGreenConfig, blue_weight: int, green_weight: int):
    """Set traffic percentages between blue and green. Weights are relative (0-100)."""
    client = boto3.client("elbv2")
    rules = client.describe_rules(ListenerArn=config.listener_arn)["Rules"]

    # Find the main forward rule (not default)
    rule_arn = next(r["RuleArn"] for r in rules if not r["IsDefault"])

    client.modify_rule(
        RuleArn=rule_arn,
        Actions=[{
            "Type": "forward",
            "ForwardConfig": {
                "TargetGroups": [
                    {"TargetGroupArn": config.blue_target_group_arn,
                     "Weight": blue_weight},
                    {"TargetGroupArn": config.green_target_group_arn,
                     "Weight": green_weight},
                ],
                "TargetGroupStickinessConfig": {
                    "Enabled": True,
                    "DurationSeconds": 300  # Session stickiness during migration
                }
            }
        }]
    )
    print(f"Traffic: blue={blue_weight}%, green={green_weight}%")

def canary_rollout(config: BlueGreenConfig, steps: list[int] = [10, 30, 50, 100]):
    """Gradually shift traffic from blue to green with validation at each step."""
    import time

    for green_pct in steps:
        blue_pct = 100 - green_pct
        set_traffic_split(config, blue_pct, green_pct)
        print(f"Waiting 2 min at {green_pct}% green to monitor error rates...")
        time.sleep(120)

        # Check CloudWatch for elevated error rates
        if check_error_rate_elevated():
            print("ERROR RATE ELEVATED — rolling back to blue")
            set_traffic_split(config, 100, 0)
            raise RuntimeError("Canary rollout failed — rolled back")

    print("Canary rollout complete — 100% on green")

def check_error_rate_elevated(threshold: float = 0.01) -> bool:
    """Return True if error rate > threshold in last 5 minutes."""
    cw = boto3.client("cloudwatch")
    response = cw.get_metric_statistics(
        Namespace="AWS/ApplicationELB",
        MetricName="HTTPCode_Target_5XX_Count",
        Dimensions=[{"Name": "LoadBalancer", "Value": "..."}],
        StartTime=__import__("datetime").datetime.utcnow() - __import__("datetime").timedelta(minutes=5),
        EndTime=__import__("datetime").datetime.utcnow(),
        Period=300,
        Statistics=["Sum"]
    )
    errors = sum(p["Sum"] for p in response["Datapoints"])
    # Compare with total request count
    return errors > 0  # Simplified — implement proper rate check
```

### 3. GitHub Actions Blue-Green Pipeline

```yaml
# .github/workflows/deploy.yml
name: Blue-Green Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.build.outputs.image }}
    steps:
      - uses: actions/checkout@v4
      - name: Build and push image
        id: build
        run: |
          IMAGE="ghcr.io/org/api:${{ github.sha }}"
          docker build -t $IMAGE .
          docker push $IMAGE
          echo "image=$IMAGE" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBECONFIG }}

      - name: Blue-green deploy
        run: |
          chmod +x ./scripts/deploy-blue-green.sh
          ./scripts/deploy-blue-green.sh "${{ needs.build.outputs.image }}"

      - name: Run integration tests
        run: |
          pip install pytest requests
          pytest tests/integration/ --timeout=60

      - name: Notify success
        if: success()
        run: |
          echo "Deploy successful: ${{ needs.build.outputs.image }}" >> $GITHUB_STEP_SUMMARY

      - name: Rollback on failure
        if: failure()
        run: |
          CURRENT=$(kubectl get svc api -n production -o jsonpath='{.spec.selector.slot}')
          PREV=$([ "$CURRENT" = "blue" ] && echo "green" || echo "blue")
          kubectl patch svc api -n production -p "{\"spec\":{\"selector\":{\"slot\":\"$PREV\"}}}"
          echo "Rolled back to $PREV slot"
```

### 4. Database Migrations for Blue-Green

```python
# migrations/manager.py — backward-compatible migration patterns

# RULE: Migrations must work with BOTH old and new application version
# Pattern: Expand → Migrate → Contract (3-phase)

"""
Phase 1 (deploy with old app): Add new column with default — both app versions work
Phase 2 (deploy new app): Both old (reads old col) and new (reads new col) work
Phase 3 (next release): Drop old column
"""

# Phase 1 migration — safe with old code
MIGRATION_PHASE_1 = """
-- ADD nullable column with default — old app ignores it, new app uses it
ALTER TABLE users ADD COLUMN display_name VARCHAR(255) DEFAULT '';
UPDATE users SET display_name = username WHERE display_name = '';
"""

# Phase 2 — new app writes to both columns during transition
# (Python side)
def update_user(conn, user_id: str, username: str, display_name: str):
    """Write to both old and new column during blue-green transition."""
    conn.execute(
        "UPDATE users SET username = $1, display_name = $2 WHERE id = $3",
        [username, display_name, user_id]
    )

# Phase 3 migration — only after all traffic is on new version for 1+ deploys
MIGRATION_PHASE_3 = """
-- Safe to drop now — no old app version running
ALTER TABLE users DROP COLUMN username;
ALTER TABLE users RENAME COLUMN display_name TO username;
"""

# Anti-pattern: NEVER do destructive migrations in the same deploy as code changes
# BAD: DROP TABLE in same deploy as feature code — old pods crash on restart
# GOOD: Deploy code that handles both schemas → wait for full cutover → run DROP
```

## Key Commands Reference

```bash
# Kubernetes blue-green operations
# Check current live slot
kubectl get svc api -n production -o jsonpath='{.spec.selector.slot}'

# Switch traffic manually (emergency)
kubectl patch svc api -n production -p '{"spec":{"selector":{"slot":"blue"}}}'

# Compare deployments
kubectl diff -f blue-deployment.yaml
kubectl rollout history deployment/api-blue -n production

# Monitor both slots
kubectl get pods -n production -l app=api --show-labels
kubectl top pods -n production -l app=api

# Port-forward to inactive slot for testing
kubectl port-forward svc/api-green 8080:80 -n production &
curl http://localhost:8080/healthz

# Argo Rollouts (blue-green via CRD)
kubectl argo rollouts get rollout api -n production
kubectl argo rollouts promote api -n production  # Confirm green promotion
kubectl argo rollouts abort api -n production    # Emergency abort to stable
kubectl argo rollouts undo api -n production     # Rollback

# ALB
aws elbv2 describe-target-health --target-group-arn <arn>
aws elbv2 describe-rules --listener-arn <arn>
```

## Common Patterns

### Pattern 1: Argo Rollouts Blue-Green (Kubernetes CRD)

```yaml
# rollout.yaml — Argo Rollouts handles blue-green automatically
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: myapp:latest
          ports:
            - containerPort: 8080
  strategy:
    blueGreen:
      activeService: api         # Points to live traffic
      previewService: api-preview  # Points to new version for testing
      autoPromotionEnabled: false  # Require manual promotion
      scaleDownDelaySeconds: 30    # Keep old pods 30s after switch
      prePromotionAnalysis:
        templates:
          - templateName: smoke-test
        args:
          - name: service-name
            value: api-preview
```

### Pattern 2: Smoke Test Script

```python
#!/usr/bin/env python3
# smoke_test.py — run after switch, fail fast for rollback
import requests, sys, time

BASE_URL = sys.argv[1]  # e.g. https://api.acme.com

CHECKS = [
    ("GET", "/healthz", 200, None),
    ("GET", "/api/v1/status", 200, {"status": "ok"}),
    ("POST", "/api/v1/echo", 200, None),
]

for method, path, expected_status, expected_body in CHECKS:
    try:
        r = requests.request(method, f"{BASE_URL}{path}", timeout=5,
                             json={"test": True} if method == "POST" else None)
        assert r.status_code == expected_status, \
            f"{path}: expected {expected_status}, got {r.status_code}"
        if expected_body:
            for key, val in expected_body.items():
                assert r.json().get(key) == val, \
                    f"{path}: expected {key}={val}, got {r.json().get(key)}"
        print(f"  OK: {method} {path}")
    except Exception as e:
        print(f"  FAIL: {method} {path}: {e}")
        sys.exit(1)

print("All smoke tests passed!")
```

### Pattern 3: Blue-Green for Serverless (Lambda with Aliases)

```bash
# AWS Lambda blue-green via function aliases
# "live" alias = current production traffic

# Deploy new version
aws lambda update-function-code \
  --function-name my-api \
  --zip-file fileb://function.zip

# Publish new version
VERSION=$(aws lambda publish-version \
  --function-name my-api \
  --query 'Version' --output text)

# Route 10% of traffic to new version (canary)
aws lambda update-alias \
  --function-name my-api \
  --name live \
  --routing-config AdditionalVersionWeights="{\"$VERSION\": 0.10}"

# After validation — 100% to new version
aws lambda update-alias \
  --function-name my-api \
  --name live \
  --function-version $VERSION \
  --routing-config AdditionalVersionWeights={}
```

## Pitfalls to Avoid

1. **Not keeping both slots resource-provisioned during the switch**: During the brief window when you're switching traffic, both environments must be fully running and healthy. A common mistake is scaling down the inactive slot to save costs — if you need to rollback, you're waiting for pods to start. Keep both slots at production capacity for at least 30 minutes post-switch before scaling down the old one.

2. **Deploying destructive database migrations in the same release**: Blue-green requires the old code version to run alongside the new one during the switch. If your migration drops a column the old code reads, the old pods crash. Always use the expand-migrate-contract pattern: add in one release, migrate data, drop in the next release once old code is fully gone.

3. **Forgetting to update the inactive slot before switching**: If blue is live and you deploy to green but forget to keep blue updated, the next deployment switches to blue — which is now N-2 versions behind. Always update the inactive slot to at least the same version as the active slot before proceeding with the next deployment cycle.

## Related Skills

- `ci-cd-pipeline-builder` — CI/CD pipelines that orchestrate blue-green
- `kubernetes-architect` — Cluster design supporting dual-environment deployments
- `senior-devops` — SRE practices including deployment strategies
- `database-migration-strategies` — Safe database changes during deployments
- `chaos-engineering` — Testing rollback procedures before you need them

## GitNexus Index

```json
{
  "skill": "blue-green-deployments",
  "category": "devops",
  "triggers": ["blue-green deployment", "zero downtime deployment", "traffic switching", "canary deployment", "instant rollback", "ALB target groups", "kubernetes blue green", "argo rollouts", "slot deployment"],
  "outputs": ["blue-deployment.yaml", "deploy-blue-green.sh", "set_traffic_split", "canary_rollout", "smoke_test.py", "Rollout blueGreen CRD"],
  "complexity": "high",
  "tools": ["kubernetes", "aws", "argo-rollouts", "github-actions", "python", "bash", "boto3"]
}
```
