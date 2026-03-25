# Skill Memory: Skill Creator

## Purpose
This skill manages the full skill creation and improvement lifecycle with quantitative evaluation infrastructure. Key components: parallel with-skill/baseline subagent runs, an eval viewer web app (generate_review.py), grading.json with standardized field names (text/passed/evidence), aggregate_benchmark script, and a description optimization loop (run_loop.py). The skill adapts significantly across platforms (Claude Code, Claude.ai, Cowork).

## Category notes
Classified as app-usage because it is a meta-tool for creating and improving the skill system itself.

## Relationships
- writing-skills: complementary — writing-skills covers TDD-based skill authoring principles; skill-creator covers the evaluation and iteration infrastructure
- test-driven-development: the eval/iterate loop mirrors TDD concepts at the skill level

## Maintenance notes
References multiple scripts, agents, and reference files (eval-viewer/generate_review.py, scripts/aggregate_benchmark, scripts/run_loop, agents/grader.md, agents/comparator.md, agents/analyzer.md, references/schemas.md, assets/eval_review.html) not included in this vault import. The skill is large but all functional content should be preserved.
