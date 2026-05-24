---
name: wasm-integration
description: Integrate WebAssembly modules into web and server applications — compilation targets, JS/TypeScript bindings, WASI, performance optimization, and toolchain setup. Use when calling Rust/C/C++ code from a browser or Node.js app, or when deploying WASM to edge runtimes.
---

# WebAssembly Integration

WebAssembly (WASM) is a binary instruction format that runs at near-native speed inside a sandboxed virtual machine. It is supported in all modern browsers, Node.js, Deno, Bun, and edge runtimes like Cloudflare Workers. WASM integration covers: compiling source code (Rust, C, C++, Go, AssemblyScript) to `.wasm`, generating JavaScript/TypeScript bindings, loading and calling the module from application code, and managing memory across the JS/WASM boundary.

WASI (WebAssembly System Interface) extends WASM with a standardized syscall layer for filesystem, networking, and environment access — enabling WASM modules to run as portable server-side programs without a browser.

## When to Use

- Calling performance-critical Rust or C code from a browser or Node.js app
- Running existing native libraries in a sandboxed WASM environment
- Deploying compute-intensive logic to edge runtimes (Cloudflare Workers, Fastly, Deno Deploy)
- Using WASI to run portable command-line tools or server logic as WASM modules
- Any task involving `wasm-pack`, `wasm-bindgen`, `Emscripten`, or `wasmtime`
- Optimizing hot paths (image processing, parsing, crypto, math) that JavaScript is too slow for

## Usage

### Rust to WASM with wasm-pack

```bash
# Install toolchain
cargo install wasm-pack
rustup target add wasm32-unknown-unknown

# Create a new library crate
cargo new --lib my-wasm-lib
cd my-wasm-lib
```

`Cargo.toml`:
```toml
[package]
name = "my-wasm-lib"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
```

`src/lib.rs`:
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn fibonacci(n: u32) -> u32 {
    match n {
        0 => 0,
        1 => 1,
        _ => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

#[wasm_bindgen]
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}
```

Build:
```bash
# For bundlers (webpack, vite) — recommended
wasm-pack build --target bundler

# For Node.js
wasm-pack build --target nodejs

# For browser without bundler
wasm-pack build --target web
```

Output: `pkg/` directory with `.wasm`, `.js` glue, and TypeScript `.d.ts` files.

### Consuming in a Vite/React Project

```bash
# In the consuming app
npm install ../my-wasm-lib/pkg
```

```typescript
// src/wasm-example.ts
import init, { fibonacci, greet } from "my-wasm-lib";

// WASM must be initialized asynchronously
await init();

console.log(fibonacci(10));   // 55
console.log(greet("World"));  // "Hello, World!"
```

Vite config (needed for WASM in dev):
```typescript
// vite.config.ts
export default {
  plugins: [],
  optimizeDeps: {
    exclude: ["my-wasm-lib"],
  },
};
```

### Consuming in Node.js

```javascript
// CommonJS
const { fibonacci, greet } = require("my-wasm-lib");
console.log(fibonacci(20)); // 6765

// ESM
import { fibonacci } from "my-wasm-lib";
```

### Loading a Raw WASM File (No Bundler)

```typescript
async function loadWasm(url: string): Promise<WebAssembly.Instance> {
  const response = await fetch(url);
  const buffer = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(buffer, {
    env: {
      memory: new WebAssembly.Memory({ initial: 10 }),  // 640KB
    },
  });
  return instance;
}

const wasm = await loadWasm("/lib/my_module.wasm");
const result = (wasm.exports.add as CallableFunction)(3, 4); // 7
```

### Cloudflare Workers WASM

```typescript
// worker.ts
import wasmModule from "./my_module.wasm";

export default {
  async fetch(request: Request): Promise<Response> {
    const instance = await WebAssembly.instantiate(wasmModule);
    const result = (instance.exports.compute as CallableFunction)(42);
    return new Response(String(result));
  },
};
```

`wrangler.toml`:
```toml
name = "my-worker"
main = "src/worker.ts"
compatibility_date = "2025-01-01"
```

### WASI with Wasmtime (Server-Side)

```bash
# Install wasmtime
curl https://wasmtime.dev/install.sh -sSf | bash

# Compile Rust to WASI target
rustup target add wasm32-wasi
cargo build --target wasm32-wasi --release

# Run with filesystem access
wasmtime --dir=. target/wasm32-wasi/release/my-tool.wasm -- arg1 arg2
```

## Key Patterns

### Memory Management Across the JS/WASM Boundary

WASM memory is a flat `ArrayBuffer`. When passing large data (strings, arrays) between JS and WASM, you must copy into WASM memory and free it:

```typescript
// wasm-bindgen handles this for you with &str and Vec<u8>
// For manual WASM: allocate, copy, call, free

const encoder = new TextEncoder();
const encoded = encoder.encode(inputString);

// Allocate in WASM memory
const ptr = wasm.exports.alloc(encoded.length) as number;
const memory = new Uint8Array((wasm.exports.memory as WebAssembly.Memory).buffer);
memory.set(encoded, ptr);

// Call the function
const result = (wasm.exports.process as CallableFunction)(ptr, encoded.length);

// Free
(wasm.exports.dealloc as CallableFunction)(ptr, encoded.length);
```

With `wasm-bindgen`, this is handled automatically for standard types.

### Streaming Instantiation (Faster Load)

```typescript
// Faster than fetching the full buffer first
const { instance } = await WebAssembly.instantiateStreaming(
  fetch("/my_module.wasm"),
  importObject,
);
```

Only available when the server sets `Content-Type: application/wasm`.

### Feature Detection

```typescript
function wasmSupported(): boolean {
  try {
    if (typeof WebAssembly !== "object") return false;
    const module = new WebAssembly.Module(
      Uint8Array.of(0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00)
    );
    return module instanceof WebAssembly.Module;
  } catch {
    return false;
  }
}
```

## Common Pitfalls

1. **Forgetting to call `init()` before using wasm-bindgen exports.** The generated glue code exports an async `init` function that fetches and instantiates the `.wasm` file. Calling exported functions before awaiting `init()` results in `TypeError: exports.fibonacci is not a function`. Always `await init()` once at app startup.

2. **Passing JS objects directly to WASM functions.** WASM only natively understands `i32`, `i64`, `f32`, `f64`. You cannot pass a JS object or array directly — you must serialize it (JSON → string → pointer, or use wasm-bindgen's `JsValue` type). Attempting to pass a plain object results in the value being coerced to `0` silently.

3. **Serving `.wasm` files with the wrong Content-Type.** `WebAssembly.instantiateStreaming` requires the server to respond with `Content-Type: application/wasm`. If your server sends `application/octet-stream`, streaming instantiation will fail with a `TypeError`. Fall back to `WebAssembly.instantiate` with `response.arrayBuffer()` if you can't control the server headers.

## Related Skills

- `webassembly-rust` — deep Rust→WASM patterns, `wasm-bindgen` advanced usage, `js-sys`/`web-sys`
- `rust-systems-programming` — Rust language fundamentals before compiling to WASM
- `edge-computing-patterns` — deploying WASM to Cloudflare Workers, Fastly Compute
- `deno-runtime` — Deno's first-class WASM and WASI support
- `performance-profiler` — profiling WASM execution with browser DevTools

## GitNexus Index

This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/wasm-integration/.gitnexus
Last indexed: 2026-05-24
