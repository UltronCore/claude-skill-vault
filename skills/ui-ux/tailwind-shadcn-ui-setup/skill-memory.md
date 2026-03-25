# Skill Memory: Tailwind + shadcn/ui Setup for Next.js

## Purpose
Automates full setup of Tailwind CSS and shadcn/ui for Next.js 16 App Router projects. Covers dependency installation, components.json initialization, global CSS with semantic design tokens (CSS variables), ThemeProvider with next-themes for dark mode, AppShell layout with responsive sidebar via Sheet, accessibility defaults including skip links and focus-visible styles, and example pages for forms, dialogs, and theme showcase.

## Category notes
Belongs in ui-ux as the foundational design system setup skill. It establishes the component library and visual language that all other ui-ux skills depend on.

## Relationships
- Is a prerequisite for form-generator-rhf-zod (shadcn/ui form components)
- Is a prerequisite for markdown-editor-integrator (theme context via next-themes)
- Is audited by ui-library-usage-auditor after setup

## Maintenance notes
Supports Tailwind v3 with forward-compatible CSS variable patterns. When Tailwind v4 stabilizes, update tailwind.config.ts template to use @theme directive. The scripts/setup_tailwind_shadcn.py automates npm install and shadcn/ui init.
