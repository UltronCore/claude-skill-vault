# Skill Memory: Supabase + Prisma Database Management

## Purpose
Provides end-to-end guidance for managing a PostgreSQL database on Supabase using Prisma ORM. Covers dual-URL configuration (direct + pooled), shadow database setup for safe migration previews, the full migration lifecycle (dev, deploy, reset), idempotent seed scripts, Prisma Client singleton pattern for Next.js, and GitHub Actions CI workflow for schema validation. Emphasizes never modifying applied migrations and always reviewing generated SQL before deployment.

## Category notes
Belongs in integrations because it integrates Prisma ORM with the Supabase PostgreSQL service, requiring specific configuration for pgBouncer connection pooling and the Supabase auth schema boundary.

## Relationships
- Direct companion to supabase-auth-ssr-setup for the full Supabase application stack
- Referenced by sentry-and-otel-setup for automatic database query tracing via OTel
- Applicable to any Next.js or Node.js project using Supabase as the database provider

## Maintenance notes
Prisma v5+ introduced breaking changes from v4; ensure patterns match the installed version. The dual-URL configuration (DATABASE_URL / DIRECT_URL) is Supabase-specific due to pgBouncer — document clearly for non-Supabase PostgreSQL users.
