# Test-Driven Development

**Category:** orchestration
**Status:** active
**Version:** v1
**Source:** superpowers@claude-plugins-official

## What it does
Enforces the Red-Green-Refactor TDD cycle: write one failing test, verify it fails for the right reason, write minimal code to pass, verify it passes, then refactor. Any code written before a failing test must be deleted and rewritten from scratch after the test is in place.

## When to use
- Before implementing any new feature or bug fix
- Before any behavior change or refactoring
- Whenever the temptation arises to "just write the code first"

## What it produces
Production code with verified test coverage where every function has a test that was observed to fail before the implementation existed.

## Related skills
systematic-debugging, subagent-driven-development, verification-before-completion, writing-plans
