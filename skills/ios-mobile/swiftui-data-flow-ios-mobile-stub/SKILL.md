---
name: swiftui-data-flow-ios-mobile-stub
description: Master SwiftUI data flow patterns — @State, @Binding, @ObservableObject, @EnvironmentObject, the Observation framework, and reactive UI updates — with guidance on choosing the right tool for each situation.
tags: [swiftui, ios, swift, data-flow, reactive]
version: 1.0.0
---

## Overview

SwiftUI's data flow determines how state changes propagate through your view hierarchy. Choose the wrong pattern and you get either excessive re-renders, broken two-way data flow, or leaked objects. This skill covers every official pattern from simple local state to cross-app environment injection.

## When to Use

- Deciding between `@State`, `@Binding`, `@ObservableObject`, or `@Observable` for a new view
- Debugging missing UI updates (view not refreshing when data changes)
- Preventing excessive re-renders causing jank or battery drain
- Sharing state between unrelated views without prop-drilling
- Migrating from `ObservableObject`/`@Published` to the Swift 5.9 Observation framework

## Pattern Selection Guide

| Pattern | Scope | Direction | Use when |
|---------|-------|-----------|---------|
| `@State` | Local to view | Read/write | Ephemeral UI state (toggle, text field, sheet) |
| `@Binding` | Parent → child | Two-way | Child needs to mutate parent's state |
| `@StateObject` | Local object lifetime | Read/write | View owns the object; created once |
| `@ObservedObject` | Injected object | Read/write | Object is owned elsewhere, passed in |
| `@EnvironmentObject` | Implicit DI | Read/write | Shared across unrelated subtree |
| `@Environment` | Key-path access | Read-only | System values (colorScheme, dismiss, locale) |
| `@Observable` (iOS 17+) | Any object | Read/write | New code; replaces ObservableObject |

## @State — Local View State

```swift
struct CounterView: View {
    @State private var count = 0         // owned by this view, persists across re-renders
    @State private var isPresented = false

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
            Button("Show Sheet") { isPresented = true }
        }
        .sheet(isPresented: $isPresented) {
            SheetView()
        }
    }
}
```

Rule: always `private`. Never pass `@State` directly to a child — pass `$count` (Binding) instead.

## @Binding — Two-Way Parent/Child Data Flow

```swift
struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool     // no $ here — binding is the value

    var body: some View {
        Toggle(label, isOn: $isOn)   // $ creates a Binding<Bool> from the Binding
    }
}

// Parent:
struct SettingsView: View {
    @State private var notificationsEnabled = true

    var body: some View {
        ToggleRow(label: "Notifications", isOn: $notificationsEnabled)
    }
}
```

## @StateObject and @ObservedObject

```swift
// ViewModel — iOS 13-16 pattern
class CartViewModel: ObservableObject {
    @Published var items: [CartItem] = []
    @Published var total: Double = 0

    func addItem(_ item: CartItem) {
        items.append(item)
        total += item.price
    }
}

// View that OWNS the ViewModel — use @StateObject
// @StateObject creates the object once and survives parent re-renders
struct CartView: View {
    @StateObject private var viewModel = CartViewModel()

    var body: some View {
        List(viewModel.items) { item in
            CartRow(item: item)
        }
        Text("Total: \(viewModel.total, format: .currency(code: "USD"))")
    }
}

// View that RECEIVES the ViewModel — use @ObservedObject
struct CartSummaryView: View {
    @ObservedObject var viewModel: CartViewModel   // doesn't own it

    var body: some View {
        Text("\(viewModel.items.count) items")
    }
}
```

**Critical distinction**: `@StateObject` initializes exactly once. `@ObservedObject` re-creates if the parent re-renders — use it only when the object is guaranteed to outlive the parent.

## @EnvironmentObject — Implicit Dependency Injection

```swift
// Model
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var theme: AppTheme = .light
}

// Root — inject once
@main
struct MyApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)   // available to ALL descendants
        }
    }
}

// Any descendant — consume without passing through intermediaries
struct ProfileBadge: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let user = appState.currentUser {
            Image(user.avatarURL)
        }
    }
}
```

Caveat: crashes at runtime if the object isn't injected. Use for truly app-wide state (auth, theme, cart) — not per-screen models.

## @Observable — Swift 5.9+ (iOS 17+)

The Observation framework replaces `ObservableObject`/`@Published`. SwiftUI only re-renders when properties accessed in `body` change, giving finer-grained invalidation.

```swift
import Observation

@Observable
class UserProfile {
    var name: String = ""
    var bio: String = ""
    var followerCount: Int = 0   // changing this won't re-render a view that only reads `name`
}

// No @StateObject/@ObservedObject needed — use plain @State or let
struct ProfileView: View {
    @State private var profile = UserProfile()
    // OR if injected from parent:
    // let profile: UserProfile

    var body: some View {
        VStack {
            Text(profile.name)    // view subscribes only to `name`
            TextField("Name", text: $profile.name)
        }
    }
}
```

**@Bindable** — for two-way bindings with @Observable objects:
```swift
struct EditProfileView: View {
    @Bindable var profile: UserProfile   // creates bindings to @Observable properties

    var body: some View {
        TextField("Name", text: $profile.name)
        TextField("Bio", text: $profile.bio)
    }
}
```

## @Environment — System Values and Custom Keys

```swift
// Reading system environment values
struct AdaptiveText: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var typeSize
    @Environment(\.locale) var locale

    var body: some View {
        Text(colorScheme == .dark ? "Dark" : "Light")
    }
}

// Custom environment key
struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .light
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// Inject:
ContentView().environment(\.appTheme, .dark)
// Read:
@Environment(\.appTheme) var theme
```

## Debugging Missing UI Updates

**Symptom**: data changed but UI didn't update.

```swift
// ❌ Wrong — mutating a struct inside a class without @Published
class Store: ObservableObject {
    var cart = Cart()   // Cart is a struct; mutations to cart.items DON'T trigger updates

    func addItem(_ item: Item) {
        cart.items.append(item)   // no @Published = no update
    }
}

// ✅ Fix 1: @Published on the property
class Store: ObservableObject {
    @Published var cart = Cart()
}

// ✅ Fix 2: Call objectWillChange manually for complex mutations
func bulkUpdate() {
    objectWillChange.send()
    cart.items = computeNewItems()
}
```

**Symptom**: too many re-renders / view flickers.

```swift
// ❌ Wrong — whole parent re-renders when any @Published property changes
class ViewModel: ObservableObject {
    @Published var name = ""
    @Published var count = 0   // changing count re-renders name-displaying views too
}

// ✅ Fix with @Observable — granular invalidation per property accessed
@Observable class ViewModel {
    var name = ""
    var count = 0   // only views reading `count` re-render
}
```

## Common Pitfalls

- **Using `@ObservedObject` where `@StateObject` is needed**: object gets destroyed and recreated when parent re-renders, losing state.
- **Mutating @State from a non-main thread**: crashes. Always `DispatchQueue.main.async` or use `@MainActor`.
- **Reference types inside `@State`**: `@State` tracks identity, not content. Use `@StateObject` for classes.
- **Forgetting `.environmentObject()` in previews**: `PreviewProvider` must also inject environment objects.
- **Deriving too much in `body`**: expensive computation in `body` runs on every render. Cache in `@State` or ViewModel.

## Related Skills

- `ios-swiftui-expert` — advanced SwiftUI patterns and architecture
- `swift-concurrency-expert` — async/await, actors, and MainActor with SwiftUI
- `swiftdata-expert` — SwiftData persistence integrated with SwiftUI data flow
