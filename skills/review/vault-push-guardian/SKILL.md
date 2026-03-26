---
name: vault-push-guardian
description: Pre-push safety review and smart sync for Skill Vault (UltronCore/claude-skill-vault) and Project Vault (UltronCore/claude-project-vault). Runs automatically before any push to either vault repo. Also invoke when the user says "sync the vaults", "push vaults", "vault review", "weekly vault push", "check vaults", or "vault maintenance". Scans for secrets, credentials, personal info, and memory violations before allowing a push. Runs silently unless a blocking issue is found. Manages usage-threshold and weekly push scheduling automatically.
---

# Vault Push Guardian

Safety review and smart push management for both vaults. This skill prevents unsafe content from reaching GitHub while keeping both repos in sync efficiently.

**Two vaults covered:**
- `~/claude-skill-vault/` → `UltronCore/claude-skill-vault` (PUBLIC — higher safety bar)
- `~/claude-project-vault/` → `UltronCore/claude-project-vault` (PRIVATE — internal context allowed, but still sanitized)

---

## When this skill runs

- Before any `git push` to either vault
- When invoked as a weekly maintenance cycle
- When triggered by a scheduled cron run
- When the user asks to sync, review, or push vaults

Run silently. Only output if something needs attention or a push is blocked.

---

## Phase 1: Detect pending changes

Check both vaults for uncommitted or unpushed changes:

```bash
cd ~/claude-skill-vault && git status --short && git log origin/main..HEAD --oneline
cd ~/claude-project-vault && git status --short && git log origin/main..HEAD --oneline
```

If neither vault has pending changes and the last push was recent (within 7 days), skip — no work needed.

Determine how many days since last push:
```bash
cd ~/claude-skill-vault && git log -1 --format="%ar" origin/main
cd ~/claude-project-vault && git log -1 --format="%ar" origin/main
```

**Push thresholds:**
- Changes exist → always review and push
- No changes but last push > 7 days → do a weekly structural review, skip push if nothing changed
- No changes, recent push → skip silently

---

## Phase 2: Safety scan

Run this scan on ALL staged, modified, **and untracked** files before any push — untracked files will be staged by `git add -A` in Phase 5, so scan them now. For skill vault, scan changed files plus a spot-check of existing skills (it's public).

### 2A — Secret and credential patterns

Search for these patterns in changed files. Block push if ANY match is found:

```bash
# Run in each vault directory against changed files
git diff --cached --unified=0 | grep -E \
  'sk-[a-zA-Z0-9]{32,}|'\
  'ghp_[a-zA-Z0-9]{36}|'\
  'gho_[a-zA-Z0-9]{36}|'\
  'ghs_[a-zA-Z0-9]{36}|'\
  'xai-[a-zA-Z0-9]{32,}|'\
  'ANT[A-Z0-9]{40,}|'\
  'Bearer [a-zA-Z0-9_\-\.]{20,}|'\
  'Authorization: Basic [a-zA-Z0-9+/=]{20,}'
```

Also grep all staged text files for generic secret assignments:
```bash
git diff --cached | grep -iE \
  '(api[_-]?key|api[_-]?secret|password|passwd|secret|private[_-]?key|access[_-]?token)\s*[=:]\s*['"'"'"][^'"'"'"]{8,}['"'"'"]'
```

### 2B — .env content check

Ensure no `.env` file contents appear in any committed file. Scan staged and untracked text files for common env variable patterns:
```bash
# Scan staged content
git diff --cached | grep -iE '^[+][A-Z_]{3,}[A-Z0-9_]*\s*=\s*[^\s$]'
# Scan untracked new files
git ls-files --others --exclude-standard | xargs grep -lE '^[A-Z_]{3,}=.+' 2>/dev/null
```

Check that `.env` files themselves are not staged:
```bash
git diff --cached --name-only | grep -E '\.env$|\.env\.'
```

### 2C — Local path exposure

Flag hardcoded absolute paths that expose machine structure (except in safe/documented contexts):
```bash
git diff --cached | grep -E '/Users/[a-zA-Z]+/(Documents|Downloads|Desktop|Library|Private)'
```

Paths written as `~/...` are fine. Fully-expanded absolute paths like `/Users/<name>/Library/...` hardcoded in committed files warrant review.

### 2D — Memory file content review

For Project Vault specifically, scan all `project-memory.md` and `repo-memory.md` files in the diff for non-operational personal content.

Read each changed memory file and check whether content is:
- **Allowed:** architecture notes, continuation priorities, file relationships, build notes, known issues, optimization notes, status notes
- **Not allowed:** personal routines, travel details, private conversations, personal identifiers unrelated to the project, medical or financial details

This check requires judgment — read the memory files and decide. When in doubt, err toward blocking.

### 2E — Skill Vault public safety check

For `claude-skill-vault` (public repo), additionally scan ALL skill SKILL.md files — not just changed ones — for:
- Any hardcoded credentials embedded in skill instructions
- Any internal repo references that shouldn't be public
- Any prompt that could facilitate malicious use

This scan only needs to run on skills modified in the current diff, plus a spot-check of 3-5 random skills to catch drift.

---

## Phase 3: Decision

**If ANY blocking issue found:**
1. Do NOT push
2. Output one concise block:
   ```
   PUSH BLOCKED — [vault name]
   Issue: [one-line description]
   File: [path]
   Fix: [specific action needed]
   ```
3. Stop. Do not push until fixed.

**If minor sanitizable issues found (no hardcoded secrets, just style/path issues):**
1. Sanitize in place:
   - Replace absolute paths with `~/<relative>` equivalents
   - Remove non-operational personal sentences from memory files
   - Keep all structural content intact
2. Stage the sanitized versions
3. Continue to push

**If clean:**
- Proceed silently to Phase 4

---

## Phase 4: Structure optimization check

Quick, non-disruptive review during each push cycle. Check:

**Skill Vault:**
- [ ] `MASTER-INDEX.md` reflects current skill count and categories
- [ ] Any new skill directories have a `SKILL.md`
- [ ] No empty category folders without an `INDEX.md`
- [ ] `_registry/` files are up to date if skills were added/removed

**Project Vault:**
- [ ] `projects/_registry/registry.json` includes all project folders
- [ ] `projects/_registry/active-projects.json` is current
- [ ] `state/structure-state.json` version is current
- [ ] Each project folder has: README.md, CURRENT.md, metadata.json

**Apply small fixes directly** (update an index entry, add a missing placeholder file). Do NOT restructure categories, rename projects, or move folders — that requires a dedicated optimization pass.

---

## Phase 5: Commit and push

If changes exist (original or from sanitization/optimization):

```bash
# Stage all vault changes
git add -A

# Commit with appropriate message
# For scheduled/weekly run:
git commit -m "review: weekly sync — $(date +%Y-%m-%d)"

# For pre-push with optimizations:
git commit -m "review: safety clean + structure pass"

# For pure sanitization:
git commit -m "review: sanitize pre-push"

# Push
git push origin main
```

Run for both vaults independently. A failure in one should not block the other.

---

## Phase 6: Usage-threshold push logic

This phase applies when the skill is invoked as part of automated or scheduled runs (not user-initiated pushes).

**Push if ANY of these are true:**
1. Uncommitted changes exist in either vault
2. Last push to either vault was more than 7 days ago and there are unverified-safe local edits
3. An explicit user or schedule trigger fired

**Skip push if ALL of these are true:**
1. Both vaults are clean (no uncommitted changes)
2. Both vaults pushed within the last 3 days
3. No structural issues found in optimization check

This avoids noisy micro-pushes while ensuring nothing drifts for more than a week.

---

## Memory file enforcement rules

Every review cycle, skim all memory files modified since last push. Enforce:

**Allowed in memory files:**
- What a project does and its architecture
- File relationships and module dependencies
- Build/run notes and commands
- Known issues and workarounds
- Continuation priorities and next steps
- Skill routing logic and category organization
- Repository structural notes and lineage

**Not allowed in memory files:**
- Personal lifestyle details (routines, travel, food preferences)
- Personal relationship or family references
- Non-project financial or medical content
- Anything that reads like a diary entry vs. an operational note

When unsure, ask: "Would this help a developer continue work on this project?" If no, remove it.

---

## Parallel execution (when helpful)

For large review cycles (e.g., weekly full scan), split into parallel passes:
- Agent A: Secret + credential scan on both vaults
- Agent B: Memory file content review
- Agent C: Structure optimization check

Merge results before the commit/push decision. Do not push until all agents report clean.

---

## Output rules

**Silent unless:**
- Push is blocked (output the PUSH BLOCKED block above)
- A sanitization was applied (one-line note: `Sanitized: [file] — [what was removed]`)
- Weekly review found a structural issue worth flagging
- First-time setup

**Do not output:**
- Progress logs for individual file checks
- "Scanning..." messages
- Confirmation that clean files passed
- Verbose grep results

The goal is zero output on a clean push cycle.

---

## Weekly schedule setup

To enable automatic weekly pushes, run once:
```
/schedule vault weekly sync
```
Point the scheduled trigger at: `Run vault-push-guardian for weekly maintenance on both vaults`

The skill handles the rest — it checks for changes, reviews, sanitizes if needed, and pushes.
