---
name: swift-macros
description: >
  Swift 5.9+ macro authoring: freestanding and attached macros using SwiftSyntax,
  macro testing, and package setup. Triggers on: @attached, @freestanding,
  swift macro, MacroExpansionContext, SwiftSyntax, macro expansion.
---

# Swift Macros

## When to Use
- Eliminating repetitive boilerplate that can't be solved with protocols or generics
- Compile-time validation of string literals (URLs, regex, identifiers)
- Auto-generating `Codable`, `Equatable`, or other conformances with custom behavior
- Reducing error-prone manual code (e.g., auto-generating `CaseIterable` raw values)

## Core Rules
1. Macros live in a separate `macro` target — they cannot be in the same target as code that uses them.
2. Freestanding macros (`#name()`) produce expressions or declarations; attached macros (`@Name`) augment existing declarations.
3. Always test macros with `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport` — it shows exactly what gets generated.
4. `MacroExpansionContext.diagnose()` emits compiler errors/warnings; always validate input and diagnose bad usage rather than crashing.
5. SwiftSyntax nodes are value types — mutations return new nodes; use the `with` pattern for modifications.
6. Macros run at compile time on source text — they can't access runtime values, file system, or network.
7. Use `@freestanding(declaration)` to generate top-level declarations; `@freestanding(expression)` for values.
8. `@attached(member)` adds stored/computed properties and methods; `@attached(accessor)` replaces property body with get/set.
9. Enable macro debugging: add `-dump-macro-expansions` to Swift compiler flags to see generated code.
10. Keep macro logic pure and fast — they run on every build incrementally but can slow cold builds if complex.

## Package Setup

```swift
// Package.swift — macro targets require swift-syntax dependency
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
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Public API target — what callers import
        .target(name: "MangaMacros", dependencies: ["MangaMacrosImpl"]),
        
        // Implementation target — contains the actual macro logic
        .macro(
            name: "MangaMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        
        // Test target
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

## Freestanding Expression Macro — Validated URL

```swift
// MangaMacros/Sources/MangaMacros/MangaMacros.swift (public API)
@freestanding(expression)
public macro URL(_ string: String) -> URL = #externalMacro(module: "MangaMacrosImpl", type: "URLMacro")

// Usage:
// let base: URL = #URL("https://api.mangasite.com/v2")  // compile error if invalid URL
```

```swift
// MangaMacrosImpl/Sources/MangaMacrosImpl/URLMacro.swift
import SwiftSyntax
import SwiftSyntaxMacros

public struct URLMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // Extract the string literal argument
        guard let argument = node.arguments.first?.expression,
              let stringLiteral = argument.as(StringLiteralExprSyntax.self),
              stringLiteral.segments.count == 1,
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            context.diagnose(Diagnostic(
                node: node,
                message: MacroError.requiresStringLiteral("#URL requires a static string literal")
            ))
            throw MacroError.requiresStringLiteral("#URL requires a static string literal")
        }
        
        let urlString = segment.content.text
        
        // Validate at compile time
        guard URL(string: urlString) != nil else {
            context.diagnose(Diagnostic(
                node: argument,
                message: MacroError.invalidURL("'\(urlString)' is not a valid URL")
            ))
            throw MacroError.invalidURL("Not a valid URL")
        }
        
        // Emit: URL(string: "...")!  — safe because we validated above
        return "URL(string: \(argument))!"
    }
}

enum MacroError: Error, DiagnosticMessage {
    case requiresStringLiteral(String)
    case invalidURL(String)
    
    var message: String {
        switch self {
        case .requiresStringLiteral(let msg), .invalidURL(let msg): return msg
        }
    }
    var diagnosticID: MessageID { .init(domain: "MangaMacros", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}
```

## Attached Member Macro — Auto Codable Keys

```swift
// Generates CodingKeys enum from property names, with optional rename
@attached(member, names: named(CodingKeys), named(init(from:)), named(encode(to:)))
public macro CodableKeys() = #externalMacro(module: "MangaMacrosImpl", type: "CodableKeysMacro")

// Usage:
@CodableKeys
struct MangaAPIResponse {
    var id: Int
    var title: String
    var coverUrl: String  // auto-generates "cover_url" if using snake_case conversion
}
```

## Attached Member Macro — Observable Stored Properties Helper

```swift
// A simpler real-world example: auto-generate a "formatted" computed property
@attached(member, names: arbitrary)
public macro AutoFormatted() = #externalMacro(module: "MangaMacrosImpl", type: "AutoFormattedMacro")

// Implementation skeleton
public struct AutoFormattedMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: MacroError.requiresStringLiteral("@AutoFormatted requires a struct")))
            return []
        }
        
        // Find stored properties
        let storedVars = structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.bindings.first?.accessorBlock == nil }
        
        // Generate formatted_ computed properties
        return storedVars.compactMap { varDecl -> DeclSyntax? in
            guard let binding = varDecl.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else { return nil }
            
            let name = pattern.identifier.text
            let type = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
            
            guard type == "Date" else { return nil }
            
            return """
            var \(raw: name)_formatted: String {
                \(raw: name).formatted(date: .abbreviated, time: .omitted)
            }
            """
        }
    }
}
```

## Peer Macro — Async Variant Generator

```swift
// Generates an async wrapper alongside a completion-handler function
@attached(peer, names: suffixed(Async))
public macro AddAsync() = #externalMacro(module: "MangaMacrosImpl", type: "AddAsyncMacro")

// Usage:
class MangaLoader {
    @AddAsync
    func loadChapter(_ id: Int, completion: @escaping (Result<Chapter, Error>) -> Void) {
        // existing callback code
    }
    // Macro generates:
    // func loadChapterAsync(_ id: Int) async throws -> Chapter { ... }
}
```

## Compiler Plugin Registration

```swift
// MangaMacrosImpl/Sources/MangaMacrosImpl/Plugin.swift
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MangaMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        URLMacro.self,
        CodableKeysMacro.self,
        AutoFormattedMacro.self,
        AddAsyncMacro.self,
    ]
}
```

## Testing Macros

```swift
import XCTest
import SwiftSyntaxMacrosTestSupport
@testable import MangaMacrosImpl

final class URLMacroTests: XCTestCase {
    let macros: [String: Macro.Type] = ["URL": URLMacro.self]
    
    func testValidURL() {
        assertMacroExpansion(
            """
            let url = #URL("https://api.manga.com")
            """,
            expandedSource: """
            let url = URL(string: "https://api.manga.com")!
            """,
            macros: macros
        )
    }
    
    func testInvalidURL() {
        assertMacroExpansion(
            """
            let url = #URL("not a url!!!")
            """,
            expandedSource: """
            let url = #URL("not a url!!!")
            """,
            diagnostics: [
                DiagnosticSpec(message: "'not a url!!!' is not a valid URL", line: 1, column: 11)
            ],
            macros: macros
        )
    }
}
```

## Common Patterns

### SwiftSyntax Cheat Sheet
```swift
// Access function name from a FunctionDeclSyntax
let name = funcDecl.name.text

// Get all parameters
let params = funcDecl.signature.parameterClause.parameters

// Build a new syntax node
let newFunc: DeclSyntax = """
func \(raw: name)Async() async throws -> \(raw: returnType) {
    try await withCheckedThrowingContinuation { continuation in
        \(raw: name) { result in continuation.resume(with: result) }
    }
}
"""

// Add leading trivia (newline before generated member)
return [newFunc.with(\.leadingTrivia, .newlines(1))]
```

### Macro Role Quick Reference

| Role | Decorator | Output |
|------|-----------|--------|
| Expression | `@freestanding(expression)` | A value/expression |
| Declaration | `@freestanding(declaration)` | Top-level declarations |
| Member | `@attached(member)` | Properties/methods on type |
| Peer | `@attached(peer)` | Sibling declaration |
| Accessor | `@attached(accessor)` | get/set/willSet/didSet |
| Extension | `@attached(extension)` | Conformance + members |
| MemberAttribute | `@attached(memberAttribute)` | Attributes on members |
