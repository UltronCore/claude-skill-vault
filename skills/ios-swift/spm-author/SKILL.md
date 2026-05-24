---
name: spm-author
description: >
  Swift Package Manager package authoring, targets, products, binary xcframework
  targets, resources, and local development workflow. Triggers on: Package.swift,
  swift package, SPM, .package(url:, .target(, .product(name:, swift-tools-version,
  xcframework, binary target.
---

# Swift Package Manager — Package Authoring

## When to Use
- Creating a reusable library from manga reader components (image decoder, cache layer, reader engine)
- Adding binary xcframework dependencies (closed-source SDKs)
- Authoring a macro package (required structure for Swift macros)
- Setting up resource bundles (image assets, localization strings) inside a package
- Local package development without publishing to a registry

## Core Rules
1. `swift-tools-version` must match the minimum Swift version you require — `5.9` for macros, `5.7` for structured concurrency features.
2. Every target name must be unique within the package and across all dependencies in a graph.
3. Resources (`Bundle.module`) only work in targets that declare `resources:` — never hardcode `Bundle.main` in a library target.
4. Binary targets require a checksum for remote URLs: generate with `swift package compute-checksum file.zip`.
5. Use `.package(path: "../MyLib")` for local packages during development — switch to URL+version before shipping.
6. Conditional platform dependencies use `#if canImport(UIKit)` in source or `.target(… dependencies: [.when(platforms: [.iOS])])` in Package.swift.
7. Test targets must be `.testTarget` not `.target` — they link XCTest automatically.
8. Products declare what's visible to consumers; targets are internal build units — a library product can expose multiple targets.
9. `@_exported import` in a module umbrella file re-exports all public symbols — use sparingly, only for clear module grouping.
10. Version constraints: prefer `.upToNextMajor(from:)` for stability; `.exact()` only for known-breaking dependencies.

## Package.swift Anatomy

```swift
// swift-tools-version: 5.10
// MangaImageKit — image loading and caching for manga pages
import PackageDescription

let package = Package(
    name: "MangaImageKit",
    
    // Minimum platform versions
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    
    // What consumers can import — the public surface
    products: [
        // .library exposes one or more targets as a Swift module
        .library(name: "MangaImageKit", targets: ["MangaImageKit"]),
        
        // A separate product for an optional feature
        .library(name: "MangaImageKitCache", targets: ["MangaImageKitCache"]),
        
        // Executable for CLI tools (uncommon in library packages)
        // .executable(name: "manga-prefetch", targets: ["MangaPrefetchTool"]),
    ],
    
    // External dependencies
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        // Local package (dev only — change to URL for release):
        // .package(path: "../MangaCore"),
    ],
    
    // Internal build units
    targets: [
        .target(
            name: "MangaImageKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "MangaImageKitCache",  // internal dependency
            ],
            path: "Sources/MangaImageKit",
            resources: [
                .process("Resources/Shaders"),   // processed (e.g., .xcassets compiled)
                .copy("Resources/DefaultCovers"), // copied as-is
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        
        .target(
            name: "MangaImageKitCache",
            dependencies: [],
            path: "Sources/Cache"
        ),
        
        // Platform-conditional target
        .target(
            name: "MangaImageKitUI",
            dependencies: [
                "MangaImageKit",
                .product(name: "Kingfisher", package: "Kingfisher",
                         condition: .when(platforms: [.iOS, .macOS])),
            ]
        ),
        
        // Test target — links XCTest automatically
        .testTarget(
            name: "MangaImageKitTests",
            dependencies: ["MangaImageKit"],
            path: "Tests/MangaImageKitTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

## Directory Structure

```
MangaImageKit/
├── Package.swift
├── Sources/
│   ├── MangaImageKit/
│   │   ├── MangaImageLoader.swift
│   │   ├── MangaImageProcessor.swift
│   │   └── Resources/
│   │       ├── Shaders/             # .metal files
│   │       └── DefaultCovers/       # .png assets
│   ├── Cache/
│   │   ├── DiskCache.swift
│   │   └── MemoryCache.swift
│   └── MangaImageKitUI/
│       └── MangaPageView.swift
└── Tests/
    └── MangaImageKitTests/
        ├── MangaImageLoaderTests.swift
        └── Fixtures/
            └── test-page.jpg
```

## Accessing Bundle Resources

```swift
// In a package target — use Bundle.module, not Bundle.main
// Bundle.module is generated by SPM for targets with resources declared

import Foundation

public struct DefaultCoverProvider {
    // Access a resource file
    public static func coverData(for genre: String) -> Data? {
        let url = Bundle.module.url(forResource: genre, withExtension: "png",
                                    subdirectory: "DefaultCovers")
        return url.flatMap { try? Data(contentsOf: $0) }
    }
    
    // Access a Metal shader
    public static var defaultLibrary: MTLLibrary? {
        let device = MTLCreateSystemDefaultDevice()
        let url = Bundle.module.url(forResource: "MangaShaders", withExtension: "metallib",
                                    subdirectory: "Shaders")
        return try? device?.makeLibrary(URL: url!)
    }
}
```

## Binary XCFramework Target

```swift
// For closed-source SDKs or pre-built frameworks
targets: [
    .binaryTarget(
        name: "MangaDecoder",
        // Remote ZIP containing the .xcframework
        url: "https://releases.example.com/MangaDecoder-2.1.0.zip",
        checksum: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        // Generate: swift package compute-checksum MangaDecoder-2.1.0.zip
    ),
    
    // Or local path during development:
    // .binaryTarget(name: "MangaDecoder", path: "Frameworks/MangaDecoder.xcframework"),
    
    .target(
        name: "MangaImageKit",
        dependencies: ["MangaDecoder"]  // links the xcframework
    )
]
```

```bash
# Build an xcframework from your own framework target:
xcodebuild archive -scheme MangaDecoder \
    -destination "generic/platform=iOS" \
    -archivePath build/ios.xcarchive

xcodebuild archive -scheme MangaDecoder \
    -destination "generic/platform=iOS Simulator" \
    -archivePath build/simulator.xcarchive

xcodebuild -create-xcframework \
    -framework build/ios.xcarchive/Products/Library/Frameworks/MangaDecoder.framework \
    -framework build/simulator.xcarchive/Products/Library/Frameworks/MangaDecoder.framework \
    -output build/MangaDecoder.xcframework
```

## Version Constraint Reference

```swift
// In a consumer's Package.swift:
.package(url: "https://github.com/you/MangaImageKit.git",
    from: "1.0.0"                       // >= 1.0.0 and < 2.0.0 (upToNextMajor)
),
.package(url: "...", .upToNextMinor(from: "1.2.0")),  // >= 1.2.0 and < 1.3.0
.package(url: "...", exact: "1.3.1"),                  // pinned
.package(url: "...", branch: "main"),                  // HEAD — unstable, avoid in production
.package(url: "...", revision: "abc123"),              // git SHA
```

## Local Package Development Workflow

```bash
# 1. Create the package
mkdir -p ~/dev/MangaImageKit/Sources/MangaImageKit
cd ~/dev/MangaImageKit
swift package init --type library --name MangaImageKit

# 2. In the host app's Package.swift or via Xcode:
#    File > Add Package Dependencies > Add Local...
#    Point to ~/dev/MangaImageKit

# 3. Develop — changes in the local package reflect immediately in the host app
# 4. When done, push the package and switch to URL+tag in the host app

# Build and test the package standalone
swift build
swift test --parallel

# Generate Xcode project for the package (optional)
swift package generate-xcodeproj   # deprecated in Xcode 14+ — open Package.swift directly

# Resolve dependencies
swift package resolve

# Show dependency graph
swift package show-dependencies

# Update all dependencies
swift package update
```

## Macro Package Structure (Swift 5.9+)

```swift
// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MangaMacros",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MangaMacros", targets: ["MangaMacros"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    ],
    targets: [
        .macro(                          // <-- special target type
            name: "MangaMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "MangaMacros", dependencies: ["MangaMacrosImpl"]),
        .testTarget(
            name: "MangaMacrosTests",
            dependencies: [
                "MangaMacrosImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
```

## Common Patterns

### Conditional Compilation by Platform
```swift
// In Package.swift
.target(
    name: "MangaPlatformKit",
    dependencies: [
        .product(name: "UIKitExtras", package: "UIExtras",
                 condition: .when(platforms: [.iOS, .tvOS])),
        .product(name: "AppKitExtras", package: "UIExtras",
                 condition: .when(platforms: [.macOS])),
    ]
)

// In Swift source
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif
```

### Exposing a C/C++ Target
```swift
.target(
    name: "MangaZipBridge",
    path: "Sources/CZip",
    publicHeadersPath: "include",
    cSettings: [.headerSearchPath(".")],
    linkerSettings: [.linkedLibrary("z")]  // link libz (zlib)
),
.target(
    name: "MangaArchive",
    dependencies: ["MangaZipBridge"]
)
```

## Related Skills
- `swift-macros` — Swift macro packages
- `ios-architecture` — package architecture
- `xcode-cloud` — package CI

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/spm-author/.gitnexus
Last indexed: 2026-05-23
