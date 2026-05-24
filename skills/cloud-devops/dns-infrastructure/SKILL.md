---
name: dns-infrastructure
description: Design and manage production DNS infrastructure — zone configuration, record types (A, CNAME, MX, TXT, SRV, CAA), TTL strategy, DNSSEC signing, health-check-based failover, GeoDNS routing, and Cloudflare/Route53 Terraform automation.
version: 1.0.0
tags: [dns, infrastructure, cloudflare, route53, dnssec, failover, terraform, networking, devops]
---

# DNS Infrastructure

## Overview

DNS (Domain Name System) is the internet's phone book — it translates human-readable domain names into IP addresses that servers use to communicate. Production DNS infrastructure requires careful TTL design (low TTLs for agility during incidents, higher TTLs to reduce latency for stable records), health-check-based failover for high availability, DNSSEC to prevent cache poisoning attacks, and automation through Terraform or provider APIs to avoid manual drift. Cloudflare and AWS Route53 are the two dominant providers; Cloudflare adds DDoS mitigation and CDN proxying on top of DNS.

## When to Use

- Setting up DNS records for a new domain or service (A, CNAME, MX, TXT)
- Configuring health-check failover so traffic routes around an unhealthy endpoint
- Implementing GeoDNS to route users to the nearest region
- Enabling DNSSEC to protect against DNS spoofing and cache poisoning
- Migrating DNS between providers without downtime (TTL reduction strategy)
- Debugging DNS propagation issues, stale caches, or misconfigured records

## Step-by-Step Workflow

### 1. Core Record Types and Zone Configuration

```hcl
# terraform/dns/cloudflare.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

variable "zone_id" { type = string }

# A record — root domain to IPv4
resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "@"              # @ = apex domain (example.com)
  value   = "203.0.113.1"
  type    = "A"
  ttl     = 1               # 1 = automatic TTL in Cloudflare (proxied)
  proxied = true             # Route through Cloudflare CDN/DDoS protection
}

# CNAME — subdomain alias
resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  value   = "example.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# MX record — email routing
resource "cloudflare_record" "mx_primary" {
  zone_id  = var.zone_id
  name     = "@"
  value    = "mail.example.com"
  type     = "MX"
  priority = 10
  ttl      = 3600
  proxied  = false           # MX records cannot be proxied
}

# SPF — authorize email senders
resource "cloudflare_record" "spf" {
  zone_id = var.zone_id
  name    = "@"
  value   = "v=spf1 include:_spf.google.com include:sendgrid.net ~all"
  type    = "TXT"
  ttl     = 3600
}

# DMARC — email authentication policy
resource "cloudflare_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc"
  value   = "v=DMARC1; p=reject; rua=mailto:dmarc-reports@example.com; pct=100"
  type    = "TXT"
  ttl     = 3600
}

# CAA — restrict which CAs can issue TLS certs
resource "cloudflare_record" "caa_letsencrypt" {
  zone_id = var.zone_id
  name    = "@"
  type    = "CAA"
  ttl     = 3600
  data {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

# SRV — service discovery (e.g., for SIP, XMPP, game servers)
resource "cloudflare_record" "sip" {
  zone_id = var.zone_id
  name    = "_sip._tcp"
  type    = "SRV"
  ttl     = 120
  data {
    priority = 10
    weight   = 20
    port     = 5060
    target   = "sip.example.com"
  }
}
```

### 2. AWS Route53 with Health-Check Failover

```hcl
# terraform/dns/route53.tf
resource "aws_route53_zone" "primary" {
  name = "example.com"
}

# Health check for primary endpoint
resource "aws_route53_health_check" "primary" {
  fqdn              = "api-us-east-1.example.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3        # Fail after 3 consecutive failures
  request_interval  = 10       # Check every 10 seconds (30 is default, 10 is fast)

  tags = { Name = "api-us-east-1-health" }
}

# PRIMARY record — routes traffic here when healthy
resource "aws_route53_record" "api_primary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
  ttl             = 30        # Low TTL (30s) enables fast failover detection
  records         = ["203.0.113.10"]
}

# SECONDARY record — receives traffic when primary is unhealthy
resource "aws_route53_record" "api_secondary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"
  ttl            = 30
  records        = ["203.0.113.20"]   # DR region IP
}
```

### 3. GeoDNS Latency-Based Routing

```hcl
# Route53 latency-based routing — users go to the lowest-latency region
resource "aws_route53_record" "api_us" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api-global"
  type    = "A"

  latency_routing_policy {
    region = "us-east-1"
  }

  set_identifier = "us-east-1"
  ttl            = 60
  records        = ["203.0.113.10"]
}

resource "aws_route53_record" "api_eu" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api-global"
  type    = "A"

  latency_routing_policy {
    region = "eu-west-1"
  }

  set_identifier = "eu-west-1"
  ttl            = 60
  records        = ["198.51.100.20"]
}

resource "aws_route53_record" "api_ap" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api-global"
  type    = "A"

  latency_routing_policy {
    region = "ap-southeast-1"
  }

  set_identifier = "ap-southeast-1"
  ttl            = 60
  records        = ["192.0.2.30"]
}
```

### 4. DNSSEC Configuration

```hcl
# Cloudflare DNSSEC — enable zone signing
resource "cloudflare_zone_dnssec" "main" {
  zone_id = var.zone_id
}

# After enabling, get the DS record to register with the registrar
output "ds_record" {
  value = cloudflare_zone_dnssec.main.ds
  # Copy this DS record to your domain registrar's control panel
  # This creates the chain of trust from the TLD to your zone
}
```

## Key Commands Reference

```bash
# Diagnose DNS records (dig is the primary tool)
dig example.com A                            # A record
dig example.com MX                           # Mail records
dig example.com TXT                          # TXT records (SPF, DMARC, verification)
dig example.com NS                           # Authoritative nameservers
dig example.com DNSKEY                       # DNSSEC key records
dig +trace example.com                       # Full resolution trace from root
dig @8.8.8.8 example.com                    # Query specific resolver (Google)
dig @ns1.cloudflare.com example.com          # Query authoritative nameserver directly

# Check propagation across multiple resolvers
nslookup -type=A example.com 1.1.1.1        # Cloudflare
nslookup -type=A example.com 8.8.8.8        # Google

# Check TTL remaining on cached record
dig +noall +answer example.com A | awk '{print "TTL:", $2}'

# Verify DNSSEC chain of trust
dig example.com +dnssec +short               # Check RRSIG records present
delv @8.8.8.8 example.com A                  # Full DNSSEC validation (delv tool)

# Test mail configuration
dig example.com MX
nslookup -type=TXT _dmarc.example.com        # DMARC policy
nslookup -type=TXT example.com | grep spf    # SPF record

# Monitor DNS health (alert if record changes)
watch -n 60 "dig +short api.example.com A"

# Cloudflare API — flush cache for a record
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://example.com"]}'
```

## Common Patterns

### Pattern 1: Zero-Downtime DNS Migration (TTL Reduction Strategy)

```bash
# STEP 1 (1 week before migration): Reduce TTL on all records
# This ensures the old value expires quickly once you switch
# Current TTL might be 3600 (1 hour) or 86400 (1 day)
# Reduce to 300 (5 minutes) and wait until all resolvers expire the old cached value

# STEP 2 (1 week later): Verify low TTL has propagated
dig +noall +answer example.com A
# TTL in response should be ≤ 300 across multiple resolvers

# STEP 3: Update A record to new IP
# With 5-minute TTL, worst case is 5 minutes of users still hitting old IP

# STEP 4 (after migration is stable): Raise TTL back to 3600
# Low TTLs increase DNS query load — raise them once stable

# CAUTION: Email-specific records (MX, SPF) need longer TTLs
# because mail servers cache aggressively. Give 24 hours after
# any MX record change before decommissioning old mail server.
```

### Pattern 2: Cloudflare Workers for DNS-Level Routing

```javascript
// cloudflare-worker.js — rewrite requests at the DNS/edge layer
// Deploy with: wrangler deploy

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // A/B test routing at the DNS level (no app changes needed)
    if (url.pathname.startsWith("/api/v2/")) {
      const backendUrl = `https://api-v2.internal${url.pathname}${url.search}`;
      return fetch(backendUrl, { headers: request.headers });
    }

    // Maintenance mode: return 503 for specific paths
    if (url.pathname === "/checkout" && env.MAINTENANCE_MODE === "true") {
      return new Response("Maintenance in progress", {
        status: 503,
        headers: { "Retry-After": "300" },
      });
    }

    // Forward to origin
    return fetch(request);
  },
};
```

### Pattern 3: DNS-Based Service Discovery for Kubernetes

```yaml
# kubernetes/service-discovery.yaml
# CoreDNS (built into k8s) resolves service names automatically:
# <service>.<namespace>.svc.cluster.local → ClusterIP

apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
spec:
  selector:
    app: payment
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP

# Internal DNS name: payment-service.production.svc.cluster.local
# Short form (within namespace): payment-service
# Short form (cross-namespace): payment-service.production

---
# External DNS: automatically create Route53 records for LoadBalancer services
# kubectl annotate service payment-service external-dns.alpha.kubernetes.io/hostname=payments.example.com
apiVersion: v1
kind: Service
metadata:
  name: payment-external
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "payments.example.com"
    external-dns.alpha.kubernetes.io/ttl: "60"
spec:
  type: LoadBalancer
  selector:
    app: payment
  ports:
    - port: 443
      targetPort: 8443
```

## Pitfalls to Avoid

1. **Setting TTL too high for records that may need to change**: A 24-hour TTL (86400) on an A record means that if your server IP changes or goes down, users may be cached to the old IP for up to 24 hours — even after you update the DNS record. Use 3600 (1 hour) for production A records on stable infrastructure, 300 (5 minutes) for records on frequently-changing endpoints or pre-migration. Only use long TTLs (86400+) for truly static content (CNAME to CDN, SPF).

2. **Missing CAA records and getting unexpected certificate issuance**: Without CAA records, any Certificate Authority can issue TLS certificates for your domain. Add CAA records to explicitly allowlist only the CAs you use (Let's Encrypt, DigiCert, etc.) and optionally add `issuewild` entries for wildcard certs. This prevents attackers who compromise a rogue CA from issuing certs for your domain. Monitor Certificate Transparency logs (crt.sh) to detect unauthorized issuance.

3. **Forgetting email authentication records (SPF, DKIM, DMARC)**: Without SPF and DKIM, email from your domain can be spoofed by anyone. Without DMARC, even having SPF and DKIM doesn't tell receiving mail servers what to do with failures. Start DMARC at `p=none` (monitor only), fix any alignment issues by checking your rua reports, then escalate to `p=quarantine` then `p=reject`. Gmail and Outlook now require DMARC for domains sending >5k emails/day.

## Related Skills

- `cloudflare-expert` — Cloudflare Workers, Pages, R2, and advanced Cloudflare features
- `senior-devops` — Infrastructure operations and on-call runbooks
- `platform-engineering` — Infrastructure as code and developer platforms
- `service-mesh-istio` — Service discovery inside Kubernetes (complements external DNS)

## GitNexus Index

```json
{
  "skill": "dns-infrastructure",
  "category": "infrastructure",
  "triggers": ["DNS configuration", "DNS records", "Route53", "Cloudflare DNS", "DNSSEC", "DNS failover", "GeoDNS", "DNS migration", "TTL strategy", "MX records", "SPF DMARC", "health check DNS", "latency routing"],
  "outputs": ["cloudflare_record", "aws_route53_record", "aws_route53_health_check", "cloudflare_zone_dnssec", "latency_routing_policy", "failover_routing_policy", "dig commands", "CAA record"],
  "complexity": "medium",
  "tools": ["terraform", "cloudflare", "aws-route53", "dig", "nslookup", "cloudflare-workers", "wrangler"]
}
```
