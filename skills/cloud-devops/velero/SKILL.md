---
name: velero
description: Velero — Kubernetes backup, restore, and migration tool. Use this skill whenever the user wants to back up Kubernetes cluster resources and persistent volumes, restore after disaster, migrate workloads between clusters, schedule automated backups, or configure backup storage locations. Trigger for "velero backup", "velero restore", "disaster recovery kubernetes", "PVC backup", or "cluster migration".
---

# Velero — Kubernetes Backup and Restore

## Overview

Velero (formerly Heptio Ark) is an open-source tool for backing up and restoring Kubernetes cluster resources and persistent volumes. Backups are stored in object storage (S3, GCS, Azure Blob). Velero can back up the entire cluster or namespace-level subsets and restore them to the same or a different cluster.

## When to Use

- Disaster recovery: protect against accidental deletion or cluster failures
- Migrating workloads between clusters or cloud providers
- Scheduled automated backups of namespaces or the full cluster
- Snapshot-based PVC (persistent volume) backup
- Pre-upgrade cluster snapshots as a safety net

## Installation

```bash
# Install Velero CLI (macOS)
brew install velero

# Install into cluster with AWS S3 backend
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket my-velero-backups \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero \
  --use-volume-snapshots=true \
  --use-node-agent   # enables file-system backups via Restic/Kopia

# credentials-velero format:
# [default]
# aws_access_key_id=XXXX
# aws_secret_access_key=XXXX
```

## Key Patterns

### Create a Backup

```bash
# Back up everything in the cluster
velero backup create full-cluster-backup

# Back up a specific namespace
velero backup create my-app-backup --include-namespaces my-app

# Back up with PVC snapshots
velero backup create my-app-backup \
  --include-namespaces my-app \
  --snapshot-volumes

# Back up with file-system level PVC backup (works without snapshot support)
velero backup create my-app-backup \
  --include-namespaces my-app \
  --default-volumes-to-fs-backup

# Exclude specific resources
velero backup create my-app-backup \
  --include-namespaces my-app \
  --exclude-resources events,endpoints

# Add TTL (default 720h)
velero backup create my-app-backup --ttl 168h  # 7 days
```

### Scheduled Backups

```yaml
# Via YAML (GitOps-friendly)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-app-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  template:
    includedNamespaces:
      - my-app
      - my-app-db
    defaultVolumesToFsBackup: true
    ttl: 168h0m0s   # 7 days retention
    storageLocation: default
    labelSelector:
      matchLabels:
        backup: "true"
```

```bash
# Via CLI
velero schedule create daily-full \
  --schedule="@daily" \
  --include-namespaces my-app \
  --ttl 720h
```

### Restore

```bash
# Restore from a backup
velero restore create --from-backup my-app-backup

# Restore to a different namespace
velero restore create \
  --from-backup my-app-backup \
  --namespace-mappings my-app:my-app-restored

# Restore specific resources only
velero restore create \
  --from-backup my-app-backup \
  --include-resources deployments,services,configmaps

# Dry run (simulate restore)
velero restore create --from-backup my-app-backup --dry-run

# Check restore status
velero restore describe my-app-backup-20240101120000
velero restore logs my-app-backup-20240101120000
```

### Backup Storage Location (Multiple Destinations)

```yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: secondary-s3
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: my-secondary-bucket
    prefix: velero
  config:
    region: eu-west-1
  credential:
    name: secondary-aws-credentials
    key: cloud
  default: false
```

### Pre/Post Backup Hooks (Quiesce Application)

```yaml
# Add annotations to your Pod/Deployment to quiesce before backup
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  template:
    metadata:
      annotations:
        # Freeze writes before snapshot
        pre.hook.backup.velero.io/command: '["/bin/bash", "-c", "psql -U postgres -c \"SELECT pg_start_backup('"'"'velero'"'"');\""]'
        pre.hook.backup.velero.io/container: postgres
        pre.hook.backup.velero.io/on-error: Fail
        pre.hook.backup.velero.io/timeout: 60s
        # Resume after snapshot
        post.hook.backup.velero.io/command: '["/bin/bash", "-c", "psql -U postgres -c \"SELECT pg_stop_backup();\""]'
        post.hook.backup.velero.io/container: postgres
```

### Cross-Cluster Migration

```bash
# 1. On source cluster: create backup
velero backup create migration-backup --include-namespaces my-app --wait

# 2. Ensure destination cluster uses same BackupStorageLocation (same S3 bucket)
# On destination cluster:
velero backup-location create default \
  --provider aws \
  --bucket my-velero-backups \
  --config region=us-east-1

# 3. Sync backup from storage to destination cluster
velero backup-location sync

# 4. Restore on destination cluster
velero restore create --from-backup migration-backup \
  --namespace-mappings my-app:my-app-new-cluster
```

## Common Commands

```bash
velero backup get                      # List backups
velero backup describe <name>          # Detailed backup info
velero backup logs <name>              # Backup logs
velero backup delete <name>            # Delete a backup
velero restore get                     # List restores
velero schedule get                    # List schedules
velero plugin get                      # List installed plugins
velero version                         # CLI + server version
kubectl logs -n velero -l app.kubernetes.io/name=velero   # Controller logs
```

## Pitfalls

- **PVC backups need plugins or node-agent**: storage snapshots require the cloud provider plugin AND snapshot support; use `--default-volumes-to-fs-backup` with the node-agent daemonset for generic file-level backups
- **Backup hooks only run on running pods**: if your pod is not `Running`, hooks are skipped silently — verify hook execution in backup logs
- **No automatic namespace creation on restore**: the target namespace must exist or use `--namespace-mappings` to map to an existing one
- **CRDs must exist before restoring CRD instances**: restore CRDs first with a separate restore, then restore the CRD instances
- **TTL vs storage costs**: Velero doesn't delete from S3 after TTL by default unless the storage backend supports lifecycle policies — set S3 lifecycle rules independently

## Related Skills

- `kubernetes-architect` — cluster design
- `argocd` — GitOps (pair with Velero for full DR)
- `flux-cd` — GitOps operator
- `aws-solution-architect` — S3 backend configuration

## GitNexus Index

Index path: /Users/localuser/.claude/skills/velero/.gitnexus
Created: 2026-05-24
