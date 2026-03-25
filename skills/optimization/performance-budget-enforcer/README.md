# Performance Budget Enforcer

**Category:** optimization
**Status:** active
**Version:** v1

## What it does
Implements automated performance monitoring and budget enforcement to prevent performance regressions by tracking Lighthouse scores, JavaScript bundle sizes, and Core Web Vitals across deployments with CI/CD integration and automated alerts.

## When to use
- Setting up performance budgets for a new or existing Next.js application
- Adding Lighthouse CI checks to a GitHub Actions workflow
- Tracking bundle size trends and detecting regressions in pull requests
- Enforcing Web Vitals thresholds (LCP, FID, CLS) as deployment gates

## What it produces
A performance-budget.json configuration, GitHub Actions workflow, Lighthouse CI config, bundle size tracking scripts, and PR comment templates with performance reports and trend analysis.

## Related skills
- server-actions-vs-api-optimizer (optimizations that improve performance scores)
- tailwind-shadcn-ui-setup (UI setup whose bundle impact this skill monitors)
