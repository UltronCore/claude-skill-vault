---
name: solidjs
version: 1.0.0
description: Fine-grained reactive UI library — no virtual DOM, surgical updates
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, solidjs, reactivity, performance, ui]
author: claude-skill-vault
created: 2026-05-24
---

# Solid.js — Fine-Grained Reactive UI

## Overview
Solid.js is a declarative UI library that uses fine-grained reactivity instead of a virtual DOM. Components compile away; only reactive primitives (signals, memos, effects) track and update the actual DOM nodes. Consistently benchmarks near the top of JS framework performance charts. SolidStart is its meta-framework for SSR/SSG.

## When to Use
- Performance-critical SPAs where React overhead is measurable
- Teams comfortable with React JSX syntax wanting better perf
- Real-time dashboards, games, large data tables
- Replacing React in projects where bundle size matters
- SolidStart for SSR full-stack apps

## Installation / Setup

```bash
# SPA (Vite)
npx degit solidjs/templates/ts my-app
cd my-app && npm install && npm run dev

# SolidStart (full-stack)
npm create solid@latest
```

## Key Patterns

### Signals — Reactive Primitives
```tsx
import { createSignal, createEffect, createMemo, on } from 'solid-js';

function Counter() {
  const [count, setCount] = createSignal(0);
  const doubled = createMemo(() => count() * 2);

  createEffect(() => {
    console.log('count changed to', count()); // auto-tracks count()
  });

  return (
    <div>
      <p>Count: {count()}</p>          {/* note: signals are called as functions */}
      <p>Doubled: {doubled()}</p>
      <button onClick={() => setCount(c => c + 1)}>Increment</button>
    </div>
  );
}
```

### Stores (Nested Reactive State)
```tsx
import { createStore, produce } from 'solid-js/store';

interface Todo { id: number; text: string; done: boolean; }

function TodoApp() {
  const [todos, setTodos] = createStore<Todo[]>([]);

  const addTodo = (text: string) => {
    setTodos(todos.length, { id: Date.now(), text, done: false });
  };

  const toggleTodo = (id: number) => {
    setTodos(
      t => t.id === id,
      produce(todo => { todo.done = !todo.done; })
    );
  };

  return (
    <ul>
      <For each={todos}>
        {todo => (
          <li onClick={() => toggleTodo(todo.id)}
              style={{ 'text-decoration': todo.done ? 'line-through' : 'none' }}>
            {todo.text}
          </li>
        )}
      </For>
    </ul>
  );
}
```

### Control Flow Components
```tsx
import { Show, For, Switch, Match, Suspense, ErrorBoundary } from 'solid-js';

// Show — conditional render
<Show when={user()} fallback={<p>Loading...</p>}>
  {user => <p>Hello, {user().name}</p>}
</Show>

// For — keyed list rendering (fine-grained, not full re-render)
<For each={items()} fallback={<p>Empty</p>}>
  {(item, index) => <li>{index() + 1}. {item.name}</li>}
</For>

// Switch/Match — multi-branch
<Switch fallback={<p>Unknown state</p>}>
  <Match when={state() === 'loading'}><Spinner /></Match>
  <Match when={state() === 'error'}><Error msg={error()} /></Match>
  <Match when={state() === 'success'}><Data value={data()} /></Match>
</Switch>
```

### Resources (Async Data)
```tsx
import { createResource, Suspense } from 'solid-js';

async function fetchUser(id: number) {
  const res = await fetch(`/api/users/${id}`);
  return res.json();
}

function UserProfile(props: { userId: number }) {
  const [user, { refetch }] = createResource(() => props.userId, fetchUser);

  return (
    <Suspense fallback={<p>Loading...</p>}>
      <div>
        <p>{user()?.name}</p>
        <button onClick={refetch}>Refresh</button>
      </div>
    </Suspense>
  );
}
```

### Context (Dependency Injection)
```tsx
import { createContext, useContext, ParentComponent } from 'solid-js';
import { createStore } from 'solid-js/store';

const ThemeContext = createContext<{ dark: boolean; toggle: () => void }>();

export const ThemeProvider: ParentComponent = (props) => {
  const [state, setState] = createStore({ dark: false });
  const value = {
    get dark() { return state.dark; },
    toggle: () => setState('dark', d => !d),
  };

  return (
    <ThemeContext.Provider value={value}>
      {props.children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be inside ThemeProvider');
  return ctx;
};
```

### Directives (Custom DOM Behaviors)
```tsx
import { onCleanup } from 'solid-js';

// Register directive
function clickOutside(el: HTMLElement, accessor: () => () => void) {
  const handler = (e: MouseEvent) => {
    if (!el.contains(e.target as Node)) accessor()();
  };
  document.addEventListener('click', handler);
  onCleanup(() => document.removeEventListener('click', handler));
}

// Use in JSX (must be declared in scope)
declare module 'solid-js' {
  namespace JSX {
    interface Directives { clickOutside: () => void; }
  }
}

<div use:clickOutside={() => setOpen(false)}>
  Dropdown content
</div>
```

## Common Pitfalls
- **Signals must be called**: `count` is a getter function, not a value — forget `()` and it renders the function reference
- **Destructuring breaks reactivity**: `const { name } = user()` extracts a static value; use `user().name` inline
- **No re-render model**: effects and memos track only what they access — wrap conditions carefully
- **`onCleanup` is mandatory for side effects**: timers, subscriptions, event listeners must be cleaned up inside `onCleanup`
- **`createStore` path updates**: use path-based setters `setStore('a', 'b', val)` not spread; avoids full subtree rerun

## Related Skills
- `vite-plugin-dev` — Solid uses Vite under the hood
- `typescript-expert` — Solid has excellent TS generics
- `tanstack-router` — works great with Solid via `@tanstack/solid-router`

## GitNexus Index
```
domain: frontend/web
tier: library
runtime: browser
language: tsx,ts
bundler: vite
reactivity: fine-grained-signals
```
