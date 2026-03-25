# Skill Memory: Supabase Auth SSR Setup

## Purpose
Provides a complete blueprint for integrating Supabase Authentication into Next.js App Router applications with proper SSR support. Defines three distinct Supabase client configurations (browser, server, middleware), Next.js middleware for automatic route protection and session refresh, authentication utility helpers (`getCurrentUser`, `requireAuth`, `getSession`), and Server Action patterns for logout. Covers the full login/logout/OAuth flow lifecycle.

## Category notes
Belongs in integrations because it integrates the Supabase Auth service into the Next.js framework with SSR-specific configuration requirements.

## Relationships
- Direct companion to supabase-prisma-database-management for full Supabase + Prisma stack
- Referenced by sentry-and-otel-setup for user context capture patterns
- Targets Next.js App Router exclusively; not applicable to Pages Router projects

## Maintenance notes
The @supabase/ssr package is the current recommended approach, replacing the deprecated @supabase/auth-helpers-nextjs. Monitor for Supabase SSR package updates and Next.js middleware API changes.
