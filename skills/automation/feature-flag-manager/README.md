# Feature Flag Manager

**Category:** misc
**Status:** active
**Version:** v1

## What it does
Implements feature flag support in Next.js applications using either LaunchDarkly or a local JSON-based configuration, enabling controlled rollouts, A/B testing, user targeting, and gating of UI components and Server Actions behind feature flags.

## When to use
- Adding feature toggles to gate new functionality without a full deploy
- Implementing progressive rollouts or canary releases for risky changes
- Setting up A/B testing with multiple UI variants
- Controlling feature availability per environment (dev/staging/production)

## What it produces
Produces a feature flag provider context, React hooks for flag evaluation, component wrappers for gating UI, server-side flag utilities for Server Actions, and a JSON configuration structure or LaunchDarkly integration setup.

## Related skills
- nextjs-fullstack-scaffold
- revalidation-strategy-planner
