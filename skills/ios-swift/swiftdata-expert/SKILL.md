---
name: swiftdata-expert
description: >
  SwiftData model persistence, relationships, migrations, and CloudKit sync
  for iOS 17+. Triggers on: SwiftData, @Model, ModelContainer, ModelContext,
  @Query, SwiftData schema, migration, SchemaMigrationPlan.
---

# SwiftData Expert

## When to Use
- Persisting app data locally with Swift-native APIs (replaces Core Data for new projects)
- Setting up model relationships (manga library: Series → Chapters → ReadProgress)
- Migrating schemas when model shapes change between app versions
- Syncing data to iCloud via CloudKit with zero extra code
- Deciding between SwiftData and Core Data for a given use case

## Core Rules
1. Mark every persistent model with `@Model` — the macro generates Core Data boilerplate automatically.
2. Never access `ModelContext` from a background thread without `modelContext.perform { }` or a separate actor — it's not thread-safe.
3. `@Query` re-executes automatically when the store changes; don't manually observe or reload.
4. Relationships default to cascade delete — set `@Relationship(deleteRule: .nullify)` when that's wrong.
5. For CloudKit sync, every `@Model` property must be optional or have a default — CloudKit requires it.
6. Use lightweight migrations (adding optional properties) when possible; only write `SchemaMigrationPlan` for destructive changes.
7. `modelContext.autosaveEnabled` is `true` by default — you rarely need to call `save()` manually.
8. Fetch with predicates at the `@Query` level, not in a `.filter` on the results — the former queries SQL, the latter loads everything.
9. For large datasets (1000+ objects), use `FetchDescriptor` with `fetchLimit` and `fetchOffset` for pagination.
10. Background processing (e.g., image processing): create a separate `ModelContext(container)` on a background actor.

## Model Definition

```swift
import SwiftData
import Foundation

@Model
final class MangaSeries {
    var title: String
    var author: String
    var coverImageData: Data?
    var lastReadDate: Date?
    var isFavorite: Bool = false
    
    // One-to-many: series has many chapters
    @Relationship(deleteRule: .cascade, inverse: \Chapter.series)
    var chapters: [Chapter] = []
    
    // Many-to-many: series can have many genres
    @Relationship var genres: [Genre] = []
    
    init(title: String, author: String) {
        self.title = title
        self.author = author
    }
}

@Model
final class Chapter {
    var number: Int
    var title: String?
    var isDownloaded: Bool = false
    var pageCount: Int = 0
    var addedDate: Date = Date()
    
    // Back-reference — SwiftData infers the inverse
    var series: MangaSeries?
    
    // One-to-one
    @Relationship(deleteRule: .cascade, inverse: \ReadProgress.chapter)
    var readProgress: ReadProgress?
    
    init(number: Int, series: MangaSeries) {
        self.number = number
        self.series = series
    }
}

@Model
final class ReadProgress {
    var currentPage: Int = 0
    var totalPages: Int = 0
    var lastReadDate: Date = Date()
    var chapter: Chapter?
    
    var progressFraction: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
}
```

## ModelContainer Setup (App Entry Point)

```swift
import SwiftUI
import SwiftData

@main
struct MangaReaderApp: App {
    let container: ModelContainer
    
    init() {
        let schema = Schema([MangaSeries.self, Chapter.self, ReadProgress.self, Genre.self])
        
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // enables CloudKit sync — remove for no sync
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
```

## @Query in SwiftUI Views

```swift
struct LibraryView: View {
    // Basic query — auto-updates when data changes
    @Query(sort: \MangaSeries.title) var allSeries: [MangaSeries]
    
    // Filtered + sorted query
    @Query(
        filter: #Predicate<MangaSeries> { $0.isFavorite == true },
        sort: \MangaSeries.lastReadDate,
        order: .reverse
    ) var favorites: [MangaSeries]
    
    var body: some View {
        List(allSeries) { series in
            SeriesRowView(series: series)
        }
    }
}

// Dynamic predicate — pass via init (common pattern)
struct FilteredSeriesView: View {
    @Query var series: [MangaSeries]
    
    init(searchText: String) {
        let predicate = #Predicate<MangaSeries> {
            searchText.isEmpty ? true : $0.title.contains(searchText)
        }
        _series = Query(filter: predicate, sort: \MangaSeries.title)
    }
    
    var body: some View {
        List(series) { SeriesRowView(series: $0) }
    }
}
```

## ModelContext CRUD

```swift
struct LibraryViewModel {
    @Environment(\.modelContext) private var context
    
    // Create
    func addSeries(title: String, author: String) {
        let series = MangaSeries(title: title, author: author)
        context.insert(series)
        // autosave handles persistence — no explicit save() needed
    }
    
    // Read (outside SwiftUI — use FetchDescriptor)
    func fetchUnread() throws -> [Chapter] {
        let descriptor = FetchDescriptor<Chapter>(
            predicate: #Predicate { $0.readProgress == nil },
            sortBy: [SortDescriptor(\Chapter.addedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    // Paginated fetch
    func fetchPage(_ page: Int, pageSize: Int = 20) throws -> [MangaSeries] {
        var descriptor = FetchDescriptor<MangaSeries>(
            sortBy: [SortDescriptor(\MangaSeries.title)]
        )
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = page * pageSize
        return try context.fetch(descriptor)
    }
    
    // Update — just mutate; SwiftData tracks changes
    func markFavorite(_ series: MangaSeries) {
        series.isFavorite.toggle()
    }
    
    // Delete
    func deleteSeries(_ series: MangaSeries) {
        context.delete(series)  // cascade deletes chapters + progress
    }
}
```

## Schema Migration

```swift
// V1 schema
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [MangaSeries.self] }
    
    @Model final class MangaSeries {
        var title: String = ""
        init(title: String) { self.title = title }
    }
}

// V2 schema — added author property
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [MangaSeries.self] }
    
    @Model final class MangaSeries {
        var title: String = ""
        var author: String = "Unknown"  // new field with default = lightweight migration
        init(title: String, author: String = "Unknown") {
            self.title = title
            self.author = author
        }
    }
}

// Migration plan
enum MangaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    // Lightweight: just adding an optional/defaulted field
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
    
    // Custom migration example (data transformation needed):
    // static let migrateV1toV2 = MigrationStage.custom(
    //     fromVersion: SchemaV1.self,
    //     toVersion: SchemaV2.self,
    //     willMigrate: nil,
    //     didMigrate: { context in
    //         let series = try context.fetch(FetchDescriptor<SchemaV2.MangaSeries>())
    //         series.forEach { $0.author = "Unknown" }
    //     }
    // )
}

// Use in ModelContainer:
// ModelContainer(for: schema, migrationPlan: MangaMigrationPlan.self, configurations: config)
```

## Background Context Operations

```swift
actor LibraryActor: ModelActor {
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    
    init(container: ModelContainer) {
        self.modelContainer = container
        let context = ModelContext(container)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }
    
    func importChapters(for seriesID: PersistentIdentifier, chapters: [ChapterDTO]) throws {
        guard let series = modelContext.model(for: seriesID) as? MangaSeries else { return }
        for dto in chapters {
            let chapter = Chapter(number: dto.number, series: series)
            chapter.title = dto.title
            modelContext.insert(chapter)
        }
        try modelContext.save()
    }
}

// Usage:
// let actor = LibraryActor(container: container)
// await actor.importChapters(for: series.persistentModelID, chapters: fetched)
```

## SwiftData vs Core Data Decision Table

| Factor | SwiftData | Core Data |
|--------|-----------|-----------|
| iOS target | iOS 17+ only | iOS 13+ |
| Swift concurrency | Native actors | Manual `performBackgroundTask` |
| CloudKit sync | `.cloudKitDatabase(.automatic)` | NSPersistentCloudKitContainer |
| Complex queries | Limited `#Predicate` | Full NSPredicate + NSExpression |
| Batch operations | Not supported | `NSBatchDeleteRequest` |
| Migration control | `SchemaMigrationPlan` | `.xcmappingmodel` |
| Maturity | iOS 17+ (newer, some bugs) | Decade+ stable |

**Verdict for new iOS 17+ projects: use SwiftData.** Drop to Core Data only for iOS 16 support, batch deletes, or complex NSExpression queries.

## Common Patterns

### In-Memory Container for Previews/Tests
```swift
extension ModelContainer {
    static var preview: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: MangaSeries.self, Chapter.self,
            configurations: config
        )
        // Seed preview data
        let ctx = container.mainContext
        let series = MangaSeries(title: "One Piece", author: "Oda")
        ctx.insert(series)
        return container
    }
}

#Preview {
    LibraryView()
        .modelContainer(.preview)
}
```

### Count Without Fetching All Objects
```swift
let count = try context.fetchCount(FetchDescriptor<Chapter>(
    predicate: #Predicate { $0.isDownloaded == true }
))
```

## Related Skills
- `ios-swiftui-expert` — SwiftUI + SwiftData
- `database-migration-strategies` — data migrations
- `swiftui-data-flow` — data flow patterns

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/swiftdata-expert/.gitnexus
Last indexed: 2026-05-23
