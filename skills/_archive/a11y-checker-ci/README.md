# A11y Checker CI

**Category:** automation
**Status:** active
**Version:** v1

## What it does
Adds comprehensive accessibility testing to CI/CD pipelines using axe-core Playwright integration or pa11y-ci. Automatically generates markdown reports for pull requests showing WCAG violations with severity levels, affected elements, and remediation guidance.

## When to use
- Adding accessibility testing to an existing CI/CD pipeline
- Enforcing WCAG compliance as a quality gate on pull requests
- Generating per-PR accessibility reports with violation details and fix guidance
- Tracking accessibility improvements over time with historical comparison

## What it produces
Generates GitHub Actions or GitLab CI workflow files that run accessibility scans and post formatted markdown reports as PR comments, including violation counts by severity and remediation guidance.

## Related skills
- testing-next-stack
- github-actions-ci-workflow
- playwright-flow-recorder
