---
name: tanstack-form
version: 1.0.0
description: Headless, type-safe form library with first-class async validation
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, react, forms, tanstack, typescript, validation]
author: claude-skill-vault
created: 2026-05-24
---

# TanStack Form — Headless Type-Safe Forms

## Overview
TanStack Form is a headless, framework-agnostic form library with first-class TypeScript support, fine-grained reactivity, and built-in async validation. Unlike React Hook Form, it uses a subscription-based model where only fields that change re-render. It supports React, Vue, Solid, Angular, and Svelte adapters.

## When to Use
- Complex multi-step forms with interdependent validation
- Forms needing async validation (username availability, email checks)
- Replacing React Hook Form when you want finer control over subscriptions
- Framework-agnostic form logic shared across React + Solid apps
- Forms where TypeScript inference of field names/values is critical

## Installation / Setup

```bash
npm install @tanstack/react-form
# Optional validators:
npm install @tanstack/zod-form-adapter zod
npm install @tanstack/valibot-form-adapter valibot
```

## Key Patterns

### Basic Form
```tsx
import { useForm } from '@tanstack/react-form';
import { zodValidator } from '@tanstack/zod-form-adapter';
import { z } from 'zod';

function SignupForm() {
  const form = useForm({
    defaultValues: {
      email: '',
      password: '',
      username: '',
    },
    onSubmit: async ({ value }) => {
      // value is fully typed: { email: string; password: string; username: string }
      await createUser(value);
    },
    validatorAdapter: zodValidator(),
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        form.handleSubmit();
      }}
    >
      <form.Field
        name="email"
        validators={{ onChange: z.string().email('Invalid email') }}
      >
        {(field) => (
          <div>
            <input
              value={field.state.value}
              onChange={(e) => field.handleChange(e.target.value)}
              onBlur={field.handleBlur}
            />
            {field.state.meta.errors.map(e => (
              <p key={e} className="text-red-500">{e}</p>
            ))}
          </div>
        )}
      </form.Field>

      <form.Subscribe selector={s => s.canSubmit}>
        {(canSubmit) => (
          <button type="submit" disabled={!canSubmit}>Sign Up</button>
        )}
      </form.Subscribe>
    </form>
  );
}
```

### Async Validation
```tsx
const form = useForm({
  defaultValues: { username: '' },
  onSubmit: async ({ value }) => { await register(value); },
});

<form.Field
  name="username"
  validators={{
    onChange: ({ value }) =>
      value.length < 3 ? 'Too short' : undefined,
    onChangeAsync: async ({ value }) => {
      // Only runs after onChange passes
      const taken = await checkUsername(value);
      return taken ? 'Username taken' : undefined;
    },
    onChangeAsyncDebounceMs: 500, // debounce async checks
  }}
>
  {(field) => (
    <div>
      <input
        value={field.state.value}
        onChange={(e) => field.handleChange(e.target.value)}
      />
      {field.state.meta.isValidating && <span>Checking...</span>}
      {field.state.meta.errors.length > 0 && (
        <p>{field.state.meta.errors[0]}</p>
      )}
    </div>
  )}
</form.Field>
```

### Array Fields (Dynamic Lists)
```tsx
const form = useForm({
  defaultValues: { emails: [{ value: '' }] },
  onSubmit: async ({ value }) => { console.log(value.emails); },
});

<form.Field name="emails" mode="array">
  {(arrayField) => (
    <div>
      {arrayField.state.value.map((_, i) => (
        <form.Field key={i} name={`emails[${i}].value`}>
          {(field) => (
            <input
              value={field.state.value}
              onChange={(e) => field.handleChange(e.target.value)}
            />
          )}
        </form.Field>
      ))}
      <button
        type="button"
        onClick={() => arrayField.pushValue({ value: '' })}
      >
        Add Email
      </button>
    </div>
  )}
</form.Field>
```

### Form-Level Validation (Cross-Field)
```tsx
const form = useForm({
  defaultValues: { password: '', confirmPassword: '' },
  validators: {
    onChange: ({ value }) => {
      if (value.password !== value.confirmPassword) {
        return 'Passwords do not match';
      }
    },
  },
  onSubmit: async ({ value }) => { await resetPassword(value); },
});

<form.Subscribe selector={s => s.errors}>
  {(errors) => errors.length > 0 && <p>{errors[0]}</p>}
</form.Subscribe>
```

### Subscription-Based Performance
```tsx
// Only re-renders when these specific values change
<form.Subscribe
  selector={(state) => ({
    isSubmitting: state.isSubmitting,
    isValid: state.isValid,
    isDirty: state.isDirty,
  })}
>
  {({ isSubmitting, isValid, isDirty }) => (
    <div>
      <button type="submit" disabled={!isValid || isSubmitting}>
        {isSubmitting ? 'Saving...' : 'Save'}
      </button>
      {isDirty && <span>Unsaved changes</span>}
    </div>
  )}
</form.Subscribe>
```

## Common Pitfalls
- **Field name is a string, not a type-checked path by default**: use `ValidateFields` from the type helpers for deeply nested field name checking
- **`onSubmit` only fires when all validators pass**: put cross-field validation in form-level validators, not submit handlers
- **Array field `mode="array"` is required**: without it, array mutations don't trigger reactivity correctly
- **Async validators can overlap**: use `onChangeAsyncDebounceMs` and check for cancellation if the component unmounts
- **`form.handleSubmit()` vs native submit**: always call `form.handleSubmit()` in the form's `onSubmit` handler, not directly from a button click

## Related Skills
- `tanstack-router` — pairs naturally in TanStack ecosystem apps
- `zod-expert` — schema validation adapter
- `form-generator-rhf-zod` — React Hook Form alternative
- `react-best-practices` — React fundamentals

## GitNexus Index
```
domain: frontend/web
tier: library
runtime: browser
language: tsx,ts
framework: react,vue,solid
purpose: forms
```
