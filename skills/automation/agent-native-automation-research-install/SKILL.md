---
name: agent-native-automation-research-install
description: Use when installing CLI-Anything for Claude Code, managing Claude Code plugin marketplaces, researching or installing n8n community nodes, or processing screenshots of automation tools, repos, commands, or agent-native software ecosystems. Handles research, validation, install, and documentation in one pass.
---

# Agent-Native Automation: Research & Install

## Overview

Research, validate, install, and document agent-native automation tools for Claude Code. Covers CLI-Anything, Claude Code plugin marketplaces, and n8n community nodes. Automatically processes screenshots of repos, commands, and toolchains into verified, structured actions.

**Claude Code only. No local models. No other platforms.**

See supporting files:
- [research-notes.md](research-notes.md) — verified source inventory
- [install-and-verify.md](install-and-verify.md) — confirmed install flows
- [playbook.md](playbook.md) — usage patterns
- [troubleshooting.md](troubleshooting.md) — known issues and fixes
- [decision-framework.md](decision-framework.md) — when to install vs document vs defer

---

## Screenshot Intelligence Protocol

When given a screenshot containing tools, repos, commands, or nodes:

1. Extract all visible text: repo names, package names, commands, headings, URLs, node names, labels
2. Build entity inventory: repos / commands / packages / plugins / nodes / websites
3. Research each item via firecrawl before acting
4. Classify each entity: install-now / document-only / optional / needs-credentials / self-hosted-only / admin-only
5. Execute only what is safe and verified
6. Report: installed / documented / blocked

---

## Activation

Activate automatically for:
- Any CLI-Anything setup or invocation request
- Any Claude Code plugin marketplace add/install/manage
- Any n8n node discovery, evaluation, or install
- Any screenshot containing automation tools, repos, or install instructions
- Any request to make software agent-native

---

## Core Tools Covered

| Tool | What it does | Install target |
|------|-------------|----------------|
| CLI-Anything | Makes any software agent-native via generated CLI | Claude Code plugin |
| Claude Code Marketplace | Distributes plugins to Claude Code | `/plugin` commands |
| n8n Community Nodes | Extends n8n workflow automation | n8n GUI / npm (self-hosted only) |
| CLI-Hub | Browse and discover CLI-Anything harnesses | Web catalog + meta-skill |

---

## Confirmed Current Install Flows

### CLI-Anything → Claude Code

**Prerequisites:** Python 3.10+, target software installed

```bash
# Step 1: Add marketplace
/plugin marketplace add HKUDS/CLI-Anything

# Step 2: Install plugin
/plugin install cli-anything

# Step 3: Generate CLI for a target app
/cli-anything:cli-anything ./target-app

# Step 4 (optional): Refine — iterative gap analysis
/cli-anything:refine ./target-app
/cli-anything:refine ./target-app "add batch processing and filters"
```

> Claude Code 2.x uses `/cli-anything` instead of `/cli-anything:cli-anything`

**Manual install fallback:**
```bash
git clone https://github.com/HKUDS/CLI-Anything.git
cp -r CLI-Anything/cli-anything-plugin ~/.claude/plugins/cli-anything
/reload-plugins
```

**What the pipeline does (7 phases):**
1. Analyze — scans source, maps GUI actions to APIs
2. Design — architects command groups, state model, output formats
3. Implement — builds Click CLI with REPL, JSON output, undo/redo
4. Plan Tests — creates TEST.md
5. Write Tests — unit + E2E test suite
6. Document — updates TEST.md with results
7. Publish — creates setup.py, installs to PATH

### Claude Code Plugin Marketplace

```bash
# Add GitHub marketplace (owner/repo format)
/plugin marketplace add HKUDS/CLI-Anything

# Add any git URL
/plugin marketplace add https://gitlab.com/org/plugins.git

# Add local path
/plugin marketplace add ./my-marketplace

# Install a plugin
/plugin install <plugin-name>@<marketplace-alias>

# Install from official Anthropic marketplace
/plugin install <name>@claude-plugins-official

# Reload without restart
/reload-plugins

# Interactive browse
/plugin   (→ Discover tab)
```

Official marketplace (`claude-plugins-official`) is pre-loaded. Browse at claude.com/plugins.

### n8n Community Nodes

See [decision-framework.md](decision-framework.md) before installing anything.

**Verified nodes (cloud + self-hosted):**
- Via nodes panel in the editor
- No admin required

**Unverified nodes from npm (SELF-HOSTED ONLY):**
```
Settings → Community Nodes → Install → Browse npm
→ Enter package name (e.g. n8n-nodes-storms)
→ Accept risk acknowledgment
→ Install
```

**Restrictions:**
- `⛔ n8n Cloud: cannot install unverified community nodes`
- `⛔ Requires Owner or Admin role on self-hosted instance`
- Blocklist enforced — some packages cannot be installed regardless

---

## Confirmed Restrictions

| Item | Restriction |
|------|-------------|
| n8n unverified community nodes | Self-hosted only, Owner/Admin role required |
| n8n Cloud community nodes | Verified nodes only (via nodes panel) |
| CLI-Anything on Windows | Requires Git for Windows (bash + cygpath) or WSL |
| CLI-Anything OpenClaw/Codex | Documented in repo but out of scope for this skill |
| CLI-Hub meta-skill | Claude Code: copy `cli-hub-skill/SKILL.md` to skills dir |

---

## Safe Autonomy Boundaries

**Claude Code can do without asking:**
- Add marketplaces via `/plugin marketplace add`
- Install plugins via `/plugin install`
- Run `/cli-anything:cli-anything` on a target app
- Run `/cli-anything:refine` for gap analysis
- Research n8n nodes and classify them
- Document n8n nodes for later human action

**Claude Code must stop and ask when:**
- n8n credentials / API keys needed
- n8n instance is Cloud (cannot install unverified nodes)
- User doesn't have Owner/Admin on self-hosted n8n
- External API requires auth setup before node is useful

---

## Future Reuse Pattern

This skill applies to any future screenshot-based tool discovery:

1. Extract entities from screenshot
2. Search each entity with firecrawl
3. Classify: install-now / document / defer / credentials-required
4. Execute safe installs
5. Output structured report

Apply to: plugin marketplaces, node ecosystems, CLI registries, agent-native toolchains.

## Related Skills
- `agent-loop-patterns` — agent execution patterns
- `web-researcher` — automated research
- `firecrawl-agent` — agent-based scraping

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/agent-native-automation-research-install/.gitnexus
Last indexed: 2026-05-23
