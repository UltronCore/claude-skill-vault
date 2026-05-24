---
name: micro-frontend-architecture
description: Design and implement micro-frontend architectures using Module Federation, single-spa, or iframes. Covers team autonomy, routing, shared state, versioning, and deployment strategies.
version: 1.0.0
tags: [micro-frontend, module-federation, single-spa, webpack, architecture, frontend, monorepo]
---

# Micro-Frontend Architecture

## Overview

This skill covers designing and building micro-frontend systems where multiple independent teams own different parts of a web application. It addresses the three main approaches — Module Federation (webpack/rspack), single-spa, and server-side composition — with concrete patterns for routing, shared dependencies, cross-app communication, and deployment. Use when multiple teams need to deploy frontend features independently.

## When to Use

- Multiple product teams need to deploy frontend changes independently
- Migrating a legacy monolithic frontend incrementally to modern stack
- Different parts of the app need different frameworks (React + Vue + Angular)
- Teams want separate CI/CD pipelines and release cycles for frontend
- Scaling frontend development across 5+ teams

## Step-by-Step Workflow

### 1. Choose the Right Strategy

```
Single-SPA: Good for multi-framework coexistence, gradual migration
Module Federation: Best for shared React components, same-framework teams
Server Composition: Best performance, requires server-side rendering
Iframe: Strongest isolation, worst UX, avoid unless hard requirement

Decision matrix:
- Same framework, shared components → Module Federation
- Multi-framework migration → single-spa
- Performance critical, SSR → Server composition (Next.js, Astro)
- Complete isolation needed → Iframes (fallback only)
```

### 2. Module Federation Setup (Webpack 5)

**Shell app (host):**
```javascript
// shell/webpack.config.js
const { ModuleFederationPlugin } = require('webpack').container;

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: 'shell',
      remotes: {
        // Runtime URLs — can be swapped per environment
        cart: 'cart@http://localhost:3001/remoteEntry.js',
        checkout: 'checkout@http://localhost:3002/remoteEntry.js',
        profile: 'profile@http://localhost:3003/remoteEntry.js',
      },
      shared: {
        react: { singleton: true, requiredVersion: '^18.0.0' },
        'react-dom': { singleton: true, requiredVersion: '^18.0.0' },
        'react-router-dom': { singleton: true },
      },
    }),
  ],
};
```

**Remote app (cart team):**
```javascript
// cart/webpack.config.js
const { ModuleFederationPlugin } = require('webpack').container;

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: 'cart',
      filename: 'remoteEntry.js',
      exposes: {
        './CartWidget': './src/CartWidget',
        './CartPage': './src/pages/CartPage',
      },
      shared: {
        react: { singleton: true, requiredVersion: '^18.0.0' },
        'react-dom': { singleton: true, requiredVersion: '^18.0.0' },
      },
    }),
  ],
};
```

**Shell consuming a remote:**
```tsx
// shell/src/App.tsx
import React, { Suspense, lazy } from 'react';
import { Routes, Route } from 'react-router-dom';

// Dynamic import of remote module
const CartPage = lazy(() => import('cart/CartPage'));
const CheckoutPage = lazy(() => import('checkout/CheckoutPage'));

// Error boundary for each micro-frontend
class MicroFrontendErrorBoundary extends React.Component {
  state = { hasError: false };
  static getDerivedStateFromError() { return { hasError: true }; }
  render() {
    if (this.state.hasError) return <div>Feature temporarily unavailable</div>;
    return this.props.children;
  }
}

export default function App() {
  return (
    <Routes>
      <Route path="/cart" element={
        <MicroFrontendErrorBoundary>
          <Suspense fallback={<Loading />}>
            <CartPage />
          </Suspense>
        </MicroFrontendErrorBoundary>
      } />
      <Route path="/checkout/*" element={
        <MicroFrontendErrorBoundary>
          <Suspense fallback={<Loading />}>
            <CheckoutPage />
          </Suspense>
        </MicroFrontendErrorBoundary>
      } />
    </Routes>
  );
}
```

### 3. Dynamic Remote URLs (Environment-Based)
```javascript
// shell/src/bootstrap.js — Load remotes dynamically
async function loadRemote(scope, module) {
  // Get URL from config service or env vars
  const url = await getRemoteUrl(scope);
  
  await __webpack_init_sharing__('default');
  const container = window[scope];
  
  if (!container) {
    // Load the script dynamically
    await new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = url;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }
  
  await window[scope].init(__webpack_share_scopes__.default);
  const factory = await window[scope].get(module);
  return factory();
}

// Usage: const { default: CartPage } = await loadRemote('cart', './CartPage');
```

### 4. Cross-App Communication
```typescript
// shared/event-bus.ts — Pub/sub without coupling
type EventHandler<T> = (payload: T) => void;

class EventBus {
  private handlers = new Map<string, Set<EventHandler<any>>>();
  
  emit<T>(event: string, payload: T): void {
    this.handlers.get(event)?.forEach(h => {
      try { h(payload); }
      catch (e) { console.error(`EventBus handler error for ${event}:`, e); }
    });
  }
  
  on<T>(event: string, handler: EventHandler<T>): () => void {
    if (!this.handlers.has(event)) this.handlers.set(event, new Set());
    this.handlers.get(event)!.add(handler);
    return () => this.handlers.get(event)?.delete(handler); // Returns unsubscribe fn
  }
}

// Expose on window for cross-bundle access
(window as any).__MFE_EVENT_BUS__ = (window as any).__MFE_EVENT_BUS__ || new EventBus();
export const eventBus = (window as any).__MFE_EVENT_BUS__ as EventBus;

// Usage in cart micro-frontend:
eventBus.emit('cart:item-added', { productId: 'p1', quantity: 1 });

// Usage in shell/header:
const unsubscribe = eventBus.on('cart:item-added', ({ quantity }) => {
  updateCartBadge(quantity);
});
```

### 5. Shared Auth State
```typescript
// shared-auth/src/index.ts — Singleton auth store
interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
}

class AuthStore {
  private state: AuthState = { user: null, token: null, isAuthenticated: false };
  private listeners = new Set<(state: AuthState) => void>();
  
  getState() { return this.state; }
  
  setUser(user: User, token: string) {
    this.state = { user, token, isAuthenticated: true };
    this.notify();
  }
  
  logout() {
    this.state = { user: null, token: null, isAuthenticated: false };
    localStorage.removeItem('auth_token');
    this.notify();
  }
  
  subscribe(listener: (state: AuthState) => void) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
  
  private notify() {
    this.listeners.forEach(l => l(this.state));
  }
}

// Shared as singleton via Module Federation
export const authStore = new AuthStore();
```

### 6. Deployment Strategy
```yaml
# Each MFE deploys independently to CDN
# Shell references remotes by environment variable

# cart-service CI/CD:
- name: Build cart MFE
  run: |
    npm run build
    aws s3 sync dist/ s3://mfe-assets/cart/${{ github.sha }}/
    
- name: Update CDN URL registry
  run: |
    aws dynamodb put-item --table-name mfe-registry \
      --item '{"name": {"S": "cart"}, "url": {"S": "https://cdn.example.com/cart/${{ github.sha }}/remoteEntry.js"}}'

# Shell reads URL registry at runtime (not build time)
```

## Key Commands Reference

```bash
# Create Vite + Module Federation (Rspack)
npm create rsbuild@latest my-mfe -- --template react-ts

# Module Federation with Vite
npm install @originjs/vite-plugin-federation

# single-spa CLI
npm install -g create-single-spa
create-single-spa --moduleType root-config  # Shell
create-single-spa --moduleType app-parcel   # Each micro-frontend

# Inspect federated modules
npx @module-federation/inspector  # Visual dependency explorer

# Check version conflicts
npx webpack-bundle-analyzer dist/stats.json
```

## Common Patterns

### Pattern 1: Shared Component Library
```javascript
// design-system/webpack.config.js — Expose shared components
exposes: {
  './Button': './src/components/Button',
  './Modal': './src/components/Modal',
  './tokens': './src/design-tokens',
},
shared: {
  react: { singleton: true },
}

// Consumed in any MFE:
import Button from 'design-system/Button';
```

### Pattern 2: Version Contract Testing
```typescript
// In each remote — define what it exposes (contract)
// __tests__/contract.test.ts
import { render } from '@testing-library/react';

describe('Cart MFE Contract', () => {
  it('exports CartWidget with required props', async () => {
    const { default: CartWidget } = await import('./src/CartWidget');
    const { container } = render(<CartWidget userId="u1" onCheckout={jest.fn()} />);
    expect(container.firstChild).toBeTruthy();
  });
});
```

### Pattern 3: Gradual Migration from Monolith
```javascript
// In legacy jQuery monolith — mount React MFE in a div
import('new-checkout/CheckoutApp').then(({ default: CheckoutApp }) => {
  const root = ReactDOM.createRoot(document.getElementById('checkout-root'));
  root.render(<CheckoutApp legacyCart={window.legacyCartData} />);
});
```

## Pitfalls to Avoid

1. **Multiple React instances**: Without `singleton: true` in shared config, each MFE bundles its own React. React hooks will fail with "invalid hook call" errors across bundle boundaries. Always mark framework packages as singletons with version ranges, and verify with the React DevTools profiler.

2. **Over-splitting**: Micro-frontends add build, deploy, and runtime complexity. Teams of fewer than 3-4 developers per app rarely benefit. The overhead (shared deps, event contracts, independent deployments) only pays off at organizational scale. Start as a monorepo with clear module boundaries first.

3. **Shared mutable global state**: Window-level stores are convenient but dangerous. Multiple MFEs writing to the same global store creates race conditions. Use an event bus for communication (fire and forget) and keep state ownership within the team that owns that domain.

## Related Skills

- `module-federation` — Deep dive into Webpack Module Federation config
- `design-tokens` — Sharing design tokens across micro-frontends
- `monorepo-architect` — Managing multiple MFE packages in one repo
- `micro-frontend-architecture` — This skill

## GitNexus Index

```json
{
  "skill": "micro-frontend-architecture",
  "category": "frontend",
  "triggers": ["micro-frontend", "microfrontend", "module federation", "single-spa", "mfe", "independent deployment frontend"],
  "outputs": ["shell app config", "remote config", "event bus", "deployment strategy"],
  "complexity": "high",
  "tools": ["webpack", "rspack", "vite", "single-spa", "module-federation"]
}
```
