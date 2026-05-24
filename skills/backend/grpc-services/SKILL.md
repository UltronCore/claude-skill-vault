---
name: grpc-services
description: Design and implement gRPC services with Protocol Buffers, streaming, interceptors, error handling, and deployment. Covers unary, server-streaming, client-streaming, and bidirectional patterns.
version: 1.0.0
tags: [grpc, protobuf, rpc, microservices, streaming, go, python, typescript]
---

# gRPC Services

## Overview

This skill covers building production gRPC services with Protocol Buffers: defining service contracts, implementing all four communication patterns (unary, server-streaming, client-streaming, bidirectional), adding interceptors for auth/logging/tracing, handling errors with rich status codes, and deploying with TLS and load balancing. Works across Go, Python, Node.js, and Java.

## When to Use

- Service-to-service communication where performance matters (10x faster than REST/JSON)
- Streaming use cases: real-time updates, file upload/download, live data feeds
- Strongly typed APIs between teams where schema evolution needs to be managed
- Replacing REST with a more efficient protocol for internal microservices
- Bidirectional streaming for chat, notifications, or live dashboards

## Step-by-Step Workflow

### 1. Define the Proto Contract
```protobuf
// proto/order/v1/order_service.proto
syntax = "proto3";

package order.v1;
option go_package = "github.com/example/order/v1;orderv1";
option java_package = "com.example.order.v1";

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

// Enums
enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  ORDER_STATUS_PENDING = 1;
  ORDER_STATUS_CONFIRMED = 2;
  ORDER_STATUS_SHIPPED = 3;
  ORDER_STATUS_DELIVERED = 4;
  ORDER_STATUS_CANCELLED = 5;
}

// Messages
message Order {
  string id = 1;
  string customer_id = 2;
  repeated OrderItem items = 3;
  int64 total_cents = 4;
  string currency = 5;
  OrderStatus status = 6;
  google.protobuf.Timestamp created_at = 7;
  google.protobuf.Timestamp updated_at = 8;
}

message OrderItem {
  string product_id = 1;
  string product_name = 2;
  int32 quantity = 3;
  int64 unit_price_cents = 4;
}

message CreateOrderRequest {
  string customer_id = 1;
  repeated OrderItem items = 2;
  string shipping_address = 3;
}

message CreateOrderResponse { Order order = 1; }
message GetOrderRequest { string order_id = 1; }
message ListOrdersRequest {
  string customer_id = 1;
  int32 page_size = 2;  // max 100
  string page_token = 3;
}
message ListOrdersResponse {
  repeated Order orders = 1;
  string next_page_token = 2;
}
message WatchOrderRequest { string order_id = 1; }
message OrderStatusUpdate {
  string order_id = 1;
  OrderStatus status = 2;
  google.protobuf.Timestamp updated_at = 3;
}

// Service definition
service OrderService {
  // Unary RPC
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
  rpc GetOrder(GetOrderRequest) returns (Order);
  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse);
  
  // Server streaming — real-time order status updates
  rpc WatchOrderStatus(WatchOrderRequest) returns (stream OrderStatusUpdate);
  
  // Client streaming — bulk order creation
  rpc BulkCreateOrders(stream CreateOrderRequest) returns (CreateOrderResponse);
  
  // Bidirectional streaming — live order management
  rpc ManageOrders(stream CreateOrderRequest) returns (stream Order);
}
```

```bash
# Generate code
buf generate  # Recommended (using buf.yaml)
# Or:
protoc --go_out=. --go-grpc_out=. proto/order/v1/order_service.proto
protoc --python_out=. --grpc_python_out=. proto/order/v1/order_service.proto
protoc --ts_out=. --grpc-web_out=. proto/order/v1/order_service.proto
```

### 2. Go Server Implementation
```go
package main

import (
    "context"
    "fmt"
    "net"
    "time"
    
    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "google.golang.org/protobuf/types/known/timestamppb"
    
    orderv1 "github.com/example/gen/order/v1"
)

type orderServer struct {
    orderv1.UnimplementedOrderServiceServer
    repo OrderRepository
    notifier OrderNotifier
}

// Unary RPC
func (s *orderServer) GetOrder(ctx context.Context, req *orderv1.GetOrderRequest) (*orderv1.Order, error) {
    if req.OrderId == "" {
        return nil, status.Error(codes.InvalidArgument, "order_id is required")
    }
    
    order, err := s.repo.FindByID(ctx, req.OrderId)
    if err != nil {
        if errors.Is(err, ErrNotFound) {
            return nil, status.Errorf(codes.NotFound, "order %s not found", req.OrderId)
        }
        return nil, status.Errorf(codes.Internal, "failed to fetch order: %v", err)
    }
    
    return toProto(order), nil
}

// Server streaming RPC
func (s *orderServer) WatchOrderStatus(req *orderv1.WatchOrderRequest, stream orderv1.OrderService_WatchOrderStatusServer) error {
    updates := s.notifier.Subscribe(req.OrderId)
    defer s.notifier.Unsubscribe(req.OrderId, updates)
    
    for {
        select {
        case <-stream.Context().Done():
            return nil  // Client disconnected
        case update, ok := <-updates:
            if !ok {
                return nil  // Channel closed (order finalized)
            }
            if err := stream.Send(&orderv1.OrderStatusUpdate{
                OrderId:   update.OrderID,
                Status:    toProtoStatus(update.Status),
                UpdatedAt: timestamppb.New(update.UpdatedAt),
            }); err != nil {
                return err  // Client stream broken
            }
        }
    }
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        panic(err)
    }
    
    s := grpc.NewServer(
        grpc.ChainUnaryInterceptor(
            loggingInterceptor,
            authInterceptor,
            recoveryInterceptor,
        ),
        grpc.ChainStreamInterceptor(
            streamLoggingInterceptor,
            streamAuthInterceptor,
        ),
    )
    
    orderv1.RegisterOrderServiceServer(s, &orderServer{})
    
    // Register reflection for grpcurl
    reflection.Register(s)
    
    fmt.Println("gRPC server listening on :50051")
    if err := s.Serve(lis); err != nil {
        panic(err)
    }
}
```

### 3. Interceptors
```go
// Auth interceptor
func authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "no metadata")
    }
    
    tokens := md.Get("authorization")
    if len(tokens) == 0 {
        return nil, status.Error(codes.Unauthenticated, "missing authorization token")
    }
    
    claims, err := validateJWT(tokens[0])
    if err != nil {
        return nil, status.Errorf(codes.Unauthenticated, "invalid token: %v", err)
    }
    
    ctx = context.WithValue(ctx, userClaimsKey{}, claims)
    return handler(ctx, req)
}

// Logging interceptor with OTel trace
func loggingInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    
    code := codes.OK
    if err != nil {
        code = status.Code(err)
    }
    
    logger.Info("grpc",
        "method", info.FullMethod,
        "duration_ms", time.Since(start).Milliseconds(),
        "code", code.String(),
    )
    return resp, err
}
```

### 4. Python Client
```python
import grpc
from order.v1 import order_service_pb2, order_service_pb2_grpc

def create_channel(address: str, use_tls: bool = True) -> grpc.Channel:
    if use_tls:
        credentials = grpc.ssl_channel_credentials()
        return grpc.secure_channel(address, credentials)
    return grpc.insecure_channel(address)

def main():
    channel = create_channel("order-service.internal:443")
    stub = order_service_pb2_grpc.OrderServiceStub(channel)
    
    # Add auth metadata
    metadata = [("authorization", "Bearer eyJ...")]
    
    # Unary call
    try:
        response = stub.GetOrder(
            order_service_pb2.GetOrderRequest(order_id="ord-123"),
            metadata=metadata,
            timeout=5.0,
        )
        print(f"Order status: {response.status}")
    except grpc.RpcError as e:
        if e.code() == grpc.StatusCode.NOT_FOUND:
            print("Order not found")
        else:
            print(f"Error {e.code()}: {e.details()}")
    
    # Server streaming
    for update in stub.WatchOrderStatus(
        order_service_pb2.WatchOrderRequest(order_id="ord-123"),
        metadata=metadata,
    ):
        print(f"Status update: {update.status}")
```

## Key Commands Reference

```bash
# Install buf CLI (better than raw protoc)
brew install bufbuild/buf/buf
buf lint         # Validate proto files
buf breaking --against .git#branch=main  # Check for breaking changes

# Test with grpcurl
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext -d '{"order_id": "ord-123"}' \
  localhost:50051 order.v1.OrderService/GetOrder

# gRPC UI (web interface for testing)
docker run -p 8080:8080 fullstorydev/grpcui --plaintext localhost:50051

# Evans (interactive gRPC client)
evans --proto proto/order/v1/order_service.proto --host localhost --port 50051
```

## Common Patterns

### Pattern 1: Rich Error Details
```go
import "google.golang.org/grpc/status"
import "google.golang.org/genproto/googleapis/rpc/errdetails"

func richError(msg string, violations []*errdetails.BadRequest_FieldViolation) error {
    st, _ := status.New(codes.InvalidArgument, msg).
        WithDetails(&errdetails.BadRequest{FieldViolations: violations})
    return st.Err()
}

// Client reads it:
if st, ok := status.FromError(err); ok {
    for _, detail := range st.Details() {
        if br, ok := detail.(*errdetails.BadRequest); ok {
            for _, v := range br.FieldViolations {
                fmt.Printf("Field %s: %s\n", v.Field, v.Description)
            }
        }
    }
}
```

### Pattern 2: Client-Side Retries
```go
retryPolicy := `{
    "methodConfig": [{
        "name": [{"service": "order.v1.OrderService"}],
        "retryPolicy": {
            "maxAttempts": 4,
            "initialBackoff": "0.1s",
            "maxBackoff": "1s",
            "backoffMultiplier": 2,
            "retryableStatusCodes": ["UNAVAILABLE", "DEADLINE_EXCEEDED"]
        }
    }]
}`

conn, _ := grpc.Dial(address,
    grpc.WithDefaultServiceConfig(retryPolicy),
    grpc.WithTransportCredentials(insecure.NewCredentials()),
)
```

### Pattern 3: Health Check
```go
import "google.golang.org/grpc/health/grpc_health_v1"
import "google.golang.org/grpc/health"

healthSrv := health.NewServer()
grpc_health_v1.RegisterHealthServer(s, healthSrv)
healthSrv.SetServingStatus("order.v1.OrderService", grpc_health_v1.HealthCheckResponse_SERVING)
```

## Pitfalls to Avoid

1. **Forgetting field numbers are permanent**: In Protocol Buffers, field numbers (the `= 1` in proto files) can never be reused once deployed. Removing a field? Reserve its number: `reserved 3;` and `reserved "old_field";`. Changing a field type is a breaking change. Use `buf breaking` in CI to catch this.

2. **Not setting deadlines on client calls**: gRPC calls without deadlines can hang indefinitely. Always set `timeout` or use a `context.WithTimeout`. The server should also respect context cancellation: check `ctx.Done()` in streaming loops.

3. **Using grpc.Dial without keepalive**: Without keepalive parameters, idle connections silently die behind proxies and load balancers. Add: `grpc.WithKeepaliveParams(keepalive.ClientParameters{Time: 30*time.Second, Timeout: 5*time.Second})`.

## Related Skills

- `go-microservices` — Go service that hosts gRPC endpoints
- `opentelemetry-instrumentation` — Tracing gRPC calls across services
- `kubernetes-architect` — Deploying gRPC services with envoy/istio
- `api-design-reviewer` — Reviewing proto API design

## GitNexus Index

```json
{
  "skill": "grpc-services",
  "category": "backend",
  "triggers": ["grpc", "protobuf", "protocol buffers", "rpc", "streaming rpc", "unary rpc", "buf", "grpcurl"],
  "outputs": ["proto definition", "grpc server", "grpc client", "interceptors"],
  "complexity": "high",
  "tools": ["protoc", "buf", "grpcurl", "evans", "grpcui"]
}
```
