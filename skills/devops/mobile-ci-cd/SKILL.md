---
name: mobile-ci-cd
description: Build CI/CD pipelines for iOS and Android apps using Fastlane, GitHub Actions, and Xcode Cloud. Covers code signing automation, TestFlight distribution, Google Play deployment, screenshot automation, versioning, and parallel device testing.
version: 1.0.0
tags: [mobile, ci-cd, fastlane, ios, android, xcode-cloud, github-actions, testflight, google-play, code-signing]
---

# Mobile CI/CD

## Overview

Mobile CI/CD is significantly more complex than web CI/CD due to code signing (provisioning profiles, certificates, keystores), platform-specific build tools (Xcode, Gradle), and multi-store distribution (App Store, Google Play). Fastlane automates the most painful parts — certificate management with `match`, TestFlight uploads with `pilot`, screenshot generation with `snapshot`, and Play Store deploys with `supply`. GitHub Actions orchestrates the pipeline with macOS runners for iOS and Linux runners for Android.

## When to Use

- Automating TestFlight or Google Play internal testing distribution on every merge
- Managing code signing certificates across a team without manual .p12 file sharing
- Running UI tests on physical devices or simulators in CI
- Generating App Store screenshots automatically across devices and localizations
- Versioning builds consistently (build number from git commit count, version from tags)
- Multi-environment builds (dev/staging/production with different bundle IDs and configs)
- Reducing "works on my machine" signing failures in a team setting

## Step-by-Step Workflow

### 1. Fastlane Setup and Code Signing with Match

```bash
# Install Fastlane
gem install fastlane
cd ios && fastlane init  # Or: cd android && fastlane init

# Set up match for code signing (stores certs in private Git repo)
fastlane match init
# Creates ios/Matchfile — configure it:
```

```ruby
# ios/Matchfile
git_url("https://github.com/your-org/ios-certificates-private")
storage_mode("git")
type("appstore")  # "development", "adhoc", "appstore", "enterprise"
app_identifier(["com.yourapp", "com.yourapp.extension"])
username("ci@yourcompany.com")
```

```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  before_all do
    # Ensure keychain is clean before CI runs
    setup_ci if is_ci
  end

  desc "Fetch certificates and provisioning profiles"
  lane :certificates do
    match(type: "development", readonly: is_ci)
    match(type: "appstore", readonly: is_ci)
  end

  desc "Run tests on simulator"
  lane :test do
    run_tests(
      scheme: "YourApp",
      device: "iPhone 15",
      result_bundle: true,
      output_files: "test_results.xml",
    )
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    certificates

    # Increment build number based on CI run number or git commit count
    increment_build_number(
      build_number: ENV["BUILD_NUMBER"] || git_branch_commit_count,
    )

    build_app(
      scheme: "YourApp",
      configuration: "Release",
      export_method: "app-store",
      export_options: {
        provisioningProfiles: {
          "com.yourapp" => "match AppStore com.yourapp"
        }
      },
      output_directory: "./build",
      include_symbols: true,
    )

    upload_to_testflight(
      api_key_path: "fastlane/api_key.json",
      skip_waiting_for_build_processing: true,
      changelog: changelog_from_git_commits(
        commits_count: 10,
        pretty: "- %s",
      ),
    )

    slack(
      message: "iOS beta uploaded to TestFlight! Build #{lane_context[SharedValues::BUILD_NUMBER]}",
      webhook_url: ENV["SLACK_WEBHOOK_URL"],
    ) if ENV["SLACK_WEBHOOK_URL"]
  end

  desc "Deploy to App Store"
  lane :release do
    certificates
    build_app(scheme: "YourApp", configuration: "Release", export_method: "app-store")
    upload_to_app_store(
      api_key_path: "fastlane/api_key.json",
      skip_screenshots: false,
      skip_metadata: false,
      submit_for_review: false,  # Set to true for automatic submission
    )
  end

  desc "Generate App Store screenshots"
  lane :screenshots do
    capture_screenshots(
      devices: ["iPhone 15 Pro Max", "iPhone SE (3rd generation)", "iPad Pro (12.9-inch)"],
      languages: ["en-US", "fr-FR", "de-DE"],
      scheme: "YourAppUITests",
      output_directory: "./fastlane/screenshots",
    )
    frame_screenshots(white: true)
  end

  private_lane :git_branch_commit_count do
    sh("git rev-list --count HEAD").strip.to_i
  end
end
```

### 2. Android Fastlane with Google Play

```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Run Android tests"
  lane :test do
    gradle(task: "test")
  end

  desc "Build and upload to Play Store internal testing"
  lane :beta do
    # Bump version code
    version_code = (ENV["BUILD_NUMBER"] || `git rev-list --count HEAD`.strip).to_i
    android_set_version_code(version_code: version_code)

    gradle(
      task: "bundle",                    # Build .aab (required for Play Store)
      build_type: "Release",
      print_command: false,
      properties: {
        "android.injected.signing.store.file" => ENV["KEYSTORE_PATH"],
        "android.injected.signing.store.password" => ENV["KEYSTORE_PASSWORD"],
        "android.injected.signing.key.alias" => ENV["KEY_ALIAS"],
        "android.injected.signing.key.password" => ENV["KEY_PASSWORD"],
      }
    )

    upload_to_play_store(
      track: "internal",
      aab: "app/build/outputs/bundle/release/app-release.aab",
      json_key: ENV["GOOGLE_PLAY_JSON_KEY"],
      skip_upload_metadata: true,
      skip_upload_images: true,
    )
  end

  desc "Promote internal to production"
  lane :promote_to_production do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
      json_key: ENV["GOOGLE_PLAY_JSON_KEY"],
      rollout: "0.1",  # 10% staged rollout
    )
  end
end
```

### 3. GitHub Actions iOS Pipeline

```yaml
# .github/workflows/ios-ci.yml
name: iOS CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      deploy_to_testflight:
        description: "Deploy to TestFlight"
        type: boolean
        default: false

jobs:
  test:
    name: Run Tests
    runs-on: macos-14  # Apple Silicon — faster builds
    steps:
      - uses: actions/checkout@v4

      - name: Cache CocoaPods
        uses: actions/cache@v4
        with:
          path: ios/Pods
          key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}

      - name: Install dependencies
        run: |
          gem install fastlane bundler
          cd ios && bundle install && pod install

      - name: Run unit tests
        run: cd ios && fastlane test
        env:
          DEVELOPER_DIR: /Applications/Xcode_15.4.app/Contents/Developer

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: ios/fastlane/test_output/

  deploy:
    name: Deploy to TestFlight
    runs-on: macos-14
    needs: test
    if: |
      github.ref == 'refs/heads/main' ||
      github.event.inputs.deploy_to_testflight == 'true'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git commit count

      - name: Set up SSH for certificates repo
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.MATCH_SSH_KEY }}

      - name: Install dependencies
        run: |
          gem install fastlane
          cd ios && bundle install && pod install

      - name: Create App Store Connect API Key
        run: |
          mkdir -p ios/fastlane
          echo '${{ secrets.APP_STORE_CONNECT_API_KEY }}' > ios/fastlane/api_key.json

      - name: Deploy to TestFlight
        run: cd ios && fastlane beta
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          BUILD_NUMBER: ${{ github.run_number }}
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_TOKEN }}

      - name: Clean up secrets
        if: always()
        run: rm -f ios/fastlane/api_key.json
```

### 4. Android GitHub Actions Pipeline

```yaml
# .github/workflows/android-ci.yml
name: Android CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: "17"
          distribution: "temurin"
          cache: gradle

      - name: Cache Gradle
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}

      - name: Run unit tests
        run: ./gradlew testDebugUnitTest

      - name: Decode keystore
        if: github.ref == 'refs/heads/main'
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > release.keystore

      - name: Build release bundle
        if: github.ref == 'refs/heads/main'
        run: ./gradlew bundleRelease
        env:
          KEYSTORE_PATH: ${{ github.workspace }}/release.keystore
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Upload to Play Store
        if: github.ref == 'refs/heads/main'
        run: |
          gem install fastlane
          cd android && fastlane beta
        env:
          KEYSTORE_PATH: ${{ github.workspace }}/release.keystore
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
          GOOGLE_PLAY_JSON_KEY: ${{ secrets.GOOGLE_PLAY_JSON_KEY }}
          BUILD_NUMBER: ${{ github.run_number }}

      - name: Upload APK for PR review
        if: github.event_name == 'pull_request'
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk
```

## Key Commands Reference

```bash
# Fastlane setup
fastlane init                              # Interactive setup
fastlane match init                        # Set up certificate management
fastlane match development                 # Fetch dev certs
fastlane match appstore --readonly         # Fetch production certs (read-only in CI)
fastlane match nuke distribution          # Revoke all distribution certs (nuclear option)

# iOS build commands
fastlane ios test                          # Run unit tests
fastlane ios beta                          # Build + TestFlight
fastlane ios release                       # Build + App Store
fastlane ios screenshots                   # Generate screenshots

# Android build commands
./gradlew assembleDebug                    # Debug APK
./gradlew bundleRelease                    # Release AAB
./gradlew testDebugUnitTest               # Unit tests
./gradlew connectedAndroidTest            # Instrumented tests (requires device/emulator)
fastlane android beta                      # Upload to Play Store

# Xcode Cloud (alternative to GitHub Actions for iOS)
# Configure in Xcode → Product → Xcode Cloud → Create Workflow

# Version management
fastlane run increment_version_number bump_type:minor
fastlane run increment_build_number build_number:$(git rev-list --count HEAD)

# Check Fastlane actions
fastlane actions                           # List all actions
fastlane action upload_to_testflight      # Docs for specific action
```

## Common Patterns

### Pattern 1: Multi-Environment Builds

```ruby
# Fastfile: build for dev, staging, production with different bundle IDs
lane :build_for_environment do |options|
  env = options[:env] || "development"

  # Load environment-specific config
  config = {
    "development" => {
      bundle_id: "com.yourapp.dev",
      scheme: "YourApp-Dev",
      match_type: "development",
      firebase_app_id: ENV["FIREBASE_APP_ID_DEV"],
    },
    "staging" => {
      bundle_id: "com.yourapp.staging",
      scheme: "YourApp-Staging",
      match_type: "adhoc",
      firebase_app_id: ENV["FIREBASE_APP_ID_STAGING"],
    },
    "production" => {
      bundle_id: "com.yourapp",
      scheme: "YourApp",
      match_type: "appstore",
      firebase_app_id: ENV["FIREBASE_APP_ID_PROD"],
    },
  }[env]

  match(type: config[:match_type], app_identifier: config[:bundle_id])

  build_app(
    scheme: config[:scheme],
    xcargs: "FIREBASE_APP_ID=#{config[:firebase_app_id]}"
  )
end
```

### Pattern 2: Automated Changelog from Git

```ruby
# Generate changelog from git commits for TestFlight/Play Store
lane :beta do |options|
  # Get commits since last tag
  changelog = changelog_from_git_commits(
    between: [last_git_tag, "HEAD"],
    pretty: "- %s",
    date_format: "short",
    match_lightweight_tag: false,
    merge_commit_filtering: "exclude_merges",
  )

  # Truncate to Play Store's 500 char limit
  changelog = changelog.slice(0, 490) + "..." if changelog.length > 490

  upload_to_testflight(changelog: changelog)
  # OR: upload_to_play_store(changelog: { "en-US" => changelog })
end
```

### Pattern 3: Parallel Device Testing with Firebase Test Lab

```yaml
# .github/workflows/device-tests.yml
- name: Run tests on Firebase Test Lab
  run: |
    # Build instrumented test APK
    ./gradlew assembleDebugAndroidTest

    # Run on real devices in Firebase Test Lab
    gcloud firebase test android run \
      --type instrumentation \
      --app app/build/outputs/apk/debug/app-debug.apk \
      --test app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
      --device model=Pixel7,version=33,locale=en,orientation=portrait \
      --device model=Pixel4,version=30,locale=en,orientation=portrait \
      --timeout 10m \
      --results-dir "gs://your-bucket/test-results/$GITHUB_SHA" \
      --results-history-name "GitHub Actions Run $GITHUB_RUN_NUMBER"
  env:
    GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
```

## Pitfalls to Avoid

1. **Storing certificates and provisioning profiles in the repo**: Committed .p12 and .mobileprovision files are a security risk and expire without notice. Use Fastlane Match with a private Git repository — Match encrypts certificates with a password, stores them centrally, and automatically fetches the right cert for each build. When a cert expires, `fastlane match renew` updates it for the entire team simultaneously.

2. **Building in Debug configuration for distribution**: TestFlight and Play Store require Release builds with code shrinking enabled. A common mistake is submitting a Debug build (which passes CI but fails App Review) or a Release build without ProGuard/R8 rules that causes crashes at runtime (minification removes reflection-dependent code). Always test the Release build locally before automating distribution.

3. **Not handling keychain access on macOS CI runners**: On macOS GitHub-hosted runners, the default keychain prompts for password. Without `setup_ci` (Fastlane) or `security unlock-keychain -p ""` in your CI script, the build hangs waiting for keychain access. Fastlane's `setup_ci` creates a temporary keychain with no password for the duration of the build — always call it first in CI lanes.

## Related Skills

- `xcode-cloud` — Apple's native CI/CD integrated into Xcode
- `ios-testing` — XCTest, XCUITest patterns
- `android-development` — Gradle build configuration
- `container-security` — Secure secrets management in CI pipelines
- `github-actions-ci-workflow` — General GitHub Actions patterns

## GitNexus Index

```json
{
  "skill": "mobile-ci-cd",
  "category": "devops",
  "triggers": ["mobile ci cd", "fastlane", "testflight automation", "google play deployment", "ios code signing", "fastlane match", "android keystore CI", "xcode github actions", "mobile pipeline", "provisioning profiles CI", "app store connect api key"],
  "outputs": ["fastlane match", "fastlane beta lane", "upload_to_testflight", "upload_to_play_store", "build_app scheme", "gradle bundleRelease", "setup_ci", "ios-ci.yml workflow", "changelog_from_git_commits"],
  "complexity": "high",
  "tools": ["fastlane", "xcode", "gradle", "github-actions", "firebase-test-lab", "app-store-connect", "google-play-console", "match", "cocoapods"]
}
```
