---
name: public-release-review
description: This skill should be used before any skill is published, updated publicly, or prepared for public download. Runs public safety checks, documentation quality review, version visibility verification, changelog accuracy check, and public update note generation. Triggers automatically during vault-push-guardian pre-push cycles when a public-facing skill has changed. Also invoke directly when preparing a skill for first public release, publishing an updated version, or verifying a public skill is ready for download. Runs silently unless a blocking issue or documentation gap is found. Trigger terms: public release review, release check, publish skill, public skill check, pre-publish review, public documentation review, public safety check, skill publication readiness.
---

# Public Release Review

Pre-publication quality gate for public-facing skills. Verifies every skill headed to the public repository is safe, well-documented, properly versioned, and understandable to any downloader.

This is not a generic push skill. It runs specifically when a skill is about to be publicly released or updated, and ensures the public-facing materials are complete and high quality.

---

## When this skill runs

**Automatically (via vault-push-guardian Phase 2F):**
- A `public_safe: true` skill is modified in a pre-push diff
- A skill transitions from `public_safe: false` to `public_safe: true`
- A skill is reorganized or optimized and remains public-facing

**Explicitly (user-invoked):**
- Preparing a skill for first public release
- Before posting or reposting a skill publicly
- After meaningful updates to a public skill's documentation, version, or behavior
- During weekly vault maintenance when public skills changed

---

## Trigger detection

Before running full review, determine whether this skill should run:

```bash
# Check which skills changed in the diff
git diff --cached --name-only | grep 'skills/' | grep -v '_archive\|_templates\|_registry\|_obsolete'
```

For each changed skill path, check its public_safe status:
```bash
cat skills/<category>/<skill-name>/metadata.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('public_safe', False))"
```

**Run review if:** `public_safe: true` OR the skill is being set to `public_safe: true` in this diff.

**Skip silently if:** `public_safe: false`, skill is in `_archive`, or no public-facing skills changed.

---

## Phase 1: Public safety check

Scan the skill's SKILL.md, README.md, CURRENT.md, metadata.json, and CHANGELOG.md for disallowed content.

**Block publication if ANY of the following appear:**

```bash
# Personal identifiers
grep -rE '/Users/[a-zA-Z]{2,20}/' skills/<category>/<skill-name>/

# API keys, tokens, secrets
grep -rE '(sk-|ghp_|gho_|ghs_|xai-|ANT[A-Z0-9]{20,}|Bearer [a-zA-Z0-9_\-\.]{20,})' skills/<category>/<skill-name>/

# Generic credential assignments
grep -riE '(api[_-]?key|api[_-]?secret|password|secret|private[_-]?key|access[_-]?token)\s*[=:]\s*['"'"'"][^'"'"'"]{8,}['"'"'"]' skills/<category>/<skill-name>/

# Private repo URLs or internal endpoints
grep -rE 'github\.com/[a-zA-Z0-9_-]+/(private|internal|personal)' skills/<category>/<skill-name>/

# Personal notes markers
grep -rE '(NOTE TO SELF|personal:|travel:|my schedule|private:)' skills/<category>/<skill-name>/
```

**Safe patterns (do not flag):**
- `~/path/to/...` — relative paths are fine
- `/path/to/project` — generic placeholder paths are fine
- `/Users/{user}/` — placeholder form is fine
- Example credentials with obvious placeholder values (e.g., `YOUR_API_KEY`, `<token>`)

**If blocked:** stop and output the BLOCKED block (see Output Rules). Do not proceed.

---

## Phase 2: README quality check

Read `README.md` for the skill under review.

**Required sections — fail if ANY are missing or clearly inadequate:**

| Check | Requirement |
|-------|------------|
| What it does | At least 1-2 sentences explaining the skill's purpose |
| When to use | At least 2 clear use cases |
| Category | Explicitly stated |
| Version | Current version visible |
| Status | active / archived / deprecated |
| Public safe | Confirmed or noted |

**Quality bar:**
- A person downloading this skill for the first time should understand it in 30 seconds
- "What it does" must not be vague (e.g., "does stuff" or just the skill name repeated)
- If the skill superseded an older skill, that relationship must be stated

**If a required section is missing:** flag it — do not block publication, but require fix before next push of this skill.

---

## Phase 3: Version visibility check

Verify the current version is consistent and visible across all files:

```bash
# Extract versions from each file
cat skills/<category>/<skill-name>/metadata.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('metadata.json version:', d.get('version'))"
grep -m1 'Version' skills/<category>/<skill-name>/README.md
grep -m1 'Version\|version' skills/<category>/<skill-name>/CURRENT.md
```

**Pass condition:** All three sources agree on the same version string (e.g., `v1`, `v2.1`).

**Fail condition:** Version missing from README or CURRENT.md, or versions disagree across files.

---

## Phase 4: CHANGELOG quality check

Read `CHANGELOG.md`. Apply these checks:

**Must have:** At least one entry if the skill has been updated since initial creation.

**Entry quality — reject entries that are only noise:**
- "small wording tweak" alone → too trivial for public changelog
- "minor formatting fix" alone → too trivial
- "temporary draft adjustment" → should never appear in public changelog

**Accept entries that reflect:**
- Added capability or behavior
- Improved documentation quality
- Security or safety improvements
- Reorganization affecting public use
- Version or category changes

**If CHANGELOG is empty on a non-v1 skill:** flag as missing.
**If CHANGELOG entries are all trivial noise:** flag for cleanup.

---

## Phase 5: Public update notes assessment

Determine whether meaningful public-facing changes occurred since the last public version.

**Check last released version:**
```bash
ls skills/<category>/<skill-name>/versions/ | sort -V | tail -1
```

**Compare current SKILL.md against last version:**
```bash
diff skills/<category>/<skill-name>/versions/<last-version>/SKILL.md \
     skills/<category>/<skill-name>/SKILL.md | head -60
```

**Classify the diff:**

| Diff type | Action |
|-----------|--------|
| No meaningful difference | No update notes needed |
| Minor wording or formatting only | No public update notes needed |
| Behavioral change, new capability, improved logic | Generate concise update note |
| Major restructure or supersession | Generate stronger update summary |

**If update notes are needed, generate a concise summary following release significance rules:**

- **PATCH** (vX.Y.Z → vX.Y.Z+1): One-line note if public behavior or clarity changed
- **MINOR** (vX.Y → vX.Y+1): 2-4 lines covering new or improved capabilities
- **MAJOR** (vX → vX+1): Short paragraph covering the larger change

**Good examples:**
- `v1.1 — improved trigger detection logic and added parallel agent support`
- `v2.0 — restructured as standalone skill; now integrates directly into vault-push-guardian`

**Bad examples (do not write):**
- `updated line 12 wording`
- `minor edit`
- `fixed typo in section 3`

If update notes are needed but missing from README and CHANGELOG, write them now and apply to both files.

---

## Phase 6: Public download readiness check

Verify the skill folder is clean and understandable for a public downloader:

```bash
ls skills/<category>/<skill-name>/
```

**Required files:**
- `SKILL.md` — main skill instructions
- `README.md` — public-facing description
- `CURRENT.md` — current state snapshot
- `metadata.json` — machine-readable metadata
- `CHANGELOG.md` — version history

**Check for junk:**
- No `.DS_Store`, `*.tmp`, `*.bak` files
- No draft files (e.g., `SKILL-DRAFT.md`, `notes-temp.md`)
- No files with names that suggest private or incomplete state

**File naming:** All filenames should be clear and purposeful. No ambiguous names.

---

## Decision and output

### If ALL checks pass:
Run silently. No output.

### If issues found:
Output one concise block per skill:

```
PUBLIC RELEASE BLOCKED — skills/<category>/<skill-name>
Issue: [specific problem]
File: [file with problem]
Fix: [exact action needed]
```

Multiple issues for the same skill:
```
PUBLIC RELEASE NEEDS FIXES — skills/<category>/<skill-name>
1. [Issue + fix]
2. [Issue + fix]
```

### If update notes were auto-generated:
One-line note only:
```
Updated public notes — skills/<category>/<skill-name>/README.md + CHANGELOG.md
```

---

## Output rules

**Silent unless:**
- Public safety fails → BLOCKED, stop everything
- Required README sections are missing → list gaps
- Version mismatch across files → flag
- CHANGELOG missing or all-noise on updated skill → flag
- Update notes were auto-generated and applied → one-line note

**Never output:**
- "Checking..." progress messages
- Confirmation that passing files passed
- Verbose grep output
- Internal diff details unless directly relevant to a reported issue

---

## Parallel execution (for full vault scan)

When reviewing multiple skills at once (e.g., weekly maintenance):

- Agent A: Public safety scan (Phase 1) across all changed public skills
- Agent B: Documentation quality review (Phases 2–3) across all changed public skills
- Agent C: Changelog and update notes (Phases 4–5) across all changed public skills

Merge results. Block push on any BLOCKED result. Apply update notes from Agent C before commit.

---

## Integration with vault-push-guardian

This skill is called during vault-push-guardian **Phase 2F**, after Phase 2E completes.

**Phase 2F trigger condition:**
Any file in `git diff --cached --name-only` matches a skill path where `public_safe: true`.

**Phase 2F behavior:**
1. Identify all public-facing skills in the diff
2. Run public-release-review on each
3. If any are BLOCKED → block the push (same as Phase 2 blocking behavior)
4. If update notes were generated → stage those files before commit
5. If fixes needed but not blocking → include in commit message as `review: public docs refresh`

**Commit message prefixes:**
- Clean push: no change to commit message
- Update notes applied: append `(public docs refreshed)`
- Blocking issue: `PUSH BLOCKED — see output above`

---

## Release significance logic

Use this table when deciding update note depth:

| Change type | Public note needed? | Length |
|-------------|---------------------|--------|
| Internal restructure, no behavior change | No | — |
| Wording or formatting only | No | — |
| Trigger description improved | Yes (patch) | 1 line |
| New capability or behavior added | Yes (minor) | 2-4 lines |
| Safety or quality improvement | Yes (minor/patch) | 1-2 lines |
| Major restructure, supersession, or workflow change | Yes (major) | Short paragraph |

When in doubt: if a public downloader would notice or benefit from knowing, include it. If they wouldn't care, skip it.

## Related Skills
- `release-manager` — release management
- `changelog-generator` — release notes
- `security-advisor` — security review

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/public-release-review/.gitnexus
Last indexed: 2026-05-23
