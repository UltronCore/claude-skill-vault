---
name: storybook-expert
description: >
  Storybook 8 for React component development, visual testing, and documentation. Triggers on: Storybook, .stories.tsx, Meta, StoryObj, args, argTypes, decorators, play function, MSW, Chromatic.
---

# Storybook 8 Expert

## When to Use

Use Storybook when building, documenting, or visually testing UI components in isolation. Each component gets a `.stories.tsx` file alongside it. Run `npx storybook dev` during development.

---

## Installation & Setup

```bash
npx storybook@latest init   # auto-detects framework (Next.js / React)
npm install -D @storybook/addon-essentials @storybook/addon-interactions @storybook/test
```

---

## Story File Setup (Meta + StoryObj)

```typescript
// components/ui/button/button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { Button } from './button'

// Meta — configures the component in Storybook
const meta: Meta<typeof Button> = {
  title: 'UI/Button',           // sidebar path: UI > Button
  component: Button,
  tags: ['autodocs'],           // auto-generate docs page
  parameters: {
    layout: 'centered',         // 'centered' | 'fullscreen' | 'padded'
  },
  argTypes: {
    variant: {
      control: { type: 'select' },
      options: ['default', 'destructive', 'outline', 'ghost'],
      description: 'Visual style of the button',
      table: {
        type: { summary: 'string' },
        defaultValue: { summary: 'default' },
      },
    },
    size: {
      control: { type: 'radio' },
      options: ['sm', 'md', 'lg'],
    },
    disabled: { control: 'boolean' },
    onClick: { action: 'clicked' },  // logs to Actions panel
  },
}

export default meta
type Story = StoryObj<typeof meta>

// Stories — each is a named export
export const Default: Story = {
  args: {
    children: 'Click me',
    variant: 'default',
    size: 'md',
  },
}

export const Destructive: Story = {
  args: {
    children: 'Delete account',
    variant: 'destructive',
  },
}

export const Disabled: Story = {
  args: {
    children: 'Unavailable',
    disabled: true,
  },
}

// Render override — full control when args aren't enough
export const IconButton: Story = {
  render: (args) => (
    <Button {...args}>
      <PlusIcon className="h-4 w-4 mr-2" />
      Add item
    </Button>
  ),
}

// Render multiple instances
export const AllVariants: Story = {
  render: () => (
    <div className="flex gap-3 flex-wrap">
      {['default', 'destructive', 'outline', 'ghost'].map(variant => (
        <Button key={variant} variant={variant as any}>
          {variant}
        </Button>
      ))}
    </div>
  ),
}
```

---

## Decorators (Providers, Themes, Layout)

```typescript
// .storybook/preview.tsx
import type { Preview } from '@storybook/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import '../app/globals.css'   // Tailwind CSS

const queryClient = new QueryClient()

const preview: Preview = {
  decorators: [
    // Global decorator — wraps every story
    (Story) => (
      <QueryClientProvider client={queryClient}>
        <Story />
      </QueryClientProvider>
    ),
  ],
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    backgrounds: {
      default: 'light',
      values: [
        { name: 'light', value: '#ffffff' },
        { name: 'dark', value: '#0f172a' },
        { name: 'gray', value: '#f1f5f9' },
      ],
    },
  },
}

export default preview

// Per-story decorators
export const DarkThemeButton: Story = {
  decorators: [
    (Story) => (
      <div className="dark bg-gray-900 p-8 rounded-xl">
        <Story />
      </div>
    ),
  ],
  args: { children: 'Dark mode button' },
}

// Decorator with router context (Next.js)
import { RouterContext } from 'next/dist/shared/lib/router-context.shared-runtime'

const preview: Preview = {
  decorators: [
    (Story) => (
      <RouterContext.Provider value={createMockRouter({})}>
        <Story />
      </RouterContext.Provider>
    ),
  ],
}
```

---

## Play Functions (Interaction Testing)

```typescript
// Play functions simulate user interactions and assert behavior
// Runs automatically in Storybook and in CI via @storybook/test-runner

import { expect, userEvent, within, waitFor } from '@storybook/test'

export const LoginFormSuccess: Story = {
  render: () => <LoginForm onSuccess={fn()} />,

  play: async ({ canvasElement, args }) => {
    const canvas = within(canvasElement)

    // Get elements
    const emailInput = canvas.getByLabelText('Email address')
    const passwordInput = canvas.getByLabelText('Password')
    const submitButton = canvas.getByRole('button', { name: 'Sign in' })

    // Simulate interactions
    await userEvent.clear(emailInput)
    await userEvent.type(emailInput, 'user@example.com', { delay: 50 })
    await userEvent.type(passwordInput, 'securepassword123')
    await userEvent.click(submitButton)

    // Assert outcomes
    await waitFor(() => {
      expect(canvas.getByText('Welcome back!')).toBeInTheDocument()
    })
  },
}

export const LoginFormValidationErrors: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const submitButton = canvas.getByRole('button', { name: 'Sign in' })

    // Submit empty form
    await userEvent.click(submitButton)

    // Check for validation errors
    expect(canvas.getByText('Email is required')).toBeInTheDocument()
    expect(canvas.getByText('Password is required')).toBeInTheDocument()

    // Verify focus is on the first error field
    expect(canvas.getByLabelText('Email address')).toHaveFocus()
  },
}

// Test keyboard navigation
export const DropdownKeyboardNav: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = canvas.getByRole('button', { name: 'Open menu' })

    await userEvent.click(trigger)
    expect(canvas.getByRole('menu')).toBeVisible()

    // Navigate with keyboard
    await userEvent.keyboard('{ArrowDown}')
    expect(canvas.getAllByRole('menuitem')[0]).toHaveFocus()

    await userEvent.keyboard('{ArrowDown}')
    expect(canvas.getAllByRole('menuitem')[1]).toHaveFocus()

    await userEvent.keyboard('{Escape}')
    expect(canvas.queryByRole('menu')).not.toBeInTheDocument()
    expect(trigger).toHaveFocus()  // focus restored
  },
}
```

---

## MSW (Mock Service Worker) for API Mocking

```bash
npm install -D msw msw-storybook-addon
npx msw init public/                  # creates public/mockServiceWorker.js
```

```typescript
// .storybook/preview.tsx
import { initialize, mswLoader } from 'msw-storybook-addon'

initialize()   // start MSW

const preview: Preview = {
  loaders: [mswLoader],
  // ...
}

// In stories — define handlers per story
import { http, HttpResponse } from 'msw'

export const UserListLoaded: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', () => {
          return HttpResponse.json([
            { id: '1', name: 'Example User', email: 'user@example.com', role: 'admin' },
            { id: '2', name: 'Jane Smith', email: 'jane@example.com', role: 'user' },
          ])
        }),
      ],
    },
  },
}

export const UserListEmpty: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', () => HttpResponse.json([])),
      ],
    },
  },
}

export const UserListError: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', () =>
          HttpResponse.json({ error: 'Internal Server Error' }, { status: 500 })
        ),
      ],
    },
  },
}

export const UserListLoading: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', async () => {
          await new Promise(resolve => setTimeout(resolve, 2000))  // simulate delay
          return HttpResponse.json([])
        }),
      ],
    },
  },
}
```

---

## Tailwind + shadcn/ui Integration

```typescript
// .storybook/main.ts
import type { StorybookConfig } from '@storybook/nextjs'
import path from 'path'

const config: StorybookConfig = {
  stories: ['../components/**/*.stories.@(ts|tsx)', '../app/**/*.stories.@(ts|tsx)'],
  addons: [
    '@storybook/addon-essentials',
    '@storybook/addon-interactions',
    {
      name: '@storybook/addon-styling-webpack',
      options: {
        rules: [{
          test: /\.css$/,
          sideEffects: true,
          use: [
            'style-loader',
            { loader: 'css-loader', options: { importLoaders: 1 } },
            { loader: 'postcss-loader', options: { implementation: require('postcss') } },
          ],
        }],
      },
    },
  ],
  framework: { name: '@storybook/nextjs', options: {} },
  docs: { autodocs: 'tag' },
  staticDirs: ['../public'],
}

export default config

// .storybook/preview.tsx
import '../app/globals.css'  // imports Tailwind base styles

// shadcn/ui components work out of the box since they use cn() utility
// Example story:
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export const ProductCard: Story = {
  render: () => (
    <Card className="w-80">
      <CardHeader>
        <CardTitle>Pro Plan</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-bold">$29/mo</p>
      </CardContent>
    </Card>
  ),
}
```

---

## Chromatic Visual Testing

```bash
npm install --save-dev chromatic
npx chromatic --project-token=YOUR_TOKEN  # first run
```

```yaml
# .github/workflows/chromatic.yml
name: Chromatic

on: push

jobs:
  chromatic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # required for TurboSnap (only test changed stories)

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - run: npm ci

      - name: Run Chromatic
        uses: chromaui/action@latest
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
          onlyChanged: true  # TurboSnap — only stories affected by code changes
```

```typescript
// Mark stories to skip visual testing (e.g., animations)
export const AnimatedLoader: Story = {
  parameters: {
    chromatic: { disableSnapshot: true },
  },
}

// Test specific viewport sizes
export const MobileCard: Story = {
  parameters: {
    chromatic: { viewports: [320, 375, 428] },
    viewport: { defaultViewport: 'mobile1' },
  },
}
```

---

## Autodocs

```typescript
// tags: ['autodocs'] on Meta enables auto-generated docs page
// Add JSDoc comments to your component for richer docs

/**
 * Primary button for user interactions.
 * Supports multiple visual variants and sizes.
 * Always use `aria-label` for icon-only buttons.
 */
export function Button({ variant = 'default', size = 'md', children, ...props }: ButtonProps) {
  // ...
}

// Component-level parameter for docs
const meta: Meta<typeof Button> = {
  component: Button,
  tags: ['autodocs'],
  parameters: {
    docs: {
      description: {
        component: 'Use `Button` for all primary actions. Prefer semantic HTML — only use `asChild` when wrapping links.',
      },
    },
  },
}
```

---

## Component-Driven Development Workflow

```
1. Create component file:    components/ui/card/card.tsx
2. Create story file:        components/ui/card/card.stories.tsx
3. Run Storybook:            npm run storybook
4. Build in isolation:       iterate on args/variants without a full page
5. Write play functions:     test interactions in the browser
6. Add MSW handlers:         mock all API states (loading, success, error, empty)
7. Run test-runner:          npx test-storybook (CI)
8. Push to GitHub:           Chromatic runs visual diff automatically
9. Integrate into page:      copy from Storybook into real page — already battle-tested
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ui-ux/storybook-expert/.gitnexus
Last indexed: 2026-05-23
