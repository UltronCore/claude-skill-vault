---
name: capacitor
version: 1.0.0
description: Native iOS and Android apps from web code — Ionic's cross-platform runtime
tools: [Read, Edit, Write, Bash]
tags: [mobile, web, capacitor, ionic, ios, android, native, typescript]
author: claude-skill-vault
created: 2026-05-24
---

# Capacitor — Native Mobile from Web Code

## Overview
Capacitor is a cross-platform native runtime that lets you build iOS and Android apps using web technologies (HTML, CSS, JS/TS). It wraps your web app in a native WebView and exposes native device APIs through a plugin system. Unlike Cordova, Capacitor has first-class TypeScript support, a cleaner plugin API, and treats iOS/Android projects as first-class citizens you can edit directly in Xcode and Android Studio.

## When to Use
- Existing web app (React, Vue, Angular, Svelte) that needs to ship as a native app
- Teams with web expertise who need iOS/Android without learning native code
- Apps needing access to Camera, Push Notifications, File System, Biometrics
- Progressive enhancement: ship as web first, add native features incrementally
- Replacing Cordova in an Ionic project

## Installation / Setup

```bash
# New project via Ionic CLI
npm install -g @ionic/cli
ionic start myApp blank --type=react --capacitor

# Add Capacitor to existing web project
npm install @capacitor/core @capacitor/cli
npx cap init myApp com.example.myapp --web-dir=dist

# Add iOS and Android platforms
npm install @capacitor/ios @capacitor/android
npx cap add ios
npx cap add android
```

```json
// capacitor.config.ts
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.myapp',
  appName: 'My App',
  webDir: 'dist',
  server: {
    // For live reload during development:
    // url: 'http://192.168.1.100:5173',
    // cleartext: true,
  },
  plugins: {
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert'],
    },
  },
};

export default config;
```

## Key Patterns

### Build + Sync Workflow
```bash
# After making web changes:
npm run build          # Build web assets
npx cap sync           # Copy web assets to native projects + update plugins

# Open native IDE
npx cap open ios       # Opens Xcode
npx cap open android   # Opens Android Studio

# Run on device/simulator
npx cap run ios
npx cap run android
```

### Camera Plugin
```ts
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';

async function takePhoto() {
  const photo = await Camera.getPhoto({
    quality: 90,
    allowEditing: false,
    resultType: CameraResultType.Uri,
    source: CameraSource.Camera,
  });

  // photo.webPath is a URL you can use in <img src="...">
  return photo.webPath;
}

// Pick from gallery
async function pickFromGallery() {
  const photos = await Camera.pickImages({
    quality: 90,
    limit: 5, // max 5 images
  });
  return photos.photos.map(p => p.webPath);
}
```

### Push Notifications
```ts
import {
  PushNotifications,
  PushNotificationSchema,
  ActionPerformed,
} from '@capacitor/push-notifications';

async function initPushNotifications() {
  // Request permission
  const permission = await PushNotifications.requestPermissions();
  if (permission.receive !== 'granted') return;

  // Register with Apple/Google
  await PushNotifications.register();

  // Get device token (send this to your server)
  PushNotifications.addListener('registration', ({ value: token }) => {
    console.log('Push token:', token);
    sendTokenToServer(token);
  });

  // Handle incoming notification (foreground)
  PushNotifications.addListener(
    'pushNotificationReceived',
    (notification: PushNotificationSchema) => {
      console.log('Notification received:', notification.title);
    }
  );

  // Handle tap on notification
  PushNotifications.addListener(
    'pushNotificationActionPerformed',
    (action: ActionPerformed) => {
      const { data } = action.notification;
      router.push(data.route);
    }
  );
}
```

### File System
```ts
import { Filesystem, Directory, Encoding } from '@capacitor/filesystem';

// Write a file
await Filesystem.writeFile({
  path: 'data/notes.json',
  data: JSON.stringify({ notes: [] }),
  directory: Directory.Documents,
  encoding: Encoding.UTF8,
  recursive: true, // create directories
});

// Read a file
const result = await Filesystem.readFile({
  path: 'data/notes.json',
  directory: Directory.Documents,
  encoding: Encoding.UTF8,
});
const notes = JSON.parse(result.data as string);

// Delete a file
await Filesystem.deleteFile({
  path: 'data/notes.json',
  directory: Directory.Documents,
});
```

### Geolocation
```ts
import { Geolocation } from '@capacitor/geolocation';

async function getCurrentPosition() {
  const permission = await Geolocation.requestPermissions();
  if (permission.location !== 'granted') throw new Error('Location denied');

  const position = await Geolocation.getCurrentPosition({
    enableHighAccuracy: true,
    timeout: 10000,
  });

  return {
    lat: position.coords.latitude,
    lng: position.coords.longitude,
    accuracy: position.coords.accuracy,
  };
}

// Watch position
const watchId = await Geolocation.watchPosition(
  { enableHighAccuracy: true },
  (position) => {
    if (position) updateMapMarker(position.coords);
  }
);

// Stop watching
await Geolocation.clearWatch({ id: watchId });
```

### Custom Native Plugin
```ts
// src/plugins/SecureStorage.ts
import { registerPlugin } from '@capacitor/core';

export interface SecureStoragePlugin {
  set(options: { key: string; value: string }): Promise<void>;
  get(options: { key: string }): Promise<{ value: string | null }>;
  remove(options: { key: string }): Promise<void>;
}

export const SecureStorage = registerPlugin<SecureStoragePlugin>('SecureStorage', {
  // Web fallback using localStorage
  web: {
    set: async ({ key, value }) => { localStorage.setItem(key, value); },
    get: async ({ key }) => ({ value: localStorage.getItem(key) }),
    remove: async ({ key }) => { localStorage.removeItem(key); },
  },
});
```

### Live Reload During Development
```bash
# Start dev server with your IP (not localhost)
npx vite --host 0.0.0.0

# Update capacitor.config.ts temporarily:
# server: { url: 'http://YOUR_IP:5173', cleartext: true }

npx cap sync && npx cap run ios
```

## Common Pitfalls
- **`npx cap sync` after every build**: forgetting to sync means the native app runs stale web assets — always sync before running
- **iOS requires HTTPS or localhost**: cleartext HTTP only works if `cleartext: true` is in the config; production builds must use HTTPS
- **Permissions must be declared in native manifests**: Camera, location, etc. require entries in `Info.plist` (iOS) and `AndroidManifest.xml` — plugins add these automatically but check after manual config changes
- **Android minSdk is 23+**: Capacitor 5+ requires Android API 23; set `minSdk=23` in `android/variables.gradle`
- **WebView localStorage is NOT the same as native storage**: use `@capacitor/preferences` (not localStorage) for data that must persist across app updates

## Related Skills
- `expo-router` — Expo alternative for React Native
- `react-native-best-practices` — native-first alternative
- `react-native-reanimated` — if migrating to fully native

## GitNexus Index
```
domain: mobile
tier: framework
runtime: ios,android,browser
language: ts,js
framework: react,vue,angular,svelte
purpose: native-bridge
```
