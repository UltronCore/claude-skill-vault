---
name: rust-systems-programming
description: Write production-quality Rust code for systems, CLIs, network services, and performance-critical applications. Covers ownership patterns, async runtimes, error handling, and unsafe code.
version: 1.0.0
tags: [rust, systems, cli, async, tokio, performance, memory-safety]
---

# Rust Systems Programming

## Overview

This skill covers idiomatic Rust for systems-level programming: ownership mastery, async/await with Tokio, zero-cost abstractions, FFI for C interop, and safe/unsafe patterns. It applies to CLIs, embedded systems, network daemons, game engines, and any performance-critical application where memory safety without a GC is required.

## When to Use

- Building a high-performance CLI tool replacing a Python/Go equivalent
- Writing a network service requiring <1ms p99 latency
- Systems-level code that must compile to bare metal or WebAssembly
- Replacing unsafe C code with memory-safe Rust equivalents
- Parsing binary formats or implementing low-level protocols

## Step-by-Step Workflow

### 1. Project Setup
```bash
cargo new --bin myproject && cd myproject
# Or library:
cargo new --lib mylib

# Add common dependencies
cargo add tokio --features full
cargo add serde --features derive
cargo add anyhow thiserror
cargo add clap --features derive
```

### 2. Error Handling Foundation
```rust
use thiserror::Error;
use anyhow::{Context, Result};

#[derive(Debug, Error)]
pub enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Parse error at line {line}: {msg}")]
    Parse { line: usize, msg: String },
    #[error("Network timeout after {seconds}s")]
    Timeout { seconds: u64 },
}

// Application entry point uses anyhow::Result for ergonomics
fn main() -> Result<()> {
    let config = parse_config().context("Failed to parse config")?;
    run(config)?;
    Ok(())
}
```

### 3. Ownership and Borrowing Patterns
```rust
// Prefer borrowing over cloning
fn process(data: &[u8]) -> Result<usize> {
    Ok(data.len())
}

// Use Cow<str> for zero-copy string handling
use std::borrow::Cow;
fn normalize(s: &str) -> Cow<str> {
    if s.contains(' ') {
        Cow::Owned(s.replace(' ', "_"))
    } else {
        Cow::Borrowed(s)
    }
}

// Builder pattern for complex structs
#[derive(Default)]
pub struct Config {
    timeout: u64,
    retries: u32,
    endpoint: String,
}

impl Config {
    pub fn timeout(mut self, t: u64) -> Self { self.timeout = t; self }
    pub fn retries(mut self, r: u32) -> Self { self.retries = r; self }
    pub fn endpoint(mut self, e: impl Into<String>) -> Self {
        self.endpoint = e.into(); self
    }
}
```

### 4. Async with Tokio
```rust
use tokio::net::TcpListener;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

#[tokio::main]
async fn main() -> Result<()> {
    let listener = TcpListener::bind("0.0.0.0:8080").await?;
    loop {
        let (mut socket, addr) = listener.accept().await?;
        tokio::spawn(async move {
            handle_connection(&mut socket, addr).await
                .unwrap_or_else(|e| eprintln!("Error: {e}"));
        });
    }
}

async fn handle_connection(
    socket: &mut tokio::net::TcpStream,
    _addr: std::net::SocketAddr,
) -> Result<()> {
    let mut buf = vec![0u8; 4096];
    let n = socket.read(&mut buf).await?;
    socket.write_all(&buf[..n]).await?; // echo
    Ok(())
}
```

### 5. Performance Profiling
```bash
# CPU profiling with flamegraph
cargo install flamegraph
cargo flamegraph --bin myapp -- [args]

# Benchmarking with criterion
cargo add criterion --dev
# Write bench in benches/my_bench.rs
cargo bench

# Memory analysis
cargo install heaptrack
heaptrack ./target/release/myapp
```

### 6. Testing
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn test_normalize() {
        assert_eq!(normalize("hello world"), "hello_world");
        assert_eq!(normalize("no_spaces"), "no_spaces");
    }

    // Property-based testing
    proptest! {
        #[test]
        fn normalize_idempotent(s in "\\PC*") {
            let once = normalize(&s).to_string();
            let twice = normalize(&once).to_string();
            prop_assert_eq!(once, twice);
        }
    }
}
```

## Key Commands Reference

```bash
# Build and check
cargo check          # Fast type check without binary
cargo build --release
cargo clippy -- -D warnings   # Lint (deny all warnings)
cargo fmt --check            # Format check
cargo doc --open             # Generate and open docs

# Dependency management
cargo tree                   # Dependency tree
cargo audit                  # Check for known vulnerabilities
cargo update                 # Update Cargo.lock
cargo outdated               # Show outdated deps

# Cross compilation
rustup target add x86_64-unknown-linux-musl
cargo build --target x86_64-unknown-linux-musl --release

# WASM compilation
rustup target add wasm32-unknown-unknown
cargo build --target wasm32-unknown-unknown --release
wasm-pack build --target web
```

## Common Patterns

### Pattern 1: Zero-Copy Parsing with nom
```rust
use nom::{bytes::complete::tag, IResult, sequence::preceded};

fn parse_key_value(input: &str) -> IResult<&str, (&str, &str)> {
    use nom::bytes::complete::take_while;
    use nom::sequence::separated_pair;
    use nom::character::complete::char;
    separated_pair(
        take_while(|c: char| c.is_alphanumeric()),
        char('='),
        take_while(|c: char| c != '\n'),
    )(input)
}
```

### Pattern 2: Channel-Based Actor Pattern
```rust
use tokio::sync::mpsc;

enum Message { Process(Vec<u8>), Shutdown }

struct Worker { rx: mpsc::Receiver<Message> }

impl Worker {
    async fn run(&mut self) {
        while let Some(msg) = self.rx.recv().await {
            match msg {
                Message::Process(data) => self.process(data).await,
                Message::Shutdown => break,
            }
        }
    }
    async fn process(&mut self, _data: Vec<u8>) { /* ... */ }
}
```

### Pattern 3: Safe FFI with C Libraries
```rust
// build.rs
fn main() {
    println!("cargo:rustc-link-lib=ssl");
    println!("cargo:rustc-link-lib=crypto");
}

// src/ffi.rs
extern "C" {
    fn RAND_bytes(buf: *mut u8, num: i32) -> i32;
}

pub fn random_bytes(n: usize) -> Vec<u8> {
    let mut buf = vec![0u8; n];
    // Safety: buf is valid for n bytes, RAND_bytes is thread-safe
    let ret = unsafe { RAND_bytes(buf.as_mut_ptr(), n as i32) };
    assert_eq!(ret, 1, "RAND_bytes failed");
    buf
}
```

## Pitfalls to Avoid

1. **Overusing `clone()`**: Cloning defeats zero-copy benefits. Profile with `cargo clippy --all` — look for `needless_clone`. Use references, `Arc<T>`, or `Cow<T>` instead. If cloning in a hot path, redesign ownership.

2. **Blocking in async context**: `std::thread::sleep` in an async fn blocks the Tokio thread pool. Use `tokio::time::sleep` instead. Similarly, `std::fs` blocks — use `tokio::fs`. CPU-bound work goes in `tokio::task::spawn_blocking`.

3. **Ignoring `#[must_use]` on `Result`**: Rust won't panic silently like Python, but you can accidentally ignore errors with `let _ = risky_op()`. Use `?` consistently, and enable `#[deny(unused_must_use)]` in `main.rs`.

## Related Skills

- `wasm-integration` — Compiling Rust to WebAssembly
- `webassembly-rust` — Advanced WASM targeting
- `c-security-review` — Reviewing unsafe Rust and FFI boundaries
- `performance-profiler` — Cross-language profiling
- `grpc-services` — Building high-performance gRPC servers in Rust

## GitNexus Index

```json
{
  "skill": "rust-systems-programming",
  "category": "backend",
  "triggers": ["rust", "cargo", "tokio", "ownership", "borrow checker", "lifetime", "async rust"],
  "outputs": ["production binary", "library crate", "WASM module", "FFI wrapper"],
  "complexity": "high",
  "tools": ["cargo", "rustc", "clippy", "flamegraph", "criterion", "nom", "tokio"]
}
```
