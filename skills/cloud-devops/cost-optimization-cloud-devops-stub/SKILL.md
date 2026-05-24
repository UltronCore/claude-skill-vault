---
name: cost-optimization-cloud-devops-stub
description: Systematically reduce cloud infrastructure costs through rightsizing, reserved instances, spot instances, autoscaling, and architectural optimization across AWS, GCP, and Azure.
tags: [cloud, cost-optimization, aws, devops, finops]
version: 1.0.0
---

## Overview

Cut cloud bills without sacrificing reliability. Covers the full FinOps cycle: visibility → analysis → action → governance. Works across AWS, GCP, and Azure with provider-specific tactics.

## When to Use

- Monthly cloud bill is growing faster than traffic
- Auditing a new account/project for waste
- Rightsizing EC2, RDS, or other compute before a renewal decision
- Choosing between on-demand, reserved, savings plans, and spot
- Setting up autoscaling to eliminate idle capacity
- Doing a FinOps review or producing a cost report for leadership

## Step 1 — Establish Visibility

Before optimizing, measure. Without baseline data, you can't prove savings.

```bash
# AWS: export Cost Explorer data for last 90 days by service + tag
aws ce get-cost-and-usage \
  --time-period Start=2026-02-23,End=2026-05-24 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json > cost_by_service.json

# AWS: find untagged resources (tag policy violations)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=env --query 'ResourceTagMappingList[?Tags==`[]`].ResourceARN'
```

Key dashboards to build:
- Cost by service (week over week)
- Cost by team/product tag
- Idle resource report (CPU < 5%, connections = 0)
- Data transfer costs (often hidden)

## Step 2 — Rightsizing Compute

EC2/GCE/VM rightsizing is typically the single largest savings lever (20-40% savings).

```python
import boto3

def find_oversized_instances(threshold_cpu=20, threshold_net=10):
    """Find instances running below threshold for 14 days."""
    cw = boto3.client('cloudwatch')
    ec2 = boto3.client('ec2')
    
    instances = ec2.describe_instances(
        Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
    )
    
    candidates = []
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            iid = instance['InstanceId']
            cpu = cw.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName='CPUUtilization',
                Dimensions=[{'Name': 'InstanceId', 'Value': iid}],
                StartTime='2026-05-10T00:00:00Z',
                EndTime='2026-05-24T00:00:00Z',
                Period=1209600,  # 14 days
                Statistics=['Average']
            )
            avg_cpu = cpu['Datapoints'][0]['Average'] if cpu['Datapoints'] else 0
            if avg_cpu < threshold_cpu:
                candidates.append({
                    'InstanceId': iid,
                    'InstanceType': instance['InstanceType'],
                    'AvgCPU': avg_cpu
                })
    return candidates
```

**Rightsizing rules of thumb:**
- CPU consistently < 10%: downsize one family tier
- CPU consistently < 5%, memory < 20%: consider Graviton (ARM) — 20% cheaper, often faster
- GPU instance idle > 8 hrs/day: switch to spot or schedule stop/start

## Step 3 — Reserved Instances and Savings Plans

**When to commit:**
- Workload has been running > 3 months with stable usage
- You can forecast 1 year out with >80% confidence

| Commitment type | Discount vs on-demand | Flexibility |
|----------------|----------------------|-------------|
| EC2 Reserved (1yr, no upfront) | ~30% | Instance family locked |
| EC2 Reserved (3yr, all upfront) | ~60% | Instance family locked |
| Compute Savings Plan (1yr) | ~17% | Any instance family/region |
| Compute Savings Plan (3yr) | ~35% | Any instance family/region |
| Spot instances | 60-90% | Can be interrupted |

**Buy coverage for your baseline; use spot/on-demand for burst:**
```
Reserved coverage = avg_hourly_spend * 0.70  # cover 70% of baseline
Spot budget       = peak_spend - avg_spend    # burst capacity
```

## Step 4 — Autoscaling and Scheduling

```yaml
# AWS Application Auto Scaling — scale ECS service on CPU
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/my-cluster/my-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 20

# Schedule dev environments off at night (saves ~65% on dev costs)
# EventBridge rule: stop at 7PM, start at 8AM weekdays
aws events put-rule \
  --name StopDevEnvs \
  --schedule-expression "cron(0 23 ? * MON-FRI *)" \
  --state ENABLED
```

**Scheduling savings by environment:**
- Dev/staging: run 10 hrs/day × 5 days = 29% of week → 71% savings on idle hours
- CI runners: use spot with on-demand fallback → 70% savings
- Batch jobs: run in off-peak hours for spot availability

## Step 5 — Storage and Data Transfer

Often overlooked: storage and egress can be 15-30% of bills.

```bash
# Find S3 buckets with no lifecycle policy
aws s3api list-buckets --query 'Buckets[].Name' --output text | \
  xargs -I {} aws s3api get-bucket-lifecycle-configuration --bucket {} 2>&1 | \
  grep -B1 "NoSuchLifecycleConfiguration"

# S3 Intelligent-Tiering for buckets > 100GB with unknown access patterns
aws s3api put-bucket-intelligent-tiering-configuration \
  --bucket my-bucket \
  --id EntireBucket \
  --intelligent-tiering-configuration '{"Id":"EntireBucket","Status":"Enabled","Tierings":[{"Days":90,"AccessTier":"ARCHIVE_ACCESS"}]}'
```

**Storage optimization checklist:**
- [ ] S3 lifecycle: move to IA after 30 days, Glacier after 90, delete after 365
- [ ] EBS: delete unattached volumes (common after instance termination)
- [ ] RDS: check allocated vs. used storage; enable storage autoscaling
- [ ] CloudWatch Logs: set retention (default = forever)
- [ ] Data transfer: use VPC endpoints to avoid NAT gateway charges

## Step 6 — Governance and Alerting

```bash
# AWS Budgets: alert when spend exceeds 80% of monthly budget
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget '{
    "BudgetName": "MonthlyBudget",
    "BudgetLimit": {"Amount": "5000", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80},
    "Subscribers":[{"SubscriptionType":"EMAIL","Address":"team@company.com"}]
  }]'
```

**Governance rules:**
- Require cost allocation tags (`env`, `team`, `product`) — enforce with SCP
- Monthly FinOps review: top 5 cost drivers, MoM change, savings actions
- Anomaly detection: alert on >20% week-over-week spike in any service

## Quick Wins Checklist

| Action | Typical savings | Effort |
|--------|----------------|--------|
| Delete unattached EBS volumes | $5-50/vol/mo | 1 hr |
| Delete unused Elastic IPs | $3.60/IP/mo | 30 min |
| Rightsize dev EC2 instances | 20-40% of dev compute | 2 hrs |
| Turn off dev envs at night | 50-70% of dev compute | 1 hr |
| S3 lifecycle policies | 30-70% of storage | 2 hrs |
| Move to Graviton | 20% of eligible compute | 4 hrs |
| Purchase Savings Plans | 17-35% of baseline | 1 hr |
| Enable S3 Intelligent-Tiering | 30-60% of storage | 1 hr |

## Related Skills

- `aws-solution-architect` — AWS architecture and service selection
- `kubernetes-architect` — K8s resource requests, limits, and VPA/HPA
- `ai-cost-optimizer` — LLM and AI inference cost reduction
