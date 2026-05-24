---
name: falco
description: Falco — runtime security monitoring for containers and Kubernetes using eBPF/syscall tracing. Use this skill whenever the user needs to detect anomalous behavior in running containers, write Falco rules, set up security alerting, investigate security events in Kubernetes, or configure Falco Sidekick for alert routing. Trigger for "falco rules", "runtime security", "syscall monitoring", container threat detection, or "falco sidekick".
---

# Falco — Runtime Security Monitoring

## Overview

Falco is a CNCF-graduated runtime security tool that monitors syscalls and Kubernetes audit events to detect threats in real time. It uses a rules engine (YAML-based) to define what constitutes suspicious behavior — a shell spawning inside a container, a file being written in /etc, unexpected network connections, etc. — and sends alerts to Slack, PagerDuty, Elasticsearch, and 50+ other outputs via Falco Sidekick.

## When to Use

- Detecting runtime intrusions in Kubernetes pods and containers
- Alerting on policy violations (unexpected privilege escalation, exec into containers)
- Investigating security incidents via syscall audit trail
- Complementing admission control (OPA/Gatekeeper) with runtime enforcement
- SOC2/compliance workloads requiring runtime anomaly detection

## Installation

```bash
# Install with Helm (eBPF driver — no kernel module needed)
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true

# Verify
kubectl logs -n falco -l app.kubernetes.io/name=falco | head -20

# With Falco Sidekick for alert routing
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=modern_ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl="https://hooks.slack.com/services/..."
```

## Key Patterns

### Understanding Built-in Rules

Falco ships with a default ruleset at `/etc/falco/falco_rules.yaml`. Common built-in rules:

```
- Terminal shell in container
- Write below binary dir
- Read sensitive file untrusted
- Change thread namespace
- Unexpected K8s NodePort connection
- Launch Privileged Container
```

### Custom Rules File

```yaml
# /etc/falco/rules.d/my-rules.yaml

# Macro: reusable condition fragments
- macro: k8s_containers
  condition: >
    container.image.repository in (
      "my-registry.io/my-app",
      "my-registry.io/api-server"
    )

# List: reusable lists
- list: allowed_read_files
  items:
    - /etc/hosts
    - /etc/resolv.conf
    - /proc/cpuinfo

# Rule: detect unauthorized shell
- rule: Shell Spawned in Application Container
  desc: Detect a shell being spawned in a non-admin container
  condition: >
    spawned_process and
    container and
    k8s_containers and
    proc.name in (bash, sh, dash, zsh) and
    not proc.pname in (runc, containerd-shim)
  output: >
    Shell spawned in application container
    (user=%user.name container=%container.name
     image=%container.image.repository
     shell=%proc.name parent=%proc.pname
     cmdline=%proc.cmdline)
  priority: WARNING
  tags: [shell, container, mitre_execution]

# Rule: detect write to /etc in container
- rule: Write Below /etc in Container
  desc: Detect writes to /etc in containers that shouldn't
  condition: >
    open_write and
    container and
    fd.name startswith /etc and
    not proc.name in (dpkg, apt, yum, rpm) and
    not k8s_containers  # exclude our known-safe images
  output: >
    File written below /etc in container
    (user=%user.name file=%fd.name
     container=%container.name image=%container.image.repository)
  priority: ERROR
  tags: [filesystem, container, mitre_persistence]

# Rule: exception pattern (append/override rules)
- rule: Terminal shell in container
  append: true  # add exceptions to existing rule
  exceptions:
    - name: allowed_shells_in_admin_containers
      fields: [container.image.repository]
      comps: [=]
      values:
        - my-registry.io/admin-tools
```

### Falco Sidekick Configuration

```yaml
# values.yaml for Helm
falcosidekick:
  enabled: true
  config:
    slack:
      webhookurl: "https://hooks.slack.com/services/T.../B.../xxx"
      minimumpriority: "warning"
      messageformat: "Falco Alert: {rule} | Priority: {priority} | Source: {source}"
    pagerduty:
      routingkey: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      minimumpriority: "critical"
    elasticsearch:
      hostport: "http://elasticsearch:9200"
      index: "falco"
      minimumpriority: "debug"
    alertmanager:
      hostport: "http://alertmanager:9093"
      minimumpriority: "warning"
```

### Kubernetes Audit Events (K8s API server)

```yaml
# Enable K8s audit log source
# In falco.yaml:
plugins:
  - name: k8saudit
    library_path: libk8saudit.so
    open_params: "http://:9765/k8saudit"

# Example rule for K8s audit
- rule: K8s Secret Get
  desc: Detect attempts to get secrets via the API
  condition: >
    k8s_audit and
    ka.verb=get and
    ka.target.resource=secrets and
    not ka.user.name in (system:kube-controller-manager, system:kube-scheduler)
  output: >
    K8s Secret accessed
    (user=%ka.user.name secret=%ka.target.name namespace=%ka.target.namespace)
  priority: WARNING
  source: k8s_audit
```

### Testing Rules

```bash
# Interactive shell for testing (will trigger shell rule if set up)
# From outside the cluster — test that alerts fire:
kubectl exec -it <pod> -- bash

# Check Falco logs for triggered alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# Test with falco --dry-run against a rule file
falco --dry-run -r my-rules.yaml

# Use falco-tester for unit testing rules
cat > test.yaml <<EOF
rules_file: my-rules.yaml
tests:
  - rule: Shell Spawned in Application Container
    runner: host_run
    before: |
      bash -c 'sleep 1' &
    validate:
      alert: true
EOF
falco-tester test.yaml
```

## Common Commands

```bash
kubectl get pods -n falco                  # Check Falco pods running
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50
falco --list                               # List all supported fields
falco --list-rules                         # List all loaded rules
falco -r /etc/falco/falco_rules.yaml -L   # Validate rule file
falcoctl artifact install falco-rules:latest  # Update rules
```

## Pitfalls

- **eBPF vs kernel module**: `modern_ebpf` works on kernels 5.8+ with no module compilation; older kernels need the `ebpf` or `module` driver — check kernel version first
- **Too many false positives**: the default ruleset is broad; tune with `exceptions` and `macros` before enabling high-priority alerting or you'll get alert fatigue
- **Container image matching**: use `container.image.repository` (no tag) for stable matching; tags change on every deploy
- **Rule priority vs routing**: Falco's `priority` (DEBUG/INFO/WARNING/ERROR/CRITICAL) controls Sidekick routing — set `minimumpriority` in each output to avoid alert storms
- **Performance impact**: syscall mode has measurable overhead on high-throughput workloads; benchmark with `modern_ebpf` which has lower overhead than the kernel module

## Related Skills

- `opa-gatekeeper` — admission-time policy enforcement (complements runtime)
- `kubernetes-architect` — cluster security architecture
- `container-security` — container hardening patterns
- `security-hardening-checklist` — broader K8s security

## GitNexus Index

Index path: /Users/localuser/.claude/skills/falco/.gitnexus
Created: 2026-05-24
