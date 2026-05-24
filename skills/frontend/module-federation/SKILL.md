---
name: module-federation
description: Implement Webpack Module Federation for micro-frontends: shared dependencies, dynamic remotes, version negotiation, and deployment strategies. Use when splitting a frontend monolith into independently deployable apps that share code at runtime.
---

# Module Federation

Webpack Module Federation (MF) is a plugin that lets multiple independently built and deployed JavaScript applications share code at runtime — without bundling everything together at build time. A "host" application loads "remote" modules from other apps dynamically, and both sides can declare shared dependencies (like React) so only one copy loads in the browser.

Module Federation solves the core micro-frontend problem: how do teams own their own deployment pipelines while still sharing a coherent UI? With MF, each team ships their own bundle to their own CDN or server, and the host discovers and loads their code dynamically. Shared singletons (React, design system) load once and are negotiated by version at runtime.

## When to Use

- Splitting a large frontend into independently deployable vertical slices (by team or domain)
- Sharing a component library between multiple apps without npm publish cycles
- Enabling teams to deploy their portion of the frontend independently
- Building a "shell" or "host" app that composes micro-frontends from multiple origins
- Exposing a set of components or utilities to other apps as a remote module
- Any question about `ModuleFederationPlugin`, `__webpack_share_scopes__`, or dynamic `import()` from remote containers

## Usage

### Host App (`webpack.config.js`)

```javascript
const { ModuleFederationPlugin } = require("webpack").container;

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "shell",
      remotes: {
        // Key = import alias, value = <remoteName>@<url>/remoteEntry.js
        checkout: "checkout@https://checkout.example.com/remoteEntry.js",
        catalog: "catalog@https://catalog.example.com/remoteEntry.js",
      },
      shared: {
        react: { singleton: true, requiredVersion: "^18.0.0" },
        "react-dom": { singleton: true, requiredVersion: "^18.0.0" },
      },
    }),
  ],
};
```

### Remote App (`webpack.config.js`)

```javascript
const { ModuleFederationPlugin } = require("webpack").container;

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "checkout",
      filename: "remoteEntry.js",     // entry point the host loads
      exposes: {
        "./CheckoutPage": "./src/CheckoutPage",
        "./CartWidget": "./src/CartWidget",
      },
      shared: {
        react: { singleton: true, requiredVersion: "^18.0.0" },
        "react-dom": { singleton: true, requiredVersion: "^18.0.0" },
      },
    }),
  ],
};
```

### Consuming a Remote in the Host

```typescript
// Host app — lazy import from remote (always async)
import React, { Suspense, lazy } from "react";

const CheckoutPage = lazy(() => import("checkout/CheckoutPage"));

export function App() {
  return (
    <Suspense fallback={<div>Loading checkout...</div>}>
      <CheckoutPage />
    </Suspense>
  );
}
```

TypeScript type declarations for remotes (add to `src/declarations.d.ts`):

```typescript
declare module "checkout/CheckoutPage" {
  const CheckoutPage: React.ComponentType;
  export default CheckoutPage;
}
```

### Dynamic Remote Loading (Runtime Discovery)

For URLs that aren't known at build time (e.g., feature flags, multi-tenant):

```typescript
async function loadRemote(scope: string, module: string, url: string) {
  // Inject the remote script dynamically
  await new Promise<void>((resolve, reject) => {
    const script = document.createElement("script");
    script.src = url;
    script.onload = () => resolve();
    script.onerror = reject;
    document.head.appendChild(script);
  });

  // Initialize the shared scope
  await __webpack_init_sharing__("default");
  const container = (window as any)[scope];
  await container.init(__webpack_share_scopes__.default);

  // Get the module factory
  const factory = await container.get(module);
  return factory();
}

// Usage
const { default: Component } = await loadRemote(
  "checkout",
  "./CheckoutPage",
  "https://checkout.example.com/remoteEntry.js"
);
```

### Vite / Rspack Alternative

For Vite-based projects use `@originjs/vite-plugin-federation`:

```typescript
// vite.config.ts (host)
import federation from "@originjs/vite-plugin-federation";

export default {
  plugins: [
    federation({
      name: "shell",
      remotes: { checkout: "https://checkout.example.com/assets/remoteEntry.js" },
      shared: ["react", "react-dom"],
    }),
  ],
  build: { target: "esnext" },
};
```

## Key Patterns

### Version Negotiation Strategy

Use `singleton: true` for shared libraries to prevent duplicate instances (especially React hooks). Use `strictVersion: false` with `requiredVersion` as a range to allow minor/patch upgrades without breaking:

```javascript
shared: {
  react: {
    singleton: true,
    strictVersion: false,       // don't throw on version mismatch
    requiredVersion: "^18.0.0",
    eager: false,               // async load (default — correct)
  },
}
```

### Eager Sharing Pitfall

Setting `eager: true` on a singleton causes the shared module to be included in the initial bundle, breaking the lazy load model. Only use `eager: true` in the host shell's bootstrap file, never in remotes.

### Bootstrap Indirection

Webpack MF requires the entry point to be async. Wrap your entry in a dynamic import:

```javascript
// src/index.js (entry point)
import("./bootstrap"); // <-- indirection required

// src/bootstrap.js
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
ReactDOM.createRoot(document.getElementById("root")!).render(<App />);
```

## Common Pitfalls

1. **Not wrapping the entry point in a dynamic import.** MF requires the share scope to initialize before any shared modules are imported. Skipping the `index.js` → `bootstrap.js` indirection causes "Shared module is not available for eager consumption" errors at runtime.

2. **Mismatched `name` between `ModuleFederationPlugin` config and the remote URL alias.** The `name` field in the remote's webpack config must exactly match the scope name used in the host's `remotes` map (e.g., `checkout@...` requires `name: "checkout"` in the remote). Mismatches cause silent 404s or `TypeError: container.get is not a function`.

3. **Over-sharing dependencies.** Adding every npm package to `shared` increases negotiation overhead and can cause subtle bugs when two packages share a singleton they weren't designed to. Only share packages that must be singletons (React, React-DOM, MobX, Redux store).

## Related Skills

- `micro-frontend-architecture` — higher-level strategy for splitting frontends by team/domain
- `monorepo-architect` — managing multiple MF apps in one repo with shared tooling
- `react-best-practices` — React patterns that work well inside federated modules
- `react-query-tanstack` — sharing data-fetching state across federated modules

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/module-federation/.gitnexus
Last indexed: 2026-05-24
