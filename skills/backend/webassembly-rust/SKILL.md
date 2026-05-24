---
name: webassembly-rust
description: Compile Rust code to WebAssembly for high-performance browser and server-side WASM modules. Covers wasm-pack, wasm-bindgen, JavaScript interop, web workers, WASI for server-side WASM, and performance optimization for CPU-intensive browser workloads.
version: 1.0.0
tags: [webassembly, wasm, rust, wasm-bindgen, wasm-pack, wasi, web-workers, javascript-interop, performance]
---

# WebAssembly Rust

## Overview

Rust compiles to WebAssembly via `wasm-pack` and `wasm-bindgen`, producing near-native-speed modules that run in any browser or WASI runtime. The combination delivers predictable performance (no GC pauses), fine-grained memory control, and safe multi-threading — making it the right choice for image/audio processing, cryptography, simulation, and any computation that JavaScript handles too slowly. WASM modules are sandboxed by design and can be instantiated in Web Workers for true parallelism.

## When to Use

- CPU-bound browser workloads: image processing, codec decoding, physics simulation, encryption
- Sharing business logic between Rust backend and browser frontend without rewriting
- WASI server-side modules that must run in any runtime (Wasmtime, WasmEdge, Fastly Compute, Cloudflare Workers)
- Performance-critical inner loops where JavaScript's JIT variability is unacceptable
- Cryptography: audited Rust crates running in-browser without server round-trips
- Legacy C/C++ libraries ported to Rust, then compiled to WASM for web delivery

## Step-by-Step Workflow

### 1. Project Setup with wasm-pack

```bash
# Install Rust and wasm toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-unknown-unknown
cargo install wasm-pack
cargo install cargo-watch

# Scaffold a new WASM library
cargo new --lib my-wasm-lib
cd my-wasm-lib
```

```toml
# Cargo.toml
[package]
name = "my-wasm-lib"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]  # cdylib for WASM, rlib for native tests

[dependencies]
wasm-bindgen = "0.2"
js-sys = "0.3"
web-sys = { version = "0.3", features = [
    "console",
    "Window",
    "Document",
    "HtmlCanvasElement",
    "CanvasRenderingContext2d",
    "ImageData",
]}
serde = { version = "1.0", features = ["derive"] }
serde-wasm-bindgen = "0.6"
getrandom = { version = "0.2", features = ["js"] }

[dev-dependencies]
wasm-bindgen-test = "0.3"

[profile.release]
opt-level = 3
lto = true         # Link-time optimization (reduces size)
panic = "abort"    # Removes unwinding code (reduces size)
```

### 2. Rust Functions Exported to JavaScript

```rust
// src/lib.rs
use wasm_bindgen::prelude::*;
use js_sys::Uint8ClampedArray;
use web_sys::ImageData;

// #[wasm_bindgen] generates JS bindings automatically
#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

// Returning complex types — use serde for JSON-compatible structs
use serde::{Deserialize, Serialize};

#[wasm_bindgen]
#[derive(Serialize, Deserialize)]
pub struct Stats {
    pub mean: f64,
    pub std_dev: f64,
    pub min: f64,
    pub max: f64,
    pub count: usize,
}

#[wasm_bindgen]
impl Stats {
    // Methods on exported structs are callable from JS
    pub fn describe(&self) -> String {
        format!(
            "n={}, mean={:.2}, std={:.2}, range=[{:.2}, {:.2}]",
            self.count, self.mean, self.std_dev, self.min, self.max
        )
    }
}

#[wasm_bindgen]
pub fn compute_stats(data: &[f64]) -> Stats {
    let n = data.len();
    if n == 0 {
        return Stats { mean: 0.0, std_dev: 0.0, min: 0.0, max: 0.0, count: 0 };
    }
    let mean = data.iter().sum::<f64>() / n as f64;
    let variance = data.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / n as f64;
    let min = data.iter().cloned().fold(f64::INFINITY, f64::min);
    let max = data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    Stats { mean, std_dev: variance.sqrt(), min, max, count: n }
}

// Image processing: manipulate raw pixel data (RGBA)
#[wasm_bindgen]
pub fn grayscale(pixels: &mut [u8]) {
    // pixels is RGBA: [r, g, b, a, r, g, b, a, ...]
    for chunk in pixels.chunks_mut(4) {
        let gray = (0.299 * chunk[0] as f32
            + 0.587 * chunk[1] as f32
            + 0.114 * chunk[2] as f32) as u8;
        chunk[0] = gray;
        chunk[1] = gray;
        chunk[2] = gray;
        // chunk[3] = alpha, unchanged
    }
}

#[wasm_bindgen]
pub fn gaussian_blur(pixels: &[u8], width: u32, height: u32, radius: u32) -> Vec<u8> {
    let mut output = pixels.to_vec();
    let sigma = radius as f32 / 3.0;
    // Separable Gaussian kernel
    let kernel = gaussian_kernel(radius as usize, sigma);

    // Horizontal pass
    for y in 0..height {
        for x in 0..width {
            let mut r = 0.0f32;
            let mut g = 0.0f32;
            let mut b = 0.0f32;
            let mut weight_sum = 0.0f32;
            for (i, &w) in kernel.iter().enumerate() {
                let kx = x as i32 + i as i32 - radius as i32;
                if kx >= 0 && kx < width as i32 {
                    let idx = (y * width + kx as u32) as usize * 4;
                    r += pixels[idx] as f32 * w;
                    g += pixels[idx + 1] as f32 * w;
                    b += pixels[idx + 2] as f32 * w;
                    weight_sum += w;
                }
            }
            let idx = (y * width + x) as usize * 4;
            output[idx] = (r / weight_sum) as u8;
            output[idx + 1] = (g / weight_sum) as u8;
            output[idx + 2] = (b / weight_sum) as u8;
        }
    }
    output
}

fn gaussian_kernel(radius: usize, sigma: f32) -> Vec<f32> {
    let size = 2 * radius + 1;
    let mut kernel = vec![0.0f32; size];
    for i in 0..size {
        let x = i as f32 - radius as f32;
        kernel[i] = (-x * x / (2.0 * sigma * sigma)).exp();
    }
    kernel
}

// Log to browser console
#[wasm_bindgen]
pub fn init_panic_hook() {
    // Better panic messages in browser DevTools
    console_error_panic_hook::set_once();
}
```

### 3. Build and Bundle

```bash
# Build for web (ES modules)
wasm-pack build --target web --out-dir pkg

# Build for bundlers (webpack/vite)
wasm-pack build --target bundler --out-dir pkg

# Build for Node.js
wasm-pack build --target nodejs --out-dir pkg

# Output: pkg/
#   my_wasm_lib_bg.wasm   — compiled WASM binary
#   my_wasm_lib.js        — JS bindings (glue code)
#   my_wasm_lib.d.ts      — TypeScript types
#   package.json          — ready to publish to npm

# Release build (optimized, ~40-80% smaller)
wasm-pack build --release --target web

# Optimize WASM size further with wasm-opt (from binaryen)
brew install binaryen
wasm-opt -Oz -o pkg/my_wasm_lib_bg_opt.wasm pkg/my_wasm_lib_bg.wasm
```

### 4. JavaScript / TypeScript Integration

```typescript
// Vite / webpack project — import WASM like an npm package
// vite.config.ts: enable wasm plugin
import { defineConfig } from "vite";
import wasm from "vite-plugin-wasm";
import topLevelAwait from "vite-plugin-top-level-await";

export default defineConfig({
  plugins: [wasm(), topLevelAwait()],
});

// main.ts
import init, { compute_stats, grayscale } from "./pkg/my_wasm_lib.js";

async function run() {
  // Initialize the WASM module (loads and compiles the .wasm binary)
  await init();

  // Now call exported Rust functions as regular JS functions
  const data = new Float64Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  const stats = compute_stats(data);
  console.log(stats.describe()); // "n=10, mean=5.50, std=2.87, range=[1.00, 10.00]"

  // Image processing
  const canvas = document.getElementById("canvas") as HTMLCanvasElement;
  const ctx = canvas.getContext("2d")!;
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const pixels = imageData.data; // Uint8ClampedArray — shared memory!

  grayscale(pixels); // Rust modifies pixels in place (zero-copy!)
  ctx.putImageData(imageData, 0, 0);
}

run();
```

### 5. Web Workers for Parallel WASM

```typescript
// worker.ts — run WASM in a worker thread (true parallelism)
import init, { gaussian_blur } from "./pkg/my_wasm_lib.js";

let wasmInitialized = false;

self.onmessage = async (event: MessageEvent) => {
  const { pixels, width, height, radius } = event.data;

  if (!wasmInitialized) {
    await init();
    wasmInitialized = true;
  }

  // Heavy computation off the main thread
  const result = gaussian_blur(pixels, width, height, radius);

  // Transfer the ArrayBuffer back (zero-copy transfer)
  self.postMessage({ result }, [result.buffer]);
};

// main.ts — spawn the worker
const worker = new Worker(new URL("./worker.ts", import.meta.url), { type: "module" });

async function blurImage(imageData: ImageData, radius: number): Promise<Uint8Array> {
  return new Promise((resolve) => {
    worker.onmessage = (e) => resolve(e.data.result);
    worker.postMessage(
      {
        pixels: imageData.data,
        width: imageData.width,
        height: imageData.height,
        radius,
      },
      [imageData.data.buffer] // Transfer ownership (avoids copy)
    );
  });
}
```

### 6. WASI Server-Side WASM

```rust
// src/bin/server_module.rs — WASI binary (no browser APIs)
// Compile: cargo build --target wasm32-wasi --release

use std::io::{self, Read, Write};

fn main() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();

    // Process input (e.g., JSON transformation)
    let result = process(&input);
    io::stdout().write_all(result.as_bytes()).unwrap();
}

fn process(input: &str) -> String {
    // Parse and transform — pure computation, no I/O side effects
    let trimmed = input.trim();
    format!("Processed: {} ({} chars)", trimmed, trimmed.len())
}
```

```bash
# Install Wasmtime
curl https://wasmtime.dev/install.sh -sSf | bash

# Compile to WASI
cargo build --target wasm32-wasi --release

# Run with Wasmtime
echo "hello world" | wasmtime target/wasm32-wasi/release/server_module.wasm

# Run in Cloudflare Workers (Wrangler)
wrangler publish --compatibility-flags="experimental:nodejs_compat"
```

## Key Commands Reference

```bash
# Initial setup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add wasm32-unknown-unknown wasm32-wasi
cargo install wasm-pack wasm-opt

# Build commands
wasm-pack build --target web              # ES module output
wasm-pack build --target bundler         # Webpack/Vite bundler
wasm-pack build --release --target web  # Optimized release
wasm-opt -Oz -o out_opt.wasm out.wasm    # Compress further

# Run Rust tests that run in the browser (headless)
wasm-pack test --headless --firefox
wasm-pack test --headless --chrome

# Check WASM binary size
ls -lh pkg/*.wasm
wasm-objdump -h pkg/my_wasm_lib_bg.wasm | grep "Section"

# Profile Rust in browser (requires wasm-profiler)
cargo install wasm-profiler
# Chrome DevTools → Performance → Load profile

# Wasmtime
cargo install wasmtime-cli
wasmtime run --wasm-features all target/wasm32-wasi/release/app.wasm

# Check WASM exports
wasm-nm pkg/my_wasm_lib_bg.wasm

# Watch mode for development
cargo watch -x "build --target wasm32-unknown-unknown" -s "wasm-pack build"
```

## Common Patterns

### Pattern 1: Zero-Copy Shared Memory with js_sys

```rust
// Pass large data between JS and WASM without copying
use wasm_bindgen::prelude::*;
use js_sys::Float64Array;

#[wasm_bindgen]
pub struct WasmBuffer {
    data: Vec<f64>,
}

#[wasm_bindgen]
impl WasmBuffer {
    pub fn new(size: usize) -> WasmBuffer {
        WasmBuffer { data: vec![0.0; size] }
    }

    // Expose a view into WASM memory — no copy, JS sees the same bytes
    pub fn as_js_array(&self) -> Float64Array {
        unsafe {
            Float64Array::view(&self.data)
        }
    }

    pub fn fill_with_computation(&mut self) {
        for (i, v) in self.data.iter_mut().enumerate() {
            *v = (i as f64).sin();
        }
    }

    pub fn get_sum(&self) -> f64 {
        self.data.iter().sum()
    }
}
```

### Pattern 2: Async Rust Exported to JS

```rust
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, Response};

#[wasm_bindgen]
pub async fn fetch_and_process(url: String) -> Result<String, JsValue> {
    let opts = RequestInit::new();
    opts.set_method("GET");
    let request = Request::new_with_str_and_init(&url, &opts)?;

    let window = web_sys::window().unwrap();
    let resp_value = JsFuture::from(window.fetch_with_request(&request)).await?;
    let resp: Response = resp_value.dyn_into()?;
    let text = JsFuture::from(resp.text()?).await?;

    Ok(format!("Fetched: {} bytes", text.as_string().unwrap_or_default().len()))
}
```

### Pattern 3: WASM Module Caching

```typescript
// Cache the initialized WASM module to avoid re-initialization cost
let wasmModule: typeof import("./pkg/my_wasm_lib.js") | null = null;

async function getWasm() {
  if (!wasmModule) {
    const mod = await import("./pkg/my_wasm_lib.js");
    await mod.default(); // Call init()
    wasmModule = mod;
  }
  return wasmModule;
}

// Usage
const wasm = await getWasm();
const stats = wasm.compute_stats(new Float64Array([1, 2, 3]));
```

## Pitfalls to Avoid

1. **Copying large arrays instead of transferring**: Passing a 10 MB `Uint8Array` from JS to WASM copies it by default. For large data, either use `WasmBuffer` with shared memory views (unsafe but zero-copy) or use `Transferable` objects with `postMessage([data], [data.buffer])` in web workers. Always profile memory bandwidth in DevTools before assuming performance is compute-bound.

2. **Blocking the main thread with heavy WASM**: Even though WASM is fast, a 200ms WASM computation still freezes the UI if run on the main thread. Any computation that takes more than ~5ms should move to a Web Worker. Initialize the WASM module in the worker on startup (pays the compile cost once) and use `postMessage` with `Transferable` buffers.

3. **Panic messages invisible in production**: By default, WASM panics produce unhelpful "unreachable executed" errors in the browser console. Always call `console_error_panic_hook::set_once()` in your init function and add the crate to `Cargo.toml` (`console_error_panic_hook = "0.1"`). In development, also enable source maps: `RUSTFLAGS="-C debuginfo=2" wasm-pack build`.

## Related Skills

- `rust-systems-programming` — Rust fundamentals, ownership, lifetimes, and concurrency
- `edge-computing-patterns` — Deploying WASM modules to Cloudflare Workers and Fastly
- `computer-vision` — Image processing pipelines that benefit from WASM acceleration
- `webassembly-rust` is also referenced by `wasm-integration` for integration testing patterns

## GitNexus Index

```json
{
  "skill": "webassembly-rust",
  "category": "backend",
  "triggers": ["webassembly rust", "wasm-pack", "wasm-bindgen", "rust wasm", "wasi", "wasm web worker", "compile rust to browser", "wasm image processing"],
  "outputs": ["Rust WASM library", "wasm-pack build", "TypeScript WASM bindings", "Web Worker WASM", "WASI binary"],
  "complexity": "high",
  "tools": ["rust", "wasm-pack", "wasm-bindgen", "wasm-opt", "wasmtime", "vite", "typescript"]
}
```
