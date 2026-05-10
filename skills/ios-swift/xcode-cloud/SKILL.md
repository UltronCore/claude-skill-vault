---
name: xcode-cloud
description: >
  Xcode Cloud CI/CD workflows, custom scripts, test plans, and TestFlight distribution.
  Triggers on: Xcode Cloud, ci_post_clone, ci_pre_xcodebuild, ci_post_xcodebuild,
  workflow, xcodebuild test-plan, CI_BUILD_NUMBER.
---

# Xcode Cloud CI/CD

## When to Use
- Setting up automated build, test, and TestFlight distribution for the manga reader
- Running custom setup steps (secrets injection, dependency install, asset generation)
- Using CI_BUILD_NUMBER to auto-increment build numbers without a script
- Connecting App Store Connect workflows to GitHub branch/PR events
- Troubleshooting why a cloud build fails but local succeeds

## Core Rules
1. Custom scripts live in `ci_scripts/` at the repo root — Xcode Cloud discovers them by name convention, not by configuration.
2. Script files must be executable: `chmod +x ci_scripts/ci_post_clone.sh` and committed with those permissions.
3. `CI_BUILD_NUMBER` is auto-incremented per workflow — use it directly as `CFBundleVersion`; don't maintain your own counter.
4. Environment variables are set in the workflow settings in App Store Connect — never commit secrets to scripts.
5. Xcode Cloud always does a clean clone — anything not in the repo must be fetched in `ci_post_clone.sh`.
6. Swift packages are resolved automatically — no need to `swift package resolve` in scripts unless using a private registry.
7. Test plans (`.xctestplan`) are the canonical way to configure which tests run in cloud — more reliable than `-testIdentifier` flags.
8. Use `CI_DERIVED_DATA_PATH` and `CI_ARCHIVE_PATH` for paths to build artifacts in post-build scripts.
9. Xcode Cloud does NOT support macOS-only tools without Rosetta — stick to `xcodebuild`, `xcrun`, standard Unix tools, and SPM packages.
10. If a workflow needs a secret (API key, token), use a custom environment variable in App Store Connect — scripts read it via `$MY_VAR`.

## Custom Script Timing

| Script name | When it runs | Common uses |
|-------------|-------------|-------------|
| `ci_post_clone.sh` | After repo clone, before build | Install tools, inject configs, set up env |
| `ci_pre_xcodebuild.sh` | Before xcodebuild runs | Bump version, generate code, patch plists |
| `ci_post_xcodebuild.sh` | After xcodebuild completes | Upload dSYMs, notify Slack, run post-analysis |

## ci_post_clone.sh — Install Dependencies

```bash
#!/bin/zsh
# ci_scripts/ci_post_clone.sh
set -euo pipefail

echo "--- CI Post-Clone ---"
echo "Xcode Cloud build: $CI_BUILD_NUMBER"
echo "Branch: $CI_BRANCH"
echo "Workflow: $CI_WORKFLOW"

# Install Homebrew tools if needed (slow — cache if possible)
# Xcode Cloud runs on macOS; brew is pre-installed but many formulae aren't
if ! command -v swiftlint &> /dev/null; then
    echo "Installing SwiftLint..."
    brew install swiftlint
fi

# Inject a config file from an env variable (secret stored in ASC)
# In ASC Workflow > Environment > Add Variable: MANGA_API_KEY (secret)
if [ -n "${MANGA_API_KEY:-}" ]; then
    echo "MANGA_API_KEY=$MANGA_API_KEY" > "$CI_WORKSPACE/MangaReader/Secrets.xcconfig"
    echo "Injected API key config"
fi

# Resolve private Swift packages (if using a private package registry)
# cd "$CI_WORKSPACE"
# swift package resolve  # usually not needed for public packages

echo "--- Post-Clone Complete ---"
```

## ci_pre_xcodebuild.sh — Version Stamping

```bash
#!/bin/zsh
# ci_scripts/ci_pre_xcodebuild.sh
set -euo pipefail

echo "--- CI Pre-xcodebuild ---"

# Xcode Cloud provides CI_BUILD_NUMBER automatically.
# Use it as CFBundleVersion (must be unique per submission):
PLIST="$CI_WORKSPACE/MangaReader/Info.plist"

if [ -f "$PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$PLIST"
    echo "Set build number to $CI_BUILD_NUMBER"
fi

# Optionally set marketing version from a VERSION file in repo
if [ -f "$CI_WORKSPACE/VERSION" ]; then
    MARKETING_VERSION=$(cat "$CI_WORKSPACE/VERSION")
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$PLIST"
    echo "Set marketing version to $MARKETING_VERSION"
fi

# Run SwiftLint (fail build on errors)
if command -v swiftlint &> /dev/null; then
    echo "Running SwiftLint..."
    cd "$CI_WORKSPACE"
    swiftlint --reporter xcode --strict || {
        echo "SwiftLint found errors — failing build"
        exit 1
    }
fi

echo "--- Pre-xcodebuild Complete ---"
```

## ci_post_xcodebuild.sh — Upload dSYMs & Notify

```bash
#!/bin/zsh
# ci_scripts/ci_post_xcodebuild.sh
set -euo pipefail

echo "--- CI Post-xcodebuild ---"
echo "Archive path: ${CI_ARCHIVE_PATH:-not set}"
echo "Result bundle: ${CI_RESULT_BUNDLE_PATH:-not set}"

# Upload dSYMs to Crashlytics (Firebase)
# Requires FIREBASE_TOKEN env var set in ASC
if [ -n "${CI_ARCHIVE_PATH:-}" ] && [ -n "${FIREBASE_TOKEN:-}" ]; then
    DSYM_DIR="$CI_ARCHIVE_PATH/dSYMs"
    if [ -d "$DSYM_DIR" ]; then
        echo "Uploading dSYMs to Firebase Crashlytics..."
        # firebase-tools must be installed in ci_post_clone.sh
        # ./firebase crashlytics:symbols:upload --app "$FIREBASE_APP_ID" "$DSYM_DIR"/*.dSYM
    fi
fi

# Slack notification
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    BUILD_STATUS="success"
    curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"MangaReader build #$CI_BUILD_NUMBER on $CI_BRANCH: $BUILD_STATUS\"}"
fi

echo "--- Post-xcodebuild Complete ---"
```

## Workflow Configuration (App Store Connect UI)

Set up in App Store Connect > Xcode Cloud > Manage Workflows:

```
Workflow: "TestFlight Beta"
├── Environment
│   ├── Xcode: latest release
│   ├── macOS: latest release  
│   └── Environment Variables:
│       ├── MANGA_API_KEY (secret) = sk-...
│       └── SLACK_WEBHOOK_URL (secret) = https://hooks.slack.com/...
├── Start Conditions
│   ├── Branch changes: main, release/*
│   └── Pull Request changes: any branch
├── Actions
│   ├── Build: scheme=MangaReader, platform=iOS
│   ├── Test: test plan=MangaReaderTests, platform=iOS Simulator
│   └── Archive: scheme=MangaReader
└── Post-Actions
    └── TestFlight (Internal) → group: "Internal Testers"
```

## Test Plans

Create `MangaReaderTests.xctestplan` via Xcode: Product > Test Plan > New Test Plan

```json
// MangaReaderTests.xctestplan (simplified structure)
{
  "configurations": [
    {
      "id": "primary",
      "name": "Primary",
      "options": {
        "codeCoverage": true,
        "environmentVariableEntries": [
          {"key": "USE_MOCK_API", "value": "1"}
        ],
        "testTimeoutsEnabled": true,
        "defaultTestExecutionTimeAllowance": 60
      }
    }
  ],
  "defaultOptions": {
    "codeCoverageTargets": [{"name": "MangaReader", "productType": "com.apple.product-type.application"}],
    "maximumTestRepetitions": 3,
    "testRepetitionMode": "retryOnFailure"
  },
  "testTargets": [
    {
      "target": {"name": "MangaReaderTests", "projectPath": "MangaReader.xcodeproj"},
      "skippedTests": ["SlowIntegrationTests"]
    }
  ],
  "version": 1
}
```

## Using CI_BUILD_NUMBER in Code

```swift
// Access build metadata at runtime
struct BuildInfo {
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    static var isCI: Bool {
        // Xcode Cloud sets CI=TRUE in its environment (not available at runtime,
        // but you can embed it during ci_pre_xcodebuild.sh into a config)
        Bundle.main.infoDictionary?["BuildEnvironment"] as? String == "CI"
    }
    static var displayVersion: String { "v\(version) (\(buildNumber))" }
}
```

## Environment Variables Available in Scripts

```bash
# Repo & workspace
CI_WORKSPACE          # /Volumes/workspace/repository
CI_DERIVED_DATA_PATH  # derived data location
CI_ARCHIVE_PATH       # path to .xcarchive (post-archive only)
CI_RESULT_BUNDLE_PATH # test results

# Build metadata
CI_BUILD_NUMBER       # unique incrementing integer (1, 2, 3…)
CI_BRANCH             # git branch name
CI_TAG                # git tag (if triggered by tag)
CI_COMMIT             # git commit SHA
CI_PULL_REQUEST_NUMBER

# Workflow
CI_WORKFLOW           # workflow name
CI_PRODUCT_PLATFORM   # iOS, macOS, tvOS, watchOS
CI_XCODE_SCHEME       # scheme being built

# Identity
CI=TRUE               # always set by Xcode Cloud
```

## Common Gotchas

| Problem | Cause | Fix |
|---------|-------|-----|
| `chmod: Operation not permitted` | Script not executable in git | `git update-index --chmod=+x ci_scripts/*.sh` |
| `command not found: brew formula` | Not installed in clone step | Install in `ci_post_clone.sh` |
| Build number conflicts | Using manual counter | Use `$CI_BUILD_NUMBER` exclusively |
| Secrets visible in logs | Logging env vars | Never `echo $SECRET` — set but don't print |
| SPM resolution fails | Private package needs auth | Use SSH key or `netrc` configured in clone step |
| Test plan not found | Wrong path in workflow | Path is relative to workspace root |
| Archive path empty in post-build | Action order wrong | `ci_post_xcodebuild` only has archive after archive action |

## Common Patterns

### Conditional Logic by Branch
```bash
#!/bin/zsh
# Only upload to TestFlight external group on main branch
if [ "$CI_BRANCH" = "main" ]; then
    echo "Main branch — will distribute to external testers"
    # (actual distribution is configured in workflow post-actions, not scripts)
fi

# Only run heavy tasks for release branches
if [[ "$CI_BRANCH" == release/* ]]; then
    echo "Release branch — running full validation"
    # ... extra steps
fi
```

### Generating a BuildInfo.plist During CI
```bash
# In ci_pre_xcodebuild.sh — embed CI metadata into app bundle
/usr/libexec/PlistBuddy -c "Add :BuildEnvironment string CI"   "$PLIST"
/usr/libexec/PlistBuddy -c "Add :BuildBranch string $CI_BRANCH" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :BuildCommit string $CI_COMMIT" "$PLIST"
```
