---
name: applescript-jxa
description: >
  macOS automation with AppleScript and JavaScript for Automation (JXA). Triggers on: AppleScript, JXA, osascript, tell application, JavaScript for Automation, System Events, keystroke, do shell script.
---

# AppleScript & JXA (JavaScript for Automation)

## When to Use

Trigger when automating macOS apps natively: clicking UI elements, typing text, controlling Finder, driving Safari/Chrome, showing dialogs, or integrating shell commands. Use JXA for complex logic; use AppleScript when scripting dictionaries are better documented in AppleScript.

---

## Core Rules

- Run scripts via `osascript -e '...'` (inline) or `osascript script.applescript` (file)
- JXA files use `.js` extension: `osascript -l JavaScript script.js`
- System Events is required for UI scripting — must enable in System Settings > Privacy > Accessibility
- Prefer JXA for anything requiring loops, data transformation, or API calls
- AppleScript string concatenation uses `&` not `+`
- JXA uses standard JS syntax — async is NOT supported; use `delay()` for pauses

---

## AppleScript Basics

### Syntax fundamentals

```applescript
-- Comments start with --
-- Variables
set myVar to "hello"
set myNum to 42
set myList to {1, 2, 3}

-- String concatenation
set greeting to "Hello, " & "world"

-- Conditionals
if myNum > 10 then
    display dialog "Big number"
else
    display dialog "Small number"
end if

-- Repeat loops
repeat with i from 1 to 5
    log i
end repeat

repeat with item in myList
    log item
end repeat

-- Functions (handlers)
on greet(name)
    return "Hello, " & name
end greet

set result to greet("Example User")
```

### tell blocks

```applescript
-- Target an application
tell application "Finder"
    set frontWindow to front window
    set folderPath to POSIX path of (target of frontWindow as alias)
end tell

-- Nested tell
tell application "System Events"
    tell process "Finder"
        click menu item "New Folder" of menu "File" of menu bar 1
    end tell
end tell
```

### Running shell commands from AppleScript

```applescript
set output to do shell script "ls ~/Desktop"
set output to do shell script "echo $HOME" with administrator privileges
set filePath to do shell script "date +%Y-%m-%d"
```

---

## JXA Basics

### Structure

```javascript
// JXA: run via `osascript -l JavaScript script.js`

function run(argv) {
  // argv is array of CLI arguments
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;

  const result = app.displayDialog("Hello from JXA!", {
    defaultAnswer: "",
    buttons: ["Cancel", "OK"],
    defaultButton: "OK",
  });

  return result.textReturned;
}
```

### Application access

```javascript
const finder = Application("Finder");
const safari = Application("Safari");
const systemEvents = Application("System Events");

// Activate (bring to front)
finder.activate();

// Check if running
finder.running(); // true/false
```

---

## Dialogs & Notifications

### AppleScript

```applescript
-- Basic dialog
display dialog "Message here" buttons {"Cancel", "OK"} default button "OK"

-- Input dialog
set userInput to text returned of (display dialog "Enter value:" default answer "")

-- Choose from list
set chosen to choose from list {"Apple", "Banana", "Cherry"} with prompt "Pick one:"

-- File chooser
set chosenFile to POSIX path of (choose file with prompt "Select a file:")

-- Folder chooser
set chosenFolder to POSIX path of (choose folder with prompt "Select folder:")

-- Notification
display notification "Task complete" with title "My Script" subtitle "Step 1"

-- Alert (no input)
display alert "Error occurred" message "Could not connect." as critical
```

### JXA

```javascript
const app = Application.currentApplication();
app.includeStandardAdditions = true;

// Dialog with input
const result = app.displayDialog("Enter your name:", {
  defaultAnswer: "Example User",
  buttons: ["Cancel", "OK"],
  defaultButton: "OK",
  withTitle: "Input Required",
});
const name = result.textReturned;

// Choose from list
const chosen = app.chooseFromList(["Option A", "Option B", "Option C"], {
  withPrompt: "Select an option:",
  defaultItems: ["Option A"],
});

// Notification
app.displayNotification("Done!", { withTitle: "Script Complete", subtitle: "All steps finished" });
```

---

## System Events (UI Scripting)

### Click a button / menu item

```applescript
tell application "System Events"
    tell process "Finder"
        -- Click a button
        click button "OK" of window 1

        -- Click menu item
        click menu item "Preferences…" of menu "Finder" of menu bar 1

        -- Type text
        keystroke "hello world"
        keystroke return

        -- Key combos
        key code 0 using {command down}  -- Cmd+A (select all)
        keystroke "c" using {command down}  -- Cmd+C (copy)
        keystroke "v" using {command down}  -- Cmd+V (paste)
        keystroke "z" using {command down, shift down}  -- Cmd+Shift+Z

        -- Click at coordinates
        click at {500, 300}
    end tell
end tell
```

### JXA System Events

```javascript
const se = Application("System Events");
const proc = se.processes["Finder"];

// Click a button
proc.windows[0].buttons.whose({ name: "OK" })[0].click();

// Type text
se.keystroke("hello world");
se.keyCode(36); // Return key

// Key combo: Cmd+A
se.keystroke("a", { using: "command down" });
```

---

## Finder Automation

```applescript
tell application "Finder"
    -- Get desktop path
    set desktopPath to POSIX path of (path to desktop)

    -- List files in folder
    set fileList to every file of folder (POSIX file "~/Desktop" as alias)
    repeat with f in fileList
        log name of f
    end repeat

    -- Create new folder
    make new folder at desktop with properties {name: "New Folder"}

    -- Move file
    move file "~/Desktop/file.txt" to folder "~/Documents"

    -- Open folder in new window
    open POSIX file "~/Documents"

    -- Reveal file in Finder
    reveal POSIX file "~/Desktop/report.pdf"
    activate
end tell
```

---

## Safari Automation (JXA)

```javascript
const safari = Application("Safari");
safari.activate();

// Get current URL
const url = safari.documents[0].url();
const title = safari.documents[0].name();

// Navigate to URL
safari.documents[0].url = "https://example.com";

// Execute JavaScript in page
const pageTitle = safari.doJavaScript("document.title", { in: safari.documents[0] });
const bodyText = safari.doJavaScript("document.body.innerText", { in: safari.documents[0] });

// Click element via JS
safari.doJavaScript("document.querySelector('#submit-btn').click()", { in: safari.documents[0] });

// Fill form field
safari.doJavaScript("document.querySelector('#email').value = 'test@example.com'", {
  in: safari.documents[0],
});
```

---

## Chrome Automation (JXA)

```javascript
const chrome = Application("Google Chrome");
chrome.activate();

const tab = chrome.windows[0].activeTab;

// Get URL and title
const url = tab.url();
const title = tab.title();

// Navigate
tab.url = "https://example.com";

// Execute JS
const result = chrome.execute(tab, { javascript: "document.title" });

// Open new tab
chrome.windows[0].tabs.push(chrome.Tab({ url: "https://google.com" }));
```

---

## Clipboard Operations

```applescript
-- AppleScript
set the clipboard to "text to copy"
set clipText to the clipboard
```

```javascript
// JXA
const app = Application.currentApplication();
app.includeStandardAdditions = true;

// Set clipboard
app.setTheClipboardTo("text to copy");

// Get clipboard
const clipText = app.theClipboard();
```

---

## Running from Claude Code (osascript)

```bash
# Inline AppleScript
osascript -e 'display notification "Build complete!" with title "Claude Code"'

# Inline JXA
osascript -l JavaScript -e '
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  app.displayNotification("Done!", { withTitle: "Claude Code" });
'

# From file
osascript ~/scripts/my-macro.applescript
osascript -l JavaScript ~/scripts/my-script.js

# Pass arguments to JXA
osascript -l JavaScript script.js "arg1" "arg2"
# Access via: function run(argv) { const arg = argv[0]; }

# Capture output in shell
RESULT=$(osascript -e 'return "hello from AppleScript"')
echo $RESULT
```

---

## Shell Script Integration

```applescript
-- Run shell, capture output, use in script
set gitStatus to do shell script "cd ~/project && git status --short"
if gitStatus is not "" then
    display dialog "Uncommitted changes:\n" & gitStatus
end if

-- Open terminal and run command
tell application "Terminal"
    activate
    do script "cd ~/project && npm run dev"
end tell

-- Run with admin privileges
do shell script "rm -rf /tmp/cache" with administrator privileges
```

---

## Practical Examples

### Show a clipboard transform notification

```bash
osascript -l JavaScript << 'EOF'
const app = Application.currentApplication();
app.includeStandardAdditions = true;
const se = Application("System Events");

// Read clipboard, transform, write back
const clip = app.theClipboard();
const upper = clip.toUpperCase();
app.setTheClipboardTo(upper);
app.displayNotification("Clipboard uppercased!", { withTitle: "Transform" });
EOF
```

### Launch app if not running

```applescript
if application "Obsidian" is not running then
    tell application "Obsidian" to activate
    delay 2
end if
tell application "Obsidian" to activate
```

### Batch rename files on Desktop

```javascript
// JXA batch rename
const finder = Application("Finder");
const desktop = finder.desktop;
const files = desktop.files();

files.forEach((file, i) => {
  const name = file.name();
  if (name.startsWith("Screen Shot")) {
    file.name = `screenshot-${String(i).padStart(3, "0")}.png`;
  }
});
```
