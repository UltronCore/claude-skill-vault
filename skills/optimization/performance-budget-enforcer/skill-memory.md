# Skill Memory: Performance Budget Enforcer

## Purpose
Sets up and enforces automated performance budgets for Next.js applications by defining thresholds for Lighthouse scores (performance, accessibility, best practices, SEO), JavaScript bundle sizes (initial, route, total, vendor), Core Web Vitals (LCP, FID, CLS, TTFB, FCP), and asset sizes. Integrates with GitHub Actions CI/CD, Lighthouse CI, and Next.js Bundle Analyzer. Generates PR comment reports with pass/warning/error status and trend charts.

## Category notes
Belongs in optimization because it enforces measurable performance constraints, prevents regressions, and drives ongoing optimization of bundle size and runtime performance metrics.

## Relationships
- Monitors bundle impact of components installed by tailwind-shadcn-ui-setup
- Optimization recommendations from server-actions-vs-api-optimizer can improve scores monitored here
- claude-usage-orchestrator can route performance audit tasks efficiently

## Maintenance notes
Uses @lhci/cli and @next/bundle-analyzer as key dependencies. GitHub Actions workflow template in assets/github-workflow.yml. Lighthouse config in assets/lighthouserc.json. Budget thresholds in performance-budget.json should be calibrated to current baseline before enforcing.
