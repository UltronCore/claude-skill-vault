# Skill Memory: Systematic Debugging

## Purpose
This skill enforces the Iron Law: no fixes without root cause investigation first. It defines four sequential phases (root cause, pattern analysis, hypothesis testing, implementation) and adds a critical architectural escalation trigger — after three failed fixes, stop and question the architecture rather than attempt a fourth fix. The "your human partner" signals section documents specific verbal cues that indicate the process is being violated.

## Category notes
Classified as research because it is fundamentally an investigation skill — its output is understanding, not code.

## Relationships
- test-driven-development: Phase 4 Step 1 explicitly calls for using TDD to write the failing test
- verification-before-completion: complementary verification after fixing
- dispatching-parallel-agents: useful when multiple independent bugs need investigation simultaneously

## Maintenance notes
References three supporting technique files (root-cause-tracing.md, defense-in-depth.md, condition-based-waiting.md) not included in this vault import. The "your human partner" phrasing is a generic term with no personal data.
