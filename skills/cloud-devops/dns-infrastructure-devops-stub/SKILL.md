---
name: dns-infrastructure-devops-stub
description: Design and manage DNS infrastructure: zone configuration, record types, TTL strategy, DNSSEC, GeoDNS, failover routing, and operational runbooks.
tags: [dns, infrastructure, networking, devops]
version: 1.0.0
---

## Overview

Design, configure, and operate DNS infrastructure from simple zone files to global GeoDNS with failover. Covers authoritative DNS, resolver configuration, DNSSEC signing, and incident response.

## When to Use

- Setting up DNS for a new domain or migrating zones between providers
- Implementing latency-based or failover routing (Route 53, Cloudflare)
- Adding DNSSEC signing to a zone
- Debugging DNS propagation issues or cache poisoning
- Designing TTL strategy for planned infrastructure changes
- Writing runbooks for DNS cutover operations

## Core Record Types Reference

| Record | Purpose | TTL guidance |
|--------|---------|-------------|
| A | IPv4 address for hostname | 300s for dynamic, 3600s for static |
| AAAA | IPv6 address for hostname | Same as A |
| CNAME | Alias to another hostname | 300-3600s; never on apex |
| MX | Mail exchanger (priority + hostname) | 3600s; lower = higher priority |
| TXT | SPF, DKIM, domain verification | 3600s |
| NS | Authoritative nameservers for zone | 86400s (24h) — rarely change |
| SOA | Zone authority, refresh, retry, expire | Managed by provider |
| SRV | Service location (protocol, port, weight) | 3600s |
| CAA | Authorized certificate authorities | 3600s |
| PTR | Reverse DNS (IP → hostname) | 3600s |
| ALIAS/ANAME | Apex CNAME workaround (provider-specific) | 60-300s |

## Zone File Example

```bind
$ORIGIN example.com.
$TTL 3600

; SOA
@    IN  SOA  ns1.example.com. hostmaster.example.com. (
               2026052401  ; Serial (YYYYMMDDnn)
               3600        ; Refresh
               900         ; Retry
               604800      ; Expire
               300 )       ; Negative TTL

; Nameservers
@    IN  NS   ns1.example.com.
@    IN  NS   ns2.example.com.

; Apex A records
@    IN  A    203.0.113.10
@    IN  A    203.0.113.11

; WWW
www  IN  CNAME  example.com.

; Mail
@    IN  MX   10  mail1.example.com.
@    IN  MX   20  mail2.example.com.

; SPF + DKIM
@    IN  TXT  "v=spf1 include:_spf.google.com ~all"
mail._domainkey  IN  TXT  "v=DKIM1; k=rsa; p=MIIBIjAN..."

; DMARC
_dmarc  IN  TXT  "v=DMARC1; p=reject; rua=mailto:dmarc@example.com"

; CAA — only Let's Encrypt may issue certs
@    IN  CAA  0 issue "letsencrypt.org"
```

## TTL Strategy for Changes

Lower TTL before any planned change — DNS caches respect TTL, so stale records persist for up to current TTL after a change.

```
T-24h:  Lower TTL to 300s (5 minutes) → wait 24h for global propagation of the lower TTL
T-0:    Make the change (swap A record, change CNAME target, etc.)
T+5m:   Verify new records propagating globally
T+1h:   Raise TTL back to 3600s once stable
```

**Propagation check:**
```bash
# Check from multiple vantage points
dig +short example.com A @8.8.8.8        # Google
dig +short example.com A @1.1.1.1        # Cloudflare
dig +short example.com A @9.9.9.9        # Quad9

# Check authoritative nameservers directly (bypasses caches)
dig +short example.com A @ns1.example.com

# Watch for propagation
watch -n5 'dig +short example.com A @8.8.8.8'
```

## Route 53 — Failover Routing

```json
// Primary record (us-east-1 ALB)
{
  "Name": "api.example.com",
  "Type": "A",
  "SetIdentifier": "primary",
  "Failover": "PRIMARY",
  "AliasTarget": {
    "HostedZoneId": "Z35SXDOTRQ7X7K",
    "DNSName": "alb-prod.us-east-1.elb.amazonaws.com",
    "EvaluateTargetHealth": true
  }
}

// Secondary record (us-west-2 ALB) — promoted on primary failure
{
  "Name": "api.example.com",
  "Type": "A",
  "SetIdentifier": "secondary",
  "Failover": "SECONDARY",
  "AliasTarget": {
    "HostedZoneId": "Z1H1FL5HABSF5",
    "DNSName": "alb-dr.us-west-2.elb.amazonaws.com",
    "EvaluateTargetHealth": true
  }
}
```

**Health check for automatic failover:**
```bash
aws route53 create-health-check --caller-reference $(date +%s) --health-check-config '{
  "Type": "HTTPS",
  "FullyQualifiedDomainName": "api.example.com",
  "Port": 443,
  "ResourcePath": "/health",
  "RequestInterval": 30,
  "FailureThreshold": 3
}'
```

## DNSSEC

DNSSEC prevents cache poisoning by cryptographically signing DNS responses. Use when your registrar and DNS provider both support it.

```bash
# AWS Route 53 — enable DNSSEC signing
aws route53 enable-hosted-zone-dnssec --hosted-zone-id Z0123456789EXAMPLE

# Get DS record to add at registrar
aws route53 get-dnssec --hosted-zone-id Z0123456789EXAMPLE

# Verify DNSSEC chain
dig +dnssec example.com A @8.8.8.8
delv @8.8.8.8 example.com A +rtrace  # full chain validation
```

**DNSSEC rollout order:**
1. Enable signing at DNS provider
2. Add DS record at registrar (links parent zone to child)
3. Wait 48h for propagation
4. Verify with `delv` — look for `; fully validated`

## Debugging Playbook

```bash
# 1. Find authoritative NS for the domain
dig +short NS example.com
whois example.com | grep -i "name server"

# 2. Query auth NS directly (no caching)
dig example.com A @ns1.example.com +norecurse

# 3. Trace delegation from root
dig +trace example.com A

# 4. Check for NXDOMAIN vs SERVFAIL
dig example.com A +noall +answer +authority +comments | grep -E "status:|ANSWER"

# 5. Find negative cache TTL (how long NXDOMAIN is cached)
dig example.com SOA | grep -A3 "AUTHORITY"  # Minimum field = negative TTL

# 6. Check split-horizon (internal vs external view)
dig example.com A @10.0.0.2          # internal resolver
dig example.com A @8.8.8.8           # external resolver
```

Common issues:
- **SERVFAIL**: NS unreachable, DNSSEC validation failure, zone transfer issue
- **NXDOMAIN**: record doesn't exist OR parent NS isn't delegating to child NS
- **Stale record**: TTL not lowered before change → wait for TTL to expire
- **Bailiwick violation**: CNAME target is out-of-zone → resolver refuses it

## Cutover Runbook Template

```markdown
## DNS Cutover: [service] to [new infrastructure]
Date: YYYY-MM-DD HH:MM UTC
Owner: @engineer
Approver: @lead

### Pre-cutover (T-24h)
- [ ] Lower TTL on affected records to 300s
- [ ] Verify new infrastructure is healthy
- [ ] Test new endpoint directly (bypass DNS)
- [ ] Alert on-call team of planned change

### Cutover (T-0)
- [ ] Update A/CNAME/Alias records in DNS console
- [ ] Note start time: ____
- [ ] Monitor error rate at T+2min, T+5min, T+10min

### Verification
- [ ] `dig +short example.com A @8.8.8.8` returns new IP
- [ ] `curl -I https://example.com` returns HTTP 200
- [ ] Synthetic monitors passing

### Rollback procedure (if needed)
- Revert DNS record to previous value
- ETA to full rollback propagation: ~5 min (TTL=300s)

### Post-cutover (T+1h)
- [ ] Raise TTL back to 3600s
- [ ] Update documentation
```

## Related Skills

- `senior-devops` — infrastructure operations and incident response
- `kubernetes-architect` — K8s ingress and external-dns operator
- `cloudflare-expert` — Cloudflare DNS, Workers, and Zero Trust
