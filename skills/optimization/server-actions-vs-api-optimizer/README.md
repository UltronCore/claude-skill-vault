# Server Actions vs API Routes Optimizer

**Category:** optimization
**Status:** active
**Version:** v1

## What it does
Analyzes existing Next.js routes and recommends whether to use Server Actions or API routes based on use case patterns including authentication, revalidation, external API calls, and client requirements.

## When to use
- Auditing an existing Next.js codebase for suboptimal route patterns
- Deciding between Server Actions and API routes for a new feature
- Refactoring API routes to Server Actions for form submissions and mutations
- Planning migration to reduce unnecessary API endpoint overhead

## What it produces
A route-by-route analysis report with recommended pattern (Server Action or API route), reasoning, migration complexity rating, before/after code examples, and a prioritized migration plan.

## Related skills
- form-generator-rhf-zod (Server Actions are generated as part of form output)
- claude-usage-orchestrator (apply usage-aware routing when running this analysis)
