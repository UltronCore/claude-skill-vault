---
name: keyboard-maestro
description: >
  Create and manage Keyboard Maestro macros via CLI and KM's macro XML format. Triggers on: Keyboard Maestro, kmtrigger, KMVAR_, macro trigger, Keyboard Maestro Engine, kmmacros.
---

# Keyboard Maestro

## When to Use

Trigger when building, triggering, or managing Keyboard Maestro macros from Claude Code. Covers the URL scheme trigger, variable passing via KMVAR_, macro XML creation, shell execution from macros, and common automation patterns.

---

## Core Rules

- Keyboard Maestro Engine must be running for `kmtrigger` URL scheme to work
- Variables are passed via environment variables prefixed with `KMVAR_`
- Macro XML files use `.kmmacros` extension
- Import macros via AppleScript or drag into KM window — not via direct file edit
- Synced macros live at `~/Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.kmsync` (or user-configured path)
- Trigger URL scheme format: `kmtrigger://macro=MacroName` or `kmtrigger://macro=UUID`

---

## Triggering Macros from CLI

### By name

```bash
# Basic trigger
open "kmtrigger://macro=My%20Macro%20Name"

# With a parameter (sets KMVAR_parameter in the macro)
open "kmtrigger://macro=Process%20File&value=hello"

# URL-encode special characters
MACRO_NAME="My Macro"
open "kmtrigger://macro=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MACRO_NAME'))")"
```

### By UUID (more reliable — name changes won't break triggers)

```bash
# Get UUID from KM: right-click macro → Copy as → UUID
open "kmtrigger://macro=E12A3456-789B-CDEF-0123-456789ABCDEF"
```

### From shell script (with wait)

```bash
#!/bin/zsh
# Trigger macro and wait for completion signal
MACRO="Build Report"
open "kmtrigger://macro=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$MACRO'))")"
# KM macros run async — use a file sentinel if you need to wait:
# Have the macro write to /tmp/km-done when complete
until [ -f /tmp/km-done ]; do sleep 0.2; done
rm /tmp/km-done
echo "Macro completed"
```

---

## KMVAR_ Variables

Environment variables prefixed with `KMVAR_` are automatically read as Keyboard Maestro local variables.

### Passing variables TO a macro

```bash
# Set variable via env (triggers from shell — not URL scheme)
# Use "Execute Shell Script" trigger or KM's shell action
export KMVAR_InputFile="/path/to/file.txt"
export KMVAR_OutputDir="~/Desktop"
open "kmtrigger://macro=Process%20Document"
```

### Passing values via `value` parameter

```bash
# The URL scheme 'value' parameter sets the KMVAR_kmtriggervalue variable
open "kmtrigger://macro=Send%20Notification&value=Build%20Succeeded"
# Inside macro: use variable %Variable%kmtriggervalue% → "Build Succeeded"
```

### Reading KM variables from shell

KM macros can run shell scripts that read/write variables:

```bash
# In a KM "Execute Shell Script" action:
echo "$KMVAR_MyVariable"           # Read KM variable
echo "new value" > $KMVAR_OutputVar  # Write back (doesn't work — use KM actions instead)
```

### Writing KM variables from shell (via osascript)

```bash
# Set a KM variable from shell
osascript -e 'tell application "Keyboard Maestro Engine" to setvariable "MyVar" to "hello"'

# Read a KM variable from shell
KM_VAR=$(osascript -e 'tell application "Keyboard Maestro Engine" to getvariable "MyVar"')
echo "$KM_VAR"
```

---

## Macro XML Format (.kmmacros)

KM macros are XML. Below is the structure for common macro types.

### Minimal macro skeleton

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <dict>
    <key>Macros</key>
    <array>
      <dict>
        <key>Actions</key>
        <array>
          <!-- Actions go here -->
        </array>
        <key>CreationDate</key>
        <real>700000000</real>
        <key>Enabled</key>
        <true/>
        <key>Name</key>
        <string>My Macro Name</string>
        <key>Triggers</key>
        <array>
          <!-- Triggers go here -->
        </array>
        <key>UID</key>
        <string>AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE</string>
      </dict>
    </array>
    <key>Name</key>
    <string>My Group</string>
    <key>UID</key>
    <string>FFFFFFFF-GGGG-HHHH-IIII-JJJJJJJJJJJJ</string>
  </dict>
</array>
</plist>
```

### Hotkey Trigger

```xml
<dict>
  <key>MacroTriggerType</key>
  <string>HotKey</string>
  <key>KeyCode</key>
  <integer>8</integer>   <!-- C key -->
  <key>Modifiers</key>
  <integer>4352</integer>  <!-- Cmd+Shift = 4352 -->
</dict>
```

Common modifier values:
- `256` = Command
- `512` = Option
- `768` = Command+Option
- `4096` = Shift
- `4352` = Command+Shift
- `4608` = Option+Shift

### Text Expansion Trigger

```xml
<dict>
  <key>MacroTriggerType</key>
  <string>TypedString</string>
  <key>TypedString</key>
  <string>:hello</string>
  <key>SimulateDeleting</key>
  <true/>
</dict>
```

### URL (kmtrigger) Trigger

```xml
<dict>
  <key>MacroTriggerType</key>
  <string>URLTrigger</string>
</dict>
```

### Shell Script Action

```xml
<dict>
  <key>ActionType</key>
  <string>ExecuteScript</string>
  <key>ScriptLanguage</key>
  <string>bash</string>
  <key>ScriptText</key>
  <string>#!/bin/bash
echo "Running from KM"
osascript -e 'display notification "Done!" with title "KM Script"'
</string>
  <key>TimeOut</key>
  <integer>30</integer>
  <key>TrimResults</key>
  <true/>
  <key>Variable</key>
  <string>ScriptOutput</string>
</dict>
```

### Type Text / Text Expansion Action

```xml
<dict>
  <key>ActionType</key>
  <string>InsertText</string>
  <key>InsertionMode</key>
  <string>Typing</string>
  <key>Text</key>
  <string>Hello, %Variable%Name%! Today is %ICUDateTime%EEEE, MMMM d%.</string>
</dict>
```

### Display Notification Action

```xml
<dict>
  <key>ActionType</key>
  <string>Notification</string>
  <key>Title</key>
  <string>Keyboard Maestro</string>
  <key>SubTitle</key>
  <string>Task Complete</string>
  <key>Message</key>
  <string>%Variable%Result%</string>
</dict>
```

---

## Importing Macros via osascript

```bash
# Import a .kmmacros file programmatically
osascript -e 'tell application "Keyboard Maestro" to loadmacros POSIX file "/path/to/macro.kmmacros"'

# Or via shell
open "/path/to/macro.kmmacros"  # Opens in KM for import confirmation
```

---

## Common Macro Patterns

### Clipboard Transform

```
Trigger: Hotkey (e.g., Cmd+Shift+U)
Actions:
  1. Set Variable "Original" to %SystemClipboard%
  2. Execute Shell Script: echo "$KMVAR_Original" | tr '[:lower:]' '[:upper:]'  → Variable "Transformed"
  3. Set Clipboard to %Variable%Transformed%
  4. Type Keystroke: Cmd+V (paste result)
```

XML for the shell action in this pattern:
```xml
<dict>
  <key>ActionType</key>
  <string>ExecuteScript</string>
  <key>ScriptLanguage</key>
  <string>bash</string>
  <key>ScriptText</key>
  <string>echo "$KMVAR_Original" | tr '[:lower:]' '[:upper:]'</string>
  <key>Variable</key>
  <string>Transformed</string>
</dict>
```

### App Launcher / Switcher

```
Trigger: Hotkey
Actions:
  1. Activate/Launch "Obsidian"
```

### Text Expansion with Date

```
Trigger: TypedString ":today"
Actions:
  1. Delete Typed String (simulate backspace × 6)
  2. Insert Text: %ICUDateTime%yyyy-MM-dd%
```

### Window Layout

```
Trigger: Hotkey (Cmd+Opt+1)
Actions:
  1. Move and Resize Window: Front Window → Left Half
  2. Activate "Obsidian"
  3. Move and Resize Window: Front Window → Right Half
```

---

## Calling from Claude Code

```bash
# Notify user that a build succeeded
osascript -e 'tell application "Keyboard Maestro Engine" to setvariable "BuildStatus" to "SUCCESS"'
open "kmtrigger://macro=Build%20Notification"

# Trigger a macro that opens a project in VS Code
PROJECT="my-project"
osascript -e "tell application \"Keyboard Maestro Engine\" to setvariable \"ProjectName\" to \"$PROJECT\""
open "kmtrigger://macro=Open%20Project"

# Read output from a KM macro (KM writes to a variable, shell reads it)
open "kmtrigger://macro=Get%20System%20Info"
sleep 1  # Wait for macro to complete
SYS_INFO=$(osascript -e 'tell application "Keyboard Maestro Engine" to getvariable "SystemInfo"')
echo "$SYS_INFO"
```

---

## Syncing Macros

```bash
# Default sync file location
ls "~/Library/Application Support/Keyboard Maestro/"

# Backup macros
cp "~/Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.kmsync" \
   "~/Desktop/km-backup-$(date +%Y%m%d).kmsync"

# Export all macros via KM app: File → Export Macros
# Import: File → Import Macros
```

---

## KM Variables Reference

| Variable Syntax | Description |
|---|---|
| `%Variable%Name%` | Local/global variable |
| `%SystemClipboard%` | Current clipboard |
| `%CurrentApplication%` | Front app name |
| `%FrontWindowName%` | Front window title |
| `%ICUDateTime%yyyy-MM-dd%` | Formatted date |
| `%ExecutingMacroName%` | Name of running macro |
| `%TriggerValue%` | Value from URL trigger |
| `%KMVAR_name%` | Variable (alternate syntax) |

---

## Debugging

```bash
# Check KM Engine is running
pgrep -x "Keyboard Maestro Engine" && echo "Running" || echo "Not running"

# Start KM Engine from terminal
open -a "Keyboard Maestro Engine"

# View KM log
tail -f ~/Library/Logs/Keyboard\ Maestro/Engine.log

# Test variable read/write
osascript -e 'tell application "Keyboard Maestro Engine" to setvariable "Test" to "hello"'
osascript -e 'tell application "Keyboard Maestro Engine" to getvariable "Test"'
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/app-usage/keyboard-maestro/.gitnexus
Last indexed: 2026-05-23
