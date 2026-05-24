---
name: turbopack
version: 1.0.0
description: Rust-based incremental bundler by Vercel — successor to webpack
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, bundler, turbopack, webpack, rust, performance, nextjs]
author: claude-skill-vault
created: 2026-05-24
---

# Turbopack — Rust-Based Incremental Bundler

## Overview
Turbopack is a Rust-based incremental bundler developed by Vercel (the webpack creator's successor project). It uses a demand-driven, incremental computation engine to rebuild only what changed. Integrated into Next.js 14+ dev mode; its stable release targets drop-in webpack replacement. It achieves significantly faster cold starts and HMR compared to webpack.

## When to Use
- Next.js 14+ projects (opt into Turbopack dev mode)
- Large apps where webpack HMR is slow (>5s)
- When webpack rebuild time is a developer productivity bottleneck
- Migrating from webpack in Next.js context

## Installation / Setup

```bash
# Already included in Next.js 14+
# Enable Turbopack in dev mode:
next dev --turbopack

# Or in package.json:
{
  "scripts": {
    "dev": "next dev --turbopack"
  }
}
```

### next.config.js (Turbopack Config)
```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Turbopack config (experimental, Next.js 14+)
  experimental: {
    turbo: {
      rules: {
        // Custom file transforms
        '*.svg': {
          loaders: ['@svgr/webpack'],
          as: '*.js',
        },
        '*.mdx': {
          loaders: ['@mdx-js/loader'],
          as: '*.tsx',
        },
      },
      resolveAlias: {
        // Module aliases (like webpack resolve.alias)
        '@': './src',
        'lodash': 'lodash-es',
      },
      resolveExtensions: ['.tsx', '.ts', '.jsx', '.js', '.mjs', '.cjs'],
    },
  },
};

module.exports = nextConfig;
```

## Key Patterns

### Checking Turbopack Status
```bash
# Verify Turbopack is active (shows in Next.js startup output)
next dev --turbopack
# Output: ▲ Next.js 14.x
#   - Local: http://localhost:3000
#   ✓ Starting Turbopack...
```

### Environment Variable Handling
```ts
// Turbopack handles NEXT_PUBLIC_ vars the same way webpack does
// No changes needed to existing env usage:
const apiUrl = process.env.NEXT_PUBLIC_API_URL;
const secret = process.env.MY_SECRET; // server-only

// .env.local (same as webpack)
NEXT_PUBLIC_API_URL=https://api.example.com
MY_SECRET=super-secret
```

### CSS & PostCSS (Unchanged API)
```css
/* globals.css — same as webpack, no changes */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

```ts
// postcss.config.js — same as webpack
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

### Custom Loaders (Turbopack Rules)
```js
// next.config.js
module.exports = {
  experimental: {
    turbo: {
      rules: {
        // Transform .yaml files to JS objects
        '*.yaml': {
          loaders: ['yaml-loader'],
          as: '*.js',
        },
        // Transform raw files
        '*.txt': {
          loaders: ['raw-loader'],
          as: '*.js',
        },
      },
    },
  },
};
```

### Module Aliasing & Path Mapping
```ts
// tsconfig.json paths (Turbopack respects these natively)
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"],
      "@lib/*": ["./src/lib/*"]
    }
  }
}
```

### Webpack Fallback (Turbopack Incompatibility)
```js
// If a specific webpack plugin isn't yet supported, fall back:
const nextConfig = {
  // Only use webpack config when NOT using Turbopack
  ...(process.env.TURBOPACK ? {} : {
    webpack(config) {
      config.plugins.push(new MyWebpackPlugin());
      return config;
    },
  }),
};
```

## Common Pitfalls
- **Not all webpack loaders are supported**: check `nextjs.org/docs/app/api-reference/turbopack` for compatibility; use the webpack fallback pattern for unsupported loaders
- **`webpack` config key is ignored under Turbopack**: configs in `webpack()` callback don't apply — use `experimental.turbo` instead
- **Production builds still use webpack** (as of 2025): Turbopack only replaces `next dev`, not `next build`
- **HMR boundary differences**: some edge cases in React fast-refresh differ from webpack; add explicit HMR accept callbacks if needed
- **Monorepo symlinks**: Turbopack follows symlinks differently; verify `transpilePackages` is configured for linked packages

## Related Skills
- `vite-plugin-dev` — Vite's plugin system (alternative bundler ecosystem)
- `biome` — linter/formatter that pairs well with fast bundlers
- `nextjs-fullstack-scaffold` — full Next.js app setup using Turbopack
- `monorepo-architect` — Turbopack in monorepo context

## GitNexus Index
```
domain: frontend/build-tools
tier: bundler
runtime: node,rust
language: ts,js
ecosystem: nextjs,webpack
status: dev-mode-stable
```
