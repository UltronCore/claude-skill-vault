---
name: xstate-v5
version: 1.0.0
description: Actor-model state machines for complex UI and async workflows
tools: [Read, Edit, Write, Bash]
tags: [frontend, web, state-management, xstate, state-machines, actors, typescript]
author: claude-skill-vault
created: 2026-05-24
---

# XState v5 — Actor-Model State Machines

## Overview
XState v5 is a state machine and statechart library based on the Actor model. Each machine is an actor with its own state, and actors can spawn child actors and communicate via events. v5 is a complete rewrite with a simpler API: unified `setup()` factory, first-class TypeScript inference, and no more configuration objects scattered across the library.

## When to Use
- Complex multi-step UI flows (wizards, checkout, auth)
- Async workflows with retries, timeouts, and cancellation
- When if/else chains in reducers become hard to reason about
- Replacing complex `useReducer` + `useEffect` combinations
- Websocket/SSE connections with reconnect logic
- Any state that has explicit transitions (not just data updates)

## Installation / Setup

```bash
npm install xstate @xstate/react
```

## Key Patterns

### Basic Machine with setup()
```ts
import { setup, assign, createActor } from 'xstate';

const counterMachine = setup({
  types: {
    context: {} as { count: number },
    events: {} as
      | { type: 'INCREMENT' }
      | { type: 'DECREMENT' }
      | { type: 'RESET' },
  },
  actions: {
    increment: assign({ count: ({ context }) => context.count + 1 }),
    decrement: assign({ count: ({ context }) => context.count - 1 }),
    reset: assign({ count: 0 }),
  },
}).createMachine({
  id: 'counter',
  initial: 'active',
  context: { count: 0 },
  states: {
    active: {
      on: {
        INCREMENT: { actions: 'increment' },
        DECREMENT: { actions: 'decrement' },
        RESET: { actions: 'reset' },
      },
    },
  },
});
```

### React Integration with useMachine
```tsx
import { useMachine } from '@xstate/react';

function Counter() {
  const [state, send] = useMachine(counterMachine);

  return (
    <div>
      <p>Count: {state.context.count}</p>
      <button onClick={() => send({ type: 'INCREMENT' })}>+</button>
      <button onClick={() => send({ type: 'DECREMENT' })}>-</button>
      <button onClick={() => send({ type: 'RESET' })}>Reset</button>
    </div>
  );
}
```

### Async State Machine (Fetch with Loading/Error)
```ts
import { setup, assign, fromPromise } from 'xstate';

interface User { id: string; name: string; }

const fetchUserMachine = setup({
  types: {
    context: {} as { user: User | null; error: string | null },
    events: {} as { type: 'FETCH'; id: string } | { type: 'RETRY' },
    input: {} as { userId: string },
  },
  actors: {
    fetchUser: fromPromise(async ({ input }: { input: { id: string } }) => {
      const res = await fetch(`/api/users/${input.id}`);
      if (!res.ok) throw new Error('Not found');
      return res.json() as Promise<User>;
    }),
  },
}).createMachine({
  id: 'fetchUser',
  initial: 'idle',
  context: { user: null, error: null },
  states: {
    idle: {
      on: { FETCH: { target: 'loading' } },
    },
    loading: {
      invoke: {
        src: 'fetchUser',
        input: ({ event }) => ({ id: (event as { type: 'FETCH'; id: string }).id }),
        onDone: {
          target: 'success',
          actions: assign({ user: ({ event }) => event.output, error: null }),
        },
        onError: {
          target: 'failure',
          actions: assign({ error: ({ event }) => String(event.error), user: null }),
        },
      },
    },
    success: {
      on: { FETCH: { target: 'loading' } },
    },
    failure: {
      on: { RETRY: { target: 'loading' } },
    },
  },
});
```

### Guards (Conditional Transitions)
```ts
const trafficLightMachine = setup({
  types: {
    context: {} as { seconds: number },
    events: {} as { type: 'TICK' } | { type: 'POWER_OUT' },
  },
  guards: {
    timerExpired: ({ context }) => context.seconds <= 0,
  },
  actions: {
    decrementTimer: assign({ seconds: ({ context }) => context.seconds - 1 }),
    setGreenTimer: assign({ seconds: 30 }),
    setYellowTimer: assign({ seconds: 5 }),
    setRedTimer: assign({ seconds: 20 }),
  },
}).createMachine({
  id: 'trafficLight',
  initial: 'green',
  context: { seconds: 30 },
  states: {
    green: {
      on: {
        TICK: [
          { guard: 'timerExpired', target: 'yellow', actions: 'setYellowTimer' },
          { actions: 'decrementTimer' },
        ],
      },
    },
    yellow: {
      on: {
        TICK: [
          { guard: 'timerExpired', target: 'red', actions: 'setRedTimer' },
          { actions: 'decrementTimer' },
        ],
      },
    },
    red: {
      on: {
        TICK: [
          { guard: 'timerExpired', target: 'green', actions: 'setGreenTimer' },
          { actions: 'decrementTimer' },
        ],
      },
    },
  },
});
```

### useSelector for Derived State (Perf)
```tsx
import { useMachine, useSelector } from '@xstate/react';

// Create actor at module/context level for sharing
const actor = createActor(fetchUserMachine).start();

function UserName() {
  // Only re-renders when name changes
  const name = useSelector(actor, (state) => state.context.user?.name ?? '');
  return <span>{name}</span>;
}

function LoadingIndicator() {
  const isLoading = useSelector(actor, (state) => state.matches('loading'));
  return isLoading ? <div>Loading...</div> : null;
}
```

### Parallel States
```ts
const settingsMachine = setup({
  types: {
    events: {} as
      | { type: 'TOGGLE_NOTIFICATIONS' }
      | { type: 'TOGGLE_DARK_MODE' },
  },
}).createMachine({
  id: 'settings',
  type: 'parallel', // all child states active simultaneously
  states: {
    notifications: {
      initial: 'enabled',
      states: {
        enabled: { on: { TOGGLE_NOTIFICATIONS: 'disabled' } },
        disabled: { on: { TOGGLE_NOTIFICATIONS: 'enabled' } },
      },
    },
    theme: {
      initial: 'light',
      states: {
        light: { on: { TOGGLE_DARK_MODE: 'dark' } },
        dark: { on: { TOGGLE_DARK_MODE: 'light' } },
      },
    },
  },
});
```

## Common Pitfalls
- **`assign` must be pure**: never mutate `context` directly — always return new values from `assign`
- **Events are discriminated unions**: `event.type` must be a string literal, not a dynamic value; TypeScript will catch mismatches
- **`fromPromise` input must be serializable**: the input is part of the actor's snapshot — avoid passing class instances or functions
- **`useMachine` re-creates the machine on every mount**: for shared global state, use `createActor` + `useSelector` with a module-level actor
- **v5 breaking change from v4**: `createMachine` config options are now in `setup()`; `send` no longer accepts plain strings — always use `{ type: 'EVENT' }`

## Related Skills
- `zustand` — simpler choice when state machines are overkill
- `jotai` — atomic state without behavioral constraints
- `react-best-practices` — React fundamentals
- `tanstack-router` — pairs with XState for navigation guards

## GitNexus Index
```
domain: frontend/web
tier: library
runtime: browser,node
language: ts,tsx
framework: react,vanilla
purpose: state-management
```
