---
name: serverless-patterns
description: Build production serverless applications with AWS Lambda, event-driven patterns, cold start optimization, Step Functions for orchestration, and cost-efficient architecture. Covers Lambda, SQS/SNS/EventBridge, DynamoDB, and SAM/CDK deployment.
version: 1.0.0
tags: [serverless, aws-lambda, step-functions, event-driven, dynamodb, sqs, cold-start, sam]
---

# Serverless Patterns

## Overview

Serverless architecture runs code in functions-as-a-service (FaaS) without managing servers — AWS Lambda scales from zero to millions of concurrent executions, billing only for compute time used. This skill covers Lambda handler patterns, cold start optimization, event-driven integration with SQS/SNS/EventBridge, Step Functions for complex workflows, DynamoDB for serverless databases, and infrastructure-as-code with SAM and CDK.

## When to Use

- Spiky or unpredictable traffic (Lambda scales instantly, no pre-provisioned capacity)
- Background processing triggered by events (file uploads, database changes, queue messages)
- API backends that don't require persistent connections
- Cost optimization: paying only for actual execution time vs. always-on servers
- Microservices that need independent scaling and deployment
- Scheduled jobs (cron-style triggers via EventBridge)

## Step-by-Step Workflow

### 1. Lambda Handler Patterns
```typescript
// handlers/orders.ts — production Lambda handler
import { APIGatewayProxyHandlerV2, APIGatewayProxyResultV2 } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { z } from "zod";

// Initialize clients OUTSIDE handler — reused across warm invocations
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
  marshallOptions: { removeUndefinedValues: true },
});

const TABLE = process.env.ORDERS_TABLE!;

const CreateOrderSchema = z.object({
  userId: z.string().uuid(),
  items: z.array(z.object({
    productId: z.string(),
    quantity: z.number().int().positive(),
    price: z.number().positive(),
  })).min(1),
  shippingAddress: z.object({
    street: z.string(),
    city: z.string(),
    country: z.string().length(2),
  }),
});

export const createOrder: APIGatewayProxyHandlerV2 = async (event) => {
  try {
    const body = JSON.parse(event.body ?? "{}");
    const order = CreateOrderSchema.parse(body);

    const orderId = crypto.randomUUID();
    const now = new Date().toISOString();
    const total = order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);

    await ddb.send(new PutCommand({
      TableName: TABLE,
      Item: {
        PK: `USER#${order.userId}`,
        SK: `ORDER#${orderId}`,
        GSI1PK: `ORDER#${orderId}`,
        orderId,
        userId: order.userId,
        items: order.items,
        total,
        status: "PENDING",
        createdAt: now,
        updatedAt: now,
        ttl: Math.floor(Date.now() / 1000) + 365 * 86400, // 1 year
      },
      ConditionExpression: "attribute_not_exists(PK)",
    }));

    return {
      statusCode: 201,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ orderId, total, status: "PENDING" }),
    };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { statusCode: 400, body: JSON.stringify({ error: "Validation failed", details: error.errors }) };
    }
    console.error("Error creating order:", error);
    return { statusCode: 500, body: JSON.stringify({ error: "Internal server error" }) };
  }
};
```

### 2. Cold Start Optimization
```typescript
// Techniques to minimize Lambda cold start latency

// 1. Keep dependencies minimal — only import what you use
import { GetCommand } from "@aws-sdk/lib-dynamodb";  // NOT import * as AWS from "aws-sdk"

// 2. Lazy-load heavy dependencies (only when first needed)
let openaiClient: any;
function getOpenAI() {
  if (!openaiClient) {
    const { OpenAI } = require("openai");  // Dynamic require
    openaiClient = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }
  return openaiClient;
}

// 3. Connection pool — reuse HTTP connections across invocations
// AWS SDK v3 does this automatically with Keep-Alive
import { NodeHttpHandler } from "@smithy/node-http-handler";
import https from "https";

const client = new DynamoDBClient({
  requestHandler: new NodeHttpHandler({
    httpsAgent: new https.Agent({ keepAlive: true, maxSockets: 50 }),
  }),
});

// 4. Lambda SnapStart (Java) or Provisioned Concurrency (any runtime)
// In SAM template:
//   Properties:
//     SnapStart:
//       ApplyOn: PublishedVersions  # Java 11/17/21 only
//     ProvisionedConcurrencyConfig:
//       ProvisionedConcurrentExecutions: 5  # Keep 5 instances warm
```

### 3. SAM Template — Full Serverless App
```yaml
# template.yaml
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: nodejs20.x
    Timeout: 30
    MemorySize: 512
    Architectures: [arm64]  # Graviton2 — 20% cheaper, often faster
    Environment:
      Variables:
        ORDERS_TABLE: !Ref OrdersTable
        POWERTOOLS_SERVICE_NAME: orders-service
        LOG_LEVEL: INFO
    Tracing: Active  # X-Ray tracing

Parameters:
  Stage:
    Type: String
    Default: prod
    AllowedValues: [dev, staging, prod]

Resources:
  # API + Lambda
  OrdersApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Stage
      TracingEnabled: true
      Auth:
        DefaultAuthorizer: CognitoAuthorizer
        Authorizers:
          CognitoAuthorizer:
            UserPoolArn: !GetAtt UserPool.Arn

  CreateOrderFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: dist/handlers/orders.createOrder
      Events:
        CreateOrder:
          Type: Api
          Properties:
            RestApiId: !Ref OrdersApi
            Path: /orders
            Method: POST
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref OrdersTable
        - SQSSendMessagePolicy:
            QueueName: !GetAtt OrderProcessingQueue.QueueName
      ReservedConcurrentExecutions: 100  # Prevent runaway scaling

  # DynamoDB — single-table design
  OrdersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      TableName: !Sub "orders-${Stage}"
      AttributeDefinitions:
        - AttributeName: PK
          AttributeType: S
        - AttributeName: SK
          AttributeType: S
        - AttributeName: GSI1PK
          AttributeType: S
      KeySchema:
        - AttributeName: PK
          KeyType: HASH
        - AttributeName: SK
          KeyType: RANGE
      GlobalSecondaryIndexes:
        - IndexName: GSI1
          KeySchema:
            - AttributeName: GSI1PK
              KeyType: HASH
          Projection:
            ProjectionType: ALL
      TimeToLiveSpecification:
        AttributeName: ttl
        Enabled: true
      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true

  # SQS Queue for async processing
  OrderProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      VisibilityTimeout: 60
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt OrderDLQ.Arn
        maxReceiveCount: 3

  OrderDLQ:
    Type: AWS::SQS::Queue
    Properties:
      MessageRetentionPeriod: 1209600  # 14 days

  # Lambda triggered by SQS
  ProcessOrderFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: dist/handlers/processor.processOrder
      Events:
        SQSTrigger:
          Type: SQS
          Properties:
            Queue: !GetAtt OrderProcessingQueue.Arn
            BatchSize: 10
            FunctionResponseTypes: [ReportBatchItemFailures]  # Partial batch success

Outputs:
  ApiUrl:
    Value: !Sub "https://${OrdersApi}.execute-api.${AWS::Region}.amazonaws.com/${Stage}"
```

### 4. Step Functions — Complex Workflows
```json
{
  "Comment": "Order fulfillment workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${ValidateOrderFunction}",
        "Payload.$": "$"
      },
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["ValidationError"],
          "Next": "OrderRejected",
          "ResultPath": "$.error"
        }
      ],
      "Next": "ProcessPayment"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "${ProcessPaymentFunction}",
        "Payload": {
          "orderId.$": "$.orderId",
          "taskToken.$": "$$.Task.Token"
        }
      },
      "HeartbeatSeconds": 300,
      "Next": "ParallelFulfillment"
    },
    "ParallelFulfillment": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "ReserveInventory",
          "States": {
            "ReserveInventory": {
              "Type": "Task",
              "Resource": "${ReserveInventoryFunction}",
              "End": true
            }
          }
        },
        {
          "StartAt": "SendConfirmationEmail",
          "States": {
            "SendConfirmationEmail": {
              "Type": "Task",
              "Resource": "${SendEmailFunction}",
              "End": true
            }
          }
        }
      ],
      "Next": "OrderComplete"
    },
    "OrderComplete": {
      "Type": "Task",
      "Resource": "${UpdateOrderStatusFunction}",
      "Parameters": {
        "orderId.$": "$.orderId",
        "status": "COMPLETE"
      },
      "End": true
    },
    "OrderRejected": {
      "Type": "Task",
      "Resource": "${NotifyRejectionFunction}",
      "End": true
    }
  }
}
```

### 5. SQS Batch Processing with Partial Failure
```typescript
import { SQSHandler, SQSRecord, SQSBatchResponse } from "aws-lambda";

export const processOrder: SQSHandler = async (event): Promise<SQSBatchResponse> => {
  const failedItems: string[] = [];

  await Promise.all(event.Records.map(async (record: SQSRecord) => {
    try {
      const order = JSON.parse(record.body);
      await fulfillOrder(order);
    } catch (error) {
      console.error(`Failed to process order ${record.messageId}:`, error);
      // Return failed message ID — SQS will retry only these messages
      failedItems.push(record.messageId);
    }
  }));

  return {
    batchItemFailures: failedItems.map((id) => ({ itemIdentifier: id })),
  };
};

async function fulfillOrder(order: any): Promise<void> {
  // Process order — throw on failure to trigger retry
  if (!order.userId) throw new Error("Missing userId");
  // ... fulfill order
}
```

## Key Commands Reference

```bash
# SAM — build and deploy
npm install -g aws-sam-cli

sam build                      # Build (runs TypeScript compile, etc.)
sam local invoke CreateOrderFunction --event events/create-order.json
sam local start-api            # Run API locally

sam deploy --guided            # First deploy (interactive)
sam deploy                     # Subsequent deploys

# Logs and monitoring
sam logs -n CreateOrderFunction --stack-name orders-stack --tail
sam logs --filter "ERROR" --start-time 5min

# AWS Lambda CLI
aws lambda invoke \
  --function-name CreateOrderFunction \
  --payload '{"body": "{\"userId\": \"123\"}"}' \
  output.json

aws lambda list-functions --query 'Functions[*].FunctionName'
aws lambda get-function-configuration --function-name CreateOrderFunction

# DynamoDB operations
aws dynamodb scan --table-name orders-prod --select COUNT
aws dynamodb query \
  --table-name orders-prod \
  --key-condition-expression "PK = :pk" \
  --expression-attribute-values '{":pk": {"S": "USER#abc123"}}'

# Step Functions
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123:stateMachine:OrderFulfillment \
  --input '{"orderId": "order-123"}'
aws stepfunctions get-execution-history --execution-arn <arn>
```

## Common Patterns

### Pattern 1: EventBridge Event Bus for Decoupling
```typescript
// Publish domain events to EventBridge
import { EventBridgeClient, PutEventsCommand } from "@aws-sdk/client-eventbridge";

const eb = new EventBridgeClient({});

async function publishOrderEvent(type: string, order: any) {
  await eb.send(new PutEventsCommand({
    Entries: [{
      EventBusName: "orders-event-bus",
      Source: "orders-service",
      DetailType: type,
      Detail: JSON.stringify(order),
      Time: new Date(),
    }],
  }));
}

// Usage
await publishOrderEvent("order.created", { orderId: "123", userId: "abc", total: 99.99 });
await publishOrderEvent("order.shipped", { orderId: "123", trackingNumber: "FEDEX123" });
```

```yaml
# EventBridge rule — route to different services
OrderCreatedRule:
  Type: AWS::Events::Rule
  Properties:
    EventBusName: orders-event-bus
    EventPattern:
      source: ["orders-service"]
      detail-type: ["order.created"]
    Targets:
      - Id: NotificationService
        Arn: !GetAtt NotificationFunction.Arn
      - Id: AnalyticsQueue
        Arn: !GetAtt AnalyticsQueue.Arn
```

### Pattern 2: Lambda Warmer (Prevent Cold Starts)
```typescript
// Use EventBridge to invoke on schedule and handle warm-up
export const handler = async (event: any) => {
  // Check for warm-up event
  if (event.source === "warmer") {
    console.log("Warm-up ping received");
    return { statusCode: 200, body: "warm" };
  }
  // Normal processing...
};
```

```yaml
WarmupRule:
  Type: AWS::Events::Rule
  Properties:
    ScheduleExpression: "rate(5 minutes)"
    Targets:
      - Id: WarmFunction
        Arn: !GetAtt MyFunction.Arn
        Input: '{"source": "warmer"}'
```

### Pattern 3: DynamoDB Streams → Lambda Pipeline
```yaml
StreamProcessorFunction:
  Type: AWS::Serverless::Function
  Properties:
    Handler: dist/handlers/stream.processStream
    Events:
      DDBStream:
        Type: DynamoDB
        Properties:
          Stream: !GetAtt OrdersTable.StreamArn
          StartingPosition: TRIM_HORIZON
          BatchSize: 100
          FilterCriteria:
            Filters:
              - Pattern: '{"eventName": ["INSERT", "MODIFY"]}'
          BisectBatchOnFunctionError: true
          DestinationConfig:
            OnFailure:
              Destination: !GetAtt StreamDLQ.Arn
```

## Pitfalls to Avoid

1. **Blocking Lambda with synchronous calls that could time out**: Lambda has a max timeout of 15 minutes. Long-running operations (video processing, ML inference, large file operations) must be offloaded to SQS + async Lambda, Step Functions, or ECS Fargate. A Lambda waiting 14 minutes for a job is burning money and blocking concurrency. Use `waitForTaskToken` in Step Functions for async handoffs.

2. **DynamoDB hot partition from predictable access patterns**: Using `userId` as the partition key for a high-traffic user causes all their writes to go to one partition. Add a shard suffix or use write sharding for high-write entities. Never use auto-incrementing IDs as partition keys — they create sequential hot partitions as traffic grows.

3. **Lambda concurrency limits causing throttling**: AWS accounts have a default limit of 3000 concurrent Lambda executions per region. A single Lambda function with `ReservedConcurrentExecutions` unset can consume the entire regional limit during a traffic spike, starving other functions. Always set reserved concurrency for critical functions and use SQS buffering to smooth bursts.

## Related Skills

- `event-driven-architecture` — Event design patterns for serverless systems
- `cqrs-patterns` — CQRS with Lambda + DynamoDB streams
- `circuit-breaker-patterns` — Resilience in Lambda-to-Lambda calls
- `api-gateway-design` — API Gateway as the entry point for Lambda APIs

## GitNexus Index

```json
{
  "skill": "serverless-patterns",
  "category": "devops",
  "triggers": ["serverless", "aws lambda", "step functions", "lambda cold start", "dynamodb serverless", "sam template", "eventbridge lambda"],
  "outputs": ["lambda handler", "SAM template", "step functions definition", "DynamoDB table", "SQS processor"],
  "complexity": "high",
  "tools": ["aws-lambda", "aws-sam", "step-functions", "dynamodb", "sqs", "eventbridge", "cloudwatch"]
}
```
