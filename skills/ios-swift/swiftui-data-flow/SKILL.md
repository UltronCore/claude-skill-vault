---
name: swiftui-data-flow
description: Master SwiftUI data flow patterns — @State, @Binding, @ObservableObject, @EnvironmentObject, the Observation framework (@Observable), and reactive UI updates. Covers ownership rules, performance optimization, and migration from ObservableObject to Observable.
version: 1.0.0
tags: [swiftui, ios, data-flow, state-management, observation, combine, reactive, swift]
---

# SwiftUI Data Flow

## Overview

SwiftUI is a declarative UI framework where the view is a function of its state — any state change automatically triggers a view update. Choosing the right property wrapper is the most critical architectural decision in a SwiftUI app: use the wrong one and you'll get either stale UI or unnecessary re-renders. iOS 17 introduced the `@Observable` macro as the modern replacement for `ObservableObject`/`@Published`, reducing boilerplate and improving performance by tracking only the properties a view actually reads.

## When to Use

- Building new iOS/macOS SwiftUI screens and need to choose the right property wrapper
- Debugging views that aren't updating when data changes, or updating too frequently
- Migrating an existing `ObservableObject`/`@Published` model to `@Observable`
- Passing data between views — deciding between `@Binding`, `@EnvironmentObject`, or navigation
- Optimizing a list or complex screen where too many child views are re-rendering
- Understanding when SwiftUI's `@State` is safe versus when you need an external model object

## Step-by-Step Workflow

### 1. Ownership Rules — Which Wrapper to Use

```swift
// DECISION TREE:
// Is this value owned by THIS view and not shared?
//   → @State (value types: Int, String, Bool, structs)
// Is this a reference to a parent's @State?
//   → @Binding
// Is this a model object shared with multiple views?
//   iOS 17+ → @Observable class + @State (in owner) / direct reference (in children)
//   iOS 16-  → ObservableObject class + @StateObject (in owner) / @ObservedObject (in children)
// Does it need to be accessible across the whole app/subtree?
//   → @EnvironmentObject (iOS 16-) or .environment() with @Observable (iOS 17+)

// src/Features/Counter/CounterView.swift

import SwiftUI

// --- SIMPLE LOCAL STATE ---
struct CounterView: View {
    @State private var count = 0          // Owned by this view, not shared
    @State private var isPresenting = false

    var body: some View {
        VStack {
            Text("\(count)")
            Button("Increment") { count += 1 }
            Button("Details") { isPresenting = true }
                .sheet(isPresented: $isPresenting) {    // $isPresenting = Binding<Bool>
                    DetailView(count: $count)           // Pass binding to child
                }
        }
    }
}

// --- BINDING: child mutates parent's state ---
struct DetailView: View {
    @Binding var count: Int               // Does NOT own this value

    var body: some View {
        Stepper("Count: \(count)", value: $count, in: 0...100)
    }
}
```

### 2. @Observable — The Modern Model Pattern (iOS 17+)

```swift
// src/Models/CartModel.swift
import Observation

@Observable                              // Replaces: class CartModel: ObservableObject
final class CartModel {
    var items: [CartItem] = []           // Replaces: @Published var items: [CartItem] = []
    var discount: Double = 0.0           // All stored properties are automatically tracked
    private var internalCache: [String: CartItem] = [:]  // NOT tracked (private, not read by views)

    var total: Double {
        items.reduce(0) { $0 + $1.price } * (1 - discount)
    }

    func addItem(_ item: CartItem) {
        items.append(item)
        internalCache[item.id] = item    // Mutating private property doesn't trigger updates
    }
}

// src/Features/Cart/CartView.swift
struct CartView: View {
    // In the OWNER view, use @State to manage the lifecycle
    @State private var cart = CartModel()

    var body: some View {
        List(cart.items) { item in
            CartRowView(item: item, cart: cart)  // Pass model reference directly
        }
        Text("Total: \(cart.total, format: .currency(code: "USD"))")
    }
}

// Child view — just reference the model directly (no @ObservedObject needed)
struct CartRowView: View {
    let item: CartItem
    var cart: CartModel                  // SwiftUI tracks which properties this view reads

    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Button("Remove") { cart.items.removeAll { $0.id == item.id } }
        }
        // This view ONLY re-renders when cart.items changes — not cart.discount
    }
}
```

### 3. ObservableObject Pattern — iOS 16 Compatible

```swift
// src/Models/UserSettings.swift — iOS 16 and earlier compatible
import Combine
import SwiftUI

class UserSettings: ObservableObject {
    @Published var username: String = ""
    @Published var notificationsEnabled: Bool = true
    @Published var theme: AppTheme = .system

    // Non-published: won't trigger view updates
    private let userDefaults = UserDefaults.standard

    func save() {
        userDefaults.set(username, forKey: "username")
    }
}

// OWNER view: @StateObject (creates and owns the object)
struct SettingsRootView: View {
    @StateObject private var settings = UserSettings()  // Created once, owned here

    var body: some View {
        NavigationStack {
            SettingsFormView(settings: settings)
                .environmentObject(settings)            // Inject into environment
        }
    }
}

// CHILD view that receives the object: @ObservedObject (does NOT own it)
struct SettingsFormView: View {
    @ObservedObject var settings: UserSettings          // Does not create or destroy

    var body: some View {
        Form {
            TextField("Username", text: $settings.username)
            Toggle("Notifications", isOn: $settings.notificationsEnabled)
        }
    }
}

// DEEPLY NESTED view: @EnvironmentObject (no parameter passing needed)
struct NotificationBadge: View {
    @EnvironmentObject var settings: UserSettings       // Pulled from environment

    var body: some View {
        if settings.notificationsEnabled {
            Image(systemName: "bell.badge")
        }
    }
}
```

### 4. Environment Values and Custom Keys

```swift
// src/Environment/AppEnvironment.swift
import SwiftUI

// Step 1: Define the key
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

// Step 2: Extend EnvironmentValues
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// Step 3: Inject at the root
struct RootApp: App {
    @State private var theme: AppTheme = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appTheme, theme)
                .environment(\.colorScheme, theme.colorScheme)
        }
    }
}

// Step 4: Read anywhere in the subtree
struct ThemedButton: View {
    @Environment(\.appTheme) var theme

    var body: some View {
        Button("Tap") { }
            .tint(theme.accentColor)
    }
}
```

## Key Commands Reference

```swift
// Property wrapper cheat sheet
@State              // Owned value, local to this view
@Binding            // Reference to parent's @State (prefix with $)
@StateObject        // Owned ObservableObject, created once (iOS 16-)
@ObservedObject     // Shared ObservableObject reference (iOS 16-)
@EnvironmentObject  // Shared ObservableObject from environment (iOS 16-)
@Observable         // Modern class observation (iOS 17+, replaces ObservableObject)
@Environment(\.key) // Read environment values (built-in or custom)

// Binding creation patterns
$someState                      // Binding to @State var
$model.property                 // Binding to @Published/@Observable property
Binding(get: { }, set: { _ in }) // Manual binding (computed derived state)
.constant(42)                   // Immutable binding (for previews/testing)

// Debugging re-renders (add to view body)
let _ = Self._printChanges()    // Prints which property caused the re-render

// Check if @Observable is tracking the right property
// Access in body → tracked. Access in init/deinit → NOT tracked.
```

## Common Patterns

### Pattern 1: Dependency Injection with @Observable (iOS 17+)

```swift
// Inject model objects via .environment() — type-safe, no key needed
struct AppRoot: App {
    @State private var authModel = AuthModel()
    @State private var cartModel = CartModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authModel)    // Inject @Observable objects
                .environment(cartModel)
        }
    }
}

// Retrieve with @Environment and the TYPE (not a key path)
struct CheckoutView: View {
    @Environment(CartModel.self) private var cart
    @Environment(AuthModel.self) private var auth

    var body: some View {
        if auth.isLoggedIn {
            Text("Items: \(cart.items.count)")
        }
    }
}
```

### Pattern 2: Derived State with onChange and Computed Properties

```swift
struct SearchView: View {
    @State private var searchText = ""
    @State private var debouncedText = ""
    @State private var results: [SearchResult] = []

    // Computed property — automatically updates when searchText changes
    // No extra @State needed for simple transformations
    var trimmedQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack {
            TextField("Search", text: $searchText)
                .onChange(of: searchText) { _, newValue in
                    // Debounce: only update debouncedText after 0.3s quiet period
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        if searchText == newValue {   // Still the same value?
                            debouncedText = newValue
                        }
                    }
                }
                .onChange(of: debouncedText) {
                    Task { results = await performSearch(debouncedText) }
                }
            List(results) { result in SearchResultRow(result: result) }
        }
    }
}
```

### Pattern 3: Sharing State Across Unrelated Views

```swift
// Pattern for sharing state between views that are not parent-child
// (e.g., tab bar items, sibling views)

@Observable
final class AppState {
    var selectedTab: Tab = .home
    var unreadCount: Int = 0
    var isLoading: Bool = false
}

// In the scene root
struct MainTabView: View {
    @State private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)
            InboxView()
                .badge(appState.unreadCount)  // Reactive badge
                .tabItem { Label("Inbox", systemImage: "envelope") }
                .tag(Tab.inbox)
        }
        .environment(appState)
    }
}

// Both HomeView and InboxView can update unreadCount
// and both will reflect the change — no prop drilling
struct InboxView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List { /* ... */ }
            .task { appState.unreadCount = await fetchUnreadCount() }
    }
}
```

## Pitfalls to Avoid

1. **Using @StateObject in child views**: `@StateObject` creates a new instance and manages its lifetime — if you use it in a child view (which gets recreated often), the object will be torn down and rebuilt unexpectedly. Use `@StateObject` only in the view that owns the model (typically the root), and pass it down as `@ObservedObject` or via the environment. With `@Observable`, you use `@State` in the owner and just reference the model directly in children.

2. **Forgetting that @Binding is a two-way channel**: A `@Binding` is a reference to the source of truth, not a copy. Writing to a `@Binding` mutates the parent's data. If you only need to READ the parent's data in a child view, accept it as a `let` constant — don't use `@Binding` just because it's from the parent. Unnecessary bindings create implicit coupling and make views harder to preview and test.

3. **Over-relying on @EnvironmentObject for everything**: Injecting every model into the environment creates invisible dependencies — a view compiles fine but crashes at runtime if the environment object isn't provided. Prefer explicit parameters or `@Observable` with `.environment()` for type safety. Reserve `@EnvironmentObject` for truly app-wide concerns (authentication state, theme, locale settings).

## Related Skills

- `ios-swiftui-expert` — Advanced SwiftUI patterns and best practices
- `swift-concurrency-expert` — async/await integration with SwiftUI
- `swiftdata-expert` — SwiftData persistence with SwiftUI
- `swiftui-performance-audit` — Diagnosing and fixing SwiftUI re-render issues

## GitNexus Index

```json
{
  "skill": "swiftui-data-flow",
  "category": "ios",
  "triggers": ["SwiftUI data flow", "@State binding", "@Observable migration", "ObservableObject SwiftUI", "@EnvironmentObject", "SwiftUI state management", "@StateObject vs @ObservedObject", "SwiftUI re-render", "Observation framework iOS 17", "property wrapper SwiftUI"],
  "outputs": ["@State", "@Binding", "@Observable", "@StateObject", "@ObservedObject", "@EnvironmentObject", "EnvironmentKey", ".environment()", "Self._printChanges()", "onChange(of:)"],
  "complexity": "medium",
  "tools": ["swift", "swiftui", "xcode", "ios", "combine", "observation-framework"]
}
```
