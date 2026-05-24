---
name: service-mesh-istio
description: Deploy and configure Istio service mesh for Kubernetes. Covers mTLS between services, traffic management with VirtualServices/DestinationRules, observability with Kiali/Jaeger/Prometheus, circuit breaking, and zero-trust networking.
version: 1.0.0
tags: [istio, service-mesh, kubernetes, mtls, traffic-management, observability, zero-trust]
---

# Service Mesh with Istio

## Overview

Istio is a service mesh that adds a sidecar proxy (Envoy) to every pod in Kubernetes, enabling mutual TLS (mTLS) between services, fine-grained traffic control, automatic distributed tracing, and policy enforcement — all without changing application code. It implements zero-trust networking (all service-to-service traffic is authenticated and encrypted by default) and provides circuit breaking, retries, and canary deployments at the infrastructure layer.

## When to Use

- Enforcing mTLS for all service-to-service communication in Kubernetes
- Canary deployments or A/B testing at the infrastructure layer (no code changes needed)
- Distributed tracing across all microservices without instrumenting each service
- Circuit breaking and retry logic without implementing it in every service
- Enforcing network policies (which services can talk to which) via AuthorizationPolicy

## Step-by-Step Workflow

### 1. Istio Installation
```bash
# Download istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.21.0
export PATH=$PWD/bin:$PATH

# Install Istio with default profile (good for production)
istioctl install --set profile=default -y

# Or install with demo profile (includes all observability tools)
istioctl install --set profile=demo -y

# Enable automatic sidecar injection for namespace
kubectl label namespace production istio-injection=enabled

# Verify installation
istioctl verify-install
kubectl get pods -n istio-system

# Install observability addons
kubectl apply -f samples/addons/prometheus.yaml
kubectl apply -f samples/addons/grafana.yaml
kubectl apply -f samples/addons/jaeger.yaml
kubectl apply -f samples/addons/kiali.yaml

# Open dashboards
istioctl dashboard kiali      # Service graph
istioctl dashboard grafana    # Metrics
istioctl dashboard jaeger     # Traces
```

### 2. mTLS and PeerAuthentication
```yaml
# Enable strict mTLS for entire mesh (all services must use mTLS)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system   # Mesh-wide policy
spec:
  mtls:
    mode: STRICT  # STRICT = only mTLS allowed; PERMISSIVE = both

---
# Namespace-level exception (e.g., legacy service that can't do mTLS)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: allow-plaintext
  namespace: legacy
spec:
  mtls:
    mode: PERMISSIVE

---
# AuthorizationPolicy — which services can call which
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: order-service-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: order-service
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/production/sa/api-gateway"
              - "cluster.local/ns/production/sa/checkout-service"
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/orders", "/api/orders/*"]
    - from:
        - source:
            principals:
              - "cluster.local/ns/monitoring/sa/prometheus"
      to:
        - operation:
            paths: ["/metrics"]
```

### 3. Traffic Management — VirtualService and DestinationRule
```yaml
# DestinationRule — defines subsets (versions) and load balancing
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service
  namespace: production
spec:
  host: product-service
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN    # or ROUND_ROBIN, RANDOM
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 200
    outlierDetection:       # Circuit breaker
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2

---
# VirtualService — traffic routing rules
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service
  namespace: production
spec:
  hosts:
    - product-service
  http:
    # Header-based routing (for QA testing of v2)
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: product-service
            subset: v2
    
    # Canary: 10% traffic to v2, 90% to v1
    - route:
        - destination:
            host: product-service
            subset: v1
          weight: 90
        - destination:
            host: product-service
            subset: v2
          weight: 10
      timeout: 5s
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: "gateway-error,connect-failure,retriable-4xx"
```

### 4. Ingress Gateway
```yaml
# Gateway — external traffic entry point
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: api-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: api-tls-secret  # K8s secret with TLS cert
      hosts:
        - "api.example.com"
    - port:
        number: 80
        name: http
        protocol: HTTP
      tls:
        httpsRedirect: true
      hosts:
        - "api.example.com"

---
# VirtualService for external routing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: external-routing
  namespace: production
spec:
  hosts:
    - "api.example.com"
  gateways:
    - istio-system/api-gateway
  http:
    - match:
        - uri:
            prefix: "/api/v1/orders"
      route:
        - destination:
            host: order-service
            port:
              number: 5000
    - match:
        - uri:
            prefix: "/api/v1/products"
      route:
        - destination:
            host: product-service
            port:
              number: 4000
```

### 5. Fault Injection (Chaos Testing)
```yaml
# Inject latency for 50% of requests to product-service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service-chaos
  namespace: production
spec:
  hosts:
    - product-service
  http:
    - fault:
        delay:
          percentage:
            value: 50
          fixedDelay: 3s
        abort:
          percentage:
            value: 5
          httpStatus: 500    # Inject 500 errors for 5% of requests
      route:
        - destination:
            host: product-service
            subset: v1
```

### 6. Observability Configuration
```yaml
# Telemetry — customize tracing sampling rate
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  tracing:
    - providers:
        - name: jaeger
      randomSamplingPercentage: 1.0   # 1% sampling in production
  metrics:
    - providers:
        - name: prometheus
  accessLogging:
    - providers:
        - name: envoy
```

```bash
# Query Prometheus metrics
kubectl port-forward svc/prometheus -n istio-system 9090:9090

# Useful PromQL for Istio metrics:
# Request rate by service
rate(istio_requests_total[5m])

# Error rate (5xx)
sum(rate(istio_requests_total{response_code=~"5.*"}[5m])) by (destination_service)
/
sum(rate(istio_requests_total[5m])) by (destination_service)

# P99 latency
histogram_quantile(0.99, rate(istio_request_duration_milliseconds_bucket[5m]))
```

## Key Commands Reference

```bash
# Check Istio proxy status
istioctl proxy-status           # All sidecars sync status
istioctl proxy-config all pod/my-pod  # Full sidecar config
istioctl proxy-config route pod/my-pod  # Route config

# Analyze config for issues
istioctl analyze                # Analyze all namespaces
istioctl analyze -n production  # Specific namespace

# Check mTLS status
istioctl authn tls-check pod/my-pod product-service.production.svc.cluster.local

# Describe routing for a service
istioctl describe service product-service.production

# View access logs (sidecar)
kubectl logs -n production deploy/product-service -c istio-proxy --tail=50

# Exec into sidecar for debugging
kubectl exec -it pod/my-pod -c istio-proxy -- curl -sS localhost:15000/config_dump

# Traffic stats
kubectl exec -it pod/my-pod -c istio-proxy -- curl localhost:15000/stats | grep upstream
```

## Common Patterns

### Pattern 1: Gradual Canary Rollout Script
```bash
#!/bin/bash
# Gradually shift traffic from v1 to v2
for weight in 10 25 50 75 100; do
  echo "Routing ${weight}% to v2..."
  
  kubectl patch virtualservice product-service -n production --type=json \
    -p="[
      {\"op\": \"replace\", \"path\": \"/spec/http/0/route/0/weight\", \"value\": $((100-weight))},
      {\"op\": \"replace\", \"path\": \"/spec/http/0/route/1/weight\", \"value\": ${weight}}
    ]"
  
  # Monitor error rate for 5 minutes
  sleep 300
  
  ERROR_RATE=$(kubectl exec -n istio-system deploy/prometheus -- \
    curl -s "localhost:9090/api/v1/query?query=sum(rate(istio_requests_total{response_code=~'5.*',destination_service='product-service'}[5m]))/sum(rate(istio_requests_total{destination_service='product-service'}[5m]))" \
    | jq '.data.result[0].value[1]' -r)
  
  echo "Error rate: ${ERROR_RATE}"
  if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
    echo "ERROR RATE TOO HIGH - Rolling back"
    kubectl patch virtualservice product-service -n production --type=json \
      -p='[{"op":"replace","path":"/spec/http/0/route/0/weight","value":100},{"op":"replace","path":"/spec/http/0/route/1/weight","value":0}]'
    exit 1
  fi
done

echo "Canary complete - 100% on v2"
```

### Pattern 2: JWT Authentication at the Mesh Level
```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-service
  jwtRules:
    - issuer: "https://accounts.example.com"
      jwksUri: "https://accounts.example.com/.well-known/jwks.json"
      audiences: ["api.example.com"]
      forwardOriginalToken: true

---
# Deny unauthenticated requests
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-service
  action: DENY
  rules:
    - from:
        - source:
            notRequestPrincipals: ["*"]  # No valid JWT
```

### Pattern 3: Rate Limiting with EnvoyFilter
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: filter-ratelimit
  namespace: production
spec:
  workloadSelector:
    labels:
      app: product-service
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          filterChain:
            filter:
              name: "envoy.filters.network.http_connection_manager"
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            value:
              stat_prefix: http_local_rate_limiter
              token_bucket:
                max_tokens: 100
                tokens_per_fill: 100
                fill_interval: 60s
              filter_enabled:
                runtime_key: local_rate_limit_enabled
                default_value:
                  numerator: 100
                  denominator: HUNDRED
```

## Pitfalls to Avoid

1. **Enabling strict mTLS before all services have sidecars**: If you switch to `STRICT` mTLS mesh-wide while some pods lack the Istio sidecar (e.g., system pods, legacy deployments), those services can no longer communicate. Always audit `istioctl proxy-status` first, label namespaces incrementally, and use `PERMISSIVE` mode during migration before switching to `STRICT`.

2. **VirtualService/DestinationRule host mismatches**: The `host` in a DestinationRule must exactly match the Kubernetes service name (as it would appear in DNS: `service-name`, `service-name.namespace`, or the full FQDN). A mismatch silently causes rules to not apply — traffic works but without the circuit breaking, retries, or routing you configured. Use `istioctl analyze` to catch these.

3. **Sidecar resource overhead**: Each Envoy sidecar consumes ~50MB RAM and ~0.1 CPU. A cluster with 500 pods adds ~25GB RAM and 50 CPU cores just for sidecars. Right-size your cluster before enabling Istio mesh-wide. Use `Sidecar` resources to restrict which services each proxy tracks — by default, Envoy tracks the entire service registry, which grows linearly with cluster size.

## Related Skills

- `kubernetes-architect` — Kubernetes foundations before adding service mesh
- `api-gateway-design` — Edge gateway (Istio handles internal; API gateway handles external)
- `opentelemetry-instrumentation` — Application-level tracing alongside Istio's infrastructure tracing
- `chaos-engineering` — Using Istio fault injection in chaos experiments

## GitNexus Index

```json
{
  "skill": "service-mesh-istio",
  "category": "devops",
  "triggers": ["istio", "service mesh", "mtls kubernetes", "traffic management", "envoy proxy", "zero trust kubernetes", "canary istio"],
  "outputs": ["PeerAuthentication", "VirtualService", "DestinationRule", "AuthorizationPolicy", "Gateway"],
  "complexity": "high",
  "tools": ["istio", "kubernetes", "envoy", "prometheus", "jaeger", "kiali"]
}
```
