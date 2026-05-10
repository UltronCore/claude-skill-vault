---
name: app-store-connect
description: >
  App Store submission, TestFlight distribution, App Store Connect API automation,
  and release management workflows. Triggers on: App Store Connect, TestFlight,
  archive, upload, App Store review, ASC API, altool, xcrun notarytool,
  xcodebuild archive, fastlane deliver.
---

# App Store Connect & Submission

## When to Use
- Archiving and uploading a build to App Store Connect
- Automating version bumps, TestFlight uploads, or release notes
- Managing TestFlight groups and external testers
- Investigating common App Store review rejections
- Using the App Store Connect API for CI/CD automation

## Core Rules
1. Never use `altool` — it is deprecated (Xcode 14+). Use `xcodebuild -exportArchive` + `xcrun altool` was replaced by `notarytool` and the Transporter CLI.
2. Code signing must be configured before archiving — use automatic signing in Xcode or explicit provisioning profiles in CI.
3. Archive with `xcodebuild archive`, export IPA with `xcodebuild -exportArchive`, then upload with `xcrun altool` or the Transporter app / `xcrun notarytool` (macOS) — or just `xcodebuild -allowProvisioningUpdates` with the destination `upload`.
4. App Store Connect API keys (`.p8`) are more reliable than Apple ID + app-specific password in CI; they never expire and don't require 2FA.
5. Build number must be unique per version per platform — automate it with `CI_BUILD_NUMBER` or git commit count.
6. TestFlight external testing requires a beta review (usually < 1 day); internal testing is instant.
7. Use phased release for major updates — roll out to 1%/2%/5%/10%/20%/50%/100% over 7 days; pause if crash rate spikes.
8. `agvtool` or direct `PlistBuddy` edits are the fastest way to bump build numbers in scripts.
9. App Store review typically takes 24–48 hours; expedite review only for critical bugs or time-sensitive launches.
10. Keep a `.xcconfig` file for each environment (dev/staging/prod) — never hardcode bundle IDs or API endpoints in code.

## Archive + Upload (xcodebuild)

```bash
#!/bin/bash
# build-and-upload.sh
set -euo pipefail

SCHEME="MangaReader"
PROJECT="MangaReader.xcodeproj"      # or .xcworkspace if using CocoaPods/SPM
ARCHIVE_PATH="$HOME/builds/MangaReader.xcarchive"
EXPORT_PATH="$HOME/builds/MangaReader-export"
EXPORT_OPTIONS_PLIST="ExportOptions.plist"

# 1. Bump build number to git commit count
BUILD_NUMBER=$(git rev-list --count HEAD)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "MangaReader/Info.plist"

# 2. Archive
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
  | xcpretty   # optional: prettier output

# 3. Export IPA
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

# 4. Upload to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file "$EXPORT_PATH/MangaReader.ipa" \
  --apiKey "$ASC_API_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --private-key "$ASC_PRIVATE_KEY_PATH"
  
# Or use Transporter CLI:
# xcrun iTMSTransporter -m upload -f "$EXPORT_PATH/MangaReader.ipa" \
#   -apiKey "$ASC_API_KEY_ID" -apiIssuer "$ASC_ISSUER_ID"
```

```xml
<!-- ExportOptions.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>  <!-- or: development, ad-hoc, enterprise -->
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

## App Store Connect API (REST)

```python
#!/usr/bin/env python3
# asc_api.py — list TestFlight builds and set release notes
import jwt, time, requests, json

KEY_ID      = "XXXXXXXXXX"           # from ASC > Users & Access > Keys
ISSUER_ID   = "xxxxxxxx-xxxx-..."    # from same page
PRIVATE_KEY = open("AuthKey_XXXXXXXXXX.p8").read()

def generate_token() -> str:
    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,   # max 20 minutes
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, PRIVATE_KEY, algorithm="ES256", headers={"kid": KEY_ID})

TOKEN = generate_token()
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
BASE = "https://api.appstoreconnect.apple.com/v1"

# List all apps
apps = requests.get(f"{BASE}/apps", headers=HEADERS).json()
app_id = apps["data"][0]["id"]

# List recent builds
builds = requests.get(
    f"{BASE}/builds",
    params={"filter[app]": app_id, "sort": "-uploadedDate", "limit": 5},
    headers=HEADERS
).json()

for build in builds["data"]:
    attrs = build["attributes"]
    print(f"Version {attrs['version']} ({attrs['buildAudienceType']}) — {attrs['processingState']}")

# Add localized "What to Test" notes to a build
build_id = builds["data"][0]["id"]
beta_build_localizations = requests.get(
    f"{BASE}/builds/{build_id}/betaBuildLocalizations",
    headers=HEADERS
).json()

for loc in beta_build_localizations["data"]:
    if loc["attributes"]["locale"] == "en-US":
        requests.patch(
            f"{BASE}/betaBuildLocalizations/{loc['id']}",
            headers=HEADERS,
            json={"data": {"type": "betaBuildLocalizations", "id": loc["id"],
                           "attributes": {"whatsNew": "Fixed chapter image loading. Added dark mode."}}}
        )
```

## fastlane Workflow

```ruby
# fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Upload to TestFlight"
  lane :beta do
    # Increment build number using git commit count
    increment_build_number(build_number: sh("git rev-list --count HEAD").strip)
    
    # Build and sign
    build_app(
      scheme: "MangaReader",
      export_method: "app-store",
      output_directory: "./build",
      xcargs: "-allowProvisioningUpdates"
    )
    
    # Upload to TestFlight
    upload_to_testflight(
      api_key_path: "fastlane/api_key.json",   # ASC API key JSON
      skip_waiting_for_build_processing: true,
      groups: ["Internal Testers"]
    )
    
    # Notify Slack (optional)
    slack(message: "New MangaReader beta uploaded!", channel: "#ios-builds")
  end
  
  desc "Submit to App Store review"
  lane :release do
    build_app(scheme: "MangaReader", export_method: "app-store")
    upload_to_app_store(
      api_key_path: "fastlane/api_key.json",
      submit_for_review: true,
      automatic_release: false,
      phased_release: true,
      force: true  # skip HTML preview
    )
  end
end
```

```json
// fastlane/api_key.json
{
  "key_id": "XXXXXXXXXX",
  "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
  "in_house": false
}
```

## Version & Build Number Automation

```bash
# Bump marketing version (CFBundleShortVersionString) — e.g., 1.2.3
xcrun agvtool new-marketing-version 1.2.3

# Bump build number to git commit count
BUILD=$(git rev-list --count HEAD)
xcrun agvtool new-version -all $BUILD

# Or with PlistBuddy (more targeted):
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.2.3" MangaReader/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD"           MangaReader/Info.plist
```

## Common Rejection Reasons & Fixes

| Rejection | Root cause | Fix |
|-----------|-----------|-----|
| 2.1 — App Completeness | Placeholder content, broken nav | Test every tab and flow before submitting |
| 2.3.3 — Accurate metadata | Screenshots from wrong device/OS | Generate fresh screenshots per device family |
| 3.1.1 — Payments | Digital goods sold outside IAP | Use StoreKit 2 for all purchasable content |
| 4.0 — Design: copycat | Icons/UI too close to system apps | Differentiate visual design |
| 5.1.1 — Data collection | No privacy policy, missing NSUsageDescription | Add privacy manifest + all NSUsageDescription keys |
| 2.5.4 — Background execution | App uses background modes it doesn't need | Remove unused entitlements |
| Guideline 1.4 — Physical damage | Missing crisis/safety resources in certain categories | Add safety resources if relevant |

## Privacy Manifest (Required iOS 17+)

Create `PrivacyInfo.xcprivacy` in your app target:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key><false/>
    <key>NSPrivacyCollectedDataTypes</key><array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>CA92.1</string></array>  <!-- app functionality -->
        </dict>
    </array>
</dict>
</plist>
```

## TestFlight Distribution

```bash
# Add external tester group via ASC API
curl -X POST "$BASE/betaGroups/$GROUP_ID/relationships/betaTesters" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [{"type": "betaTesters", "id": "TESTER_ID"}]
  }'

# Get tester ID by email first:
curl "$BASE/betaTesters?filter[email]=tester@example.com" \
  -H "Authorization: Bearer $TOKEN"
```
