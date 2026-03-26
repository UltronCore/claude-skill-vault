# Skill Memory: Claude Usage Orchestrator

## Purpose
Provides a four-lane routing framework (Minimal, Standard, Intensive, Offload) for disciplined Claude Code usage control. Enforces sufficiency checks before any task, promotes reuse of existing skills and prior outputs, integrates with the Codex skill for mechanical execution work, and defines anti-waste rules to prevent over-reasoning, excessive context scanning, and unnecessary output verbosity. Contains a full decision matrix and Codex handoff template.

## Category notes
Belongs in optimization because its entire purpose is reducing API token consumption, routing work through cost-appropriate paths, and maximizing output-per-token efficiency across all Claude Code tasks.

## Relationships
- Coordinates with any skill that benefits from usage-aware routing before execution
- Integrates directly with the Codex skill for offloading mechanical work
- Can direct server-actions-vs-api-optimizer and performance-budget-enforcer tasks to appropriate lanes

## Maintenance notes
Workspace-specific paths were sanitized during import (replaced with generic /path/to/workspace/ references). The Codex integration section references "the existing Codex skill" — ensure that skill remains available in the vault for this integration to function.
