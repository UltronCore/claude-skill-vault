# Revalidation Strategy Planner

**Category:** misc
**Status:** active
**Version:** v1

## What it does
Analyzes Next.js application routes and recommends optimal caching and revalidation strategies, outputting appropriate revalidate settings, cache tags for ISR, SSR/SSG configurations, and streaming patterns based on each route's data freshness and update frequency requirements.

## When to use
- Optimizing Next.js application performance by choosing the right rendering strategy per route
- Configuring Incremental Static Regeneration (ISR) with appropriate revalidation intervals
- Planning cache invalidation using revalidateTag and revalidatePath in server actions
- Implementing streaming with Suspense for pages with slow or multiple data sources

## What it produces
Produces per-route configuration recommendations including export const revalidate values, cache tag patterns, generateStaticParams implementations, and streaming component structures with Suspense boundaries.

## Related skills
- nextjs-fullstack-scaffold
- feature-flag-manager
