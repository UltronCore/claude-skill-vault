---
name: a11y-wcag
description: >
  Web accessibility implementation: ARIA patterns, keyboard navigation, focus management, and WCAG 2.2 compliance. Triggers on: aria-label, aria-*, role=, focus trap, keyboard navigation, screen reader, WCAG, axe, accessibility.
---

# Accessibility (a11y) & WCAG 2.2

## When to Use

Apply this skill whenever building interactive components (modals, menus, forms, tabs, accordions), writing ARIA attributes, managing focus, or auditing a component for screen reader and keyboard accessibility.

---

## ARIA Landmark Roles

```html
<!-- Semantic landmarks — use native HTML elements where possible -->
<header role="banner">          <!-- or just <header> -->
<nav role="navigation">         <!-- or just <nav> — add aria-label if multiple navs -->
<main role="main">              <!-- or just <main> — one per page -->
<aside role="complementary">    <!-- or just <aside> -->
<footer role="contentinfo">     <!-- or just <footer> -->
<section aria-labelledby="section-heading">  <!-- named region -->

<!-- When you have multiple navs -->
<nav aria-label="Main navigation">...</nav>
<nav aria-label="Breadcrumb">...</nav>

<!-- Search landmark -->
<search>
  <form role="search" aria-label="Site search">...</form>
</search>
```

---

## Labeling Rules

```typescript
// 1. aria-label — short, inline string (no visible label exists)
<button aria-label="Close dialog">
  <XIcon aria-hidden="true" />   {/* hide decorative icons from AT */}
</button>

// 2. aria-labelledby — references visible text by ID (preferred over aria-label)
<h2 id="modal-title">Delete Account</h2>
<dialog aria-labelledby="modal-title">
  ...
</dialog>

// 3. aria-describedby — supplementary description (help text, error messages)
<input
  id="email"
  aria-describedby="email-hint email-error"  // space-separated IDs
/>
<p id="email-hint">We'll never share your email.</p>
<p id="email-error" role="alert">Invalid email format</p>

// Priority order: native label > aria-labelledby > aria-label
// Never use aria-label on non-interactive elements unless necessary

// 4. For icon-only buttons — always provide a label
function IconButton({ icon: Icon, label, onClick }: IconButtonProps) {
  return (
    <button onClick={onClick} aria-label={label}>
      <Icon aria-hidden="true" className="h-5 w-5" />
    </button>
  )
}

// 5. Form labels — always explicitly associate
<label htmlFor="username">Username</label>
<input id="username" type="text" />

// OR use aria-label when label is visually hidden
<input
  type="search"
  aria-label="Search products"
  placeholder="Search..."
/>
```

---

## Focus Management

```typescript
// Focus trap for dialogs and drawers
import { useEffect, useRef } from 'react'

function useFocusTrap(isActive: boolean) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!isActive || !containerRef.current) return

    const container = containerRef.current
    const focusableSelectors = [
      'a[href]',
      'button:not([disabled])',
      'input:not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])',
    ].join(', ')

    const focusable = [...container.querySelectorAll<HTMLElement>(focusableSelectors)]
    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    // Save and restore focus
    const previouslyFocused = document.activeElement as HTMLElement
    first?.focus()

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key !== 'Tab') return

      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault()
          last?.focus()
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault()
          first?.focus()
        }
      }
    }

    container.addEventListener('keydown', handleKeyDown)
    return () => {
      container.removeEventListener('keydown', handleKeyDown)
      previouslyFocused?.focus()  // restore focus on close
    }
  }, [isActive])

  return containerRef
}

// Usage in Modal
function Modal({ isOpen, onClose, children }: ModalProps) {
  const containerRef = useFocusTrap(isOpen)

  // Close on Escape
  useEffect(() => {
    function handleEsc(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    if (isOpen) document.addEventListener('keydown', handleEsc)
    return () => document.removeEventListener('keydown', handleEsc)
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <div role="dialog" aria-modal="true" aria-labelledby="modal-title" ref={containerRef}>
      {children}
    </div>
  )
}
```

---

## Skip Links

```typescript
// app/layout.tsx — always add skip link as first focusable element
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {/* Visually hidden until focused */}
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-blue-600 focus:text-white focus:rounded-lg"
        >
          Skip to main content
        </a>
        <Header />
        <main id="main-content" tabIndex={-1}>  {/* tabIndex=-1 allows programmatic focus */}
          {children}
        </main>
        <Footer />
      </body>
    </html>
  )
}
```

---

## Keyboard Navigation Patterns

```typescript
// Roving tabindex pattern — for widget groups (toolbars, menu items, tabs)
// Only ONE item in the group is in the tab order at a time

function TabList({ tabs, selectedId, onSelect }: TabListProps) {
  const [focusedId, setFocusedId] = useState(selectedId)
  const ids = tabs.map(t => t.id)

  function handleKeyDown(e: React.KeyboardEvent, id: string) {
    const currentIndex = ids.indexOf(id)

    const keyActions: Record<string, () => void> = {
      ArrowRight: () => {
        const nextId = ids[(currentIndex + 1) % ids.length]
        setFocusedId(nextId)
        document.getElementById(`tab-${nextId}`)?.focus()
      },
      ArrowLeft: () => {
        const prevId = ids[(currentIndex - 1 + ids.length) % ids.length]
        setFocusedId(prevId)
        document.getElementById(`tab-${prevId}`)?.focus()
      },
      Home: () => {
        setFocusedId(ids[0])
        document.getElementById(`tab-${ids[0]}`)?.focus()
      },
      End: () => {
        const lastId = ids[ids.length - 1]
        setFocusedId(lastId)
        document.getElementById(`tab-${lastId}`)?.focus()
      },
      Enter: () => onSelect(id),
      ' ': () => onSelect(id),
    }

    if (e.key in keyActions) {
      e.preventDefault()
      keyActions[e.key]()
    }
  }

  return (
    <div role="tablist" aria-label="Settings sections">
      {tabs.map(tab => (
        <button
          key={tab.id}
          id={`tab-${tab.id}`}
          role="tab"
          aria-selected={tab.id === selectedId}
          aria-controls={`panel-${tab.id}`}
          tabIndex={tab.id === focusedId ? 0 : -1}  // roving tabindex
          onClick={() => onSelect(tab.id)}
          onKeyDown={(e) => handleKeyDown(e, tab.id)}
        >
          {tab.label}
        </button>
      ))}
    </div>
  )
}
```

---

## Live Regions (`aria-live`)

```typescript
// aria-live: announces dynamic content changes to screen readers
// polite — waits for user to finish current action
// assertive — interrupts immediately (use sparingly — only for errors/alerts)

// Announcement component
function LiveRegion({ message, politeness = 'polite' }: {
  message: string
  politeness?: 'polite' | 'assertive'
}) {
  return (
    <div
      role={politeness === 'assertive' ? 'alert' : 'status'}
      aria-live={politeness}
      aria-atomic="true"    // announce entire region, not just changed part
      className="sr-only"   // visually hidden but available to AT
    >
      {message}
    </div>
  )
}

// Usage — toast notifications
function useAnnouncement() {
  const [message, setMessage] = useState('')

  function announce(msg: string) {
    setMessage('')  // clear first to re-trigger announcement of same message
    setTimeout(() => setMessage(msg), 100)
  }

  return { message, announce }
}

// Form error — use assertive
<div role="alert" aria-live="assertive">
  {error && <p id="email-error">{error}</p>}
</div>

// Search results count — use polite
<div role="status" aria-live="polite">
  {`${resultCount} results found`}
</div>
```

---

## Color Contrast Requirements (WCAG 2.2)

```typescript
// WCAG AA: Normal text ≥ 4.5:1, Large text (18pt/14pt bold) ≥ 3:1
// WCAG AAA: Normal text ≥ 7:1, Large text ≥ 4.5:1
// UI components / graphical objects: ≥ 3:1 against adjacent colors

// Tailwind — safe combinations (approximate — always verify with a contrast checker)
// bg-white (white) + text-gray-700 (#374151) → 12.6:1 ✓ AAA
// bg-blue-600 (#2563EB) + text-white → 4.6:1 ✓ AA
// bg-gray-100 + text-gray-500 → ~4.6:1 ✓ AA (check your specific shades)

// FAIL examples:
// bg-gray-100 + text-gray-400 → ~2.9:1 ✗
// bg-yellow-400 + text-white → ~1.9:1 ✗

// Don't rely on color alone for meaning
function StatusBadge({ status }: { status: 'success' | 'error' | 'pending' }) {
  const config = {
    success: { label: 'Success', icon: '✓', className: 'bg-green-100 text-green-800' },
    error: { label: 'Error', icon: '✕', className: 'bg-red-100 text-red-800' },
    pending: { label: 'Pending', icon: '○', className: 'bg-yellow-100 text-yellow-800' },
  }[status]

  return (
    <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${config.className}`}>
      <span aria-hidden="true">{config.icon}</span>
      {config.label}
    </span>
  )
}

// Focus visible — never remove outline without replacement
// ✗ Bad: outline-none with no replacement
// ✓ Good: use focus-visible: with custom ring
<button className="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2">
  Submit
</button>
```

---

## Form Accessibility

```typescript
// Accessible form component with react-hook-form
import { useForm } from 'react-hook-form'

function AccessibleForm() {
  const { register, handleSubmit, formState: { errors } } = useForm()

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      {/* Field group */}
      <div>
        {/* Explicit label association */}
        <label htmlFor="email" className="block text-sm font-medium text-gray-700">
          Email address
          <span aria-hidden="true" className="text-red-500 ml-1">*</span>
        </label>

        <input
          id="email"
          type="email"
          autoComplete="email"
          aria-required="true"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : 'email-hint'}
          {...register('email', { required: 'Email is required', pattern: { value: /\S+@\S+\.\S+/, message: 'Invalid email' } })}
          className="mt-1 block w-full rounded-md border-gray-300 focus:border-blue-500 focus:ring-blue-500"
        />

        <p id="email-hint" className="mt-1 text-sm text-gray-500">
          We'll send a confirmation link to this address.
        </p>

        {errors.email && (
          <p id="email-error" role="alert" className="mt-1 text-sm text-red-600">
            {String(errors.email.message)}
          </p>
        )}
      </div>

      {/* Fieldset for related checkboxes/radios */}
      <fieldset>
        <legend className="text-sm font-medium text-gray-700">
          Notification preferences
        </legend>
        <div className="mt-2 space-y-2">
          <label className="flex items-center gap-2">
            <input type="checkbox" {...register('emailNotifs')} />
            Email notifications
          </label>
          <label className="flex items-center gap-2">
            <input type="checkbox" {...register('smsNotifs')} />
            SMS notifications
          </label>
        </div>
      </fieldset>

      <button type="submit">
        Create account
        <span className="sr-only">(required fields marked with asterisk)</span>
      </button>
    </form>
  )
}
```

---

## Testing with axe-core

```bash
npm install --save-dev @axe-core/react axe-core
```

```typescript
// Development-only automatic scanning
// app/axe.tsx  — only load in development
if (typeof window !== 'undefined' && process.env.NODE_ENV !== 'production') {
  import('@axe-core/react').then(({ default: axe }) => {
    import('react-dom').then(({ default: ReactDOM }) => {
      axe(React, ReactDOM, 1000)  // scan 1 second after render
    })
  })
}

// jest-axe for unit tests
import { axe, toHaveNoViolations } from 'jest-axe'
import { render } from '@testing-library/react'
expect.extend(toHaveNoViolations)

test('Button has no accessibility violations', async () => {
  const { container } = render(<Button>Click me</Button>)
  const results = await axe(container)
  expect(results).toHaveNoViolations()
})

// Playwright for integration testing
import { checkA11y } from 'axe-playwright'

test('Home page is accessible', async ({ page }) => {
  await page.goto('/')
  await checkA11y(page, undefined, {
    detailedReport: true,
    detailedReportOptions: { html: true },
  })
})
```

---

## Common WCAG Violations to Avoid

```typescript
// 1. ✗ Images without alt text
<img src="/product.jpg" />                    // missing alt
<img src="/product.jpg" alt="Product photo" /> // ✓ descriptive
<img src="/decorative.jpg" alt="" />           // ✓ empty alt for decorative

// 2. ✗ Links/buttons without accessible names
<a href="/about"><img src="/logo.png" /></a>                          // no alt
<a href="/about"><img src="/logo.png" alt="Go to About page" /></a>   // ✓

// 3. ✗ Click handlers on non-interactive elements
<div onClick={handleClick}>Click me</div>     // no keyboard access, no role
<button onClick={handleClick}>Click me</button>  // ✓

// 4. ✗ Removing focus indicators
.button { outline: none; }                    // breaks keyboard navigation
// ✓ Use :focus-visible instead of removing entirely

// 5. ✗ Using color alone to convey meaning
<span style={{ color: 'red' }}>Error</span>  // color-blind users miss it
<span><ErrorIcon /> Error: Invalid email</span>  // ✓ icon + text

// 6. ✗ Auto-playing media
<video autoPlay src="..." />
<video autoPlay muted src="..." controls />  // ✓ muted + controls to pause

// 7. ✗ Insufficient touch target size (WCAG 2.5.8 — AA in 2.2)
// Minimum 24×24px, recommended 44×44px
<button className="p-1">  // likely too small
<button className="min-h-[44px] min-w-[44px] p-3">  // ✓

// 8. ✗ Placeholder as label
<input placeholder="Email address" />  // placeholder disappears on input
<label htmlFor="email">Email address</label>   // ✓ always visible
<input id="email" placeholder="name@example.com" />
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ui-ux/a11y-wcag/.gitnexus
Last indexed: 2026-05-23
