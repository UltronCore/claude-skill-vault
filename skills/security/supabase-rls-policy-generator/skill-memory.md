# Skill Memory: Supabase RLS Policy Generator

## Purpose
Generates SQL Row-Level Security policies for Supabase PostgreSQL databases by analyzing the schema, determining the security model (multi-tenant, RBAC, or hybrid), and producing migration files with all CRUD policies, SECURITY DEFINER helper functions, test queries, and documentation.

## Category notes
Belongs in security because RLS is the primary mechanism for preventing unauthorized data access at the database layer — an essential complement to application-layer authentication controls.

## Relationships
- Pairs with `auth-route-protection-checker` which handles application-layer auth; this skill handles database-layer auth
- Referenced by `security-hardening-checklist` in its Step 4 RLS audit section
- These two skills together provide defense-in-depth: app routes + database rows

## Maintenance notes
Policy templates use Supabase's `auth.uid()` and `auth.jwt()` functions. If Supabase changes its auth API surface, templates may need updates. Performance advice (indexing user_id, tenant_id columns) should remain valid regardless of Supabase version changes.
