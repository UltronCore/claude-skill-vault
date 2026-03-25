# Skill Memory: Role Permission Table Builder

## Purpose
Builds complete RBAC systems: defines role hierarchies, generates four-level permission matrices (page, component, data operation, server action), produces SQL schema for roles/permissions/user_roles tables, generates Next.js middleware for route protection, creates a reusable ProtectedComponent React wrapper, and provides server action guard utilities for ownership and permission checks.

## Category notes
Belongs in misc as an authorization design and documentation skill that spans database schema, backend logic, and frontend UI concerns across any project type.

## Relationships
Integrates naturally with nextjs-fullstack-scaffold projects for adding authorization. Feature-flag-manager may complement RBAC when access is controlled by both role and flag state.

## Maintenance notes
None
