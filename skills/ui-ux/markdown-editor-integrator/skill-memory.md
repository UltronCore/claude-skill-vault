# Skill Memory: Markdown Editor Integrator

## Purpose
Installs and configures @uiw/react-md-editor for React/Next.js projects with full theme integration, SSR safety via dynamic import, server-side HTML sanitization using rehype-sanitize, and persistence patterns including auto-save debouncing and localStorage. Covers controlled mode for RHF integration, uncontrolled mode, preview-only display, custom toolbar commands, image upload on paste, word count, and version history UI.

## Category notes
Belongs in ui-ux because it provides a rich user-facing editing interface. The skill's primary output is an interactive editor component that directly affects the content authoring experience.

## Relationships
- Depends on tailwind-shadcn-ui-setup for theme context (data-color-mode syncs with next-themes)
- Integrates with form-generator-rhf-zod via Controller/FormField wrapper for RHF-managed forms

## Maintenance notes
The @uiw/react-md-editor package requires dynamic import with ssr: false for Next.js. CSS imports must be in layout or _app. The data-color-mode attribute on the wrapper div must match the active theme string.
