---
name: widgetkit
description: >
  WidgetKit widgets, Live Activities, and interactive widgets for iOS 16+/17+.
  Triggers on: WidgetKit, Widget, TimelineProvider, AppIntent, LiveActivity,
  ActivityKit, WidgetConfiguration, WidgetFamily, TimelineEntry.
---

# WidgetKit Widgets & Live Activities

## When to Use
- Adding a home screen or lock screen widget (reading streak, current chapter, recently added manga)
- Building a Live Activity for active manga download progress
- Making widget buttons interactive (iOS 17+ AppIntent)
- Providing glanceable stats from the manga reader on the home screen

## Core Rules
1. Widgets have NO persistent state of their own — all data comes through `TimelineEntry`; fetch from App Group UserDefaults or shared SwiftData store.
2. `TimelineProvider.getTimeline()` must complete fast — do NOT make network calls in the critical path; use cached data.
3. Widget views must be pure SwiftUI with no gestures, no scroll views, no animations (beyond `.widgetAccentable` and system transitions).
4. Interactive widgets (buttons/toggles) require `AppIntent` conformance, iOS 17+. Use `Button(intent:)` / `Toggle(isOn:intent:)`.
5. Always implement all three sizes in `supportedFamilies` or explicitly declare the subset you support.
6. Deep link from widget taps via `.widgetURL(url)` or `Link(destination:)` — the app handles navigation in `onOpenURL`.
7. `TimelineReloadPolicy.atEnd` re-fetches after the last entry expires; `after(date:)` and `never` are the other options.
8. Live Activities use `ActivityKit`, not WidgetKit directly — but the UI is a WidgetKit `ActivityConfiguration`.
9. Preview widgets with `#Preview(as:)` macro (Xcode 15+) — much faster than running in simulator.
10. App Group is mandatory for sharing data between the app and widget extension targets.

## Basic Timeline Widget

```swift
import WidgetKit
import SwiftUI

// Entry: the data snapshot at a moment in time
struct ReadingEntry: TimelineEntry {
    let date: Date
    let seriesTitle: String
    let currentChapter: Int
    let readingStreak: Int
    let coverColor: Color
}

// Provider: generates the timeline of entries
struct ReadingProvider: TimelineProvider {
    // Placeholder shown while real data loads (should be fast, use dummy data)
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: .now, seriesTitle: "One Piece", currentChapter: 1085,
                     readingStreak: 7, coverColor: .blue)
    }
    
    // Snapshot for widget gallery preview
    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(placeholder(in: context))
    }
    
    // The real timeline — build from cached app data
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        let shared = UserDefaults(suiteName: "group.com.mangareader")
        let title   = shared?.string(forKey: "currentSeriesTitle") ?? "No manga"
        let chapter = shared?.integer(forKey: "currentChapter") ?? 0
        let streak  = shared?.integer(forKey: "readingStreak") ?? 0
        
        let entry = ReadingEntry(date: .now, seriesTitle: title,
                                 currentChapter: chapter, readingStreak: streak,
                                 coverColor: .indigo)
        
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
```

## Widget Views (All Sizes)

```swift
struct ReadingWidgetEntryView: View {
    var entry: ReadingEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        case .accessoryCircular: AccessoryCircularView(entry: entry)  // lock screen
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        default: SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: ReadingEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📖").font(.title2)
            Spacer()
            Text(entry.seriesTitle)
                .font(.caption2).bold()
                .lineLimit(2)
            Text("Ch. \(entry.currentChapter)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(entry.readingStreak)d")
                    .font(.caption2).bold()
            }
        }
        .padding()
        .widgetURL(URL(string: "mangareader://continue"))  // tap → deep link
        .containerBackground(entry.coverColor.gradient, for: .widget)
    }
}
```

## Widget Configuration

```swift
@main
struct MangaWidget: Widget {
    let kind = "com.mangareader.readingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingProvider()) { entry in
            ReadingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Reading Progress")
        .description("Shows your current manga and streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// Xcode 15+ preview
#Preview(as: .systemSmall) {
    MangaWidget()
} timeline: {
    ReadingEntry(date: .now, seriesTitle: "Berserk", currentChapter: 364,
                 readingStreak: 12, coverColor: .brown)
}
```

## Interactive Widget with AppIntent (iOS 17+)

```swift
import AppIntents

// The action that runs when user taps button (runs in widget process)
struct MarkChapterReadIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Chapter Read"
    
    @Parameter(title: "Series ID") var seriesID: String
    @Parameter(title: "Chapter Number") var chapterNumber: Int
    
    func perform() async throws -> some IntentResult {
        // Persist to App Group shared store
        let defaults = UserDefaults(suiteName: "group.com.mangareader")
        defaults?.set(chapterNumber + 1, forKey: "currentChapter_\(seriesID)")
        
        // Trigger widget reload
        WidgetCenter.shared.reloadTimelines(ofKind: "com.mangareader.readingWidget")
        return .result()
    }
}

// In your entry view:
struct InteractiveChapterView: View {
    let entry: ReadingEntry
    
    var body: some View {
        VStack {
            Text("Ch. \(entry.currentChapter)")
            
            // Button triggers AppIntent without opening the app
            Button(intent: MarkChapterReadIntent(
                seriesID: "op",
                chapterNumber: entry.currentChapter)
            ) {
                Label("Done", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        }
        .containerBackground(.fill, for: .widget)
    }
}
```

## Live Activity (Download Progress)

```swift
import ActivityKit

// Shared between app and widget extension (put in shared framework or copy)
struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var downloadedPages: Int
        var totalPages: Int
        var chapterTitle: String
        
        var progress: Double { Double(downloadedPages) / Double(max(totalPages, 1)) }
    }
    
    var seriesTitle: String
    var chapterNumber: Int
}

// In your widget extension — Live Activity UI
struct DownloadLiveActivityView: View {
    let context: ActivityViewContext<DownloadActivityAttributes>
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(context.attributes.seriesTitle).font(.caption).bold()
                Text("Ch. \(context.attributes.attributes.chapterNumber): \(context.state.chapterTitle)")
                    .font(.caption2)
                ProgressView(value: context.state.progress)
            }
            Text("\(context.state.downloadedPages)/\(context.state.totalPages)")
                .font(.caption2).monospacedDigit()
        }
        .padding()
    }
}
```

```swift
// Starting a Live Activity from the app
func startDownloadActivity(series: MangaSeries, chapter: Chapter) throws {
    let attributes = DownloadActivityAttributes(
        seriesTitle: series.title,
        chapterNumber: chapter.number
    )
    let initialState = DownloadActivityAttributes.ContentState(
        downloadedPages: 0,
        totalPages: chapter.pageCount,
        chapterTitle: chapter.title ?? ""
    )
    let activity = try Activity.request(
        attributes: attributes,
        content: .init(state: initialState, staleDate: nil)
    )
    print("Started Live Activity: \(activity.id)")
}

// Updating progress
func updateDownloadActivity(_ activity: Activity<DownloadActivityAttributes>, page: Int) async {
    let state = DownloadActivityAttributes.ContentState(
        downloadedPages: page,
        totalPages: activity.content.state.totalPages,
        chapterTitle: activity.content.state.chapterTitle
    )
    await activity.update(.init(state: state, staleDate: nil))
}

// Ending it
func endDownloadActivity(_ activity: Activity<DownloadActivityAttributes>) async {
    await activity.end(nil, dismissalPolicy: .immediate)
}
```

## App Group Setup (Required for Data Sharing)

1. In both app target and widget extension target → Signing & Capabilities → + App Groups → `group.com.mangareader`
2. Write from app:
```swift
UserDefaults(suiteName: "group.com.mangareader")?.set(series.title, forKey: "currentSeriesTitle")
WidgetCenter.shared.reloadAllTimelines()  // call after data change
```
3. Read from widget: same `UserDefaults(suiteName:)` access

## Timeline Reload Triggers

```swift
// After user finishes a chapter — call from app target
WidgetCenter.shared.reloadTimelines(ofKind: "com.mangareader.readingWidget")

// Reload all widgets (use sparingly — impacts battery)
WidgetCenter.shared.reloadAllTimelines()

// Check current configurations
WidgetCenter.shared.getCurrentConfigurations { result in
    guard case .success(let widgets) = result else { return }
    print("Active widgets: \(widgets.map(\.kind))")
}
```

## Common Patterns

### Lock Screen Accessory Circular (Streak Counter)
```swift
struct AccessoryCircularView: View {
    let entry: ReadingEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.caption)
                Text("\(entry.readingStreak)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .widgetAccentable()
            }
        }
    }
}
```

### Configurable Widget (User Picks Series)
- Use `AppIntentConfiguration` + `WidgetConfigurationIntent` instead of `StaticConfiguration`
- The intent provides a series picker; Xcode 16 generates most boilerplate
