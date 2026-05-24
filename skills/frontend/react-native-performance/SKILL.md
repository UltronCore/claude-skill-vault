---
name: react-native-performance
description: Optimize React Native apps for 60/120fps rendering, reduce JS bundle size, eliminate bridge bottlenecks with the new architecture (JSI/Fabric/TurboModules), profile with Flipper and Perf Monitor, and tune FlatList/FlashList for large datasets.
version: 1.0.0
tags: [react-native, performance, jsi, fabric, turbomodules, flashlist, flipper, profiling, mobile, ios, android]
---

# React Native Performance Optimization

## Overview

React Native performance falls into three categories: JS thread (heavy computation, long renders), UI thread (layout, native views), and bridge (serialization overhead in the old architecture). The new architecture — JSI (JavaScript Interface), Fabric renderer, and TurboModules — eliminates the asynchronous bridge bottleneck, enabling synchronous C++ calls from JS. Most apps spending >16ms on any frame can reach 60fps by eliminating unnecessary re-renders, moving computation off the JS thread with Reanimated worklets, and replacing heavy list components with FlashList.

## When to Use

- App dropping frames below 60fps (Perf Monitor shows JS or UI thread > 16ms)
- Slow list scrolling with hundreds of items in FlatList
- Large initial bundle causing slow first screen (>2s on mid-range Android)
- Heavy touch handlers causing delayed response (INP equivalent in RN)
- Animations janking when JS thread is busy
- Memory growth leaking native views or JS closures
- Bridge calls causing lag in old architecture apps being migrated to New Architecture

## Step-by-Step Workflow

### 1. Profiling with Flipper and React DevTools

```bash
# Install Flipper (macOS)
brew install --cask flipper

# Enable Hermes engine (required for JS profiling)
# ios/Podfile:
# :hermes_enabled => true

# Android: android/app/build.gradle
# hermesEnabled=true in gradle.properties

# Start the app in profiling mode
npx react-native run-ios --configuration Release  # Profile against release build
npx react-native run-android --variant=release
```

```javascript
// Track render count per component — find unnecessary re-renders
// src/utils/why-did-you-render.js
import React from "react";

if (__DEV__) {
  const whyDidYouRender = require("@welldone-software/why-did-you-render");
  whyDidYouRender(React, {
    trackAllPureComponents: false,
    // Enable per-component:
    // Add `ComponentName.whyDidYouRender = true;` after class/function definition
  });
}
```

```javascript
// Mark performance segments for Flipper Performance Plugin
import { Performance } from "react-native";

async function loadFeed() {
  performance.mark("feed_load_start");
  const data = await fetchFeed();
  performance.mark("feed_load_end");
  performance.measure("feed_load", "feed_load_start", "feed_load_end");
  return data;
}
```

### 2. FlashList for High-Performance Lists

```bash
npm install @shopify/flash-list
cd ios && pod install
```

```tsx
// src/components/feed/FeedList.tsx
import { FlashList, ListRenderItem } from "@shopify/flash-list";
import React, { useCallback, memo } from "react";
import { View, Text, StyleSheet } from "react-native";

interface FeedItem {
  id: string;
  title: string;
  body: string;
  imageUrl: string;
}

// Memoize item component to prevent re-renders when parent updates
const FeedCard = memo(({ item }: { item: FeedItem }) => (
  <View style={styles.card}>
    <Text style={styles.title}>{item.title}</Text>
    <Text style={styles.body} numberOfLines={3}>{item.body}</Text>
  </View>
));

export function FeedList({ items }: { items: FeedItem[] }) {
  const renderItem: ListRenderItem<FeedItem> = useCallback(
    ({ item }) => <FeedCard item={item} />,
    []
  );

  const keyExtractor = useCallback((item: FeedItem) => item.id, []);

  return (
    <FlashList
      data={items}
      renderItem={renderItem}
      keyExtractor={keyExtractor}
      estimatedItemSize={120}          // Critical for FlashList performance
      drawDistance={500}              // Pixels to render ahead of viewport
      initialNumToRender={10}
      overrideItemLayout={(layout, item) => {
        // If items have variable height, specify here for accurate estimation
        layout.size = item.imageUrl ? 200 : 100;
      }}
      ListEmptyComponent={<EmptyFeed />}
      onEndReachedThreshold={0.5}
      onEndReached={loadMoreItems}
    />
  );
}

const styles = StyleSheet.create({
  card: { padding: 16, backgroundColor: "#fff", marginVertical: 4 },
  title: { fontSize: 16, fontWeight: "600" },
  body: { fontSize: 14, color: "#666", marginTop: 4 },
});
```

### 3. Reanimated 3 for 60fps Animations

```bash
npm install react-native-reanimated
# babel.config.js: add 'react-native-reanimated/plugin' to plugins
```

```tsx
// src/components/SwipeCard.tsx — 60fps swipe gesture on UI thread
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  runOnJS,
  interpolate,
  Extrapolation,
} from "react-native-reanimated";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import { Dimensions } from "react-native";

const SCREEN_WIDTH = Dimensions.get("window").width;
const SWIPE_THRESHOLD = SCREEN_WIDTH * 0.4;

interface SwipeCardProps {
  onSwipeLeft: () => void;
  onSwipeRight: () => void;
  children: React.ReactNode;
}

export function SwipeCard({ onSwipeLeft, onSwipeRight, children }: SwipeCardProps) {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);

  const gesture = Gesture.Pan()
    .onUpdate((event) => {
      // This runs on UI thread — no bridge, no JS thread involvement
      translateX.value = event.translationX;
      translateY.value = event.translationY * 0.4;  // Reduce Y movement
    })
    .onEnd((event) => {
      if (Math.abs(event.translationX) > SWIPE_THRESHOLD) {
        // Swipe off screen
        const direction = event.translationX > 0 ? 1 : -1;
        translateX.value = withTiming(direction * SCREEN_WIDTH * 1.5, { duration: 300 }, () => {
          // Call JS function from UI thread — needs runOnJS wrapper
          runOnJS(event.translationX > 0 ? onSwipeRight : onSwipeLeft)();
        });
      } else {
        // Snap back
        translateX.value = withSpring(0);
        translateY.value = withSpring(0);
      }
    });

  const animatedStyle = useAnimatedStyle(() => {
    const rotate = interpolate(
      translateX.value,
      [-SCREEN_WIDTH / 2, 0, SCREEN_WIDTH / 2],
      [-15, 0, 15],
      Extrapolation.CLAMP
    );

    return {
      transform: [
        { translateX: translateX.value },
        { translateY: translateY.value },
        { rotate: `${rotate}deg` },
      ],
    };
  });

  return (
    <GestureDetector gesture={gesture}>
      <Animated.View style={[styles.card, animatedStyle]}>
        {children}
      </Animated.View>
    </GestureDetector>
  );
}
```

### 4. Bundle Optimization and Code Splitting

```bash
# Analyze bundle size
npx react-native bundle \
  --platform ios \
  --dev false \
  --entry-file index.js \
  --bundle-output /tmp/bundle.js \
  --assets-dest /tmp/assets

# Visualize bundle with source-map-explorer
npx react-native bundle --platform ios --dev false \
  --entry-file index.js \
  --bundle-output /tmp/bundle.js \
  --sourcemap-output /tmp/bundle.js.map

source-map-explorer /tmp/bundle.js /tmp/bundle.js.map
```

```javascript
// Lazy load heavy screens with React.lazy (RN 0.73+)
import React, { Suspense, lazy } from "react";
import { ActivityIndicator, View } from "react-native";

// These screens only load their JS when first navigated to
const ProfileScreen = lazy(() => import("./screens/ProfileScreen"));
const SettingsScreen = lazy(() => import("./screens/SettingsScreen"));

function AppNavigator() {
  return (
    <Stack.Navigator>
      <Stack.Screen name="Home" component={HomeScreen} />
      <Stack.Screen name="Profile">
        {() => (
          <Suspense fallback={<View><ActivityIndicator /></View>}>
            <ProfileScreen />
          </Suspense>
        )}
      </Stack.Screen>
    </Stack.Navigator>
  );
}

// Optimize imports — import only what you need
// BAD: import _ from 'lodash';  (entire lodash in bundle)
// GOOD: import debounce from 'lodash/debounce';

// Use React.memo + custom equality for expensive renders
const ExpensiveItem = React.memo(
  ({ data, onPress }) => <HeavyComponent data={data} onPress={onPress} />,
  (prev, next) =>
    prev.data.id === next.data.id && prev.onPress === next.onPress
);
```

### 5. New Architecture (JSI + TurboModules)

```javascript
// Enable New Architecture
// android/gradle.properties:
// newArchEnabled=true

// ios/Podfile:
// :fabric_enabled => true

// Create a TurboModule for synchronous native access
// specs/NativeImageProcessor.ts
import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

export interface Spec extends TurboModule {
  // Synchronous method (possible with JSI)
  processImageSync(base64: string): string;
  // Async method
  processImageAsync(base64: string): Promise<string>;
}

export default TurboModuleRegistry.getEnforcing<Spec>("ImageProcessor");
```

```objc
// ios/ImageProcessor.mm — TurboModule native implementation
#import "ImageProcessor.h"
#import <React/RCTBridge+Private.h>

@implementation ImageProcessor

RCT_EXPORT_MODULE()

- (NSString *)processImageSync:(NSString *)base64 {
  // Runs synchronously on calling thread — only possible with JSI
  // No bridge serialization overhead
  UIImage *image = [self decodeBase64:base64];
  return [self applyFilter:image];
}

// For Fabric/New Architecture:
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeImageProcessorSpecJSI>(params);
}

@end
```

## Key Commands Reference

```bash
# Enable Perf Monitor in app (shake device or cmd+D)
# Shows: JS FPS, UI FPS, RAM, Views

# Hermes bytecode bundle (faster startup)
# Enabled by default in RN 0.70+

# Profile startup time
npx react-native profile-hermes --sourcemap-path /tmp/bundle.js.map

# Android profiling with systrace
python $ANDROID_HOME/platform-tools/systrace/systrace.py \
  --time=10 -o trace.html \
  sched freq idle am wm gfx view binder_driver hal dalvik

# Check bridge traffic (old architecture)
# In __DEV__: global.__fbBatchedBridge.callFunctionReturnFlushedQueue

# Measure JS thread time
console.time("heavy-operation");
// ... work ...
console.timeEnd("heavy-operation");

# FlashList diagnostic
# Wrap in <FlashList ... onLoad={({ elapsedTimeInMs }) => console.log(elapsedTimeInMs)} />

# Memory profiling on iOS
# Xcode → Instruments → Leaks / Allocations
# Check for growing "React Native Views" allocations

# Android memory
adb shell dumpsys meminfo com.yourapp
```

## Common Patterns

### Pattern 1: useCallback and useMemo to Prevent Re-renders

```tsx
// Prevent reference equality failures causing FlatList/FlashList re-renders
import React, { useCallback, useMemo, useState } from "react";

function ProductList({ products, userId }) {
  const [cart, setCart] = useState(new Set<string>());

  // Stable reference — won't cause all list items to re-render on cart change
  const handleAddToCart = useCallback((productId: string) => {
    setCart(prev => new Set([...prev, productId]));
  }, []);  // No deps — stable forever

  // Derived state — only recomputes when products or cart changes
  const enrichedProducts = useMemo(() =>
    products.map(p => ({
      ...p,
      inCart: cart.has(p.id),
    })),
    [products, cart]
  );

  const renderItem = useCallback(
    ({ item }) => (
      <ProductCard
        product={item}
        onAddToCart={handleAddToCart}
      />
    ),
    [handleAddToCart]  // Stable reference
  );

  return (
    <FlashList
      data={enrichedProducts}
      renderItem={renderItem}
      estimatedItemSize={180}
    />
  );
}
```

### Pattern 2: Move Heavy Work to Background Thread

```javascript
// Use react-native-workers or expo-task-manager for CPU-intensive work
// Or: use InteractionManager to defer work until animations complete
import { InteractionManager } from "react-native";

function Screen() {
  const [data, setData] = useState(null);

  useEffect(() => {
    // Defer expensive processing until after navigation animation settles
    const task = InteractionManager.runAfterInteractions(async () => {
      const result = await processLargeDataset();  // Runs after transitions
      setData(result);
    });

    return () => task.cancel();
  }, []);

  // Screen renders immediately; data loads after animations finish
  return <Content data={data} />;
}

// For truly CPU-heavy work: use a Web Worker via react-native-workers
import { createWorker } from "react-native-workers";

const worker = createWorker(() => {
  // This code runs in a separate thread
  self.onmessage = ({ data: { numbers } }) => {
    const sorted = [...numbers].sort((a, b) => a - b);
    self.postMessage({ sorted });
  };
});

async function sortInBackground(numbers) {
  return new Promise((resolve) => {
    worker.postMessage({ numbers });
    worker.onmessage = ({ data }) => resolve(data.sorted);
  });
}
```

### Pattern 3: Image Performance

```tsx
// Use react-native-fast-image for cached, prioritized image loading
import FastImage from "react-native-fast-image";

function ProductImage({ uri, priority = "normal" }) {
  return (
    <FastImage
      style={{ width: 200, height: 200 }}
      source={{
        uri,
        priority: FastImage.priority[priority],  // "low" | "normal" | "high"
        cache: FastImage.cacheControl.immutable, // Never re-fetch same URL
      }}
      resizeMode={FastImage.resizeMode.cover}
    />
  );
}

// Preload images before navigation
FastImage.preload([
  { uri: "https://cdn.example.com/hero.jpg", priority: FastImage.priority.high },
  { uri: "https://cdn.example.com/product1.jpg" },
]);

// Blur hash placeholder for progressive loading
import { Image } from "expo-image";

function ProgressiveImage({ uri, blurHash }) {
  return (
    <Image
      source={uri}
      placeholder={blurHash}            // Shows blurred preview immediately
      contentFit="cover"
      transition={300}                  // Smooth fade-in when loaded
      cachePolicy="memory-disk"
    />
  );
}
```

## Pitfalls to Avoid

1. **Passing inline functions or objects as props to memoized components**: `<FeedCard onPress={() => navigate(item.id)} />` creates a new function reference on every render, defeating `React.memo`. Extract stable callbacks with `useCallback` and pass IDs as primitive props. The item component calls the callback with its ID. This is the single most common RN performance mistake.

2. **Using FlatList instead of FlashList for large datasets**: FlatList maintains a window of rendered items but has poor memory management for large lists. FlashList (Shopify) recycles native views like UICollectionView/RecyclerView, reducing memory by 50-70% and improving scroll FPS significantly. Always provide `estimatedItemSize` — without it, FlashList falls back to measuring each item which defeats recycling.

3. **Running animations on the JS thread**: Any animation using `Animated.timing()` without `useNativeDriver: true` runs on the JS thread. When the JS thread is busy (data fetch, renders), animations stutter. Use `react-native-reanimated` worklets which run entirely on the UI thread and are unaffected by JS thread load. Only use `useNativeDriver: true` for transform/opacity — layout animations require Reanimated.

## Related Skills

- `react-native-best-practices` — Architecture patterns for RN apps
- `ios-performance` — Native iOS performance tools (Instruments)
- `android-development` — Android performance profiling (Systrace, Perfetto)
- `nextjs-performance` — Web performance counterpart

## GitNexus Index

```json
{
  "skill": "react-native-performance",
  "category": "mobile",
  "triggers": ["react native performance", "RN 60fps", "FlashList", "react-native-reanimated", "Fabric renderer", "TurboModules", "JSI react native", "react native FlatList slow", "react native bundle size", "react native Hermes", "Flipper profiling"],
  "outputs": ["FlashList estimatedItemSize", "useAnimatedStyle worklet", "InteractionManager.runAfterInteractions", "React.memo custom equality", "FastImage preload", "useCallback stable reference", "TurboModule spec"],
  "complexity": "medium",
  "tools": ["react-native", "reanimated", "flashlist", "flipper", "hermes", "gesture-handler", "fast-image", "expo-image"]
}
```
