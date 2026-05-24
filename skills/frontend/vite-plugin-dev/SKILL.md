---
name: vite-plugin-dev
version: 1.0.0
description: Authoring custom Vite plugins — transforms, virtual modules, HMR
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, vite, plugins, build-tools, bundler]
author: claude-skill-vault
created: 2026-05-24
---

# Vite Plugin Development

## Overview
Vite plugins extend the build pipeline using a Rollup-compatible plugin API plus Vite-specific hooks. Plugins can transform source files, inject virtual modules, manipulate HTML, implement Hot Module Replacement (HMR), and hook into the dev server. Most Vite plugins work in both dev (using esbuild) and build (using Rollup) modes.

## When to Use
- Need a custom file transform (MDX, YAML, GraphQL, binary assets)
- Injecting environment variables or generated code at build time
- Auto-importing files based on file-system conventions
- Custom HMR behavior for non-standard file types
- Wrapping an existing Rollup plugin for Vite compatibility

## Installation / Setup

```bash
# Publishing a plugin
npm init
npm install vite --save-dev

# Using a plugin
npm install -D vite-plugin-example
```

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import myPlugin from './plugins/my-plugin';

export default defineConfig({
  plugins: [myPlugin({ option: true })],
});
```

## Key Patterns

### Basic Plugin Structure
```ts
// plugins/my-plugin.ts
import type { Plugin } from 'vite';

interface MyPluginOptions {
  include?: string | RegExp;
  verbose?: boolean;
}

export function myPlugin(options: MyPluginOptions = {}): Plugin {
  const { include = /\.myext$/, verbose = false } = options;

  return {
    name: 'vite-plugin-my-plugin',   // required, shown in warnings
    enforce: 'pre',                   // 'pre' | 'post' — ordering relative to core plugins

    // --- Build hooks (also used in dev via Rollup compat) ---
    buildStart() {
      if (verbose) console.log('[my-plugin] Build starting');
    },

    resolveId(id) {
      // Return a custom id to "claim" this module
      if (id === 'virtual:my-data') return '\0virtual:my-data';
    },

    load(id) {
      // Provide module source for virtual modules
      if (id === '\0virtual:my-data') {
        return `export const data = ${JSON.stringify({ version: '1.0' })};`;
      }
    },

    transform(code, id) {
      // Transform file content
      if (!id.match(include)) return null; // null = pass through unchanged
      const transformed = code.replace('__VERSION__', '1.0.0');
      return { code: transformed, map: null };
    },

    generateBundle(options, bundle) {
      // Inspect/modify output bundle
      console.log('Bundle contains:', Object.keys(bundle));
    },
  };
}
```

### Vite-Specific Hooks
```ts
export function devServerPlugin(): Plugin {
  return {
    name: 'vite-plugin-dev-server',
    apply: 'serve', // only run in dev, not build

    configureServer(server) {
      // Add custom middleware
      server.middlewares.use('/api/health', (req, res) => {
        res.end(JSON.stringify({ status: 'ok' }));
      });

      // Hook into server restart
      return () => {
        server.httpServer?.once('listening', () => {
          console.log('[my-plugin] Dev server ready');
        });
      };
    },

    handleHotUpdate({ file, server, modules }) {
      // Custom HMR for non-standard files
      if (file.endsWith('.data.json')) {
        server.ws.send({ type: 'full-reload', path: '*' });
        return []; // skip default HMR handling
      }
    },

    transformIndexHtml(html) {
      // Inject into HTML
      return html.replace(
        '<head>',
        `<head><meta name="build-time" content="${Date.now()}">`
      );
    },
  };
}
```

### Virtual Modules Pattern
```ts
// Common pattern: virtual:plugin-name/config
export function configInjectorPlugin(): Plugin {
  const virtualModuleId = 'virtual:app-config';
  const resolvedId = '\0' + virtualModuleId;

  return {
    name: 'vite-plugin-config-injector',
    resolveId(id) {
      if (id === virtualModuleId) return resolvedId;
    },
    load(id) {
      if (id === resolvedId) {
        // Read config at build time and bundle it as a module
        const config = readConfigFile('app.config.json');
        return `export default ${JSON.stringify(config)};`;
      }
    },
  };
}

// Usage in app code:
// import config from 'virtual:app-config';
```

### Source Map Support
```ts
import MagicString from 'magic-string'; // npm install magic-string

export function transformWithSourceMap(): Plugin {
  return {
    name: 'transform-with-sourcemap',
    transform(code, id) {
      if (!id.endsWith('.ts')) return;

      const s = new MagicString(code);
      s.replace(/REPLACE_ME/g, 'replaced');

      return {
        code: s.toString(),
        map: s.generateMap({ hires: true }),
      };
    },
  };
}
```

### Plugin Ordering
```ts
export default defineConfig({
  plugins: [
    // enforce: 'pre' — runs before Vite core transforms
    preTransformPlugin(),
    // default — runs after pre, before post
    normalPlugin(),
    // enforce: 'post' — runs after Vite core (including alias, resolve)
    postTransformPlugin(),
  ],
});
```

## Common Pitfalls
- **Always prefix virtual module IDs with `\0`**: prevents other plugins from processing them
- **`apply` field for dev-only or build-only**: forgetting it runs dev-server hooks during build and crashes
- **`transform` returning `null` vs `undefined`**: both skip the transform — be explicit for readability
- **Source maps are required for good DX**: returning `map: null` breaks breakpoints in dev tools
- **Plugin order matters**: use `enforce: 'pre'` when your transform must run before JSX/TS compilation

## Related Skills
- `turbopack` — alternative bundler (Rust-based, Next.js)
- `biome` — linting/formatting tool that integrates with build tools
- `vite-plugin-dev` is used by: `astro`, `sveltekit`, `solidjs`, `qwik`, `nuxt3`

## GitNexus Index
```
domain: frontend/build-tools
tier: plugin
runtime: node
language: ts
ecosystem: vite,rollup
```
