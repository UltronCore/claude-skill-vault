---
name: go-microservices
description: Build, structure, and deploy production Go microservices with proper error handling, middleware, graceful shutdown, observability, and Docker/Kubernetes deployment patterns.
version: 1.0.0
tags: [go, golang, microservices, backend, api, docker, kubernetes, observability]
---

# Go Microservices

## Overview

This skill covers building production-grade microservices in Go from project layout through deployment. It addresses the full lifecycle: HTTP/gRPC server setup, middleware chains, structured logging, metrics, distributed tracing, graceful shutdown, health checks, and containerization. Designed for teams that need reliable, observable services at scale.

## When to Use

- Building a new backend microservice in Go
- Refactoring a monolith into Go microservices
- Adding observability (metrics, tracing, logging) to an existing Go service
- Needing a reference for Go project layout and idiomatic patterns
- Deploying a Go service to Kubernetes

## Step-by-Step Workflow

### 1. Project Layout (Standard Go Layout)
```
myservice/
├── cmd/
│   └── server/
│       └── main.go          # Entry point
├── internal/
│   ├── config/              # Configuration loading
│   ├── handler/             # HTTP/gRPC handlers
│   ├── service/             # Business logic
│   ├── repository/          # Data access layer
│   └── middleware/          # HTTP middleware
├── pkg/
│   └── errors/              # Exported error types
├── api/
│   └── openapi.yaml         # API specification
├── deploy/
│   ├── Dockerfile
│   └── k8s/
├── go.mod
└── go.sum
```

### 2. HTTP Server with Graceful Shutdown
```go
package main

import (
    "context"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
    
    mux := http.NewServeMux()
    mux.HandleFunc("GET /health", healthHandler)
    mux.HandleFunc("GET /ready", readyHandler)
    mux.HandleFunc("GET /api/v1/items", itemsHandler)
    
    handler := chain(mux,
        requestIDMiddleware,
        loggingMiddleware(logger),
        recoveryMiddleware(logger),
    )
    
    srv := &http.Server{
        Addr:         ":8080",
        Handler:      handler,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 30 * time.Second,
        IdleTimeout:  120 * time.Second,
    }
    
    go func() {
        logger.Info("server starting", "addr", srv.Addr)
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            logger.Error("server error", "error", err)
            os.Exit(1)
        }
    }()
    
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    
    if err := srv.Shutdown(ctx); err != nil {
        logger.Error("shutdown error", "error", err)
    }
    logger.Info("server stopped")
}
```

### 3. Middleware Chain
```go
type Middleware func(http.Handler) http.Handler

func chain(h http.Handler, middlewares ...Middleware) http.Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        h = middlewares[i](h)
    }
    return h
}

func loggingMiddleware(logger *slog.Logger) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            rw := &responseWriter{ResponseWriter: w, status: 200}
            next.ServeHTTP(rw, r)
            logger.Info("request",
                "method", r.Method,
                "path", r.URL.Path,
                "status", rw.status,
                "duration_ms", time.Since(start).Milliseconds(),
                "request_id", r.Header.Get("X-Request-ID"),
            )
        })
    }
}
```

### 4. Configuration with Validation
```go
package config

import (
    "fmt"
    "os"
    "strconv"
    "time"
)

type Config struct {
    Port        string
    DatabaseURL string
    LogLevel    string
    Timeout     time.Duration
    MaxConns    int
}

func Load() (*Config, error) {
    c := &Config{
        Port:     getEnv("PORT", "8080"),
        LogLevel: getEnv("LOG_LEVEL", "info"),
    }
    
    c.DatabaseURL = os.Getenv("DATABASE_URL")
    if c.DatabaseURL == "" {
        return nil, fmt.Errorf("DATABASE_URL is required")
    }
    
    timeoutSecs, err := strconv.Atoi(getEnv("TIMEOUT_SECS", "30"))
    if err != nil {
        return nil, fmt.Errorf("invalid TIMEOUT_SECS: %w", err)
    }
    c.Timeout = time.Duration(timeoutSecs) * time.Second
    
    return c, nil
}

func getEnv(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}
```

### 5. Error Handling Pattern
```go
// Custom error types with HTTP status codes
type AppError struct {
    Code    int    `json:"-"`
    Message string `json:"error"`
    Detail  string `json:"detail,omitempty"`
}

func (e *AppError) Error() string { return e.Message }

var (
    ErrNotFound   = &AppError{Code: 404, Message: "not found"}
    ErrBadRequest = &AppError{Code: 400, Message: "bad request"}
    ErrInternal   = &AppError{Code: 500, Message: "internal server error"}
)

func writeError(w http.ResponseWriter, err error) {
    var appErr *AppError
    if errors.As(err, &appErr) {
        writeJSON(w, appErr.Code, appErr)
        return
    }
    writeJSON(w, 500, ErrInternal)
}
```

### 6. Metrics with Prometheus
```go
import "github.com/prometheus/client_golang/prometheus"

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{Name: "http_requests_total", Help: "Total requests"},
        []string{"method", "path", "status"},
    )
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{Name: "http_request_duration_seconds",
            Buckets: prometheus.DefBuckets},
        []string{"method", "path"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal, requestDuration)
}
```

## Key Commands Reference

```bash
# Initialize module
go mod init github.com/org/myservice

# Run with live reload
air  # install: go install github.com/cosmtrek/air@latest

# Build optimized binary
CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o bin/server ./cmd/server/

# Docker multi-stage build
docker build -t myservice:latest .

# Run tests with race detector
go test -race ./...

# Generate mocks
go generate ./...

# Lint
golangci-lint run

# Vulnerability check
govulncheck ./...
```

## Common Patterns

### Pattern 1: Repository with Context
```go
type ItemRepository interface {
    GetByID(ctx context.Context, id string) (*Item, error)
    Create(ctx context.Context, item *Item) error
    List(ctx context.Context, filter Filter) ([]*Item, error)
}

type postgresItemRepo struct { db *sql.DB }

func (r *postgresItemRepo) GetByID(ctx context.Context, id string) (*Item, error) {
    row := r.db.QueryRowContext(ctx,
        "SELECT id, name, created_at FROM items WHERE id = $1", id)
    var item Item
    if err := row.Scan(&item.ID, &item.Name, &item.CreatedAt); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("query item: %w", err)
    }
    return &item, nil
}
```

### Pattern 2: Retry with Exponential Backoff
```go
func retry(ctx context.Context, maxAttempts int, fn func() error) error {
    var err error
    for i := 0; i < maxAttempts; i++ {
        if err = fn(); err == nil {
            return nil
        }
        wait := time.Duration(1<<uint(i)) * 100 * time.Millisecond
        select {
        case <-time.After(wait):
        case <-ctx.Done():
            return ctx.Err()
        }
    }
    return fmt.Errorf("after %d attempts: %w", maxAttempts, err)
}
```

### Pattern 3: Minimal Dockerfile
```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server ./cmd/server/

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

## Pitfalls to Avoid

1. **Goroutine leaks**: Always ensure goroutines have an exit condition. Use `context.Context` for cancellation and `errgroup` for structured concurrency. A goroutine that reads from an unbuffered channel with no sender will leak forever.

2. **Mutex copying**: Never copy a `sync.Mutex` after first use. If a struct has a mutex, pass it by pointer everywhere. Use `go vet` which catches this — run it in CI.

3. **Not handling partial writes**: `http.ResponseWriter.Write` may return `n < len(data)` without an error. Always check both return values: `if n, err := w.Write(data); err != nil || n != len(data)`.

## Related Skills

- `grpc-services` — gRPC service implementation in Go
- `kafka-event-streaming` — Event-driven Go services with Kafka
- `opentelemetry-instrumentation` — Distributed tracing setup
- `kubernetes-architect` — Deploying Go services to Kubernetes
- `postgres-advanced` — Database patterns for Go services

## GitNexus Index

```json
{
  "skill": "go-microservices",
  "category": "backend",
  "triggers": ["golang", "go service", "go api", "go microservice", "net/http", "goroutine"],
  "outputs": ["http service", "grpc service", "docker image", "kubernetes manifest"],
  "complexity": "medium",
  "tools": ["go", "air", "golangci-lint", "prometheus", "docker"]
}
```
