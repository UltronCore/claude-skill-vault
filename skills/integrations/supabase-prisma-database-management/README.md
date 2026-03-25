# Supabase + Prisma Database Management

**Category:** integrations
**Status:** active
**Version:** v1

## What it does
Manages database schema, migrations, and seed data using Prisma ORM connected to Supabase PostgreSQL. Covers initial setup, shadow database configuration, migration workflows, idempotent seeding, Prisma Client singleton patterns, and CI/CD schema validation.

## When to use
- Setting up Prisma ORM with a Supabase PostgreSQL database
- Creating and managing database migrations across environments
- Seeding initial or reference data for development and testing
- Adding schema validation checks to a CI/CD pipeline

## What it produces
A fully configured Prisma + Supabase database layer with schema, migration files, seed script, Prisma Client singleton, and optional GitHub Actions workflow for schema validation.

## Related skills
- supabase-auth-ssr-setup (auth layer that integrates with Supabase database)
- sentry-and-otel-setup (database query tracing via Prisma + OTel)
