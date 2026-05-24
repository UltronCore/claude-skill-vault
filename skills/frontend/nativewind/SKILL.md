---
name: nativewind
version: 1.0.0
description: Tailwind CSS utility classes for React Native — universal styling
tools: [Read, Edit, Write, Bash]
tags: [mobile, react-native, expo, tailwind, nativewind, styling, typescript, universal]
author: claude-skill-vault
created: 2026-05-24
---

# NativeWind — Tailwind CSS for React Native

## Overview
NativeWind uses Tailwind CSS as a universal styling language for React Native. Write `className` strings with Tailwind utility classes and NativeWind compiles them to React Native `StyleSheet` objects at build time. v4 (current) targets Expo SDK 52+ and uses CSS variables for theming, making dark mode and custom themes effortless.

## When to Use
- React Native or Expo projects where your team already knows Tailwind
- Universal apps sharing Tailwind styles across web (Next.js) and native
- Replacing StyleSheet objects with utility-first classes for faster iteration
- Expo projects needing dark mode with minimal setup
- Teams migrating from a web Tailwind codebase to add a native app

## Installation / Setup

```bash
# NativeWind v4 with Expo
npx expo install nativewind tailwindcss react-native-reanimated react-native-safe-area-context

# Run the setup command (configures babel, metro, tsconfig)
npx expo customize metro.config.js
```

```js
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,jsx,ts,tsx}',
    './components/**/*.{js,jsx,ts,tsx}',
  ],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        brand: '#6366f1',
      },
    },
  },
};
```

```js
// metro.config.js
const { getDefaultConfig } = require('expo/metro-config');
const { withNativeWind } = require('nativewind/metro');

const config = getDefaultConfig(__dirname);
module.exports = withNativeWind(config, { input: './global.css' });
```

```css
/* global.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

```tsx
// app/_layout.tsx
import '../global.css';
```

```ts
// nativewind-env.d.ts (TypeScript support)
/// <reference types="nativewind/types" />
```

## Key Patterns

### Basic className Usage
```tsx
import { View, Text, Pressable } from 'react-native';

function Button({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      className="bg-indigo-600 rounded-xl px-6 py-3 active:opacity-70"
      onPress={onPress}
    >
      <Text className="text-white font-semibold text-base text-center">
        {label}
      </Text>
    </Pressable>
  );
}

function Card({ title, body }: { title: string; body: string }) {
  return (
    <View className="bg-white dark:bg-zinc-900 rounded-2xl p-4 shadow-sm mx-4 my-2">
      <Text className="text-zinc-900 dark:text-white text-lg font-bold mb-1">
        {title}
      </Text>
      <Text className="text-zinc-500 dark:text-zinc-400 text-sm leading-relaxed">
        {body}
      </Text>
    </View>
  );
}
```

### Dark Mode
```tsx
import { useColorScheme } from 'nativewind';

function ThemeToggle() {
  const { colorScheme, toggleColorScheme } = useColorScheme();

  return (
    <Pressable
      className="flex-row items-center gap-2 p-3 rounded-lg bg-zinc-100 dark:bg-zinc-800"
      onPress={toggleColorScheme}
    >
      <Text className="text-zinc-900 dark:text-white">
        {colorScheme === 'dark' ? 'Light Mode' : 'Dark Mode'}
      </Text>
    </Pressable>
  );
}
```

### Conditional Classes (clsx/cn)
```tsx
import { cn } from '@/lib/utils'; // clsx + twMerge helper
import { View, Text } from 'react-native';

type BadgeVariant = 'default' | 'success' | 'warning' | 'error';

function Badge({ label, variant = 'default' }: { label: string; variant?: BadgeVariant }) {
  return (
    <View
      className={cn(
        'px-2 py-0.5 rounded-full self-start',
        variant === 'default' && 'bg-zinc-100 dark:bg-zinc-800',
        variant === 'success' && 'bg-green-100 dark:bg-green-900',
        variant === 'warning' && 'bg-amber-100 dark:bg-amber-900',
        variant === 'error' && 'bg-red-100 dark:bg-red-900',
      )}
    >
      <Text
        className={cn(
          'text-xs font-medium',
          variant === 'default' && 'text-zinc-600 dark:text-zinc-300',
          variant === 'success' && 'text-green-700 dark:text-green-300',
          variant === 'warning' && 'text-amber-700 dark:text-amber-300',
          variant === 'error' && 'text-red-700 dark:text-red-300',
        )}
      >
        {label}
      </Text>
    </View>
  );
}
```

```ts
// lib/utils.ts — cn helper
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### Responsive Platform Classes
```tsx
import { View, Text } from 'react-native';

// NativeWind v4 supports platform modifiers
function PlatformAdaptive() {
  return (
    <View className="ios:pt-12 android:pt-8 web:pt-4 px-4 bg-white dark:bg-black">
      <Text className="ios:text-lg android:text-base font-semibold">
        Platform-specific styles
      </Text>
    </View>
  );
}
```

### FlatList with NativeWind
```tsx
import { FlatList, View, Text } from 'react-native';

interface Item { id: string; title: string; subtitle: string; }

function ItemRow({ item }: { item: Item }) {
  return (
    <View className="flex-row items-center px-4 py-3 border-b border-zinc-100 dark:border-zinc-800">
      <View className="w-10 h-10 rounded-full bg-indigo-100 dark:bg-indigo-900 items-center justify-center mr-3">
        <Text className="text-indigo-600 dark:text-indigo-300 font-bold text-base">
          {item.title[0]}
        </Text>
      </View>
      <View className="flex-1">
        <Text className="text-zinc-900 dark:text-white font-medium">{item.title}</Text>
        <Text className="text-zinc-500 dark:text-zinc-400 text-sm">{item.subtitle}</Text>
      </View>
    </View>
  );
}

function ItemList({ items }: { items: Item[] }) {
  return (
    <FlatList
      data={items}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => <ItemRow item={item} />}
      className="flex-1 bg-white dark:bg-black"
    />
  );
}
```

### Custom CSS Variables (Theming)
```css
/* global.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --color-primary: 99 102 241;      /* indigo-500 */
    --color-background: 255 255 255;
    --color-foreground: 24 24 27;
  }
  .dark {
    --color-primary: 129 140 248;     /* indigo-400 */
    --color-background: 9 9 11;
    --color-foreground: 244 244 245;
  }
}
```

```js
// tailwind.config.js
theme: {
  extend: {
    colors: {
      primary: 'rgb(var(--color-primary) / <alpha-value>)',
      background: 'rgb(var(--color-background) / <alpha-value>)',
      foreground: 'rgb(var(--color-foreground) / <alpha-value>)',
    },
  },
}
```

## Common Pitfalls
- **Dynamic class strings don't work**: never concatenate class strings like `"bg-" + color` — Tailwind's static analyzer won't find them; use `cn()` with full class names or a `cva` variant map
- **Metro cache must be cleared after config changes**: `npx expo start --clear` after modifying `tailwind.config.js` or `metro.config.js`
- **Not all Tailwind utilities translate to native**: web-only utilities like `grid`, `display: inline`, and CSS Grid don't work on native — use flexbox equivalents
- **`className` prop only works on core RN primitives**: third-party components don't accept `className` unless they spread props — wrap them in a `View` with NativeWind or use `cssInterop`
- **v4 vs v3 APIs differ significantly**: v3 used `styled()` HOC from `nativewind`; v4 uses native `className` prop — don't mix tutorials from different versions

## Related Skills
- `tamagui` — full UI kit alternative with more complete universal components
- `expo-router` — routing that pairs naturally with NativeWind
- `react-native-reanimated` — animations complementing NativeWind styling
- `react-native-best-practices` — React Native fundamentals
- `tailwind-shadcn-ui-setup` — web Tailwind setup for comparison

## GitNexus Index
```
domain: mobile
tier: library
runtime: ios,android,browser
language: tsx,ts,css
framework: react-native,expo
purpose: styling
```
