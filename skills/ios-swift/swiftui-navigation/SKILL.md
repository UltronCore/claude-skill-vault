---
name: swiftui-navigation
description: >
  SwiftUI NavigationStack deep linking, programmatic navigation, routing patterns,
  and tab coordination for iOS 16+. Triggers on: NavigationStack, NavigationPath,
  navigationDestination, deep link, universal link, .navigationDestination(isPresented:),
  programmatic navigation, sheet coordination.
---

# SwiftUI Navigation — NavigationStack & Routing

## When to Use
- Building the main navigation hierarchy (library → series → chapter → page)
- Programmatic navigation (e.g., "continue reading" jumping directly to a chapter)
- Handling deep links or universal links that open specific manga/chapters
- Coordinating sheets, full-screen covers, and navigation within a TabView
- Persisting navigation state across app launches

## Core Rules
1. Use `NavigationStack(path:)` with a bound `NavigationPath` for any programmatic navigation — stateless `NavigationStack` can't be driven from code.
2. `NavigationLink(value:)` (value-based) is preferred over `NavigationLink(destination:)` — it decouples the link from the view hierarchy.
3. Register destinations with `.navigationDestination(for: MyType.self)` at or near the root — not inside list rows.
4. Append to `path` to push; use `path.removeLast()` for pop; `path = NavigationPath()` for pop-to-root.
5. `NavigationPath` is type-erased — it can hold heterogeneous values as long as each type has a matching `.navigationDestination`.
6. For deep links, decode the URL in `onOpenURL` and set the path directly — don't try to animate intermediate screens.
7. Sheets and full-screen covers are separate from the navigation stack — don't push sheets onto the path.
8. In `TabView`, each tab should have its own `NavigationStack` with its own path state — shared state causes tab-switching bugs.
9. `NavigationPath` is `Codable` if all contained values are `Codable` — use this for state persistence.
10. Avoid mixing old `NavigationView` and new `NavigationStack` in the same app — they conflict.

## Basic NavigationStack with Path

```swift
import SwiftUI

// Routable types — each represents a "screen" in the stack
enum MangaRoute: Hashable {
    case seriesDetail(MangaSeries)
    case chapterList(MangaSeries)
    case chapterReader(Chapter)
    case pageView(Chapter, pageIndex: Int)
}

@Observable
class NavigationRouter {
    var path = NavigationPath()
    
    func navigate(to route: MangaRoute) {
        path.append(route)
    }
    
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
    
    // Jump deep — clears existing stack first
    func navigateToChapter(_ chapter: Chapter, in series: MangaSeries) {
        path = NavigationPath()
        path.append(MangaRoute.seriesDetail(series))
        path.append(MangaRoute.chapterReader(chapter))
    }
}
```

```swift
struct RootView: View {
    @State private var router = NavigationRouter()
    
    var body: some View {
        NavigationStack(path: $router.path) {
            LibraryView()
                .navigationDestination(for: MangaRoute.self) { route in
                    switch route {
                    case .seriesDetail(let series):
                        SeriesDetailView(series: series)
                    case .chapterList(let series):
                        ChapterListView(series: series)
                    case .chapterReader(let chapter):
                        ChapterReaderView(chapter: chapter)
                    case .pageView(let chapter, let page):
                        PageView(chapter: chapter, startingPage: page)
                    }
                }
        }
        .environment(router)
    }
}
```

## Value-Based NavigationLink

```swift
// In LibraryView — link provides a value, root handles destination
struct LibraryView: View {
    @Query(sort: \MangaSeries.title) var series: [MangaSeries]
    
    var body: some View {
        List(series) { manga in
            // Value-based link — destination registered at root level
            NavigationLink(value: MangaRoute.seriesDetail(manga)) {
                SeriesRowView(series: manga)
            }
        }
        .navigationTitle("Library")
    }
}

// Programmatic navigation via environment router
struct SeriesRowView: View {
    @Environment(NavigationRouter.self) var router
    let series: MangaSeries
    
    var body: some View {
        HStack {
            SeriesThumbnail(series: series)
            VStack(alignment: .leading) {
                Text(series.title).font(.headline)
                Text("Continue: Ch. \(series.chapters.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Continue") {
                if let lastChapter = series.chapters.last {
                    router.navigateToChapter(lastChapter, in: series)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
```

## Deep Linking with onOpenURL

```swift
// URL scheme: mangareader://series/op?chapter=1085&page=3
// Universal link: https://mangareader.app/series/op?chapter=1085

struct RootView: View {
    @State private var router = NavigationRouter()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack(path: $router.path) {
            LibraryView()
                .navigationDestination(for: MangaRoute.self) { route in
                    routeView(for: route)
                }
        }
        .environment(router)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        // iOS 17+: handle UserActivity from universal links
        .onContinueUserActivity(NSUserActivityTypes.browsingWeb) { activity in
            if let url = activity.webpageURL {
                handleDeepLink(url)
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        // mangareader://series/{id}?chapter={num}&page={num}
        let pathParts = components.path.split(separator: "/")
        guard pathParts.first == "series", let seriesID = pathParts.dropFirst().first else { return }
        
        // Resolve model from SwiftData
        guard let series = fetchSeries(id: String(seriesID)) else { return }
        
        let chapterNum = Int(components.queryValue("chapter") ?? "") ?? 0
        let pageNum = Int(components.queryValue("page") ?? "") ?? 0
        
        if let chapter = series.chapters.first(where: { $0.number == chapterNum }) {
            router.path = NavigationPath()
            router.navigate(to: .seriesDetail(series))
            router.navigate(to: .chapterReader(chapter))
            if pageNum > 0 {
                router.navigate(to: .pageView(chapter, pageIndex: pageNum))
            }
        } else {
            router.path = NavigationPath()
            router.navigate(to: .seriesDetail(series))
        }
    }
    
    private func fetchSeries(id: String) -> MangaSeries? {
        let descriptor = FetchDescriptor<MangaSeries>(
            predicate: #Predicate { $0.slug == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

extension URLComponents {
    func queryValue(_ name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}
```

## Tab Navigation with Independent Stacks

```swift
@Observable
class AppRouter {
    var selectedTab: Tab = .library
    var libraryPath = NavigationPath()
    var searchPath = NavigationPath()
    var settingsPath = NavigationPath()
    
    enum Tab: Int, CaseIterable {
        case library, search, settings
    }
    
    // Deep link: switch tab and set path
    func open(route: MangaRoute, in tab: Tab = .library) {
        selectedTab = tab
        switch tab {
        case .library: libraryPath.append(route)
        case .search:  searchPath.append(route)
        case .settings: break
        }
    }
}

struct AppTabView: View {
    @State private var router = AppRouter()
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            // Each tab has its own NavigationStack + path
            NavigationStack(path: $router.libraryPath) {
                LibraryView()
                    .navigationDestination(for: MangaRoute.self) { routeView(for: $0) }
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(AppRouter.Tab.library)
            
            NavigationStack(path: $router.searchPath) {
                SearchView()
                    .navigationDestination(for: MangaRoute.self) { routeView(for: $0) }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppRouter.Tab.search)
            
            NavigationStack(path: $router.settingsPath) {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(AppRouter.Tab.settings)
        }
        .environment(router)
    }
}
```

## Sheet and Full-Screen Cover Coordination

```swift
struct SeriesDetailView: View {
    let series: MangaSeries
    @State private var showingAddToList = false
    @State private var selectedGenre: Genre? = nil
    
    var body: some View {
        List {
            ForEach(series.chapters) { chapter in
                NavigationLink(value: MangaRoute.chapterReader(chapter)) {
                    ChapterRowView(chapter: chapter)
                }
            }
        }
        .navigationTitle(series.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add to List") { showingAddToList = true }
            }
        }
        // Sheet — separate from navigation stack
        .sheet(isPresented: $showingAddToList) {
            AddToListSheet(series: series)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Optional value-driven sheet
        .sheet(item: $selectedGenre) { genre in
            GenreDetailSheet(genre: genre)
        }
    }
}
```

## Navigation State Persistence

```swift
// NavigationPath is Codable when all values are Codable
// Add Codable to your route enum:
enum MangaRoute: Hashable, Codable {
    case seriesDetail(String)  // use IDs (Strings/Ints), not full model objects
    case chapterReader(String, Int)  // seriesID, chapterNumber
}

@Observable
class PersistableRouter {
    var path: NavigationPath {
        didSet { saveState() }
    }
    
    init() {
        // Restore on launch
        if let data = UserDefaults.standard.data(forKey: "nav.path"),
           let restored = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) {
            self.path = NavigationPath(restored)
        } else {
            self.path = NavigationPath()
        }
    }
    
    private func saveState() {
        guard let codable = path.codable,
              let data = try? JSONEncoder().encode(codable) else { return }
        UserDefaults.standard.set(data, forKey: "nav.path")
    }
}
```

## Common Patterns

### "Continue Reading" Button (Jump Deep)
```swift
struct ContinueReadingButton: View {
    @Environment(NavigationRouter.self) var router
    let series: MangaSeries
    
    var body: some View {
        Button("Continue Reading") {
            guard let lastReadChapter = series.lastReadChapter else { return }
            router.navigateToChapter(lastReadChapter, in: series)
        }
        .buttonStyle(.borderedProminent)
    }
}
```

### Pop from Child View Without Router
```swift
struct ChapterReaderView: View {
    @Environment(\.dismiss) private var dismiss  // works for both push & sheet
    
    var body: some View {
        ReaderContent()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
    }
}
```

### Navigation Decision Table

| Scenario | Solution |
|----------|----------|
| Push new screen | `path.append(route)` or `NavigationLink(value:)` |
| Pop one screen | `path.removeLast()` or `dismiss()` |
| Pop to root | `path = NavigationPath()` |
| Jump to specific screen | Clear path, then append intermediate + target |
| Show modal | `.sheet(isPresented:)` or `.sheet(item:)` |
| Show fullscreen | `.fullScreenCover(isPresented:)` |
| Tab + deep navigation | `router.selectedTab = .library; libraryPath.append(route)` |
| Preserve on background | Encode `path.codable` to UserDefaults |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ios-swift/swiftui-navigation/.gitnexus
Last indexed: 2026-05-23
