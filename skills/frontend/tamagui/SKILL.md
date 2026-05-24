---
name: tamagui
version: 1.0.0
description: Universal UI kit for React Native and web — performant, themeable, typed
tools: [Read, Edit, Write, Bash]
tags: [mobile, web, react-native, tamagui, ui-library, universal, typescript, styled]
author: claude-skill-vault
created: 2026-05-24
---

# Tamagui — Universal UI Kit

## Overview
Tamagui is a universal UI library and style system that works across React Native and the web from a single codebase. It compiles styles at build time to avoid runtime overhead, ships with a complete component library, and supports themes, tokens, and animations natively. On the web it generates atomic CSS; on native it uses StyleSheet with optimized props.

## When to Use
- Universal apps targeting React Native + web with shared UI components
- Design systems that must look and behave the same on iOS, Android, and web
- Replacing styled-components/StyleSheet with a typed, design-token-aware system
- Expo or Next.js projects that want a polished out-of-the-box component library
- Apps needing dark mode, theming, and responsive design across platforms

## Installation / Setup

```bash
# With Expo (recommended)
npx create-expo-app my-app -t with-tamagui

# Manual (Expo project)
npx expo install tamagui @tamagui/config @tamagui/babel-plugin

# Manual (Next.js)
npm install tamagui @tamagui/config @tamagui/next-plugin
```

```ts
// tamagui.config.ts
import { createTamagui } from 'tamagui';
import { config } from '@tamagui/config/v3';

export const tamaguiConfig = createTamagui(config);
export type Conf = typeof tamaguiConfig;
declare module 'tamagui' {
  interface TamaguiCustomConfig extends Conf {}
}
export default tamaguiConfig;
```

```tsx
// App.tsx — wrap with TamaguiProvider
import { TamaguiProvider } from 'tamagui';
import tamaguiConfig from './tamagui.config';

export default function App() {
  return (
    <TamaguiProvider config={tamaguiConfig} defaultTheme="light">
      <AppContent />
    </TamaguiProvider>
  );
}
```

## Key Patterns

### Stack, XStack, YStack (Layout Primitives)
```tsx
import { XStack, YStack, Text, Button } from 'tamagui';

function Card({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <YStack
      padding="$4"          // uses $4 spacing token
      gap="$2"
      backgroundColor="$background"
      borderRadius="$4"
      borderWidth={1}
      borderColor="$borderColor"
    >
      <Text fontSize="$6" fontWeight="700" color="$color">
        {title}
      </Text>
      <Text fontSize="$3" color="$colorSubtle">
        {subtitle}
      </Text>
      <XStack gap="$2" justifyContent="flex-end">
        <Button size="$3" variant="outlined">Cancel</Button>
        <Button size="$3" theme="active">Confirm</Button>
      </XStack>
    </YStack>
  );
}
```

### Theming
```tsx
import { Theme, XStack, Button, Text } from 'tamagui';

// Apply a sub-theme to a subtree
function DangerZone() {
  return (
    <Theme name="red">
      <XStack backgroundColor="$background" padding="$4" gap="$3">
        <Text color="$color">This is danger zone</Text>
        <Button>Delete Account</Button>
      </XStack>
    </Theme>
  );
}

// Dark/light toggle
import { useColorScheme } from 'react-native';
function ThemedApp() {
  const scheme = useColorScheme();
  return (
    <TamaguiProvider config={tamaguiConfig} defaultTheme={scheme ?? 'light'}>
      <App />
    </TamaguiProvider>
  );
}
```

### Responsive Design (Media Queries)
```tsx
import { YStack, Text } from 'tamagui';

function ResponsiveLayout() {
  return (
    <YStack
      width="100%"
      $gtSm={{ flexDirection: 'row', maxWidth: 800 }}  // > sm breakpoint
      $sm={{ flexDirection: 'column' }}                  // sm breakpoint
      padding="$4"
    >
      <YStack flex={1} $gtSm={{ flex: 0.4 }}>
        <Text>Sidebar</Text>
      </YStack>
      <YStack flex={1} $gtSm={{ flex: 0.6 }}>
        <Text>Content</Text>
      </YStack>
    </YStack>
  );
}
```

### Styled Components (Custom Design System)
```tsx
import { styled, Text, YStack } from 'tamagui';

// Extend existing Tamagui components
const Heading = styled(Text, {
  fontSize: '$8',
  fontWeight: '700',
  color: '$color',

  variants: {
    size: {
      sm: { fontSize: '$6' },
      md: { fontSize: '$8' },
      lg: { fontSize: '$10' },
    },
    muted: {
      true: { color: '$colorSubtle', opacity: 0.7 },
    },
  } as const,
});

const Card = styled(YStack, {
  backgroundColor: '$background',
  borderRadius: '$4',
  padding: '$4',
  borderWidth: 1,
  borderColor: '$borderColor',

  pressStyle: { opacity: 0.8 },
  hoverStyle: { borderColor: '$colorFocus' },
});

// Usage
<Heading size="lg">Hello World</Heading>
<Card onPress={handlePress}>
  <Heading muted>Subtitle</Heading>
</Card>
```

### Animations
```tsx
import { AnimatePresence, YStack } from 'tamagui';
import { useState } from 'react';

function FadeToggle() {
  const [show, setShow] = useState(true);

  return (
    <>
      <Button onPress={() => setShow(v => !v)}>Toggle</Button>
      <AnimatePresence>
        {show && (
          <YStack
            key="content"
            animation="quick"   // built-in animation preset
            enterStyle={{ opacity: 0, y: -10 }}
            exitStyle={{ opacity: 0, y: 10 }}
          >
            <Text>Animated content</Text>
          </YStack>
        )}
      </AnimatePresence>
    </>
  );
}
```

### Sheet (Bottom Sheet)
```tsx
import { Sheet, Button, YStack, Text } from 'tamagui';
import { useState } from 'react';

function BottomSheetExample() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <Button onPress={() => setOpen(true)}>Open Sheet</Button>
      <Sheet
        open={open}
        onOpenChange={setOpen}
        snapPoints={[85, 50, 25]}
        dismissOnSnapToBottom
        animation="medium"
      >
        <Sheet.Overlay />
        <Sheet.Handle />
        <Sheet.Frame padding="$4">
          <YStack gap="$3">
            <Text fontSize="$6" fontWeight="700">Sheet Title</Text>
            <Text>Sheet content goes here.</Text>
            <Button onPress={() => setOpen(false)}>Close</Button>
          </YStack>
        </Sheet.Frame>
      </Sheet>
    </>
  );
}
```

## Common Pitfalls
- **Babel plugin required**: without `@tamagui/babel-plugin`, styles don't compile and performance degrades significantly — always configure it
- **`$token` vs raw values**: always prefer `$4` (token) over `16` (raw) — tokens respond to theme changes; raw values don't
- **`pressStyle`/`hoverStyle` not on arbitrary components**: pseudo-styles only work on Tamagui's native interactable components or components that pass through interaction props
- **Web-only media queries**: `$gtSm`, `$lg`, etc. work on web via CSS; on native they're evaluated at runtime — test both
- **SSR with Next.js requires `@tamagui/next-plugin`**: without it, server-rendered HTML has no styles and there's a flash of unstyled content

## Related Skills
- `nativewind` — Tailwind alternative for React Native without universal ambition
- `expo-router` — routing that pairs naturally with Tamagui
- `react-native-reanimated` — advanced animations beyond Tamagui's built-ins
- `react-native-best-practices` — React Native fundamentals

## GitNexus Index
```
domain: mobile,frontend/web
tier: library
runtime: ios,android,browser
language: tsx,ts
framework: react-native,expo,next
purpose: ui-components
```
