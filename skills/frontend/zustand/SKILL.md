---
name: zustand
version: 1.0.0
description: Minimal React state management — bears, slices, middleware
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, react, state-management, zustand, typescript]
author: claude-skill-vault
created: 2026-05-24
---

# Zustand — Minimal React State Management

## Overview
Zustand is a small (~1KB), fast, and opinionated state management library for React. It uses a hook-based API with no providers, no reducers, and no boilerplate. State is stored outside React's tree and components subscribe to only what they need. Works with React, React Native, and Next.js (with SSR considerations).

## When to Use
- React apps needing global state simpler than Redux
- Replacing Context + useReducer for mid-size state trees
- React Native apps (no special setup needed)
- Next.js apps with careful SSR hydration handling
- Zustand is a good default for 80% of state management needs

## Installation / Setup

```bash
npm install zustand
```

## Key Patterns

### Basic Store
```ts
import { create } from 'zustand';

interface CounterState {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

export const useCounterStore = create<CounterState>()((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}));

// Usage: no Provider needed
function Counter() {
  const { count, increment } = useCounterStore();
  return <button onClick={increment}>Count: {count}</button>;
}
```

### Selective Subscriptions (Perf)
```tsx
// Only re-renders when count changes, NOT when increment changes
function Count() {
  const count = useCounterStore((state) => state.count);
  return <span>{count}</span>;
}

// Only re-renders when user.name changes (not other user fields)
const name = useUserStore((state) => state.user.name);
```

### Store Slices (Composing Large Stores)
```ts
import { create, StateCreator } from 'zustand';

interface BearSlice {
  bears: number;
  addBear: () => void;
}

interface FishSlice {
  fish: number;
  removeFish: () => void;
}

const createBearSlice: StateCreator<BearSlice & FishSlice, [], [], BearSlice> = (set) => ({
  bears: 0,
  addBear: () => set((state) => ({ bears: state.bears + 1 })),
});

const createFishSlice: StateCreator<BearSlice & FishSlice, [], [], FishSlice> = (set) => ({
  fish: 10,
  removeFish: () => set((state) => ({ fish: state.fish - 1 })),
});

export const useBoundStore = create<BearSlice & FishSlice>()((...args) => ({
  ...createBearSlice(...args),
  ...createFishSlice(...args),
}));
```

### Middleware: persist, devtools, immer
```ts
import { create } from 'zustand';
import { persist, devtools, createJSONStorage } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface CartItem { id: string; qty: number; }
interface CartState {
  items: CartItem[];
  addItem: (id: string) => void;
  removeItem: (id: string) => void;
}

export const useCartStore = create<CartState>()(
  devtools(
    persist(
      immer((set) => ({
        items: [],
        addItem: (id) => set((state) => {
          const item = state.items.find(i => i.id === id);
          if (item) item.qty++; // immer allows direct mutation
          else state.items.push({ id, qty: 1 });
        }),
        removeItem: (id) => set((state) => {
          state.items = state.items.filter(i => i.id !== id);
        }),
      })),
      {
        name: 'cart-storage',
        storage: createJSONStorage(() => localStorage),
        partialize: (state) => ({ items: state.items }), // only persist items
      }
    ),
    { name: 'CartStore' }
  )
);
```

### Async Actions
```ts
import { create } from 'zustand';

interface UserState {
  user: User | null;
  loading: boolean;
  error: string | null;
  fetchUser: (id: string) => Promise<void>;
}

export const useUserStore = create<UserState>()((set) => ({
  user: null,
  loading: false,
  error: null,
  fetchUser: async (id) => {
    set({ loading: true, error: null });
    try {
      const user = await api.getUser(id);
      set({ user, loading: false });
    } catch (err) {
      set({ error: String(err), loading: false });
    }
  },
}));
```

### Accessing Store Outside React
```ts
// Get state snapshot (not reactive)
const count = useCounterStore.getState().count;

// Subscribe to changes (returns unsubscribe)
const unsub = useCounterStore.subscribe(
  (state) => state.count,
  (count) => console.log('count changed:', count)
);

// Set state imperatively
useCounterStore.setState({ count: 42 });
```

## Common Pitfalls
- **Selecting objects/arrays without memoization re-renders on every state update**: use `useShallow` or a custom equality function: `useStore(selector, shallow)`
- **SSR with Next.js requires per-request stores**: don't create stores at module level for SSR — use a store factory pattern
- **`immer` middleware must wrap the store creator, not actions**: incorrect nesting breaks TypeScript types
- **persist middleware hydrates asynchronously**: check `useStore.persist.hasHydrated()` before rendering hydration-dependent UI
- **devtools middleware must be the outermost wrapper**: other middleware order can cause type issues

## Related Skills
- `jotai` — atomic alternative to Zustand
- `xstate-v5` — for complex state machines
- `react-best-practices` — React fundamentals
- `tanstack-router` — routing that pairs well with Zustand

## GitNexus Index
```
domain: frontend/web
tier: library
runtime: browser,node
language: ts,tsx
framework: react,react-native
purpose: state-management
```
