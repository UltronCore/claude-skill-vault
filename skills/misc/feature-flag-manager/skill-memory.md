# Skill Memory: Feature Flag Manager

## Purpose
Adds feature flag infrastructure to Next.js applications with two implementation paths: LaunchDarkly SDK integration for cloud-managed flags with advanced targeting, or a lightweight JSON-based local implementation. Covers React context providers, hooks, component gating wrappers, Server Action guards, environment-specific overrides, and testing utilities for mocking flag states.

## Category notes
Belongs in misc because it is a cross-cutting concern applicable to many project types and feature development workflows, not specific to automation pipelines or a single technical area.

## Relationships
Commonly used within projects scaffolded by nextjs-fullstack-scaffold. Flag-gated features may interact with revalidation-strategy-planner when cached pages need invalidation based on flag changes.

## Maintenance notes
None
