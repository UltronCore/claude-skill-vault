---
name: expo-router
version: 1.0.0
description: File-based routing for React Native and web via Expo — universal navigation
tools: [Read, Edit, Write, Bash]
tags: [mobile, react-native, expo, routing, navigation, typescript, universal]
author: claude-skill-vault
created: 2026-05-24
---

# Expo Router — File-Based Universal Routing

## Overview
Expo Router brings file-based routing (similar to Next.js) to React Native and the web. Every file in the `app/` directory maps to a route — including dynamic segments, layout routes, and deep linking. It's built on React Navigation under the hood and supports iOS, Android, and web from a single codebase with full URL support.

## When to Use
- React Native apps needing deep linking out of the box
- Universal apps (iOS + Android + web) from a single codebase
- Replacing React Navigation's imperative stack for declarative file-based routing
- Expo-managed workflow projects (most common Expo setup)
- Apps that need shared navigation state across platforms

## Installation / Setup

```bash
# New project
npx create-expo-app@latest my-app --template tabs
cd my-app && npx expo start

# Add to existing Expo project
npx expo install expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-status-bar
```

```json
// app.json
{
  "expo": {
    "scheme": "myapp",
    "web": { "bundler": "metro" }
  }
}
```

```json
// package.json
{
  "main": "expo-router/entry"
}
```

## Key Patterns

### File Structure
```
app/
  _layout.tsx          → Root layout (wraps all routes)
  index.tsx            → / (home)
  about.tsx            → /about
  (tabs)/              → Pathless group (tab layout)
    _layout.tsx        → Tab bar definition
    home.tsx           → /home tab
    profile.tsx        → /profile tab
  posts/
    index.tsx          → /posts
    [id].tsx           → /posts/:id (dynamic)
    (details)/
      [id]/
        comments.tsx   → /posts/:id/comments
  (auth)/              → Pathless group (auth guard)
    login.tsx          → /login
    signup.tsx         → /signup
```

### Root Layout
```tsx
// app/_layout.tsx
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

export default function RootLayout() {
  return (
    <>
      <Stack>
        <Stack.Screen name="index" options={{ title: 'Home' }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="posts/[id]"
          options={{ title: 'Post', presentation: 'modal' }}
        />
      </Stack>
      <StatusBar style="auto" />
    </>
  );
}
```

### Tab Layout
```tsx
// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabsLayout() {
  return (
    <Tabs screenOptions={{ tabBarActiveTintColor: '#007AFF' }}>
      <Tabs.Screen
        name="home"
        options={{
          title: 'Home',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="person" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}
```

### Dynamic Routes and Params
```tsx
// app/posts/[id].tsx
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { useEffect, useState } from 'react';

export default function PostScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [post, setPost] = useState<Post | null>(null);

  useEffect(() => {
    fetchPost(id).then(setPost);
  }, [id]);

  return (
    <>
      <Stack.Screen options={{ title: post?.title ?? 'Loading...' }} />
      <ScrollView>
        {post && <Text>{post.body}</Text>}
        <Button title="Comments" onPress={() => router.push(`/posts/${id}/comments`)} />
      </ScrollView>
    </>
  );
}
```

### Programmatic Navigation
```tsx
import { router, useRouter, Link, Redirect } from 'expo-router';

// Imperative navigation
router.push('/posts/42');
router.replace('/login');  // replaces history (no back button)
router.back();
router.push({ pathname: '/posts/[id]', params: { id: '42' } });

// Link component (declarative)
<Link href="/about">About</Link>
<Link href={{ pathname: '/posts/[id]', params: { id: '42' } }}>
  View Post
</Link>

// Redirect (renders nothing, navigates immediately)
if (!isLoggedIn) return <Redirect href="/login" />;
```

### Authentication Guard
```tsx
// app/(auth)/_layout.tsx
import { useAuth } from '@/hooks/useAuth';
import { Redirect, Stack } from 'expo-router';

export default function AuthLayout() {
  const { isLoggedIn } = useAuth();
  if (isLoggedIn) return <Redirect href="/(tabs)/home" />;
  return <Stack />;
}

// app/(protected)/_layout.tsx
export default function ProtectedLayout() {
  const { isLoggedIn } = useAuth();
  if (!isLoggedIn) return <Redirect href="/(auth)/login" />;
  return <Stack />;
}
```

### Error Boundary and Not Found
```tsx
// app/+not-found.tsx
import { Link, Stack } from 'expo-router';
import { View, Text } from 'react-native';

export default function NotFound() {
  return (
    <>
      <Stack.Screen options={{ title: 'Not Found' }} />
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
        <Text>This screen doesn't exist.</Text>
        <Link href="/">Go Home</Link>
      </View>
    </>
  );
}

// app/+error.tsx (per-route error boundary)
import { ErrorBoundaryProps } from 'expo-router';
export function ErrorBoundary({ error, retry }: ErrorBoundaryProps) {
  return (
    <View>
      <Text>{error.message}</Text>
      <Button title="Retry" onPress={retry} />
    </View>
  );
}
```

## Common Pitfalls
- **`(group)` directories are pathless**: wrapping in `(parens)` removes the directory name from the URL — use for layout grouping without affecting URL
- **`useLocalSearchParams` vs `useGlobalSearchParams`**: local gives the current route's params; global gives all params across the entire URL — prefer local
- **`router.push` with typed params**: always use `{ pathname, params }` form with dynamic segments to get TypeScript checking
- **Deep link scheme required**: set `expo.scheme` in `app.json` — without it, deep links won't open the app
- **Web builds require Metro web bundler**: set `"web": { "bundler": "metro" }` — without it, `expo export --platform web` fails

## Related Skills
- `react-native-reanimated` — animations for transitions and gestures
- `react-native-best-practices` — React Native fundamentals
- `nativewind` — Tailwind styling for Expo apps
- `tamagui` — universal UI component kit

## GitNexus Index
```
domain: mobile
tier: framework
runtime: ios,android,browser
language: tsx,ts
framework: react-native,expo
purpose: routing
```
