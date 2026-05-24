---
name: android-reverse-engineering
description: Reverse engineer Android APKs using jadx, apktool, frida, and static/dynamic analysis workflows to understand app internals, detect malware, or perform security research.
version: 1.0.0
tags: [security, android, reverse-engineering, mobile, apk, jadx, frida]
---

# Android Reverse Engineering

## Overview

This skill provides a structured workflow for decompiling, analyzing, and dynamically instrumenting Android APK files. It covers static analysis with jadx/apktool, dynamic analysis with Frida, and complete security audit workflows. Use it for vulnerability research, malware analysis, CTF challenges, or understanding closed-source apps.

## When to Use

- Analyzing a suspicious APK for malware indicators or data exfiltration
- Security auditing a third-party Android application before enterprise deployment
- CTF challenges involving Android APKs
- Reverse engineering an app to understand its API contract or obfuscation scheme
- Extracting hardcoded secrets, API keys, or certificate pins

## Step-by-Step Workflow

### Phase 1: Reconnaissance & Static Extraction

1. **Obtain and verify the APK**
   ```bash
   # Pull from device
   adb shell pm list packages | grep <app-name>
   adb shell pm path com.target.app
   adb pull /data/app/com.target.app-1/base.apk ./target.apk

   # Verify APK integrity
   apksigner verify --verbose target.apk
   file target.apk  # Should be Zip archive
   ```

2. **Decompile with apktool (resources + smali)**
   ```bash
   apktool d target.apk -o target_decompiled/
   # Flags: -r (no resource decode), -s (no smali), -f (force overwrite)
   ls target_decompiled/
   # AndroidManifest.xml, smali/, res/, assets/, lib/
   ```

3. **Decompile to Java with jadx**
   ```bash
   jadx target.apk -d target_java/ --threads-count 4
   jadx-gui target.apk  # GUI for interactive analysis
   ```

4. **Inspect the manifest first**
   ```bash
   cat target_decompiled/AndroidManifest.xml | grep -E "(permission|activity|service|receiver|provider)"
   # Look for: exported components, dangerous permissions, deeplinks
   ```

### Phase 2: Static Analysis

5. **Search for secrets and hardcoded values**
   ```bash
   grep -r "api_key\|apikey\|secret\|password\|token\|private_key" target_java/ -i
   grep -r "http://\|https://" target_java/ | grep -v "schemas\|android\|google"
   grep -r "AES\|RSA\|MD5\|SHA\|encrypt\|decrypt" target_java/ -i
   ```

6. **Analyze native libraries**
   ```bash
   ls target_decompiled/lib/arm64-v8a/
   strings target_decompiled/lib/arm64-v8a/libapp.so | grep -E "http|key|pass|token"
   nm -D target_decompiled/lib/arm64-v8a/libapp.so  # Symbol table
   ```

7. **Check certificate pinning**
   ```bash
   grep -r "CertificatePinner\|X509TrustManager\|checkServerTrusted\|pinnedCertificate" target_java/ -i
   ```

### Phase 3: Dynamic Analysis with Frida

8. **Set up Frida server on device**
   ```bash
   adb root
   adb push frida-server /data/local/tmp/
   adb shell chmod 755 /data/local/tmp/frida-server
   adb shell /data/local/tmp/frida-server &
   frida-ps -U  # List running processes
   ```

9. **Hook methods at runtime**
   ```javascript
   // hook_crypto.js - Intercept AES encryption
   Java.perform(function() {
     var Cipher = Java.use("javax.crypto.Cipher");
     Cipher.doFinal.overload("[B").implementation = function(data) {
       console.log("doFinal called with: " + bytesToHex(data));
       var result = this.doFinal(data);
       console.log("Result: " + bytesToHex(result));
       return result;
     };
   });
   ```
   ```bash
   frida -U -l hook_crypto.js -f com.target.app --no-pause
   ```

10. **Bypass certificate pinning**
    ```javascript
    // certpin_bypass.js
    Java.perform(function() {
      var TrustManager = Java.registerClass({
        name: "com.custom.TrustManager",
        implements: [Java.use("javax.net.ssl.X509TrustManager")],
        methods: {
          checkClientTrusted: function(chain, authType) {},
          checkServerTrusted: function(chain, authType) {},
          getAcceptedIssuers: function() { return []; }
        }
      });
    });
    ```

### Phase 4: Traffic Interception

11. **Route traffic through Burp Suite**
    ```bash
    # On host
    adb shell settings put global http_proxy <host-ip>:8080

    # Install Burp CA on device (Android < 7)
    adb push burp_ca.cer /sdcard/
    adb shell am start -n com.android.certinstaller/.CertInstallerMain \
      --es name "Burp CA" --es certPath /sdcard/burp_ca.cer
    ```

## Key Commands Reference

```bash
# jadx batch decompile + search
jadx target.apk -d out/ && grep -r "BuildConfig\|API_URL" out/

# Smali to Java mental model: v0-vN are registers, p0=this
# Find all exported Activities
aapt dump xmltree target.apk AndroidManifest.xml | grep -A2 "exported"

# Frida trace all methods in a class
frida-trace -U -j 'com.target.app.NetworkClient!*' com.target.app

# objection for automated analysis
objection -g com.target.app explore
> android sslpinning disable
> android hooking list classes

# Pull app databases
adb shell run-as com.target.app cp /data/data/com.target.app/databases/app.db /sdcard/
adb pull /sdcard/app.db
sqlite3 app.db .tables
```

## Common Patterns

### Pattern 1: API Key Extraction
```bash
# Step 1: Search compiled strings
jadx target.apk -d out/ 2>/dev/null
grep -r "X-Api-Key\|Authorization\|Bearer" out/ --include="*.java"

# Step 2: Check BuildConfig
find out/ -name "BuildConfig.java" -exec cat {} \;

# Step 3: Search native strings
find target_decompiled/lib -name "*.so" -exec strings {} \; | grep -i "key\|token\|secret"
```

### Pattern 2: Reverse-Engineer Custom Obfuscation
```bash
# Map ProGuard obfuscated names using mapping file
# Find mapping.txt in build artifacts or crash reports
jadx --deobf target.apk -d out_deobf/  # auto deobfuscation
# Manual: look for single-letter class names — likely obfuscated
```

### Pattern 3: Modify & Repack APK
```bash
apktool d target.apk -o modified/
# Edit smali files to patch logic
# e.g., change if-eqz to if-nez to flip a condition
vim modified/smali/com/target/app/LicenseCheck.smali
apktool b modified/ -o modified_unsigned.apk
# Sign with debug key
keytool -genkey -v -keystore debug.keystore -alias debug -keyalg RSA -keysize 2048 -validity 10000
jarsigner -verbose -keystore debug.keystore modified_unsigned.apk debug
adb install modified_unsigned.apk
```

## Pitfalls to Avoid

1. **Root detection bypasses needed**: Many apps detect rooted devices or Frida presence. Use Magisk with Zygisk + LSPosed + XPrivacyLua to hide root. For Frida detection, rename the binary: `mv frida-server frida-server32` and use `--no-pause` with spawn mode.

2. **Multi-dex apps**: Large apps use multiple dex files. jadx handles this automatically, but apktool may require `--only-main-classes`. Check `classes2.dex`, `classes3.dex` — auth logic often lives in secondary dex files.

3. **Legal and ethical boundaries**: Always have written authorization before analyzing a production app. Reverse engineering for security research is legal in most jurisdictions under responsible disclosure frameworks, but modifying and redistributing is not. Maintain a clear audit trail.

## Related Skills

- `security-pen-testing` — Full application penetration testing
- `c-security-review` — Native code (C/C++) security review
- `semgrep-rule-creator` — Static analysis rule creation
- `api-security-hardening` — Securing the server-side APIs discovered

## GitNexus Index

```json
{
  "skill": "android-reverse-engineering",
  "category": "security",
  "triggers": ["apk", "android reverse", "jadx", "frida", "decompile android", "apktool", "smali", "malware android"],
  "outputs": ["decompiled source", "hooked runtime", "extracted secrets", "traffic analysis"],
  "complexity": "high",
  "tools": ["jadx", "apktool", "frida", "objection", "adb", "burpsuite"]
}
```
