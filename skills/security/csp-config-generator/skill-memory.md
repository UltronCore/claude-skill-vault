# Skill Memory: CSP Config Generator

## Purpose
Generates Content Security Policy headers for Next.js applications by scanning the codebase for external resource domains, then producing nonce-based middleware, config files, and violation reporting endpoints. Handles environment-specific differences between development (permissive) and production (strict) CSP.

## Category notes
Belongs in security as CSP is a primary browser-enforced defense against XSS attacks and unauthorized resource loading — a core web security concern.

## Relationships
- Works alongside `security-hardening-checklist` which audits broader security including but not limited to CSP
- Indirectly related to `auth-route-protection-checker` since both harden the same Next.js app layer

## Maintenance notes
CSP nonce implementation details may need updates if Next.js App Router changes how headers propagate. The skill recommends nonce-based (Strategy A) as the default — this is correct for App Router apps.
