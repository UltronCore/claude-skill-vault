# Supabase RLS Policy Generator

**Category:** security
**Status:** active
**Version:** v1

## What it does
Generates comprehensive Row-Level Security (RLS) SQL policies for Supabase/PostgreSQL databases, covering multi-tenant isolation, role-based access control, user ownership, and JWT claims-based access. Produces migration files, helper functions, test queries, and documentation.

## When to use
- When setting up a new Supabase database with user data that needs row-level isolation
- When implementing multi-tenant data separation (tenant_id scoping)
- When adding role-based or permission-based database access controls
- When auditing existing RLS policies for gaps or over-permissiveness

## What it produces
A complete SQL migration file with RLS enable statements, DROP/CREATE POLICY statements for all CRUD operations, reusable SECURITY DEFINER helper functions, test queries for validating policy behavior, and markdown documentation explaining the access model.

## Related skills
- security-hardening-checklist
- auth-route-protection-checker
