# Skill Memory: Revalidation Strategy Planner

## Purpose
Evaluates Next.js route characteristics (data freshness needs, update frequency, personalization, data source latency) and recommends the optimal rendering and caching strategy for each route. Covers SSG, ISR with time-based and on-demand revalidation via cache tags, SSR with force-dynamic, and streaming with Suspense. Includes cascade and batch invalidation patterns for server actions.

## Category notes
Belongs in misc as a Next.js-specific optimization advisory skill that spans performance, architecture, and data patterns rather than fitting purely into automation or a single feature domain.

## Relationships
Applies to projects scaffolded by nextjs-fullstack-scaffold. Feature-flag-manager interactions may require cache invalidation planning when flag-gated content affects cached pages.

## Maintenance notes
None
