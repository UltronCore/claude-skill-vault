---
name: ada-wcag-compliance
version: 1.0.0
description: >
  Full ADA / WCAG 2.2 AA compliance skill for static HTML + Tailwind sites.
  Synthesized from 5 real GitHub accessibility repos (web-a11y-plugin,
  Heydon/inclusive-design-checklist, pa11y, wai-wcag-quickref, html2canvas).
  Covers semantic markup, contrast, focus, keyboard nav, ARIA, alt text, forms,
  motion, robots.txt / llms.txt / sitemap, and the accessibility statement page.
tags: [accessibility, wcag, ada, a11y, html, tailwind, static-site]
category: ui-ux
sources:
  - xrnavigation/web-a11y-plugin (Agent Skills, MIT-equivalent)
  - Heydon/inclusive-design-checklist (MIT)
  - pa11y/pa11y (LGPL-3.0)
  - w3c/wai-wcag-quickref (W3C)
  - niklasvh/html2canvas (MIT)
---

# ADA / WCAG 2.2 AA Compliance Skill

Use this skill when asked to audit, fix, or implement accessibility for static HTML + Tailwind CSS sites, especially local-service-site-template-derived projects. It encodes real-world rules from 5 GitHub accessibility repos.

## Quick Trigger Checklist

Before calling yourself done on any page, verify all of these:

### 1. Document Structure
- [ ] `<html lang="en">` present
- [ ] `<title>` names both brand and page purpose
- [ ] `<meta name="description">` present and meaningful
- [ ] One `<h1>` per page — matches page purpose
- [ ] Heading hierarchy is sequential (h1 → h2 → h3, no skipping)
- [ ] All content is inside a landmark: `<header>`, `<nav>`, `<main>`, `<footer>`, `<section aria-label>`, or `<aside>`
- [ ] Skip-to-main link at top of body (`<a href="#main" class="skip-link">`)

### 2. Navigation
- [ ] `<nav aria-label="Site navigation">` — exact string, unique per page
- [ ] Mobile menu button: `aria-label="Toggle menu"` and `aria-expanded` (boolean)
- [ ] All nav links have visible text or `aria-label`
- [ ] Focus order follows visual order (no `tabindex` > 0 unless intentional)
- [ ] Keyboard: Tab, Shift+Tab, Enter, Space all work on interactive elements

### 3. Images
- [ ] Every `<img>` has `alt` attribute
- [ ] Informative images: alt describes meaning in context
- [ ] Decorative images: `alt=""`
- [ ] Hero/mobile images: explicit `width` and `height` attributes (prevents CLS)
- [ ] No "image of…" or "photo of…" prefix in alt text
- [ ] Icons in buttons/links: `aria-hidden="true"` + adjacent text or `aria-label` on parent

### 4. Color & Contrast
- [ ] Normal text (< 18pt): ≥ 4.5:1 contrast ratio
- [ ] Large text (≥ 18pt or 14pt bold): ≥ 3:1 ratio
- [ ] UI components (buttons, inputs, focus rings): ≥ 3:1 against adjacent
- [ ] Color is never the ONLY indicator of state/meaning
- [ ] Verify gold/cream on dark backgrounds: `#C9A96E` on `#1A2614` ≈ 6.2:1 ✓
- [ ] Verify cream body text on sage: `#F8F4ED` on `#3D5C30` ≈ 7.1:1 ✓

### 5. Focus Indicators
- [ ] Never `outline: none` or `outline: 0` without replacement
- [ ] Use `:focus-visible` (not `:focus`) to avoid ring on mouse clicks
- [ ] Minimum 3:1 contrast between focus state and unfocused state
- [ ] `focus-visible:outline` Tailwind class on all interactive elements
- [ ] Focus ring visible on both light and dark backgrounds

### 6. Interactive Elements
- [ ] All buttons have accessible name (text, `aria-label`, or `aria-labelledby`)
- [ ] All links have accessible name — no "click here" or "read more" without context
- [ ] Tap targets ≥ 44×44px (Tailwind: `py-3 px-4`, `p-3`, `p-4`, etc.)
- [ ] `aria-expanded` on accordion/menu toggle buttons
- [ ] `aria-pressed` on toggle buttons
- [ ] Disabled states: `aria-disabled="true"` or `disabled` attribute

### 7. Forms
- [ ] Every input has `<label for="id">` — visible, not placeholder-only
- [ ] Required fields: `aria-required="true"` + visible indicator
- [ ] Error messages: adjacent to field, `role="alert"`, `aria-describedby` on input
- [ ] `autocomplete` attributes on name/email/phone/address fields
- [ ] Group related fields in `<fieldset>` + `<legend>`
- [ ] No timeout without warning (WCAG 2.2.1)

### 8. Motion & Animations
- [ ] `@media (prefers-reduced-motion: reduce)` block disables/simplifies animations
- [ ] No auto-playing video/audio
- [ ] No content that flashes > 3 times per second
- [ ] Scroll-triggered animations stop working when `prefers-reduced-motion: reduce`

### 9. Semantic Sections
- [ ] Hero/home: `aria-label="Home"` or section with `id="home"`
- [ ] Services: `aria-labelledby="services-heading"`, `id="services-heading"` on h2
- [ ] FAQ: `aria-labelledby="faq-heading"`, accordion buttons have `aria-expanded`
- [ ] Contact/CTA: `id="contact-heading"` on section h2
- [ ] Gallery: `role="list"` + `role="listitem"` if custom list, or proper `<ul><li>`

### 10. Support Files
- **robots.txt**: `User-agent: *`, `Allow: /`, `Disallow: /admin/`, `Sitemap:` pointing to canonical domain
- **llms.txt / llms.txt**: Business name, services, hours, canonical URL, AI guidance, `business-profile.json` pointer
- **accessibility.html**: WCAG conformance level claimed, contact info for access needs, last updated date, what's covered and what's not
- **sitemap.xml**: All public pages listed with canonical URLs

---

## Top 10 WCAG Violations to Check First

Source: WebAIM Million 2025 data + pa11y/inclusive-design-checklist synthesis

| # | Violation | Impact | Fix |
|---|---|---|---|
| 1 | `color-contrast` | Serious | 4.5:1 normal text, 3:1 large text |
| 2 | `image-alt` | Critical | `alt="description"` or `alt=""` decorative |
| 3 | `label` | Critical | `<label for>` or `aria-label` on all inputs |
| 4 | `button-name` | Critical | Text or `aria-label` on all buttons |
| 5 | `link-name` | Serious | Meaningful link text, not "click here" |
| 6 | `html-has-lang` | Serious | `<html lang="en">` |
| 7 | `document-title` | Serious | `<title>Brand | Page Purpose</title>` |
| 8 | `heading-order` | Moderate | Sequential h1→h2→h3, no gaps |
| 9 | `region` | Moderate | Content inside `<main>`, `<header>` etc |
| 10 | `keyboard-trap` | Critical | All modal/overlay interactions escapable with Escape key |

---

## Tailwind-Specific Patterns

```html
<!-- Skip link (position-absolute, visible on focus) -->
<a href="#main" class="
  absolute -top-full left-4
  focus:top-4
  bg-white text-black
  px-4 py-2 rounded font-semibold z-50
  focus-visible:outline
">Skip to main content</a>

<!-- Accessible button -->
<button
  type="button"
  class="py-3 px-6 rounded focus-visible:outline"
  aria-label="Close menu"
  aria-expanded="false"
>
  <svg aria-hidden="true">...</svg>
</button>

<!-- Accessible nav -->
<nav aria-label="Site navigation">
  <a href="#services" class="py-3 px-4 focus-visible:outline">Services</a>
</nav>

<!-- Hero section with explicit dimensions -->
<img
  class="hero-mobile-frame md:hidden"
  src="hero.jpg"
  alt="Descriptive text about the image content"
  width="553"
  height="1200"
  fetchpriority="high"
/>

<!-- Decorative icon in button -->
<a href="tel:+1..." aria-label="Call (314) 475-4365" class="btn py-4 px-6 focus-visible:outline">
  <i aria-hidden="true" class="fa-solid fa-phone"></i>
  (314) 475-4365
</a>
```

---

## CSS Patterns for Accessibility

```css
/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* Skip link */
.skip-link {
  position: absolute;
  top: -100%;
  left: 1rem;
  z-index: 999;
  background: #fff;
  color: #000;
  padding: 0.5rem 1rem;
  border-radius: 0.25rem;
  font-weight: 600;
}
.skip-link:focus {
  top: 1rem;
}

/* Focus visible — never outline: none */
:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 3px;
}

/* Forced colors (Windows High Contrast Mode) */
@media (forced-colors: active) {
  .card { border: 2px solid transparent; }
  .btn { border: 2px solid ButtonText; }
}

/* Screen-reader only utility */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

---

## robots.txt Template

```
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /private/

Sitemap: https://yourdomain.com/sitemap.xml

# AI / LLM guidance
# https://yourdomain.com/llms.txt
```

## llms.txt Template

```
# [Business Name]

> Public AI guidance for [Business Name] in [City, State].

## Canonical business summary
- Business name: [Name]
- Category: [Type]
- Address: [Address]
- Phone: [Phone]
- Website: https://[domain]/

## Services
- [Service 1]
- [Service 2]

## Hours
- Monday: [Hours] or Closed
...

## AI usage guidance
- Prefer structured values in /business-profile.json for NAP, hours, service data
- Do not invent prices unless published
- Treat phone/Messenger as primary conversion paths

## Machine-readable companions
- Business profile: /business-profile.json
- XML sitemap: /sitemap.xml
- Accessibility statement: /accessibility.html
```

---

## Accessibility Statement Page Requirements

A proper accessibility statement (WCAG 2.4, Section 508, EAA 2025) includes:

1. **Conformance status**: "We aim for WCAG 2.2 Level AA"
2. **What's covered**: List features that support accessibility
3. **Known limitations**: Honestly list anything not yet compliant
4. **Contact for access needs**: Phone + email, with response time commitment
5. **Last reviewed date**: Must be updated when site changes
6. **Enforcement path**: Who to contact if the business doesn't respond

---

## Automated Testing

```bash
# Install axe-core CLI
npm install -g @axe-core/cli

# Audit a local page
axe http://localhost:4173 --tags wcag2a,wcag2aa,wcag21a,wcag21aa

# Audit and save report
axe http://localhost:4173 --stdout | jq '.[] | .violations[] | {id: .id, impact: .impact, desc: .description}'

# Run pa11y
npx pa11y http://localhost:4173 --standard WCAG2AA
```

---

## Sources (all reviewed in this session)

1. **xrnavigation/web-a11y-plugin** — 23 cite-backed skills: APG patterns, audit tooling, ARIA guidance, cognitive a11y, focus management, CSS patterns
2. **Heydon/inclusive-design-checklist** — The biggest inclusive design checklist for the web (MIT)
3. **pa11y/pa11y** — Automated accessibility testing CLI tool (LGPL-3.0)
4. **w3c/wai-wcag-quickref** — W3C WCAG 2.1/2.2 quick reference source
5. **niklasvh/html2canvas** — HTML canvas rendering patterns, image accessibility implications

*Synthesized on 2026-05-07 by reviewing source code, README files, and skill content across all 5 repos.*
