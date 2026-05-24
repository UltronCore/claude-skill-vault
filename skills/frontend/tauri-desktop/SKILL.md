---
name: tauri-desktop
description: Build native desktop apps with Tauri 2.x — using web frontend (React/Vue/Svelte) with a Rust backend. Covers commands, events, file system access, window management, and distribution.
version: 1.0.0
tags: [tauri, desktop, rust, electron-alternative, cross-platform, native, react]
---

# Tauri Desktop Development

## Overview

This skill covers building production desktop applications with Tauri 2.x — the Electron alternative that uses native webviews and a Rust backend instead of bundling Chromium. Tauri apps are 10-100x smaller than Electron, use less RAM, and have direct Rust access to the OS. It covers the full workflow: project setup, frontend/backend communication, file system access, native menus, auto-update, and code signing for distribution.

## When to Use

- Building a desktop app where bundle size matters (Tauri ~5MB vs Electron ~200MB)
- Need native OS integrations (system tray, notifications, file associations)
- Existing web app that needs a desktop wrapper
- Security-conscious apps — Tauri has a security model Electron lacks
- Apps that need high-performance native code (Rust backend)

## Step-by-Step Workflow

### 1. Project Setup
```bash
# Create new Tauri + React + TypeScript project
npm create tauri-app@latest my-app
# Select: TypeScript, React, Vite

cd my-app
npm install
npm run tauri dev  # Start in development mode

# Project structure:
# src/          ← React/web frontend
# src-tauri/    ← Rust backend
#   src/
#     main.rs
#     lib.rs    ← Commands and app logic
#   Cargo.toml
#   tauri.conf.json
```

### 2. Rust Commands (Backend → Frontend Bridge)
```rust
// src-tauri/src/lib.rs
use tauri::Manager;
use std::path::PathBuf;

// Simple command: frontend calls, Rust responds
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

// Async command with error handling
#[tauri::command]
async fn read_config(app: tauri::AppHandle) -> Result<serde_json::Value, String> {
    let config_dir = app.path().app_config_dir()
        .map_err(|e| e.to_string())?;
    
    let config_path = config_dir.join("config.json");
    
    if !config_path.exists() {
        return Ok(serde_json::json!({}));
    }
    
    let content = tokio::fs::read_to_string(&config_path)
        .await
        .map_err(|e| format!("Failed to read config: {e}"))?;
    
    serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse config: {e}"))
}

// Command with state (shared mutable state)
use std::sync::Mutex;

struct AppState {
    counter: Mutex<i32>,
}

#[tauri::command]
fn increment(state: tauri::State<AppState>) -> i32 {
    let mut counter = state.counter.lock().unwrap();
    *counter += 1;
    *counter
}

// Register commands in app builder
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState { counter: Mutex::new(0) })
        .invoke_handler(tauri::generate_handler![
            greet,
            read_config,
            increment,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 3. TypeScript Frontend
```typescript
// src/lib/tauri.ts
import { invoke } from '@tauri-apps/api/core';
import { listen, emit } from '@tauri-apps/api/event';

// Call Rust command
export async function greet(name: string): Promise<string> {
  return invoke('greet', { name });
}

export async function readConfig(): Promise<Record<string, unknown>> {
  return invoke('read_config');
}

// Listen to events from Rust
export function onProgressUpdate(handler: (progress: number) => void) {
  return listen<number>('progress-update', (event) => {
    handler(event.payload);
  });
}

// React hook
import { useState, useEffect } from 'react';

export function useCounter() {
  const [count, setCount] = useState(0);
  
  const increment = async () => {
    const newCount = await invoke<number>('increment');
    setCount(newCount);
  };
  
  return { count, increment };
}
```

### 4. File System Access
```rust
// src-tauri/src/lib.rs
use tauri_plugin_fs::FsExt;

#[tauri::command]
async fn save_document(
    app: tauri::AppHandle,
    content: String,
    filename: String,
) -> Result<String, String> {
    use tauri_plugin_dialog::DialogExt;
    
    let file_path = app.dialog()
        .file()
        .set_file_name(&filename)
        .add_filter("Text Files", &["txt", "md"])
        .save_file()
        .await
        .ok_or("No file selected")?;
    
    tokio::fs::write(&file_path, content)
        .await
        .map_err(|e| e.to_string())?;
    
    Ok(file_path.to_string_lossy().to_string())
}
```

```typescript
// Frontend: drag-and-drop file reading
import { readTextFile, readBinaryFile } from '@tauri-apps/plugin-fs';
import { open } from '@tauri-apps/plugin-dialog';

async function openFile() {
  const path = await open({
    multiple: false,
    filters: [{ name: 'Documents', extensions: ['txt', 'md', 'json'] }],
  });
  
  if (path) {
    const content = await readTextFile(path as string);
    setContent(content);
  }
}
```

### 5. System Tray and Native Menus
```rust
// src-tauri/src/lib.rs
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, TrayIconBuilder, TrayIconEvent},
    Manager,
};

pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let show = MenuItem::with_id(app, "show", "Show Window", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show, &quit])?;
            
            TrayIconBuilder::new()
                .menu(&menu)
                .show_menu_on_left_click(false)
                .icon(app.default_window_icon().unwrap().clone())
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => app.exit(0),
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    _ => {}
                })
                .build(app)?;
            
            Ok(())
        })
        // ...
}
```

### 6. Build and Distribution
```bash
# Build for current platform
npm run tauri build

# tauri.conf.json — configure bundle
{
  "bundle": {
    "active": true,
    "identifier": "com.example.myapp",
    "icon": ["icons/32x32.png", "icons/128x128.png", "icons/icon.icns", "icons/icon.ico"],
    "targets": "all",
    "macOS": {
      "signingIdentity": "Developer ID Application: Name (TEAMID)",
      "providerShortName": "TEAMID",
      "entitlements": "entitlements.plist"
    },
    "windows": {
      "certificateThumbprint": null,
      "digestAlgorithm": "sha256",
      "timestampUrl": ""
    }
  },
  "updater": {
    "active": true,
    "endpoints": ["https://releases.myapp.com/{{target}}/{{arch}}/{{current_version}}"],
    "dialog": true,
    "pubkey": "YOUR_UPDATE_KEY"
  }
}
```

## Key Commands Reference

```bash
# Development
npm run tauri dev           # Hot-reload dev mode
npm run tauri dev -- --features debug  # With debug features

# Building
npm run tauri build         # Production build
npm run tauri build -- --target universal-apple-darwin  # macOS universal binary

# Android/iOS (Tauri Mobile)
npm run tauri android dev
npm run tauri ios dev

# Signing (macOS)
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: ..." \
  src-tauri/target/release/bundle/macos/MyApp.app

# Update public key generation
npm run tauri signer generate -- --password ""
```

## Common Patterns

### Pattern 1: Event Emission from Rust
```rust
// Emit events from long-running Rust operations
#[tauri::command]
async fn process_files(
    app: tauri::AppHandle,
    paths: Vec<String>,
) -> Result<(), String> {
    for (i, path) in paths.iter().enumerate() {
        process_single_file(path)?;
        app.emit("progress", (i + 1) as f64 / paths.len() as f64)
            .map_err(|e| e.to_string())?;
    }
    app.emit("processing-complete", ()).unwrap();
    Ok(())
}

// Frontend listens:
const unlisten = await listen('progress', (e) => setProgress(e.payload as number));
```

### Pattern 2: Window Management
```rust
#[tauri::command]
fn toggle_maximize(window: tauri::WebviewWindow) {
    if window.is_maximized().unwrap_or(false) {
        window.unmaximize().unwrap();
    } else {
        window.maximize().unwrap();
    }
}

// Custom titlebar: hide native, implement in HTML
// tauri.conf.json:
"windows": [{"decorations": false, "titleBarStyle": "Overlay"}]
```

### Pattern 3: Global Keyboard Shortcuts
```rust
use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut};

app.global_shortcut().register(
    Shortcut::new(Some(Modifiers::SUPER), Code::KeyK),
    |app, shortcut, event| {
        if event.state() == ShortcutState::Pressed {
            if let Some(window) = app.get_webview_window("main") {
                window.emit("open-command-palette", ()).unwrap();
            }
        }
    },
)?;
```

## Pitfalls to Avoid

1. **Forgetting Tauri's security allowlist**: By default, Tauri restricts which plugins and commands are available. The `capabilities/` directory controls what the frontend can access. Missing capability → silent failure or panic. Start from the minimal capability and add as needed.

2. **Blocking the main thread in Rust commands**: Heavy computation in a `#[tauri::command]` without `async` blocks the window event loop, freezing the UI. Always use `async` + `tokio` for I/O and CPU work: `tokio::task::spawn_blocking` for CPU-bound, `tokio::fs::*` for file I/O.

3. **Not handling app directory paths correctly**: Never hardcode paths or use `~/` in Rust code. Use `app.path().app_data_dir()`, `app.path().app_config_dir()`, etc. These resolve correctly across all platforms (macOS `~/Library/Application Support/`, Windows `%APPDATA%`, Linux `~/.config/`).

## Related Skills

- `rust-systems-programming` — Rust patterns for the Tauri backend
- `react-best-practices` — React patterns for the Tauri frontend
- `electron-alternative` — When comparing Tauri to Electron

## GitNexus Index

```json
{
  "skill": "tauri-desktop",
  "category": "frontend",
  "triggers": ["tauri", "desktop app", "tauri rust", "electron alternative", "native desktop web", "tauri react"],
  "outputs": ["tauri command", "desktop app bundle", "system tray", "native menu"],
  "complexity": "high",
  "tools": ["tauri", "rust", "cargo", "vite", "react"]
}
```
