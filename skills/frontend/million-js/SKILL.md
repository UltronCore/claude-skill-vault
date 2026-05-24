---
name: million-js
version: 1.0.0
description: React performance optimization via virtual DOM replacement
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, react, performance, million, virtual-dom, optimization]
author: claude-skill-vault
created: 2026-05-24
---

# Million.js — React Virtual DOM Replacement

## Overview
Million.js optimizes React rendering by replacing React's virtual DOM diffing with a direct, fine-grained block-based DOM update mechanism. It can make React components up to 70% faster by bypassing reconciliation for static component shapes. Works as a drop-in optimization without rewriting your React code.

## When to Use
- Large data tables or lists that re-render frequently
- Dashboard components with many updating cells
- React apps where profiling shows reconciliation as the bottleneck
- Targeting 60fps on components with 50+ DOM nodes
- Existing React codebases that need perf gains without framework migration

## Installation / Setup

```bash
npm install million
# For Next.js:
npm install million
```

### Vite / webpack config
```ts
// vite.config.ts
import million from 'million/compiler';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [
    million.vite({ auto: true }), // auto mode wraps eligible components
    react(),
  ],
});
```

```js
// next.config.js
const million = require('million/compiler');

module.exports = million.next({
  enabled: true,
  auto: { rsc: true }, // enable for React Server Components
});
```

## Key Patterns

### block() — Manual Optimization
```tsx
import { block } from 'million/react';

// Wrap your component to use Million's block-based rendering
const HeavyRow = block(function HeavyRow({
  name, value, status
}: { name: string; value: number; status: 'ok' | 'error' }) {
  return (
    <tr>
      <td>{name}</td>
      <td>{value.toFixed(2)}</td>
      <td class={status === 'ok' ? 'text-green-600' : 'text-red-600'}>{status}</td>
    </tr>
  );
});

// Use exactly like a normal React component
function DataTable({ rows }: { rows: Row[] }) {
  return (
    <table>
      <tbody>
        {rows.map(row => <HeavyRow key={row.id} {...row} />)}
      </tbody>
    </table>
  );
}
```

### For — Optimized List Rendering
```tsx
import { For } from 'million/react';

function ProductList({ products }: { products: Product[] }) {
  return (
    <For each={products} memo>
      {(product) => (
        <div class="product-card">
          <img src={product.image} alt={product.name} />
          <h3>{product.name}</h3>
          <p>${product.price.toFixed(2)}</p>
        </div>
      )}
    </For>
  );
}
```

### Auto Mode (Compiler-Based)
```tsx
// With auto: true in the compiler config, Million.js automatically
// wraps eligible components. You write normal React:

function MetricCard({ label, value, delta }: MetricCardProps) {
  return (
    <div className="metric-card">
      <span className="label">{label}</span>
      <span className="value">{value}</span>
      <span className={delta >= 0 ? 'up' : 'down'}>{delta}%</span>
    </div>
  );
}

// Million compiler detects the stable shape and optimizes automatically
```

### Profiling to Identify Candidates
```tsx
// Use React DevTools Profiler to find components with:
// - High "render duration" (>16ms)
// - Many re-renders triggered by parent state
// - Large DOM subtrees (tables, lists)

// Then apply block() to those specific components
const OptimizedTable = block(function DataGrid({ rows }: { rows: Row[] }) {
  // Only wrap the costly component, not the whole page
  return <table>{rows.map(r => <tr key={r.id}><td>{r.value}</td></tr>)}</table>;
});
```

### Combining with React.memo
```tsx
import { block } from 'million/react';
import { memo } from 'react';

// million/react block already memoizes by prop equality,
// but you can still use React.memo for the wrapper
const Row = memo(block(function Row({ data }: { data: RowData }) {
  return <tr><td>{data.name}</td><td>{data.count}</td></tr>;
}));
```

## Common Pitfalls
- **Dynamic component shape breaks optimization**: if component structure changes based on props (conditional root elements, dynamic tag names), Million can't optimize it — it falls back to React automatically
- **Hooks with side effects inside blocks**: keep effects minimal; complex useEffect logic may not benefit and could cause confusion
- **Non-primitive props**: passing objects/arrays as props to block() components works, but changing object identity on every render defeats the optimization
- **Context updates still cause re-renders**: block() doesn't bypass context — use it for leaf components that receive data as props
- **Auto mode false positives**: the compiler may wrap components unnecessarily; use `// million-ignore` comment to opt out

## Related Skills
- `react-best-practices` — baseline React patterns
- `react-native-reanimated` — native-side animations (different perf domain)
- `core-web-vitals` — measuring the real-world impact
- `vite-plugin-dev` — compiler integration

## GitNexus Index
```
domain: frontend/web
tier: library
runtime: browser
language: tsx,ts
framework: react
purpose: performance-optimization
```
