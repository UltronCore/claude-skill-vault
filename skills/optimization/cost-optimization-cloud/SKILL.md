---
name: cost-optimization-cloud
description: Systematically reduce cloud infrastructure costs — rightsizing EC2/RDS instances, Reserved Instances and Savings Plans, Spot instance patterns for fault-tolerant workloads, Kubernetes resource requests/limits tuning, S3 lifecycle policies, and architectural patterns like Lambda vs container trade-offs.
version: 1.0.0
tags: [cloud-cost, aws, kubernetes, rightsizing, spot-instances, reserved-instances, savings-plans, s3-lifecycle, finops, cost-optimization]
---

# Cloud Cost Optimization

## Overview

Cloud bills grow silently — idle resources, oversized instances, and forgotten services accumulate unchecked. Effective cloud cost optimization requires continuous visibility (cost explorer + tagging), a prioritized approach (tackle the largest line items first), and an understanding of the commitment vs. flexibility trade-off (on-demand → Savings Plans → Reserved Instances → Spot, in order of discount depth). The goal is not to minimize cost at any expense — it is to optimize cost-per-unit-of-value while maintaining reliability SLAs.

## When to Use

- Monthly cloud bill is growing faster than business metrics (revenue, users, requests)
- AWS Cost Explorer shows unexpectedly large line items or untagged resources
- Kubernetes nodes are consistently under-utilized (CPU/memory below 30-40%)
- Engineering team is complaining about slow test environments that run 24/7
- Preparing for a FinOps review or needing to reduce burn rate
- Scaling a service and needing to decide between Lambda, containers, and VMs

## Step-by-Step Workflow

### 1. Cost Visibility and Tagging Enforcement

```python
# src/finops/cost_reporter.py
# Pull cost breakdown by service and tag using boto3
import boto3
from datetime import datetime, timedelta

def get_cost_by_service(days: int = 30) -> list[dict]:
    """Get AWS cost breakdown by service for the last N days."""
    client = boto3.client("ce", region_name="us-east-1")

    end = datetime.now().strftime("%Y-%m-%d")
    start = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")

    response = client.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )

    results = []
    for group in response["ResultsByTime"][0]["Groups"]:
        cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
        if cost > 1.0:  # Filter noise
            results.append({
                "service": group["Keys"][0],
                "cost_usd": round(cost, 2),
            })

    return sorted(results, key=lambda x: x["cost_usd"], reverse=True)


def find_untagged_resources() -> list[dict]:
    """Find EC2 instances and RDS clusters missing required tags."""
    ec2 = boto3.client("ec2", region_name="us-east-1")
    required_tags = {"Environment", "Team", "Project"}

    untagged = []
    paginator = ec2.get_paginator("describe_instances")
    for page in paginator.paginate(Filters=[{"Name": "instance-state-name", "Values": ["running"]}]):
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                existing_keys = {t["Key"] for t in instance.get("Tags", [])}
                missing = required_tags - existing_keys
                if missing:
                    untagged.append({
                        "resource_id": instance["InstanceId"],
                        "type": instance["InstanceType"],
                        "missing_tags": list(missing),
                    })
    return untagged
```

### 2. EC2 Rightsizing — Find Oversized Instances

```python
# src/finops/rightsizing.py
# Use CloudWatch metrics to find instances with low CPU/memory utilization

import boto3
from datetime import datetime, timedelta

def find_oversized_ec2(
    days: int = 14,
    cpu_threshold: float = 10.0,     # Average CPU < 10% = oversized
    network_threshold: float = 5_000_000,  # < 5 MB/s average = low traffic
) -> list[dict]:
    """
    Find EC2 instances that are consistently underutilized.
    These are candidates for downsizing (e.g., m5.xlarge → m5.large saves ~50%).
    """
    ec2 = boto3.client("ec2")
    cw = boto3.client("cloudwatch")

    instances = ec2.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )

    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=days)
    oversized = []

    for reservation in instances["Reservations"]:
        for inst in reservation["Instances"]:
            instance_id = inst["InstanceId"]
            instance_type = inst["InstanceType"]

            # Get average CPU utilization
            cpu_response = cw.get_metric_statistics(
                Namespace="AWS/EC2",
                MetricName="CPUUtilization",
                Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
                StartTime=start_time,
                EndTime=end_time,
                Period=86400,  # Daily averages
                Statistics=["Average"],
            )

            if not cpu_response["Datapoints"]:
                continue

            avg_cpu = sum(d["Average"] for d in cpu_response["Datapoints"]) / len(cpu_response["Datapoints"])

            if avg_cpu < cpu_threshold:
                name = next(
                    (t["Value"] for t in inst.get("Tags", []) if t["Key"] == "Name"),
                    instance_id
                )
                oversized.append({
                    "instance_id": instance_id,
                    "name": name,
                    "instance_type": instance_type,
                    "avg_cpu_pct": round(avg_cpu, 1),
                    "recommendation": "Downsize to smaller instance type",
                    "estimated_monthly_savings_pct": 50,
                })

    return oversized


# RDS rightsizing — check if db.r5.2xlarge can become db.r5.xlarge
def get_rds_cpu_utilization(db_identifier: str, days: int = 14) -> float:
    cw = boto3.client("cloudwatch")
    end = datetime.utcnow()
    start = end - timedelta(days=days)

    response = cw.get_metric_statistics(
        Namespace="AWS/RDS",
        MetricName="CPUUtilization",
        Dimensions=[{"Name": "DBInstanceIdentifier", "Value": db_identifier}],
        StartTime=start,
        EndTime=end,
        Period=86400,
        Statistics=["Average", "Maximum"],
    )

    datapoints = response["Datapoints"]
    avg = sum(d["Average"] for d in datapoints) / len(datapoints) if datapoints else 0
    maximum = max(d["Maximum"] for d in datapoints) if datapoints else 0

    # Only downsize if max CPU < 40% (leave headroom for spikes)
    print(f"{db_identifier}: avg={avg:.1f}%, max={maximum:.1f}%")
    if maximum < 40:
        print(f"CANDIDATE for downsizing — max CPU {maximum:.1f}% < 40%")
    return avg
```

### 3. Kubernetes Resource Optimization

```yaml
# kubernetes/resource-tuning.yaml
# Before optimization: over-provisioned requests waste capacity
# After optimization: requests match actual usage + 20-30% headroom

apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  template:
    spec:
      containers:
        - name: api
          image: myapp:latest
          resources:
            requests:
              # Set requests to P95 of actual usage (not theoretical max)
              cpu: "100m"      # Was 500m — reduced after profiling
              memory: "256Mi"  # Was 1Gi — reduced after measuring actual RSS
            limits:
              # Limits should be 2-3x requests for bursty workloads
              # Do NOT set CPU limits (causes CPU throttling even with headroom)
              cpu: "500m"
              memory: "512Mi"

---
# Use Vertical Pod Autoscaler (VPA) to get recommendations automatically
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-service-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  updatePolicy:
    updateMode: "Off"    # "Off" = recommendations only, no auto-apply
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: "50m"
          memory: "128Mi"
        maxAllowed:
          cpu: "2"
          memory: "4Gi"
```

```bash
# Check VPA recommendations (after running in Off mode for 1+ week)
kubectl describe vpa api-service-vpa

# Cluster-level utilization (Kube-State-Metrics + Prometheus)
# kubectl top nodes — shows actual CPU/memory usage per node
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=memory | head -20

# Find pods with no resource requests (they hurt bin-packing)
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.containers[].resources.requests == null) | .metadata.name'
```

## Key Commands Reference

```bash
# AWS Cost Explorer CLI
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-02-01 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Find idle EC2 instances (stopped but still incurring EBS costs)
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=stopped \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]'

# S3 bucket size by bucket (identify storage hogs)
aws s3api list-buckets --query 'Buckets[].Name' --output text | \
  xargs -I {} aws cloudwatch get-metric-statistics \
    --namespace AWS/S3 --metric-name BucketSizeBytes \
    --dimensions Name=BucketName,Value={} Name=StorageType,Value=StandardStorage \
    --start-time 2024-01-01 --end-time 2024-02-01 \
    --period 86400 --statistics Average --query 'Datapoints[0].Average'

# RDS: identify multi-AZ DBs in dev/test (single-AZ saves ~50%)
aws rds describe-db-instances \
  --query 'DBInstances[?MultiAZ==`true`].[DBInstanceIdentifier,DBInstanceClass,MultiAZ]'

# Spot instance interruption rates by instance type/region
# https://spot-price.s3.amazonaws.com/spot.js — check before choosing instance type

# Turn off dev environments at night (save 70% on non-prod)
# AWS Instance Scheduler: https://aws.amazon.com/solutions/implementations/instance-scheduler/
```

## Common Patterns

### Pattern 1: Spot Instances for Fault-Tolerant Workloads

```python
# src/finops/spot_strategy.py
# Spot instances: 70-90% cheaper than on-demand, but can be interrupted
# Best for: batch jobs, ML training, CI/CD workers, stateless web tier

import boto3

def create_spot_autoscaling_group(
    name: str,
    min_size: int = 2,
    max_size: int = 20,
    target_cpu: float = 60.0,
) -> str:
    """
    Mixed-instances policy: On-demand base + Spot for scale
    This provides cost savings while ensuring a minimum of reliable capacity.
    """
    asg = boto3.client("autoscaling")

    asg.create_auto_scaling_group(
        AutoScalingGroupName=name,
        MinSize=min_size,
        MaxSize=max_size,
        MixedInstancesPolicy={
            "InstancesDistribution": {
                "OnDemandBaseCapacity": 2,              # Always keep 2 on-demand
                "OnDemandPercentageAboveBaseCapacity": 20,  # 20% on-demand above base
                "SpotAllocationStrategy": "capacity-optimized",  # Best interruption protection
            },
            "LaunchTemplate": {
                "LaunchTemplateSpecification": {
                    "LaunchTemplateName": f"{name}-lt",
                    "Version": "$Latest",
                },
                "Overrides": [
                    # Diverse instance types — more capacity pools = fewer interruptions
                    {"InstanceType": "m5.xlarge"},
                    {"InstanceType": "m5a.xlarge"},
                    {"InstanceType": "m4.xlarge"},
                    {"InstanceType": "m5d.xlarge"},
                ],
            },
        },
        VPCZoneIdentifier="subnet-xxx,subnet-yyy,subnet-zzz",   # Multiple AZs
    )
    return name
```

### Pattern 2: S3 Lifecycle Policies for Storage Tiering

```python
# src/finops/s3_lifecycle.py
# S3 Standard: $0.023/GB/month
# S3 Standard-IA: $0.0125/GB (after 30 days) — 45% cheaper
# S3 Glacier Instant: $0.004/GB (after 90 days) — 83% cheaper
# S3 Glacier Deep Archive: $0.00099/GB (after 180 days) — 96% cheaper

import boto3

def apply_cost_optimized_lifecycle(bucket_name: str):
    """Apply intelligent tiering lifecycle to an S3 bucket."""
    s3 = boto3.client("s3")

    lifecycle_config = {
        "Rules": [
            {
                "ID": "archive-old-objects",
                "Status": "Enabled",
                "Filter": {"Prefix": ""},  # Apply to entire bucket
                "Transitions": [
                    {"Days": 30, "StorageClass": "STANDARD_IA"},
                    {"Days": 90, "StorageClass": "GLACIER_IR"},     # Instant retrieval
                    {"Days": 180, "StorageClass": "DEEP_ARCHIVE"},  # 12-hour retrieval
                ],
                "Expiration": {
                    "Days": 365 * 3,  # Delete after 3 years
                },
                "AbortIncompleteMultipartUpload": {
                    "DaysAfterInitiation": 7,   # Clean up failed uploads
                },
            },
            {
                "ID": "delete-old-versions",
                "Status": "Enabled",
                "Filter": {"Prefix": ""},
                "NoncurrentVersionExpiration": {
                    "NoncurrentDays": 30,       # Delete old versions after 30 days
                },
            },
        ]
    }

    s3.put_bucket_lifecycle_configuration(
        Bucket=bucket_name,
        LifecycleConfiguration=lifecycle_config,
    )
    print(f"Applied lifecycle policy to {bucket_name}")
```

### Pattern 3: AWS Savings Plans Purchase Automation

```python
# src/finops/savings_plans.py
# Savings Plans: commit to $/hour spend for 1-3 years, get 30-60% discount
# Compute Savings Plans: most flexible (covers EC2, Lambda, Fargate)
# EC2 Instance Savings Plans: highest discount (~66%) but instance-family specific

import boto3

def analyze_savings_plan_opportunity(
    lookback_days: int = 30,
    commitment_term: str = "ONE_YEAR",  # or THREE_YEAR
    payment: str = "NO_UPFRONT",         # NO_UPFRONT, PARTIAL_UPFRONT, ALL_UPFRONT
) -> dict:
    """Get AWS recommendation for optimal Savings Plan purchase."""
    ce = boto3.client("ce")

    response = ce.get_savings_plans_purchase_recommendation(
        SavingsPlansType="COMPUTE_SP",
        TermInYears=commitment_term,
        PaymentOption=payment,
        LookbackPeriodInDays=str(lookback_days),
    )

    summary = response["SavingsPlansPurchaseRecommendation"]["SavingsPlansPurchaseRecommendationSummary"]

    return {
        "recommended_hourly_commitment": summary.get("HourlyCommitmentToPurchase", "0"),
        "estimated_monthly_savings": summary.get("MonthlySavingsAmount", "0"),
        "estimated_roi": summary.get("EstimatedROI", "0"),
        "current_on_demand_spend": summary.get("CurrentOnDemandSpend", "0"),
        "coverage_pct": summary.get("EstimatedSavingsPercentage", "0"),
    }
```

## Pitfalls to Avoid

1. **Setting Kubernetes CPU limits (causes throttling at any utilization)**: Kubernetes CPU limits trigger CFS (Completely Fair Scheduler) throttling — if a pod's average CPU is well below the limit but has a burst, it still gets throttled because the CFS quota is applied per scheduling period (100ms). This manifests as high p99 latency even when average CPU looks fine. Set CPU requests (for scheduling) but remove CPU limits or set them very high. Only keep memory limits, since OOM kills are preferable to silent memory-based throttling.

2. **Buying Reserved Instances before rightsizing**: Purchasing 1-year or 3-year RIs for oversized instances locks you into paying for capacity you don't need. Always rightsize first (reduce instance types to match actual usage), run in on-demand for 2-4 weeks to validate, then purchase Savings Plans or RIs for the stable baseline. Savings Plans are more flexible than RIs — prefer Compute Savings Plans over EC2 Reserved Instances for most workloads.

3. **Ignoring data transfer costs**: Data egress from AWS to the internet costs $0.08/GB ($80/TB). Between regions: $0.02/GB. Data transfer between AZs within a region: $0.01/GB in each direction. These add up quickly for data-intensive services. Optimize by: placing tightly-coupled services in the same AZ, using S3 Transfer Acceleration only when needed, routing CloudFront → S3 (egress from S3 to CloudFront is free), and using VPC endpoints to avoid NAT gateway costs for S3/DynamoDB traffic.

## Related Skills

- `aws-solution-architect` — AWS architecture patterns and service selection
- `kubernetes-architect` — Kubernetes cluster design and resource management
- `ai-cost-optimizer` — AI/LLM inference cost reduction
- `senior-devops` — Infrastructure operations and on-call workflows

## GitNexus Index

```json
{
  "skill": "cost-optimization-cloud",
  "category": "infrastructure",
  "triggers": ["cloud cost optimization", "AWS cost reduction", "EC2 rightsizing", "Reserved Instances", "Savings Plans", "Spot instances", "Kubernetes resource tuning", "S3 lifecycle policy", "FinOps", "cloud bill reduction", "VPA recommendations", "cost explorer"],
  "outputs": ["get_cost_by_service()", "find_oversized_ec2()", "create_spot_autoscaling_group()", "apply_cost_optimized_lifecycle()", "analyze_savings_plan_opportunity()", "VerticalPodAutoscaler", "MixedInstancesPolicy"],
  "complexity": "medium",
  "tools": ["aws", "boto3", "terraform", "kubernetes", "cloudwatch", "cost-explorer", "python"]
}
```
