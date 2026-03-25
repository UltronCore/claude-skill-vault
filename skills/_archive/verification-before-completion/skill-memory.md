# Skill Memory: Verification Before Completion

## Purpose
This skill enforces evidence-before-claims through a mandatory gate function: identify the verification command, run it fresh, read the full output including exit code, then make the claim with evidence. It covers a comprehensive set of common claim types (tests, linter, build, bug fixed, agent delegation, requirements) and their required verification commands.

## Category notes
Classified as orchestration because it gates all task completion and milestone claims across every workflow.

## Relationships
- test-driven-development: TDD's red-green cycle requires this verification discipline
- systematic-debugging: Phase 4 fix verification requires running verification commands
- subagent-driven-development: the review loop depends on honest verification reporting

## Maintenance notes
The "from 24 failure memories" reference is a generic documentation note with no personal data — it describes the origin of the skill's lessons.
