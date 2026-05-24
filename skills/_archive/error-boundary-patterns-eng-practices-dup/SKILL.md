---
name: error-boundary-patterns
description: Build resilient React and Next.js UIs with error boundaries, suspense fallbacks, and structured error recovery flows. Covers class-based boundaries, react-error-boundary library, per-route boundaries, async error handling, and error reporting to Sentry.
version: 1.0.0
tags: [react, error-boundary, suspense, next.js, resilience, sentry, error-handling, ui, react-error-boundary]
---

# Error Boundary Patterns

## Overview

Error boundaries are React components that catch JavaScript errors in their child component tree and display fallback UI instead of crashing the entire application. Combined with Suspense for loading states, they form the primary resilience layer for React applications. Without them, a single unhandled render error takes down the entire page — with them, the impact is scoped to the boundary.

## When to Use

- Any production React application where component errors must not crash the entire page
- Route-level boundaries to limit blast radius to a single page
- Widget or section boundaries for independently-failing UI panels
- Async data-fetching components wrapped in Suspense + error boundary
- Error reporting pipelines that send errors to Sentry with component context
- Third-party embedded components that could throw unpredictably

## Step-by-Step Workflow

### 1. Class-Based Error Boundary (Foundation)

```tsx
// components/ErrorBoundary.tsx
import React, { Component, ReactNode, ErrorInfo } from "react";

interface Props {
  children: ReactNode;
  fallback?: ReactNode | ((error: Error, reset: () => void) => ReactNode);
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Report to error tracking before showing fallback
    this.props.onError?.(error, errorInfo);
    console.error("Caught by ErrorBoundary:", error, errorInfo);
  }

  reset = () => {
    this.setState({ error: null });
  };

  render() {
    if (this.state.error) {
      const { fallback } = this.props;
      if (typeof fallback === "function") {
        return fallback(this.state.error, this.reset);
      }
      return fallback ?? <DefaultErrorFallback error={this.state.error} onReset={this.reset} />;
    }
    return this.props.children;
  }
}

function DefaultErrorFallback({ error, onReset }: { error: Error; onReset: () => void }) {
  return (
    <div role="alert" className="p-4 border border-red-300 rounded-md bg-red-50">
      <h2 className="text-red-700 font-semibold">Something went wrong</h2>
      <p className="text-red-600 text-sm mt-1">{error.message}</p>
      <button
        onClick={onReset}
        className="mt-3 px-3 py-1.5 text-sm bg-red-600 text-white rounded hover:bg-red-700"
      >
        Try again
      </button>
    </div>
  );
}
```

### 2. react-error-boundary Library (Recommended)

```bash
npm install react-error-boundary
```

```tsx
// The react-error-boundary library handles the class component boilerplate
import { ErrorBoundary, useErrorBoundary } from "react-error-boundary";

// Basic usage with a fallback component
function OrdersSection() {
  return (
    <ErrorBoundary
      FallbackComponent={OrdersFallback}
      onError={(error, info) => {
        // Report to Sentry or other tracker
        Sentry.captureException(error, { extra: { componentStack: info.componentStack } });
      }}
      onReset={() => {
        // Optionally clear query cache on reset
        queryClient.invalidateQueries(["orders"]);
      }}
    >
      <OrderList />
    </ErrorBoundary>
  );
}

function OrdersFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div role="alert" className="rounded-lg bg-yellow-50 p-6 text-center">
      <AlertTriangle className="mx-auto h-8 w-8 text-yellow-500" />
      <h3 className="mt-2 font-medium text-yellow-800">Failed to load orders</h3>
      <p className="mt-1 text-sm text-yellow-700">{error.message}</p>
      <button onClick={resetErrorBoundary} className="mt-4 btn-secondary">
        Retry
      </button>
    </div>
  );
}

// Programmatic error throwing from async code
function OrderList() {
  const { showBoundary } = useErrorBoundary();

  const handleExport = async () => {
    try {
      await exportOrders();
    } catch (err) {
      // Trigger the nearest error boundary
      showBoundary(err);
    }
  };

  return <button onClick={handleExport}>Export</button>;
}
```

### 3. Suspense + Error Boundary Combo

```tsx
// The canonical pattern: Suspense for loading, ErrorBoundary for errors
import { Suspense } from "react";
import { ErrorBoundary } from "react-error-boundary";

// Async component using use() or a Suspense-compatible data fetcher
async function UserProfile({ userId }: { userId: string }) {
  // This throws a Promise (Suspense) or an Error (ErrorBoundary)
  const user = await fetchUser(userId);
  return <div>{user.name}</div>;
}

// Wrapper handles both loading and error states
function UserProfileSection({ userId }: { userId: string }) {
  return (
    <ErrorBoundary
      FallbackComponent={({ error, resetErrorBoundary }) => (
        <ErrorCard error={error} onRetry={resetErrorBoundary} />
      )}
    >
      <Suspense fallback={<UserProfileSkeleton />}>
        <UserProfile userId={userId} />
      </Suspense>
    </ErrorBoundary>
  );
}

// Skeleton fallback for Suspense
function UserProfileSkeleton() {
  return (
    <div className="animate-pulse space-y-3">
      <div className="h-12 w-12 rounded-full bg-gray-200" />
      <div className="h-4 w-32 rounded bg-gray-200" />
      <div className="h-3 w-48 rounded bg-gray-200" />
    </div>
  );
}
```

### 4. Next.js App Router Error Files

```tsx
// app/orders/error.tsx — Route segment error boundary (auto-wired by Next.js)
"use client"; // error.tsx must be a Client Component

import { useEffect } from "react";

export default function OrdersError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log to error reporting service
    reportError(error);
  }, [error]);

  return (
    <div className="min-h-[400px] flex items-center justify-center">
      <div className="text-center">
        <h2 className="text-xl font-semibold text-gray-900">Failed to load orders</h2>
        <p className="mt-2 text-gray-500">{error.message}</p>
        {error.digest && (
          <p className="mt-1 text-xs text-gray-400">Error ID: {error.digest}</p>
        )}
        <button
          onClick={reset}
          className="mt-4 rounded-md bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
        >
          Try again
        </button>
      </div>
    </div>
  );
}

// app/orders/loading.tsx — Auto-wired Suspense boundary
export default function OrdersLoading() {
  return (
    <div className="space-y-4 p-6">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="h-16 animate-pulse rounded-lg bg-gray-100" />
      ))}
    </div>
  );
}

// app/global-error.tsx — Catches errors in layout, not just page
"use client";
export default function GlobalError({ reset }: { reset: () => void }) {
  return (
    <html>
      <body>
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-center">
            <h1 className="text-2xl font-bold">Application Error</h1>
            <button onClick={reset} className="mt-4 btn-primary">
              Refresh
            </button>
          </div>
        </div>
      </body>
    </html>
  );
}
```

### 5. Sentry Integration with Error Boundaries

```tsx
// lib/error-reporting.ts
import * as Sentry from "@sentry/nextjs";

export function reportError(error: Error, context?: Record<string, unknown>) {
  Sentry.captureException(error, { extra: context });
}

// components/SentryErrorBoundary.tsx
import * as Sentry from "@sentry/nextjs";
import { ErrorBoundary } from "react-error-boundary";
import type { ComponentType, ReactNode } from "react";

interface Props {
  children: ReactNode;
  FallbackComponent: ComponentType<any>;
  context?: Record<string, string>;
}

export function SentryErrorBoundary({ children, FallbackComponent, context }: Props) {
  return (
    <ErrorBoundary
      FallbackComponent={FallbackComponent}
      onError={(error, info) => {
        Sentry.withScope((scope) => {
          scope.setExtras({ componentStack: info.componentStack, ...context });
          scope.setLevel("error");
          Sentry.captureException(error);
        });
      }}
    >
      {children}
    </ErrorBoundary>
  );
}

// Usage
function Dashboard() {
  return (
    <SentryErrorBoundary
      FallbackComponent={DashboardFallback}
      context={{ section: "dashboard", userId: currentUser.id }}
    >
      <DashboardContent />
    </SentryErrorBoundary>
  );
}
```

### 6. Custom Hook for Async Error Propagation

```tsx
// hooks/useAsyncWithBoundary.ts
// Bridges async errors into the error boundary system
import { useState, useCallback } from "react";
import { useErrorBoundary } from "react-error-boundary";

export function useAsyncWithBoundary<T extends unknown[], R>(
  asyncFn: (...args: T) => Promise<R>
) {
  const [loading, setLoading] = useState(false);
  const { showBoundary } = useErrorBoundary();

  const execute = useCallback(
    async (...args: T): Promise<R | undefined> => {
      setLoading(true);
      try {
        const result = await asyncFn(...args);
        return result;
      } catch (err) {
        // Route unexpected errors to the nearest error boundary
        showBoundary(err);
        return undefined;
      } finally {
        setLoading(false);
      }
    },
    [asyncFn, showBoundary]
  );

  return { execute, loading };
}

// Usage in a component
function PayButton({ orderId }: { orderId: string }) {
  const { execute, loading } = useAsyncWithBoundary(processPayment);

  return (
    <button onClick={() => execute(orderId)} disabled={loading}>
      {loading ? "Processing..." : "Pay Now"}
    </button>
  );
}
```

## Key Commands Reference

```bash
# Install react-error-boundary
npm install react-error-boundary

# Install Sentry for Next.js
npx @sentry/wizard@latest -i nextjs

# Install Sentry for React
npm install @sentry/react

# Storybook story for error boundary visual testing
# Create a story that throws on render
npm install --save-dev @storybook/addon-interactions

# Playwright test: verify error boundary renders
# await page.getByRole("alert").waitFor()
# await page.getByText("Something went wrong").isVisible()

# React DevTools: inspect error boundary state in browser
# Components panel → filter "ErrorBoundary" → see state.error
```

## Common Patterns

### Pattern 1: Per-Widget Boundaries for Dashboard Panels

```tsx
// Isolate each dashboard card — one failure doesn't kill the whole dashboard
function Dashboard() {
  return (
    <div className="grid grid-cols-2 gap-4 p-6">
      {panels.map((panel) => (
        <ErrorBoundary
          key={panel.id}
          FallbackComponent={({ error, resetErrorBoundary }) => (
            <PanelErrorCard title={panel.title} onRetry={resetErrorBoundary} />
          )}
        >
          <Suspense fallback={<PanelSkeleton />}>
            <panel.Component />
          </Suspense>
        </ErrorBoundary>
      ))}
    </div>
  );
}

function PanelErrorCard({ title, onRetry }: { title: string; onRetry: () => void }) {
  return (
    <div className="flex h-40 flex-col items-center justify-center rounded-lg border border-red-200 bg-red-50">
      <span className="text-sm text-red-600">{title} failed to load</span>
      <button onClick={onRetry} className="mt-2 text-xs text-red-500 underline">
        Retry
      </button>
    </div>
  );
}
```

### Pattern 2: Error Boundary + React Query Reset

```tsx
// When React Query is the data layer, reset query cache on boundary reset
import { QueryErrorResetBoundary } from "@tanstack/react-query";
import { ErrorBoundary } from "react-error-boundary";

function OrdersPage() {
  return (
    <QueryErrorResetBoundary>
      {({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          FallbackComponent={({ error, resetErrorBoundary }) => (
            <ErrorCard error={error} onRetry={resetErrorBoundary} />
          )}
        >
          <Suspense fallback={<OrdersSkeleton />}>
            <OrdersList />
          </Suspense>
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  );
}
```

### Pattern 3: resetKeys for Auto-Recovery

```tsx
// Automatically reset boundary when key data changes (e.g., user navigates to a new route)
import { useLocation } from "react-router-dom";

function AppRoutes() {
  const location = useLocation();

  return (
    <ErrorBoundary
      FallbackComponent={PageErrorFallback}
      // Reset the boundary on route change — clears stale error state
      resetKeys={[location.key]}
    >
      <Routes>
        <Route path="/orders" element={<OrdersPage />} />
        <Route path="/products" element={<ProductsPage />} />
      </Routes>
    </ErrorBoundary>
  );
}
```

## Pitfalls to Avoid

1. **One global error boundary for everything**: A single boundary at the app root means every error shows the same full-page failure. Instead, use layered boundaries: global (for true app-level crashes), route-level (Next.js error.tsx), and widget-level (individual panels or forms). The goal is minimum blast radius per error.

2. **Async errors not reaching boundaries**: Error boundaries only catch synchronous render errors and lifecycle errors. Async errors from `useEffect`, event handlers, or `setTimeout` must be explicitly thrown via `useErrorBoundary().showBoundary(err)` or stored in state and re-thrown during render. Never swallow async errors silently.

3. **Missing reset logic after user action**: If an error boundary resets but the underlying query or state still has bad data, the component will immediately throw again. Always reset the data source (invalidate query, clear Zustand slice, call `reset()` in React Query) in the `onReset` callback alongside the boundary reset.

## Related Skills

- `react-best-practices` — Component composition and performance patterns
- `streaming-llm-responses` — Handling streaming errors in AI chat UIs with boundaries
- `observability-engineer` — Correlating error boundary events with backend traces
- `react-query-tanstack` — QueryErrorResetBoundary integration for data-fetching errors

## GitNexus Index

```json
{
  "skill": "error-boundary-patterns",
  "category": "frontend",
  "triggers": ["error boundary", "react error boundary", "suspense fallback", "next.js error.tsx", "component error handling", "react crash recovery", "useErrorBoundary"],
  "outputs": ["ErrorBoundary component", "FallbackComponent", "error.tsx", "loading.tsx", "useAsyncWithBoundary hook"],
  "complexity": "medium",
  "tools": ["react", "react-error-boundary", "next.js", "sentry", "@tanstack/react-query", "typescript"]
}
```
