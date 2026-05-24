---
name: react-native-reanimated
version: 1.0.0
description: Native-thread animations for React Native — worklets, shared values, gestures
tools: [Read, Edit, Write, Bash]
tags: [mobile, react-native, animation, reanimated, gesture-handler, typescript]
author: claude-skill-vault
created: 2026-05-24
---

# React Native Reanimated — Native-Thread Animations

## Overview
React Native Reanimated v3 runs animations on the native UI thread via worklets — small JavaScript functions that compile to native code and execute without crossing the JS bridge. This eliminates frame drops during heavy JS work. It integrates tightly with React Native Gesture Handler v2 to create buttery smooth gesture-driven interactions.

## When to Use
- Any animation that needs to feel native (60/120fps)
- Gesture-driven animations: swipe to dismiss, pull to refresh, drag & drop
- Scroll-linked animations: collapsing headers, parallax, sticky elements
- Replacing Animated API where performance matters
- Complex entrance/exit animations that outlast component lifecycle

## Installation / Setup

```bash
npm install react-native-reanimated react-native-gesture-handler
```

```js
// babel.config.js — Reanimated plugin MUST be last
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: ['react-native-reanimated/plugin'],
};
```

```tsx
// App.tsx — wrap root with GestureHandlerRootView
import { GestureHandlerRootView } from 'react-native-gesture-handler';

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <Navigation />
    </GestureHandlerRootView>
  );
}
```

## Key Patterns

### Basic Shared Value + Animated Style
```tsx
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { Pressable } from 'react-native';

function ScaleButton() {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <Pressable
      onPressIn={() => { scale.value = withSpring(0.92); }}
      onPressOut={() => { scale.value = withSpring(1); }}
    >
      <Animated.View style={[styles.button, animatedStyle]}>
        <Text>Press Me</Text>
      </Animated.View>
    </Pressable>
  );
}
```

### Gesture-Driven Drag (Pan Gesture)
```tsx
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  runOnJS,
} from 'react-native-reanimated';

function DraggableCard({ onDismiss }: { onDismiss: () => void }) {
  const offsetX = useSharedValue(0);
  const offsetY = useSharedValue(0);

  const panGesture = Gesture.Pan()
    .onUpdate((e) => {
      offsetX.value = e.translationX;
      offsetY.value = e.translationY;
    })
    .onEnd((e) => {
      if (Math.abs(e.translationX) > 150) {
        // Dismiss — call JS function from worklet
        runOnJS(onDismiss)();
      } else {
        // Snap back
        offsetX.value = withSpring(0);
        offsetY.value = withSpring(0);
      }
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: offsetX.value },
      { translateY: offsetY.value },
    ],
  }));

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View style={[styles.card, animatedStyle]} />
    </GestureDetector>
  );
}
```

### Scroll-Linked Collapsing Header
```tsx
import Animated, {
  useAnimatedScrollHandler,
  useSharedValue,
  useAnimatedStyle,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated';

const HEADER_MAX_HEIGHT = 200;
const HEADER_MIN_HEIGHT = 60;

function ScrollableScreen() {
  const scrollY = useSharedValue(0);

  const scrollHandler = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollY.value = event.contentOffset.y;
    },
  });

  const headerStyle = useAnimatedStyle(() => {
    const height = interpolate(
      scrollY.value,
      [0, HEADER_MAX_HEIGHT - HEADER_MIN_HEIGHT],
      [HEADER_MAX_HEIGHT, HEADER_MIN_HEIGHT],
      Extrapolation.CLAMP
    );
    const opacity = interpolate(
      scrollY.value,
      [0, HEADER_MAX_HEIGHT - HEADER_MIN_HEIGHT],
      [1, 0],
      Extrapolation.CLAMP
    );
    return { height, opacity };
  });

  return (
    <>
      <Animated.View style={[styles.header, headerStyle]} />
      <Animated.ScrollView onScroll={scrollHandler} scrollEventThrottle={16}>
        {/* content */}
      </Animated.ScrollView>
    </>
  );
}
```

### enter/exit Animations (Layout Animations)
```tsx
import Animated, {
  FadeIn,
  FadeOut,
  SlideInRight,
  SlideOutLeft,
  Layout,
} from 'react-native-reanimated';

function AnimatedList({ items }: { items: string[] }) {
  return (
    <>
      {items.map((item) => (
        <Animated.View
          key={item}
          entering={SlideInRight.duration(300)}
          exiting={SlideOutLeft.duration(200)}
          layout={Layout.springify()}
        >
          <Text>{item}</Text>
        </Animated.View>
      ))}
    </>
  );
}
```

### Worklet — Native-Thread Logic
```tsx
import { runOnUI, runOnJS } from 'react-native-reanimated';

// 'worklet' directive runs this on the native UI thread
function clamp(value: number, min: number, max: number): number {
  'worklet';
  return Math.min(Math.max(value, min), max);
}

// Run arbitrary code on UI thread
runOnUI(() => {
  'worklet';
  const clamped = clamp(someSharedValue.value, 0, 100);
  // ... use clamped in animations
})();

// Call JS from UI thread (crosses the bridge)
runOnJS(someJsFunction)(arg1, arg2);
```

## Common Pitfalls
- **`'worklet'` directive required for native-thread functions**: any function called inside `useAnimatedStyle`, gesture handlers, or `runOnUI` must be marked with `'worklet'` or imported from Reanimated
- **`runOnJS` for JS calls from worklets**: you cannot call regular JS functions directly from worklet context — always wrap with `runOnJS`
- **Reanimated Babel plugin must be last**: if other plugins run after it, worklet transformation breaks silently
- **`useAnimatedStyle` reads, not writes**: setting `sharedValue.value` inside `useAnimatedStyle` causes an infinite loop
- **`GestureHandlerRootView` must wrap the entire app**: nesting gesture handlers outside the root view causes gesture recognition failures on Android

## Related Skills
- `expo-router` — navigation that pairs with Reanimated screen transitions
- `react-native-best-practices` — React Native fundamentals
- `react-native-performance` — profiling native animations
- `nativewind` — styling companion for React Native

## GitNexus Index
```
domain: mobile
tier: library
runtime: ios,android
language: tsx,ts
framework: react-native,expo
purpose: animation
```
