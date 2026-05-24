---
name: jotai
version: 1.0.0
description: Atomic React state management — composable, bottom-up, minimal re-renders
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, react, state-management, jotai, atomic, typescript]
author: claude-skill-vault
created: 2026-05-24
---

# Jotai — Atomic React State Management

## Overview
Jotai is a primitive, atomic state management library for React. State is broken into atoms — small, independent units that can be derived, combined, and composed. Components subscribe only to the atoms they read, eliminating unnecessary re-renders. It's inspired by Recoil but has no string keys, no Provider boilerplate for simple cases, and a much smaller bundle (~3KB).

## When to Use
- React apps where Context causes too many re-renders
- Fine-grained state subscriptions without Redux complexity
- Derived/computed state that depends on multiple sources
- Apps where state naturally decomposes into independent atoms
- As a lighter alternative to Recoil or Zustand for atomic patterns

## Installation / Setup

```bash
npm install jotai
```

## Key Patterns

### Basic Atom
```ts
import { atom, useAtom, useAtomValue, useSetAtom } from 'jotai';

// Define atoms at module level (not inside components)
export const countAtom = atom(0);
export const nameAtom = atom('');

function Counter() {
  const [count, setCount] = useAtom(countAtom);
  return (
    <button onClick={() => setCount(c => c + 1)}>
      Count: {count}
    </button>
  );
}

// Read-only — no subscription to setter
function Display() {
  const count = useAtomValue(countAtom);
  return <span>{count}</span>;
}

// Write-only — no re-render on value change
function Reset() {
  const setCount = useSetAtom(countAtom);
  return <button onClick={() => setCount(0)}>Reset</button>;
}
```

### Derived (Read-Only) Atoms
```ts
import { atom } from 'jotai';

const priceAtom = atom(100);
const quantityAtom = atom(3);
const taxRateAtom = atom(0.08);

// Derived — recomputes automatically when dependencies change
const subtotalAtom = atom((get) => get(priceAtom) * get(quantityAtom));
const taxAtom = atom((get) => get(subtotalAtom) * get(taxRateAtom));
const totalAtom = atom((get) => get(subtotalAtom) + get(taxAtom));

function OrderSummary() {
  const subtotal = useAtomValue(subtotalAtom);
  const tax = useAtomValue(taxAtom);
  const total = useAtomValue(totalAtom);
  return (
    <div>
      <p>Subtotal: ${subtotal.toFixed(2)}</p>
      <p>Tax: ${tax.toFixed(2)}</p>
      <p>Total: ${total.toFixed(2)}</p>
    </div>
  );
}
```

### Read-Write Derived Atoms
```ts
import { atom } from 'jotai';

const celsiusAtom = atom(0);

// Two-way derived: read converts C→F, write converts F→C
const fahrenheitAtom = atom(
  (get) => get(celsiusAtom) * 9 / 5 + 32,
  (_get, set, fahrenheit: number) => {
    set(celsiusAtom, (fahrenheit - 32) * 5 / 9);
  }
);

function TempConverter() {
  const [celsius, setCelsius] = useAtom(celsiusAtom);
  const [fahrenheit, setFahrenheit] = useAtom(fahrenheitAtom);
  return (
    <div>
      <input type="number" value={celsius} onChange={e => setCelsius(+e.target.value)} />°C
      <input type="number" value={fahrenheit} onChange={e => setFahrenheit(+e.target.value)} />°F
    </div>
  );
}
```

### Async Atoms
```ts
import { atom, useAtom } from 'jotai';

const userIdAtom = atom(1);

// Async derived atom — suspends until resolved
const userAtom = atom(async (get) => {
  const id = get(userIdAtom);
  const res = await fetch(`/api/users/${id}`);
  return res.json() as Promise<User>;
});

// Use with Suspense
function UserProfile() {
  const [user] = useAtom(userAtom); // suspends while loading
  return <div>{user.name}</div>;
}

function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <UserProfile />
    </Suspense>
  );
}
```

### atomWithStorage (Persistence)
```ts
import { atomWithStorage } from 'jotai/utils';

// Persists to localStorage automatically
const themeAtom = atomWithStorage<'light' | 'dark'>('theme', 'light');
const sidebarOpenAtom = atomWithStorage('sidebar-open', true);

function ThemeToggle() {
  const [theme, setTheme] = useAtom(themeAtom);
  return (
    <button onClick={() => setTheme(t => t === 'light' ? 'dark' : 'light')}>
      {theme === 'light' ? 'Dark Mode' : 'Light Mode'}
    </button>
  );
}
```

### atomFamily (Dynamic Atoms)
```ts
import { atomFamily } from 'jotai/utils';

// Creates one atom per unique parameter
const todoAtomFamily = atomFamily((id: number) =>
  atom({ id, text: '', done: false })
);

function TodoItem({ id }: { id: number }) {
  const [todo, setTodo] = useAtom(todoAtomFamily(id));
  return (
    <label>
      <input
        type="checkbox"
        checked={todo.done}
        onChange={e => setTodo(t => ({ ...t, done: e.target.checked }))}
      />
      {todo.text}
    </label>
  );
}
```

### Accessing Atoms Outside React
```ts
import { createStore } from 'jotai';

const store = createStore();

// Set/get outside React
store.set(countAtom, 42);
const count = store.get(countAtom);

// Subscribe to changes
const unsub = store.sub(countAtom, () => {
  console.log('count changed:', store.get(countAtom));
});

// Provide store to React tree (optional — only needed for custom stores)
import { Provider } from 'jotai';
<Provider store={store}><App /></Provider>
```

## Common Pitfalls
- **Defining atoms inside components**: atoms must be module-level constants — defining inside a component creates a new atom on every render
- **Async atoms need Suspense**: if you use async atoms without a `<Suspense>` boundary, React throws during render
- **atomFamily identity**: same parameter values must be referentially stable — use primitives (string/number) as family params, not objects
- **No built-in devtools**: use `jotai-devtools` package for atom inspection (separate install)
- **`useAtomValue` vs `useAtom`**: prefer `useAtomValue` for read-only access — it avoids subscribing to the setter, which is a minor perf win

## Related Skills
- `zustand` — store-based alternative; better for deeply nested or action-heavy state
- `xstate-v5` — state machines for complex behavioral state
- `react-best-practices` — React fundamentals
- `tanstack-router` — routing that pairs well with atomic state

## GitNexus Index
```
domain: frontend/web
tier: library
runtime: browser,node
language: ts,tsx
framework: react
purpose: state-management
```
