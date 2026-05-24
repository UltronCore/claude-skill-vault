---
name: pulumi
description: Infrastructure as code using real programming languages (TypeScript, Python, Go, C#, Java, YAML) with Pulumi. Use this skill whenever the user wants to define, deploy, or manage cloud infrastructure using code, wants to migrate from Terraform/CDK to Pulumi, needs to create Pulumi stacks or programs, asks about Pulumi state management, providers, component resources, or automation API. Trigger for any mention of Pulumi, IaC with real languages, or "pulumi up/preview/destroy".
---

# Pulumi — Infrastructure as Code with Real Languages

## Overview

Pulumi lets you define cloud infrastructure using TypeScript, Python, Go, C#, Java, or YAML — the same languages you use for application code. Unlike DSLs, you get loops, conditionals, abstractions, tests, and package managers for free. Pulumi manages state and communicates with cloud providers through a resource model.

## When to Use

- Defining or deploying AWS, Azure, GCP, Kubernetes, or 120+ other cloud resources
- Migrating from Terraform, AWS CDK, or CloudFormation
- Building reusable infrastructure components (component resources)
- Automating deployments programmatically with the Automation API
- Testing infrastructure code with standard unit test frameworks

## Installation

```bash
# macOS
brew install pulumi/tap/pulumi

# Verify
pulumi version

# Install cloud provider SDK (TypeScript example)
mkdir my-infra && cd my-infra
pulumi new aws-typescript   # interactive wizard
# or python: pulumi new aws-python
```

## Key Patterns

### Basic Resource Definition (TypeScript)

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

// Create an S3 bucket
const bucket = new aws.s3.BucketV2("my-bucket", {
    tags: { Environment: pulumi.getStack() },
});

// Enable versioning
const versioning = new aws.s3.BucketVersioningV2("bucket-versioning", {
    bucket: bucket.id,
    versioningConfiguration: { status: "Enabled" },
});

// Export the bucket name
export const bucketName = bucket.id;
export const bucketArn = bucket.arn;
```

### Python Example — VPC + Subnets

```python
import pulumi
import pulumi_aws as aws

vpc = aws.ec2.Vpc("main",
    cidr_block="10.0.0.0/16",
    enable_dns_hostnames=True,
    tags={"Name": f"{pulumi.get_stack()}-vpc"})

public_subnet = aws.ec2.Subnet("public",
    vpc_id=vpc.id,
    cidr_block="10.0.1.0/24",
    map_public_ip_on_launch=True)

pulumi.export("vpc_id", vpc.id)
pulumi.export("subnet_id", public_subnet.id)
```

### Component Resources (Reusable Abstractions)

```typescript
import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

class WebServer extends pulumi.ComponentResource {
    public readonly instanceId: pulumi.Output<string>;

    constructor(name: string, opts?: pulumi.ComponentResourceOptions) {
        super("myapp:index:WebServer", name, {}, opts);

        const sg = new aws.ec2.SecurityGroup(`${name}-sg`, {
            ingress: [{ protocol: "tcp", fromPort: 80, toPort: 80, cidrBlocks: ["0.0.0.0/0"] }],
            egress:  [{ protocol: "-1", fromPort: 0, toPort: 0, cidrBlocks: ["0.0.0.0/0"] }],
        }, { parent: this });

        const instance = new aws.ec2.Instance(`${name}-instance`, {
            ami: "ami-0c55b159cbfafe1f0",
            instanceType: "t3.micro",
            vpcSecurityGroupIds: [sg.id],
        }, { parent: this });

        this.instanceId = instance.id;
        this.registerOutputs({ instanceId: this.instanceId });
    }
}

const server = new WebServer("prod");
export const serverId = server.instanceId;
```

### Automation API (Programmatic Control)

```python
import asyncio
from pulumi.automation import create_or_select_stack, LocalWorkspace

async def deploy():
    stack = await create_or_select_stack(
        stack_name="dev",
        project_name="my-project",
        program=pulumi_program,
        opts=LocalWorkspaceOptions(work_dir="./infra"),
    )
    await stack.set_config("aws:region", ConfigValue("us-east-1"))
    result = await stack.up(on_output=print)
    return result.outputs

asyncio.run(deploy())
```

### Stack References (Cross-Stack Outputs)

```typescript
// Consume outputs from another stack
const networkStack = new pulumi.StackReference("org/network/prod");
const vpcId = networkStack.getOutput("vpcId");

const cluster = new aws.ecs.Cluster("app-cluster", {});
// Use vpcId from the network stack
```

### Kubernetes Resources

```typescript
import * as k8s from "@pulumi/kubernetes";

const deployment = new k8s.apps.v1.Deployment("nginx", {
    spec: {
        replicas: 3,
        selector: { matchLabels: { app: "nginx" } },
        template: {
            metadata: { labels: { app: "nginx" } },
            spec: { containers: [{ name: "nginx", image: "nginx:1.25" }] },
        },
    },
});
```

## Common CLI Commands

```bash
pulumi new <template>          # Initialize project from template
pulumi up                      # Preview and deploy changes
pulumi preview                 # Preview without deploying
pulumi destroy                 # Tear down all resources
pulumi stack ls                # List stacks
pulumi stack select <name>     # Switch active stack
pulumi config set key value    # Set stack config
pulumi config set --secret key value  # Set encrypted secret
pulumi logs                    # View resource logs
pulumi refresh                 # Sync state with actual cloud state
pulumi import aws:s3/bucket:Bucket my-bucket my-existing-bucket  # Import existing resource
```

## State Management

```bash
# Pulumi Cloud (default, free tier available)
pulumi login

# Self-hosted: S3 backend
pulumi login s3://my-state-bucket

# Local filesystem
pulumi login --local
```

## Pitfalls

- **Output vs plain values**: `pulumi.Output<string>` cannot be used directly as a string. Use `.apply()` to transform: `bucket.id.apply(id => \`https://${id}.s3.amazonaws.com\`)`
- **Implicit dependencies**: Pulumi tracks dependencies through Output chains — always pass resource outputs (not `.get()` or hardcoded IDs) to dependent resources
- **Stack names are globally unique in Pulumi Cloud**: use `org/project/stack` format in stack references
- **`pulumi refresh` before destructive operations**: cloud drift can cause unexpected diffs
- **Secrets**: use `pulumi.secret()` or `--secret` flag; never put credentials in stack config as plain text
- **Resource deletion protection**: set `protect: true` in resource options for stateful resources like databases

## Related Skills

- `terraform-code-generation` — Terraform/OpenTofu alternative
- `kubernetes-architect` — K8s infrastructure patterns
- `aws-solution-architect` — AWS resource design
- `azure-cloud-architect` — Azure resource design

## GitNexus Index

Index path: /Users/localuser/.claude/skills/pulumi/.gitnexus
Created: 2026-05-24
